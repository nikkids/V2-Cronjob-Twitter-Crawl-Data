#!/usr/bin/env bash
set -euo pipefail

# -------------------------
# Config
# -------------------------
SEARCH='pemilu OR jokowi OR prabowo OR capres OR pilpres'
WINDOW_HOURS=6
LIMIT_PER_WINDOW=500

CURSOR_FILE="data/.cursor_date"
OUT_DIR="data"
LIMIT_DATE="2019-07-19"

TWITTER_TOKEN="${TWITTER_TOKEN:-}"

# -------------------------
# Safety checks
# -------------------------
if [[ -z "$TWITTER_TOKEN" ]]; then
  echo "TWITTER_TOKEN is not set"
  exit 1
fi

if [[ ! -f "$CURSOR_FILE" ]]; then
  echo "Cursor file not found: $CURSOR_FILE"
  exit 1
fi

mkdir -p "$OUT_DIR"
mkdir -p tweets-data/output

# -------------------------
# Read cursor
# -------------------------
SINCE_DATE=$(cat "$CURSOR_FILE")
END_DATE=$(date -u -d "$SINCE_DATE +1 day" +"%Y-%m-%d")

# Stop after 3 months
if [[ "$(date -d "$SINCE_DATE" +%s)" -ge "$(date -d "$LIMIT_DATE" +%s)" ]]; then
  echo "Reached limit date ($LIMIT_DATE). Stopping crawl."
  exit 0
fi

echo "Crawl day: since $SINCE_DATE, until $END_DATE"

# -------------------------
# Crawl windows
# -------------------------
i=0
out_files=()

while true; do
  window_start=$(date -u -d "${SINCE_DATE} +${i} hours" +"%Y-%m-%dT%H:%M:%SZ")
  window_end=$(date -u -d "${window_start} +${WINDOW_HOURS} hours" +"%Y-%m-%dT%H:%M:%SZ")

  if [[ "$(date -u -d "$window_start" +%s)" -ge "$(date -u -d "${END_DATE}T00:00:00Z" +%s)" ]]; then
    break
  fi

  fname="tweets-data/output/tweets_${SINCE_DATE}_w${i}.csv"

  echo "Fetching window $window_start -> $window_end"

  QUERY="${SEARCH} since:${window_start} until:${window_end} lang:id"

  # Hard runtime guard + hard tweet limit
  timeout 5m npx -y tweet-harvest@2.6.1 \
    -o "$fname" \
    -s "$QUERY" \
    --tab "LATEST" \
    -l "$LIMIT_PER_WINDOW" \
    --token "$TWITTER_TOKEN" || true

  out_files+=("$fname")
  i=$((i + WINDOW_HOURS))
done

# -------------------------
# Merge windows into daily file
# -------------------------
FINAL="${OUT_DIR}/pemilu_${SINCE_DATE}.csv"

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

echo "Final file: $FINAL"
ls -lh "$OUT_DIR"

# -------------------------
# Move cursor to next day
# -------------------------
echo "$END_DATE" > "$CURSOR_FILE"
echo "Cursor moved to $END_DATE"
