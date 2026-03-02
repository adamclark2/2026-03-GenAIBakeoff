#!/bin/sh

#=====================================================================
## Podcast Downloader
## -------------------------------------------------------------------
## Reads a CSV (Folder,URL,Feed URL) and for each row:
##   • creates the target folder,
##   • downloads the feed XML with curl (‑L to follow redirects),
##   • calculates a week‑long window from today,
##   • runs `npx podcast-dl` with all required switches.
##
## Usage
##   ./podcast_downloader.sh [csv_file]
##
## Options
##   -h | --help      Show this help text and exit.
##
## Environment variables
##   HEC_REMOTE_LOG – If set, a JSON‑style payload is printed to STDOUT
##                    in addition to the human readable log line.
##=====================================================================

#---------------------------------------------------------------------
## Self‑documenting help extraction
## All lines that start with ## are part of this script’s documentation.
## `print_help` extracts them and displays a nicely indented version.
##---------------------------------------------------------------------
print_help() {
    # Print every line that begins with “##”, strip the leading marker,
    # then indent four spaces so it looks nice on the terminal.
    awk '/^##/ { sub(/^#?/, ""); print }' "$0" |
        sed 's/^/    /'
}

#---------------------------------------------------------------------
## Dependency check
## Abort early if a required external program is missing.
##---------------------------------------------------------------------
hasProgram() {
    command -v "$1" >/dev/null 2>&1
}
if ! hasProgram "curl"; then
    echo "Error: curl is not installed." >&2; exit 1
fi

#---------------------------------------------------------------------
## Logging helper
##   * Human‑readable logs → STD_ERR (standard error)
##   * If HEC_REMOTE_LOG is set, a JSON payload line → STDOUT
##---------------------------------------------------------------------
log() {
    level="$1"
    shift
    msg="$*"

    # ISO‑8601 timestamp in the local timezone (as required by the standard)
    ts=$(date +"%Y-%m-%dT%H:%M:%S %z")
    printf '[%s] [status=%s] [%s] -- %s\n' "$level" "${STATUS:-unknown}" "$ts" "$msg" >&2

    if [ -n "${HEC_REMOTE_LOG-}" ]; then
        json=$(printf '{"event":"%s","level":"%s","status":"%s","time":"%s"}' \
            "$msg" "$level" "${STATUS:-unknown}" "$ts")
        printf '%s\n' "$json"
    fi
}
STATUS="success"

#---------------------------------------------------------------------
## Cleanup – always executed (trap on EXIT)
##---------------------------------------------------------------------
cleanup() {
    log "INFO" "Cleaning up…"
}
trap cleanup EXIT

#=====================================================================
## Main processing
##=====================================================================
main() {
    # -----------------------------------------------------------------
    ## 1️⃣ Locate the CSV file (argument or STDIN)
    ## -----------------------------------------------------------------
    csv_file="${1:-/dev/stdin}"
    if [ ! -f "$csv_file" ]; then
        log "ERROR" "File not found: $csv_file"
        exit 1
    fi
    log "INFO" "Reading CSV file: $csv_file"

    # -----------------------------------------------------------------
    ## 2️⃣ Iterate over every line of the CSV, skipping blank lines.
    ##    The redirection `< "$csv_file"` is attached to the whole loop,
    ##    so the shell never blocks waiting for input from a terminal.
    ## -----------------------------------------------------------------
    while IFS=',' read -r folder url feedurl; do
        # Guard against completely empty rows
        [ -z "$folder" ] && continue

        log "DEBUG" "Top of loop"

        log "INFO" "Processing entry – Folder: $folder, Feed URL: $feedurl"
        log "DEBUG" "   After guard"

        # -------------------------------------------------------------
        ## 4️⃣ Create (or reuse) the target directory
        ## -------------------------------------------------------------
        mkdir -p "$folder" || {
            log "ERROR" "Unable to create folder '$folder'"
            continue
        }
        pushd "$folder" > /dev/null

        # -------------------------------------------------------------
        ## 5️⃣ Download the feed XML (‑L follows redirects)
        ## -------------------------------------------------------------
        xml_file="feed.xml"
        if ! curl -L -o "$xml_file" "$feedurl"; then
            log "ERROR" "Failed to download $feedurl"
            popd > /dev/null
            continue
        fi

        # -------------------------------------------------------------
        ## 6️⃣ Compute the week‑long window (format matches the README)
        ## -------------------------------------------------------------
        today=$(date +"%m/%d/%Y")
        if date --version 2>/dev/null | grep -q GNU; then   # GNU coreutils
            week_ago=$(date -d "7 days ago" +"%m/%d/%Y")
        else                                                   # BSD/macOS date
            week_ago=$(date -v-"7"d +"%m/%d/%Y")
        fi
        log "INFO" "Downloading episodes from $week_ago to $today"

        # -------------------------------------------------------------
        ## 7️⃣ Run the podcast‑dl command with all required switches
        ## -------------------------------------------------------------
        npx podcast-dl \
            --include-meta \
            --include-episode-meta \
            --include-episode-transcripts \
            --include-episode-images \
            --before "$today" \
            --after  "$week_ago" \
            --file   "$xml_file"
        poddl_status=$?

        if [ $poddl_status -ne 0 ]; then
            STATUS="failure"
            log "ERROR" "npx podcast-dl exited with code $poddl_status"
            popd > /dev/null
            continue
        fi

        # -------------------------------------------------------------
        ## 8️⃣ Success logging for this entry
        ## -------------------------------------------------------------
        STATUS="success"
        log "INFO" "Successfully downloaded episodes for folder '$folder'"

        popd > /dev/null   # leave temporary directory
    done < "$csv_file"

    log "INFO" "All entries processed."
}

#=====================================================================
## Argument handling & entry point
##=====================================================================
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    print_help | sed 's/^/    /'   # indent for prettier terminal display
    exit 0
fi

# Run the main routine; any error will be caught by the trap above.
main "$@"