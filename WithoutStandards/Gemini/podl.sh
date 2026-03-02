#!/bin/bash

CSV_FILE="$1"

if [[ ! -f "$CSV_FILE" ]]; then
    echo "Error: $CSV_FILE not found."
    exit 1
fi

# Compatibility fix for Date (Works on both macOS/BSD and Linux/GNU)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS/BSD style
    DATE_TODAY=$(date +"%m/%d/%Y")
    DATE_LAST_WEEK=$(date -v-7d +"%m/%d/%Y")
else
    # Linux/GNU style
    DATE_TODAY=$(date +"%m/%d/%Y")
    DATE_LAST_WEEK=$(date -d "7 days ago" +"%m/%d/%Y")
fi

echo "Target Range: $DATE_LAST_WEEK to $DATE_TODAY"
echo "----------------------------------------------------------------"

# Skip header and process CSV
tail -n +2 "$CSV_FILE" | while IFS=',' read -r folder url feed_url
do
    # Remove hidden Windows line endings (\r)
    folder=$(echo "$folder" | tr -d '\r')
    feed_url=$(echo "$feed_url" | tr -d '\r')
    xml_file="${folder}.rss.xml"

    echo "Processing Folder: $folder"
    
    # Download the feed
    echo "  -> Fetching RSS: $feed_url"
    curl -L -s -o "$xml_file" "$feed_url"

    # Run downloader with explicit week-long range
    npx podcast-dl \
        --include-meta \
        --include-episode-meta \
        --include-episode-transcripts \
        --include-episode-images \
        --after "$DATE_LAST_WEEK" \
        --before "$DATE_TODAY" \
        --file "$xml_file"

    echo "  -> Finished $folder"
    echo "----------------------------------------------------------------"
done