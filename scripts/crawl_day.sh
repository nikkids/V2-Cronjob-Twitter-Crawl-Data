#!/usr/bin/env bash
set -euo pipefail

if [ -z "${TWITTER_TOKEN:-}" ]; then
  echo "TWITTER_TOKEN is not set"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"

DATA_DIR="data"
CURSOR_FILE="${DATA_DIR}/.cursor_date"

OUT_DIR="tweets-data/output"

mkdir -p "$DATA_DIR"
mkdir -p "$OUT_DIR"

SINCE_DATE=$(cat "$CURSOR_FILE")
UNTIL_DATE=$(date -u -d "${SINCE_DATE} +1 day" +"%Y-%m-%d")

echo "Crawl day: since ${SINCE_DATE}, until ${UNTIL_DATE}"

WINDOW_HOURS=6
SEARCH='pemilu OR jokowi OR prabowo OR capres OR pilpres'

i=0
files=()

while true; do
  window_start=$(date -u -d "${SINCE_DATE} +${i} hours" +"%Y-%m-%dT%H:%M:%SZ")
  window_end=$(date -u -d "${window_start} +${WINDOW_HOURS} hours" +"%Y-%m-%dT%H:%M:%SZ")

  if [[ "$(date -u -d "$window_start" +%s)" -ge "$(date -u -d "${UNTIL_DATE}T00:00:00Z" +%s)" ]]; then
    break
  fi

  fname="tweets_${SINCE_DATE}_w${i}.csv"

  echo "Fetching window ${window_start} -> ${window_end}"

  npx -y tweet-harvest@2.6.1 \
    -o "tweets-data/output/${fname}" \
    -s "${SEARCH} since:${window_start} until:${window_end} lang:id" \
    --tab "LATEST" \
    -l 500 \
    --token "${TWITTER_TOKEN}" || true

  if [ -f "tweets-data/output/${fname}" ]; then
    files+=("tweets-data/output/${fname}")
  fi

  i=$((i + WINDOW_HOURS))
done

FINAL_FILE="${DATA_DIR}/pemilu_${SINCE_DATE}.csv"

echo "Merging to ${FINAL_FILE}"

first=true
> "${FINAL_FILE}"

for f in "${files[@]}"; do
  if $first; then
    cat "$f" >> "${FINAL_FILE}"
    first=false
  else
    tail -n +2 "$f" >> "${FINAL_FILE}"
  fi
done

NEXT_DATE=$(date -u -d "${SINCE_DATE} +1 day" +"%Y-%m-%d")
echo "${NEXT_DATE}" > "${CURSOR_FILE}"

echo "Saved ${FINAL_FILE}"
echo "Next cursor: ${NEXT_DATE}"
