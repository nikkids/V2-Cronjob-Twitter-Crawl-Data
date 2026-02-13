#!/usr/bin/env bash
set -euo pipefail

TWITTER_TOKEN="${TWITTER_TOKEN:-}"
PART_DIR="data"
FINAL_DIR="data"

mkdir -p "tweets-data/${PART_DIR}"
mkdir -p "${FINAL_DIR}"

WINDOW_HOURS=6

# ---- SETTINGS ----
TIME_LIMIT=210         # Global limit for this step
SAFETY_BUFFER=30      # Don't start a new scrape if less than 30s remain
# ------------------

START_TS=$(date +%s)
SINCE_DATE="${CRAWL_DATE:?CRAWL_DATE is required}"
UNTIL_DATE=$(date -u -d "${SINCE_DATE} +1 day" +"%Y-%m-%d")

echo "Crawl day: ${SINCE_DATE} -> ${UNTIL_DATE}"
echo "Time limit: ${TIME_LIMIT}s (Safety buffer: ${SAFETY_BUFFER}s)"

i=0
out_files=()

while true; do
  # 1. CHECK TIME
  now=$(date +%s)
  elapsed=$((now - START_TS))
  remaining=$((TIME_LIMIT - elapsed))

  # If we have less time left than the buffer, STOP now.
  if [ "$remaining" -lt "$SAFETY_BUFFER" ]; then
    echo "Time remaining (${remaining}s) is less than safety buffer (${SAFETY_BUFFER}s). Stopping."
    break
  fi

  # 2. CHECK DATE BOUNDARY
  window_start=$(date -u -d "${SINCE_DATE} +${i} hours" +"%Y-%m-%dT%H:%M:%SZ")
  if [[ "$(date -u -d "$window_start" +%s)" -ge "$(date -u -d "${UNTIL_DATE}T00:00:00Z" +%s)" ]]; then
    break
  fi

  fname="${PART_DIR}/_part_${SINCE_DATE}_w${i}.csv"
  echo "Fetching window ${window_start} (Time left: ${remaining}s)"

  SEARCH='pemilu OR jokowi OR prabowo OR capres OR pilpres'
  QUERY="${SEARCH} since:${SINCE_DATE} until:${UNTIL_DATE} lang:id"

  # 3. RUN WITH TIMEOUT
  # We give it slightly less than the remaining time to ensure we catch it here
  RUN_TIMEOUT=$((remaining - 5))
  
  # Ensure timeout is at least 10s, otherwise skip
  if [ "$RUN_TIMEOUT" -lt 10 ]; then echo "Not enough time to start process."; break; fi

  # We add "|| true" to ignore the crash error when timeout kills it
  timeout "${RUN_TIMEOUT}s" npx -y tweet-harvest@2.6.1 \
    -o "${fname}" \
    -s "${QUERY}" \
    --tab "LATEST" \
    -l 1000 \
    --token "${TWITTER_TOKEN}" || true

  # 4. COLLECT DATA
  real_file="tweets-data/${fname}"
  if [[ -f "${real_file}" && -s "${real_file}" ]]; then
    echo "Saved: ${real_file}"
    out_files+=("${real_file}")
  fi

  i=$((i + WINDOW_HOURS))
done

# 5. MERGE FILES
FINAL="${FINAL_DIR}/${SINCE_DATE}.csv"
> "$FINAL"

echo "Merging ${#out_files[@]} files..."

first=true
for f in "${out_files[@]}"; do
  if [[ ! -f "$f" ]]; then continue; fi
  if $first; then
    cat "$f" >> "$FINAL"
    first=false
  else
    tail -n +2 "$f" >> "$FINAL"
  fi
done

# Cleanup temp files
rm -f "tweets-data/${PART_DIR}/_part_${SINCE_DATE}_w"*.csv

echo "Final file created: $FINAL"
exit 0
