#!/usr/bin/env bash
set -euo pipefail

SEARCH='pemilu OR jokowi OR prabowo OR capres OR pilpres'
WINDOW_HOURS=6

DATA_DIR="data"
TMP_DIR="tmp"

mkdir -p "$DATA_DIR"
mkdir -p "$TMP_DIR"

# read cursor
CURSOR_FILE="data/.cursor_date"
SINCE_DATE=$(cat "$CURSOR_FILE")

# stop after 3 months
END_DATE="2019-07-19"

UNTIL_DATE=$(date -u -d "${SINCE_DATE} +1 day" +"%Y-%m-%d")

echo "Crawl day: since ${SINCE_DATE}, until ${UNTIL_DATE}"

if [[ "$(date -d "$SINCE_DATE" +%s)" -ge "$(date -d "$END_DATE" +%s)" ]]; then
  echo "Reached end date. Stop crawling."
  exit 0
fi

out_files=()
i=0

while true; do
  window_start=$(date -u -d "${SINCE_DATE} +${i} hours" +"%Y-%m-%dT%H:%M:%SZ")
  window_end=$(date -u -d "${window_start} +${WINDOW_HOURS} hours" +"%Y-%m-%dT%H:%M:%SZ")

  if [[ "$(date -u -d "$window_start" +%s)" -ge "$(date -u -d "${UNTIL_DATE}T00:00:00Z" +%s)" ]]; then
    break
  fi

  fname="${TMP_DIR}/tweets_${SINCE_DATE}_w${i}.csv"

  echo "Fetching window ${window_start} -> ${window_end}"

  QUERY="${SEARCH} since:${window_start} until:${window_end} lang:id"

  timeout 5m npx -y tweet-harvest@2.6.1 \
    -o "$fname" \
    -s "$QUERY" \
    --tab "LATEST" \
    -l 500 \
    --token "${TWITTER_TOKEN}" || true

  out_files+=("$fname")

  i=$((i + WINDOW_HOURS))
done


FINAL="${DATA_DIR}/pemilu_${SINCE_DATE}.csv"

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

# advance cursor
date -d "${SINCE_DATE} +1 day" +"%Y-%m-%d" > "$CURSOR_FILE"

echo "Saved $FINAL"
