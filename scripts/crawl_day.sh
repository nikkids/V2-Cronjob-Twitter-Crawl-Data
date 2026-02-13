#!/usr/bin/env bash
set -Eeuo pipefail

#####################################
# Config
#####################################

TIME_LIMIT=60            # seconds
WINDOW_HOURS=6

OUT_DIR="data"
mkdir -p "$OUT_DIR"

START_TIME=$(date +%s)

#####################################
# Required env from workflow
#####################################

: "${CRAWL_DATE:?CRAWL_DATE is required}"
: "${TWITTER_TOKEN:?TWITTER_TOKEN is required}"

SINCE_DATE="$CRAWL_DATE"
UNTIL_DATE=$(date -u -d "${SINCE_DATE} +1 day" +"%Y-%m-%d")

echo "Crawl day: since ${SINCE_DATE}, until ${UNTIL_DATE}"
echo "Time limit: ${TIME_LIMIT}s"

#####################################
# Helpers
#####################################

time_up() {
  now=$(date +%s)
  (( now - START_TIME >= TIME_LIMIT ))
}

#####################################
# Main loop
#####################################

i=0
out_files=()

while true; do

  if time_up; then
    echo "Time limit reached. Stop crawling."
    break
  fi

  window_start=$(date -u -d "${SINCE_DATE} +${i} hours" +"%Y-%m-%dT%H:%M:%SZ")

  if [[ "$(date -u -d "$window_start" +%s)" -ge \
        "$(date -u -d "${UNTIL_DATE}T00:00:00Z" +%s)" ]]; then
    break
  fi

  fname="${OUT_DIR}/_part_${SINCE_DATE}_w${i}.csv"

  echo "Fetching window ${window_start}"

  SEARCH='pemilu OR jokowi OR prabowo OR capres OR pilpres'
  QUERY="${SEARCH} since:${SINCE_DATE} until:${UNTIL_DATE} lang:id"

  #
  # IMPORTANT:
  # tweet-harvest MUST be wrapped by timeout
  #
  timeout 55s \
    npx -y tweet-harvest@2.6.1 \
      -o "${fname}" \
      -s "${QUERY}" \
      --tab "LATEST" \
      -l 1000 \
      --token "${TWITTER_TOKEN}" \
    || echo "Window timed out or failed, continue..."

  if [[ -f "$fname" ]]; then
    out_files+=("$fname")
  fi

  i=$((i + WINDOW_HOURS))

done

#####################################
# Merge files
#####################################

FINAL="${OUT_DIR}/${SINCE_DATE}.csv"

first=true
: > "$FINAL"

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

#####################################
# Cleanup
#####################################

rm -f "${OUT_DIR}/_part_${SINCE_DATE}_w"*.csv || true

echo "Final file created: $FINAL"
ls -lh "$OUT_DIR"
