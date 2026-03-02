#!/usr/bin/env bash

# podcast_downloader.sh
#
# A simple bash wrapper that reads a CSV of podcasts and uses the
# `podcast-dl` npm package to fetch a week's worth of episodes for each
# feed.  The CSV is expected to have a header row with the columns in
# the following order:
#
#   Folder,URL,Feed URL
#
# Example row:
#
#   audiopodcast-hello,https://example.com/hello,https://example.com/hello.feed
#
# Usage:
#
#   ./podcast_downloader.sh podcasts.csv
#

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <csv-file>" >&2
    exit 1
fi

csvfile="$1"

if [[ ! -f "$csvfile" ]]; then
    echo "CSV file '$csvfile' not found" >&2
    exit 1
fi

# compute date range: after = 7 days ago, before = today
# on macOS `date` supports -v; fall back to Linux-style if needed
if date -v-1d >/dev/null 2>&1; then
    before=$(date +%m/%d/%Y)
    after=$(date -v-7d +%m/%d/%Y)
else
    before=$(date +%m/%d/%Y)
    after=$(date -d '7 days ago' +%m/%d/%Y)
fi

# strip header and iterate lines
 tail -n +2 "$csvfile" | while IFS=, read -r folder url feed;
 do
    # trim possible whitespace
    folder=$(echo "$folder" | xargs)
    url=$(echo "$url" | xargs)
    feed=$(echo "$feed" | xargs)

    if [[ -z "$folder" || -z "$feed" ]]; then
        echo "Skipping invalid line: $folder,$url,$feed" >&2
        continue
    fi

    echo "Processing podcast '$folder' (feed: $feed)"
    mkdir -p "$folder"

    # let podcast-dl fetch the RSS itself; files will be placed under the
    # output directory, which also keeps the feed XML alongside the
    # downloaded episodes (podcast-dl saves a copy of the feed automatically).
    echo "  invoking podcast-dl from $after to $before (out-dir=$folder)"
    npx podcast-dl \
        --include-meta \
        --include-episode-meta \
        --include-episode-transcripts \
        --include-episode-images \
        --before "$before" \
        --after "$after" \
        --url "$feed" \
        --out-dir "$folder" \
        || echo "  npx podcast-dl failed for $folder" >&2

done
