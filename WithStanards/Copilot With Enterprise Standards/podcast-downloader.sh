#!/bin/sh

## podcast-downloader.sh
## - Wrapper to download a week's worth of podcast episodes using npx podcast-dl
##
## Usage:
##   podcast-downloader.sh --file podcasts.csv [--after YYYY-MM-DD] [--before YYYY-MM-DD]
##
## Notes:
##   - Always includes meta, episode meta, transcripts and images per standards
##   - Uses `podcast_helper.py daterange` to compute default date range

hasProgram () {
    command -v "$1" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: $1 is not installed." 1>&2
        exit 1
    fi
}

hasProgram "python3"
hasProgram "curl"
hasProgram "npx"

log() {
    LEVEL="$1"
    MESSAGE="$2"
    TS=$(date "+%d/%b/%Y:%H:%M:%S %z")
    if [ "${LEVEL}" = "ERROR" ]; then
        STATUS="failure"
    else
        STATUS="success"
    fi
    echo "[${LEVEL}] [status=${STATUS}] [${TS}] -- ${MESSAGE}"
}

show_help() {
    cat "$0" | grep "##" | sed 's/^## //'
}

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

CSV_FILE="podcasts.csv"
AFTER=""
BEFORE=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --file)
            CSV_FILE="$2"; shift 2;;
        --after)
            AFTER="$2"; shift 2;;
        --before)
            BEFORE="$2"; shift 2;;
        --help|-h)
            show_help; exit 0;;
        *)
            echo "Unknown arg: $1" 1>&2; show_help; exit 1;;
    esac
done

if [ ! -f "$CSV_FILE" ]; then
    log "ERROR" "CSV file not found: ${CSV_FILE}"
    exit 1
fi

# Compute default date range using macOS `date -v` when available, else python helper
if [ -z "$AFTER" ] || [ -z "$BEFORE" ]; then
    if date -v+1d +"%m/%d/%Y" >/dev/null 2>&1; then
        BEFORE=$(date -v+1d +"%m/%d/%Y")
        AFTER=$(date -v-7d +"%m/%d/%Y")
    else
        DATES=$(python3 podcast_helper.py daterange_mmdd 2>/dev/null)
        set -- $DATES
        AFTER="$1"
        BEFORE="$2"
    fi
fi

log "INFO" "Using date range after=${AFTER} before=${BEFORE}"

# Iterate CSV rows (skip header)
tail -n +2 "$CSV_FILE" | while IFS=, read -r FOLDER BASEURL FEEDURL || [ -n "$FOLDER" ]; do
    FOLDER=$(echo "$FOLDER" | sed 's/^ *//; s/ *$//')
    FEEDURL=$(echo "$FEEDURL" | sed 's/^ *//; s/ *$//')
    if [ -z "$FOLDER" ] || [ -z "$FEEDURL" ]; then
        log "ERROR" "Skipping invalid CSV row"
        continue
    fi

    mkdir -p "$FOLDER"
    FEED_FILE="$FOLDER/feed.rss"
    log "INFO" "Downloading feed for ${FOLDER} from ${FEEDURL}"
    curl -L -s -o "$FEED_FILE" "$FEEDURL"
    if [ $? -ne 0 ] || [ ! -s "$FEED_FILE" ]; then
        log "ERROR" "Failed to download feed for ${FOLDER}"
        continue
    fi

    log "INFO" "Invoking npx podcast-dl for ${FOLDER} (out-dir=${FOLDER})"
    npx podcast-dl --include-meta --include-episode-meta --include-episode-transcripts --include-episode-images \
        --after "$AFTER" --before "$BEFORE" --file "$FEED_FILE" --out-dir "$FOLDER"
    if [ $? -ne 0 ]; then
        log "ERROR" "npx podcast-dl failed for ${FOLDER}"
    fi

done

log "INFO" "Done"
