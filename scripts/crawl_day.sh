#!/usr/bin/env bash
set -euo pipefail

# -------------------------
# Config
# -------------------------
MAX_RUNTIME=60          # seconds (1 minute)
WINDOW_HOURS=6

SEARCH='pemilu OR jokowi OR prabowo OR capres OR pilpres'

# -------------------------
# Safety checks
# -------------------------
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

if [ ! -f "$CURSOR_FILE" ]; then
  echo "Cursor file not found: $CURSOR_FILE"
  exit 1
fi

SINCE_DATE="$(cat "$CURSOR_FILE")"
UNTIL_DATE="$(date -u -d "${SINCE_DATE} +1 day" +"%Y-%m-%d")"

echo "Crawl day: since ${SINCE_DATE}, until ${UNTIL_DATE}"

QUERY="${SEARCH} since:${SINCE_DATE} until:${UNTIL_DATE} lang:id"

# -------------------------
# Timer start
# -------------------------
START_TS=$(date +%s)

i=0
out_files=()

while true; do
  now=$(date +%s)
  elapsed=$((now - START_TS))

  if [ "$elapsed" -ge "$MAX_RUNTIME" ]; then
    echo "Time limit reached (${MAX_RUNTIME}s). Stopping crawl."
    break
  fi

  window_start=$(date -u -d "${SINCE_DATE} +${i} hours" +"%Y-%m-%dT%H:%M:%SZ")

  if [[ "$(date -u -d "$window_start" +%s)" -ge "$(date -u -d "${UNTIL_DATE}T00:00:00Z" +%s)" ]]; then
    break
  fi

  fname="${OUT_DIR}/tweets_${SINCE_DATE}_w${i}.csv"

  echo "Fetching window ${window_start} -> ${UNTIL_DATE}"

  npx -y tweet-harvest@2.6.1 \
    -o "${fname}" \
    -s "${QUERY}" \
    --tab "LATEST" \
    -l 1000 \
    --token "${TWITTER_TOKEN}" || true

  # only keep files that actually exist
  if [[ -f "$fname" ]]; then
    out_files+=("$fname")
  fi

  i=$((i + WINDOW_HOURS))
done

# -------------------------
# Merge results
# -------------------------
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

# -------------------------
# Update cursor
# -------------------------
NEXT_DATE="$(date -u -d "${SINCE_DATE} +1 day" +"%Y-%m-%d")"
echo "$NEXT_DATE" > "$CURSOR_FILE"

echo "Saved $FINAL"
echo "Next cursor: $NEXT_DATE"
