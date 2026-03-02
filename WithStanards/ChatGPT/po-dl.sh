#!/bin/sh

## Podcast Downloader
## - Downloads one week of podcast episodes for each feed listed in a CSV file.
## - For each podcast:
##     1. Downloads the RSS feed via curl (follows redirects).
##     2. Uses npx podcast-dl to download episodes from the last 7 days.
## - Implements enterprise logging (STDOUT + optional remote HEC).
##
## Usage:
##   ./podcast-downloader.sh podcasts.csv
##
## $1 - Path to CSV file (required)
##
## Environment Variables:
##   HEC_REMOTE_LOG - Optional HTTP endpoint for remote log ingestion.
##                    If unset or empty, remote logging is disabled.
##
## CSV Format:
##   Header must be:
##     Folder,URL,Feed URL
##
## NOTE:
##   CSV file MUST end with a blank newline character.
##   Script will exit if it does not.

########################################
# Help
########################################

if [ "$1" = "--help" ]; then
    grep "^##" "$0" | sed 's/^## //'
    exit 0
fi

########################################
# Logging
########################################

log () {
    LEVEL="$1"
    STATUS="$2"
    MESSAGE="$3"

    TIMESTAMP="$(date '+%d/%b/%Y:%H:%M:%S %z')"

    echo "[$LEVEL] [status=$STATUS] [$TIMESTAMP] -- $MESSAGE"

    if [ -n "$HEC_REMOTE_LOG" ]; then
        JSON_PAYLOAD="{\"event\":\"$MESSAGE\",\"level\":\"$LEVEL\",\"status\":\"$STATUS\",\"sourcetype\":\"script\",\"time\":\"$TIMESTAMP\"}"
        curl -s -X POST -H "Content-Type: application/json" \
            -d "$JSON_PAYLOAD" "$HEC_REMOTE_LOG" >/dev/null 2>&1
    fi
}

########################################
# Dependency Checks
########################################

hasProgram () {
    command -v "$1" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log "ERROR" "failure" "$1 is not installed."
        exit 1
    fi
}

hasProgram "curl"
hasProgram "npx"
hasProgram "date"
hasProgram "awk"
hasProgram "sed"
hasProgram "tail"

########################################
# Argument Validation
########################################

CSV_FILE="$1"

if [ -z "$CSV_FILE" ]; then
    log "ERROR" "failure" "CSV file required."
    exit 1
fi

if [ ! -f "$CSV_FILE" ]; then
    log "ERROR" "failure" "CSV file not found: $CSV_FILE"
    exit 1
fi

if [ ! -s "$CSV_FILE" ]; then
    log "ERROR" "failure" "CSV file is empty: $CSV_FILE"
    exit 1
fi

########################################
# CSV Validation
########################################

# Validate trailing newline
LAST_CHAR="$(tail -c 1 "$CSV_FILE" 2>/dev/null)"
if [ "$LAST_CHAR" != "" ]; then
    log "ERROR" "failure" "CSV file must end with a newline character."
    exit 1
fi

# Validate header
HEADER="$(head -n 1 "$CSV_FILE")"
EXPECTED_HEADER="Folder,URL,Feed URL"

if [ "$HEADER" != "$EXPECTED_HEADER" ]; then
    log "ERROR" "failure" "Invalid CSV header. Expected: $EXPECTED_HEADER"
    exit 1
fi

########################################
# Date Range (Last 7 Days)
########################################

TODAY="$(date '+%m/%d/%Y')"
WEEK_AGO="$(date -d '7 days ago' '+%m/%d/%Y' 2>/dev/null)"

# macOS compatibility
if [ -z "$WEEK_AGO" ]; then
    WEEK_AGO="$(date -v -7d '+%m/%d/%Y')"
fi

########################################
# Main Processing
########################################

log "INFO" "success" "Starting podcast download process."

# Skip header row and safely handle last line without newline
tail -n +2 "$CSV_FILE" | while IFS=',' read -r FOLDER URL FEED_URL || [ -n "$FOLDER" ]
do
    if [ -z "$FOLDER" ] || [ -z "$FEED_URL" ]; then
        log "ERROR" "failure" "Invalid CSV row encountered."
        continue
    fi

    log "INFO" "success" "Processing podcast: $FOLDER"

    mkdir -p "$FOLDER"

    RSS_FILE="$FOLDER/feed.rss.xml"

    curl -L -s -o "$RSS_FILE" "$FEED_URL"

    if [ $? -ne 0 ] || [ ! -s "$RSS_FILE" ]; then
        log "ERROR" "failure" "Failed to download RSS feed for $FOLDER"
        continue
    fi

    log "INFO" "success" "Downloaded RSS feed for $FOLDER"

    BEFORE_COUNT="$(ls "$FOLDER"/*.mp3 2>/dev/null | wc -l | tr -d ' ')"

    npx --yes podcast-dl \
        --include-meta \
        --include-episode-meta \
        --include-episode-transcripts \
        --include-episode-images \
        --before "$TODAY" \
        --after "$WEEK_AGO" \
        --file "$RSS_FILE" \
        --out-dir "$FOLDER"

    if [ $? -ne 0 ]; then
        log "ERROR" "failure" "podcast-dl execution failed for $FOLDER"
        continue
    fi

    AFTER_COUNT="$(ls "$FOLDER"/*.mp3 2>/dev/null | wc -l | tr -d ' ')"

    if [ "$AFTER_COUNT" -gt "$BEFORE_COUNT" ]; then
        DOWNLOADED=$((AFTER_COUNT - BEFORE_COUNT))
        log "INFO" "success" "Downloaded $DOWNLOADED episode(s) for $FOLDER"
    else
        log "INFO" "success" "No episodes found in date range for $FOLDER"
    fi

done

log "INFO" "success" "Podcast download process finished."
exit 0