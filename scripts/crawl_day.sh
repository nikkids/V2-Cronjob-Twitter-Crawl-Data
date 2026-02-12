#!/usr/bin/env bash
set -euo pipefail

# -------------------------
# Config
# -------------------------
MAX_RUNTIME=60
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

START_TS=$(date +%s)

i=0
out_files=()

while true; do
  now=$(date +%s)
  elapsed=$((now - START_TS))

  if [ "$elapsed" -ge "$MAX_RUNTIME" ]; then
    echo "Time limit reached (${MAX_RUNTIME}s). Stop loop."
    break
  fi

  window_start=$(date -u -d "${SINCE_DATE} +${i} hours" +"%Y-%m-%dT%H:%M:%SZ")
  window_end=$(date -u -d "${window_start} +${WINDOW_HOURS} hours" +"%Y-%m-%dT%H:%M:%SZ")

  if [[ "$(date -u -d "$window_start" +%s)" -ge \
        "$(date -u -d "${UNTIL_DATE}T00:00:00Z" +%s)" ]]; then
    break
  fi

  fname="output/tweets_${SINCE_DATE}_w${i}.csv"

  QUERY="${SEARCH} since:${window_start} until:${window_end} lang:id"

  echo "Fetching window ${window_start} -> ${window_end}"

  # hard stop per crawl call so total runtime is respected
  timeout 55s npx -y tweet-harvest@2.6.1 \
    -o "$fname" \
    -s "$QUERY" \
    --tab "LATEST" \
    -l 1000 \
    --token "$TWITTER_TOKEN" || true

  if [[ -f "$fname" && -s "$fname" ]]; then
    out_files+=("$fname")
  fi

  i=$((i + WINDOW_HOURS))
done

# -------------------------
# Merge
# -------------------------
FINAL="${DATA_DIR}/pemilu_${SINCE_DATE}.csv"

if [ "${#out_files[@]}" -eq 0 ]; then
  echo "No output files produced."
  echo "id,created_at,text" > "$FINAL"
else
  first=true
  > "$FINAL"

  for f in "${out_files[@]}"; do
    if $first; then
      cat "$f" >> "$FINAL"
      first=false
    else
      tail -n +2 "$f" >> "$FINAL"
    fi
  done
fi

# -------------------------
# Update cursor
# -------------------------
NEXT_DATE="$(date -u -d "${SINCE_DATE} +1 day" +"%Y-%m-%d")"
echo "$NEXT_DATE" > "$CURSOR_FILE"

echo "Saved $FINAL"
echo "Next cursor: $NEXT_DATE"
