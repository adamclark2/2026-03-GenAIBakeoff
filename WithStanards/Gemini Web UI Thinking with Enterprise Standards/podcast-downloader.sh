#!/bin/bash

## Podcast Downloader
## - Downloads a week's worth of podcasts based on a CSV input file.
##
## Usage:
##   ./podcast_downloader.sh [csv_file]
##
## Arguments:
##   $1 - Path to the CSV file containing Folder, URL, and Feed URL.
##
## Environment Variables:
##   HEC_REMOTE_LOG - (Optional) URL for remote logging HEC.
##
## Standards Compliance:
## - Self-documenting help text (##)
## - Dependency aware (hasProgram)
## - Structured logging (JSON for remote, formatted for STDOUT)

# --- Help Text Logic ---
if [ "$1" == "--help" ]; then
    cat "$0" | grep "##" | tr -d "#"
    exit 0
fi

# --- Dependency Awareness ---
hasProgram () {
    command -v "$1" >/dev/null 2>&1
    HAS_PROGRAM="$?"
    if [ $HAS_PROGRAM -ne 0 ]; then
        echo "Error: $1 is not installed."
        exit 1
    fi
}

hasProgram "curl"
hasProgram "npx"
hasProgram "date"

# --- Logging Logic ---
log() {
    local level="$1"
    local status="$2"
    local message="$3"
    local timestamp=$(date +"%d/%b/%Y:%H:%M:%S.000 %z")
    
    # Standard Out Logging
    echo "[$level] [status=$status] [$timestamp] -- $message"

    # Remote HEC Logging
    if [ -n "$HEC_REMOTE_LOG" ]; then
        local payload="{\"event\": \"$message\", \"level\": \"$level\", \"status\": \"$status\", \"sourcetype\": \"script\", \"time\": \"$timestamp\"}"
        curl -s -X POST "$HEC_REMOTE_LOG" -d "$payload" > /dev/null 2>&1
    fi
}

# --- Validation ---
CSV_FILE="$1"
if [ -z "$CSV_FILE" ]; then
    log "ERROR" "failure" "No CSV file provided as argument."
    exit 1
fi

if [ ! -f "$CSV_FILE" ]; then
    log "ERROR" "failure" "CSV file not found: $CSV_FILE"
    exit 1
fi

# --- Date Calculation (Portable for macOS/Linux) ---
# Detect if we are using GNU date or BSD date (macOS)
if date --version >/dev/null 2>&1; then
    # GNU Date (Linux)
    DATE_BEFORE=$(date -d "tomorrow" +"%Y-%m-%d")
    DATE_AFTER=$(date -d "7 days ago" +"%Y-%m-%d")
else
    # BSD Date (macOS)
    DATE_BEFORE=$(date -v+1d +"%Y-%m-%d")
    DATE_AFTER=$(date -v-7d +"%Y-%m-%d")
fi

log "INFO" "success" "Target date range: After $DATE_AFTER until Before $DATE_BEFORE"

# --- Process CSV ---
# Header: Folder, URL, Feed URL
{
    read # Skip header row
    while IFS=, read -r folder url feed_url || [ -n "$folder" ]; do
        # Clean potential carriage returns from Windows-formatted CSVs
        folder=$(echo "$folder" | tr -d '\r')
        feed_url=$(echo "$feed_url" | tr -d '\r')

        if [ -z "$folder" ] || [ -z "$feed_url" ]; then
            continue
        fi

        log "INFO" "success" "Processing feed: $folder"

        # 1. Create directory
        mkdir -p "$folder"
        # Use subshell to handle cd so we don't lose our place if it fails
        (
            if cd "$folder"; then
                # 2. Download the RSS XML
                RSS_FILE="feed.rss.xml"
                log "INFO" "success" "Downloading feed XML from $feed_url"
                
                if curl -L -s -o "$RSS_FILE" "$feed_url"; then
                    # 3. Use npx podcast-dl to download episodes
                    log "INFO" "success" "Running podcast-dl for $folder [Range: $DATE_AFTER to $DATE_BEFORE]"
                    
                    npx podcast-dl --include-meta \
                                   --include-episode-meta \
                                   --include-episode-transcripts \
                                   --include-episode-images \
                                   --before "$DATE_BEFORE" \
                                   --after "$DATE_AFTER" \
                                   --file "$RSS_FILE"
                    
                    if [ $? -eq 0 ]; then
                        log "INFO" "success" "Successfully processed $folder"
                    else
                        log "WARN" "failure" "podcast-dl encountered an issue with $folder"
                    fi
                else
                    log "ERROR" "failure" "Failed to download RSS feed for $folder"
                fi
            else
                log "ERROR" "failure" "Could not enter directory $folder"
            fi
        )

    done 
} < "$CSV_FILE"

log "INFO" "success" "Podcast download script completed."