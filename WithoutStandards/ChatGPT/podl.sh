#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 podcasts.csv"
  exit 1
fi

CSV_FILE="$1"

# ---- Date range: last 7 days ----
TODAY=$(date +"%m/%d/%Y")
ONE_WEEK_AGO=$(date -v -7d +"%m/%d/%Y" 2>/dev/null || date -d "7 days ago" +"%m/%d/%Y")

echo "Downloading podcasts from $ONE_WEEK_AGO to $TODAY"
echo

# Open CSV on FD 3
exec 3< "$CSV_FILE"

# Skip header
read -r _ <&3

while IFS=',' read -r FOLDER URL FEED_URL <&3
do
  [[ -z "$FOLDER" ]] && continue

  echo "Processing: $FOLDER"
  echo "Feed URL: $FEED_URL"

  mkdir -p "$FOLDER"
  pushd "$FOLDER" > /dev/null

  FEED_FILE="feed.rss.xml"

  echo "Downloading feed..."
  curl -L -f -o "$FEED_FILE" "$FEED_URL"

  echo "Downloading episodes..."
    if ! npx podcast-dl \
    --include-meta \
    --include-episode-meta \
    --include-episode-transcripts \
    --include-episode-images \
    --before "$TODAY" \
    --after "$ONE_WEEK_AGO" \
    --file "$FEED_FILE" \
    < /dev/null
    then
    echo "Warning: podcast-dl returned non-zero status for $FOLDER"
    fi

  popd > /dev/null

  echo "Finished: $FOLDER"
  echo "----------------------------------------"

done

exec 3<&-

echo "All podcasts processed."