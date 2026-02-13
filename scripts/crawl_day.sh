#!/usr/bin/env bash
set -euo pipefail

TWITTER_TOKEN="${TWITTER_TOKEN:-}"

# tweet-harvest always writes under tweets-data/
PART_DIR="tweets-data/data"

# final dataset that will be committed to the repo
FINAL_DIR="data"

mkdir -p "$PART_DIR"
mkdir -p "$FINAL_DIR"

WINDOW_HOURS=6

# ---- time limit (seconds) ----
TIME_LIMIT=60
START_TS=$(date +%s)
# --------------------------------

# must be provided by GitHub Actions
SINCE_DATE="${CRAWL_DATE:?CRAWL_DATE is required}"
UNTIL_DATE=$(date -u -d "${SINCE_DATE} +1 day" +"%Y-%m-%d")

echo "Crawl day: since ${SINCE_DATE}, until ${UNTIL_DATE}"
echo "Time limit: ${TIME_LIMIT}s"

i=0
out_files=()

while true; do

  # ---- global time guard ----
  now=$(date +%s)
  elapsed=$((now - START_TS))
  if [ "$elapsed" -ge "$TIME_LIMIT" ]; then
    echo "Time limit reached (${elapsed}s). Stopping crawl loop."
    break
  fi
  # ---------------------------

  window_start=$(date -u -d "${SINCE_DATE} +${i} hours" +"%Y-%m-%dT%H:%M:%SZ")
  window_end=$(date -u -d "${window_start} +${WINDOW_HOURS} hours" +"%Y-%m-%dT%H:%M:%SZ")

  if [[ "$(date -u -d "$window_start" +%s)" -ge "$(date -u -d "${UNTIL_DATE}T00:00:00Z" +%s)" ]]; then
    break
  fi

  fname="${PART_DIR}/_part_${SINCE_DATE}_w${i}.csv"

  echo "Fetching window ${window_start} -> ${window_end}"

  SEARCH='pemilu OR jokowi OR prabowo OR capres OR pilpres'
  QUERY="${SEARCH} since:${SINCE_DATE} until:${UNTIL_DATE} lang:id"

  # protect single crawl execution
  timeout 55s npx -y tweet-harvest@2.6.1 \
    -o "${fname}" \
    -s "${QUERY}" \
    --tab "LATEST" \
    -l 1000 \
    --token "${TWITTER_TOKEN}" || echo "tweet-harvest timed out"

  if [[ -f "${fname}" ]]; then
    out_files+=("${fname}")
  fi

  i=$((i + WINDOW_HOURS))
done

FINAL="${FINAL_DIR}/${SINCE_DATE}.csv"

first=true
> "$FINAL"

for f in "${out_files[@]}"; do
  if [[ ! -f "$f" ]]; then
    continue
  fi

  if $first; then
    cat "$f" >> "$FINAL"
    first=false
  else
    tail -n +2 "$f" >> "$FINAL"
  fi
done

# cleanup partial files
rm -f "${PART_DIR}/_part_${SINCE_DATE}_w"*.csv

echo "Final file created: $FINAL"
ls -lh "$FINAL_DIR"
