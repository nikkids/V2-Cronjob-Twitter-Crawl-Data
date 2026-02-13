#!/usr/bin/env bash
set -euo pipefail

TWITTER_TOKEN="${TWITTER_TOKEN:-}"

# Required from workflow
SINCE_DATE="${CRAWL_DATE:?CRAWL_DATE is required}"
UNTIL_DATE=$(date -u -d "${SINCE_DATE} +1 day" +"%Y-%m-%d")

WINDOW_HOURS=6

# IMPORTANT: match tweet-harvest real folder behaviour
BASE_DIR="tweets-data/data"
PART_DIR="${BASE_DIR}/parts"
FINAL_DIR="data"

mkdir -p "$PART_DIR"
mkdir -p "$FINAL_DIR"

echo "Crawl day: since ${SINCE_DATE}, until ${UNTIL_DATE}"

START_TIME=$(date +%s)
TIME_LIMIT=60

i=0
out_files=()

while true; do
  NOW=$(date +%s)
  ELAPSED=$((NOW - START_TIME))

  if [ "$ELAPSED" -ge "$TIME_LIMIT" ]; then
    echo "Time limit reached. Stopping crawler loop."
    break
  fi

  window_start=$(date -u -d "${SINCE_DATE} +${i} hours" +"%Y-%m-%dT%H:%M:%SZ")
  window_end=$(date -u -d "${window_start} +${WINDOW_HOURS} hours" +"%Y-%m-%dT%H:%M:%SZ")

  if [[ "$(date -u -d "$window_start" +%s)" -ge "$(date -u -d "${UNTIL_DATE}T00:00:00Z" +%s)" ]]; then
    break
  fi

  fname="${PART_DIR}/_part_${SINCE_DATE}_w${i}.csv"

  echo "Fetching window ${window_start} -> ${window_end}"

  SEARCH='pemilu OR jokowi OR prabowo OR capres OR pilpres'
  QUERY="${SEARCH} since:${SINCE_DATE} until:${UNTIL_DATE} lang:id"

  echo "Time limit: ${TIME_LIMIT}s"

  # HARD STOP the crawler itself
  timeout 55s npx -y tweet-harvest@2.6.1 \
    -o "${fname}" \
    -s "${QUERY}" \
    --tab "LATEST" \
    -l 1000 \
    --token "${TWITTER_TOKEN}" || true

  if [ -f "$fname" ]; then
    out_files+=("$fname")
  fi

  i=$((i + WINDOW_HOURS))
done

FINAL="${FINAL_DIR}/${SINCE_DATE}.csv"

first=true
> "$FINAL"

for f in "${out_files[@]}"; do
  if [[ ! -s "$f" ]]; then
    continue
  fi

  if $first; then
    cat "$f" >> "$FINAL"
    first=false
  else
    tail -n +2 "$f" >> "$FINAL"
  fi
done

rm -f "${PART_DIR}/_part_${SINCE_DATE}_w"*.csv

echo "Final file created: $FINAL"
ls -lh "$FINAL_DIR"
