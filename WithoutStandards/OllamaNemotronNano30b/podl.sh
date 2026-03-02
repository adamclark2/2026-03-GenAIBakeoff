#!/usr/bin/env sh
# =============================================================================
# podl.sh – Podcast downloader that reads a CSV (Folder,URL,Feed URL)
#
#   • Skips the header automatically.
#   • Creates <Folder>/hello.rss.xml from each feed URL.
#   • Calls: npx podcast-dl with an actual 7‑day window ending today.
#
# Usage:
#      ./podl.sh </full/path/to/file.csv>
#
# =============================================================================

# set -eu                     # abort on unexpected errors; we trap only expected cases.

# --------------------------------------------------- helper utilities
trim_leading_trailing() {
    # $1 = variable name (passed by reference)
    # Example:   eval "var=$(trim_leading_trailing 'folder')"
    local var_name=$1
    local val_var
    eval "val_var=\${$var_name}"
    # strip leading & trailing whitespace via awk
    printf '%s' "$val_var" |
        awk '{ $1=$NF=""; sub(/[ \t]+$/,""); print }'
}
# --------------------------------------------------- usage message
usage() {
    cat >&2 <<'EOF'
Usage: $0 <csv-file>

The CSV must contain a header line exactly like:
Folder,URL,Feed URL

Each following line creates a directory (first field) and downloads the feed
specified in the third field. Example:

   Folder,URL,Feed URL
   audiopodcast-hello,https://example.com/hello,https://feeds.example.com/hello.rss
EOF
    exit 1
}
# --------------------------------------------------- argument handling
if [ $# -ne 1 ]; then usage; fi

CSV_FILE=$1                  # keep the argument exactly as typed
[ ! -r "$CSV_FILE" ] && { echo "Error: cannot read '$CSV_FILE'" >&2; exit 2; }

echo "Using CSV file: $CSV_FILE"
echo "--------------------------------------------------"

# --------------------------------------------------- compute a rolling 7‑day window
TODAY=$(date +"%m/%d/%Y")
if uname | grep -qi darwin; then                # macOS → BSD date syntax
    SEVEN_DAYS_AGO=$(date -v-7d +"%m/%d/%Y")
else                                            # Assume GNU coreutils (Linux)
    if date -d "7 days ago" >/dev/null 2>&1; then
        SEVEN_DAYS_AGO=$(date -d "7 days ago" +"%m/%d/%Y")
    else                                       # Fallback using epoch arithmetic
        now_sec=$(date +%s)
        seven_sec=$((now_sec - 7*24*60*60))
        SEVEN_DAYS_AGO=$(date -r "$seven_sec" +"%m/%d/%Y") || true
    fi
fi

echo "Downloading podcasts for the window $SEVEN_DAYS_AGO → $TODAY"
echo "--------------------------------------------------"

# --------------------------------------------------- main processing loop
# --------------------------------------------------- main processing loop
#
# Process‑substitution replaces the pipeline, so the loop runs in the
# current shell and can see every line – even a final line that does not
# end with a newline.
#
while IFS= read -r RAW_LINE || [ -n "$RAW_LINE" ]; do   # ← READ LAST LINE TOO
    echo "DEBUG: ← raw line = |$RAW_LINE| length=${#RAW_LINE}" >&2   # <‑‑ DEBUG INFO

    # --------------------------------------------------- 1️⃣ Skip blank lines
    case "$RAW_LINE" in (*[[:space:]]*) continue;; esac

    # --------------------------------------------------- 2️⃣ Split CSV fields
    folder=$(cut -d',' -f1 <<<"$RAW_LINE")                     # column‑1 → folder name
    feed_raw=$(cut -d',' -f3- <<<"$RAW_LINE")                  # everything after the 2nd comma

    # --------------------------------------------------- 3️⃣ Trim whitespace (both ends)
    # leading trim – remove longest run of spaces/tabs at the start
    folder=${folder#"${folder%%[![:space:]]*}"}
    feed_url=$feed_raw
    feed_url=${feed_url#"${feed_url%%[![:space:]]*}"}         # strip left spaces

    # trailing trim – remove any trailing space/tab characters
    folder=${folder%"${folder##*[![:space:]]}"}
    feed_url=${feed_url%"${feed_url##*[![:space:]]}"}

    # --------------------------------------------------- 4️⃣ Validate fields
    if [ -z "$folder" ]; then
        echo "Warning: missing folder name in line → $RAW_LINE" >&2
        continue
    fi
    if [ -z "$feed_url" ]; then
        echo "Warning: empty feed URL in line → $RAW_LINE" >&2
        continue
    fi

    # --------------------------------------------------- 5️⃣ Do the work
    mkdir -p "$folder"
    feed_file="${folder}/hello.rss.xml"

    echo "Downloading feed for '${folder}' → ${feed_file}"
    curl -L -o "$feed_file" "$feed_url"

    echo "Running podcast‑dl for '${folder}'"
    npx podcast-dl \
        --include-meta \
        --include-episode-meta \
        --include-episode-transcripts \
        --include-episode-images \
        --before   "$TODAY" \
        --after    "$SEVEN_DAYS_AGO" \
        --file     "$feed_file"

    echo "--------------------------------------------------"
done < <(tail -n +2 "$CSV_FILE")                           

echo "All done!"
# ================================================