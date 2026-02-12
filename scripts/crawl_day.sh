#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${TWITTER_TOKEN:-}" ]]; then
  echo "TWITTER_TOKEN is not set"
  exit 1
fi

START_LIMIT="2019-07-19"   # stop after 3 months

CURSOR_FILE=".cursor_date"
OUT_DIR="data"

mkdir -p "$OUT_DIR"

CURRENT_DATE=$(cat "$CURSOR_FILE")

if [[ "$CURRENT_DATE" > "$START_LIMIT" ]]; then
  echo "Finished 3-month range. Nothing to crawl."
  exit 0
fi

NEXT_DATE=$(date -d "$CURRENT_DATE +1 day" +"%Y-%m-%d")

FILE_NAME="pemilu_${CURRENT_DATE}.csv"
OUT_PATH="${OUT_DIR}/${FILE_NAME}"

SEARCH='pemilu OR jokowi OR prabowo OR capres OR pilpres'
QUERY="${SEARCH} since:${CURRENT_DATE} until:${NEXT_DATE} lang:id"

echo "Crawling date: $CURRENT_DATE"
echo "Query: $QUERY"
echo "Output: $OUT_PATH"

# IMPORTANT: hard timeout to avoid endless loop
timeout 12m npx -y tweet-harvest@2.6.1 \
  -o "$OUT_PATH" \
  -s "$QUERY" \
  --tab "LATEST" \
  -l 1000 \
  --token "$TWITTER_TOKEN" || true

# advance cursor
echo "$NEXT_DATE" > "$CURSOR_FILE"

echo "Done. Cursor moved to $NEXT_DATE"
