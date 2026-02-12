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
mkdir -p "$OUT_DIR"
mkdir -p "$DATA_DIR"

WINDOW_HOURS=6

SINCE_DATE="$(cat "$CURSOR_FILE")"
UNTIL_DATE="$(date -u -d "${SINCE_DATE} +1 day" +"%Y-%m-%d")"

echo "Crawl day: since ${SINCE_DATE}, until ${UNTIL_DATE}"

SEARCH='pemilu OR jokowi OR prabowo OR capres OR pilpres'
QUERY="${SEARCH} since:${SINCE_DATE} until:${UNTIL_DATE} lang:id"

i=0
out_files=()

while true; do
  window_start=$(date -u -d "${SINCE_DATE} +${i} hours" +"%Y-%m-%dT%H:%M:%SZ")

  if [[ "$(date -u -d "$window_start" +%s)" -ge "$(date -u -d "${UNTIL_DATE}T00:00:00Z" +%s)" ]]; then
    break
  fi

  fname="output/tweets_${SINCE_DATE}_w${i}.csv"

  echo "Fetching window ${window_start} -> ${UNTIL_DATE} (date based query)"

  npx -y tweet-harvest@2.6.1 \
    -o "${fname}" \
    -s "${QUERY}" \
    --tab "LATEST" \
    -l 1000 \
    --token "${TWITTER_TOKEN}" || true

  if [[ -f "$fname" ]]; then
    out_files+=("$fname")
  fi

  i=$((i + WINDOW_HOURS))
done

FINAL="${DATA_DIR}/pemilu_${SINCE_DATE}.csv"
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

NEXT_DATE="$(date -u -d "${SINCE_DATE} +1 day" +"%Y-%m-%d")"
echo "$NEXT_DATE" > "$CURSOR_FILE"

echo "Saved $FINAL"
echo "Next cursor: $NEXT_DATE"
