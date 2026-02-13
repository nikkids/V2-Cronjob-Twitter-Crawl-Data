#!/usr/bin/env bash
set -euo pipefail

TWITTER_TOKEN="${TWITTER_TOKEN:-}"
PART_DIR="data"
FINAL_DIR="data"

# Ensure directories exist
mkdir -p "tweets-data/${PART_DIR}"
mkdir -p "${FINAL_DIR}"

WINDOW_HOURS=6

# ---- time limit (seconds) ----
# We set this to 60s to respect your workflow limit
TIME_LIMIT=60
START_TS=$(date +%s)
# --------------------------------

SINCE_DATE="${CRAWL_DATE:?CRAWL_DATE is required}"
# Calculate next day for the 'until' parameter
UNTIL_DATE=$(date -u -d "${SINCE_DATE} +1 day" +"%Y-%m-%d")

echo "Crawl day: since ${SINCE_DATE}, until ${UNTIL_DATE}"
echo "Global Time limit: ${TIME_LIMIT}s"

i=0
out_files=()

while true; do
  # 1. CHECK TIME LIMIT
  now=$(date +%s)
  elapsed=$((now - START_TS))
  
  if [ "$elapsed" -ge "$TIME_LIMIT" ]; then
    echo "Time limit reached (${elapsed}s). Stopping crawl loop to save data."
    break
  fi

  # 2. CALCULATE WINDOW
  window_start=$(date -u -d "${SINCE_DATE} +${i} hours" +"%Y-%m-%dT%H:%M:%SZ")
  
  # Stop if we went past the target day
  if [[ "$(date -u -d "$window_start" +%s)" -ge "$(date -u -d "${UNTIL_DATE}T00:00:00Z" +%s)" ]]; then
    break
  fi

  fname="${PART_DIR}/_part_${SINCE_DATE}_w${i}.csv"
  echo "Fetching window starting ${window_start}..."

  SEARCH='pemilu OR jokowi OR prabowo OR capres OR pilpres'
  
  # We construct the query. 
  # Note: 'since' usually takes YYYY-MM-DD, but we pass the loop logic anyway.
  QUERY="${SEARCH} since:${SINCE_DATE} until:${UNTIL_DATE} lang:id"

  # 3. RUN HARVEST WITH TIMEOUT
  # We set timeout to 50s (less than global 60s) so we have time to save.
  # The "|| true" ensures the script doesn't crash if timeout kills the process.
  timeout 50s npx -y tweet-harvest@2.6.1 \
    -o "${fname}" \
    -s "${QUERY}" \
    --tab "LATEST" \
    -l 1000 \
    --token "${TWITTER_TOKEN}" || echo "tweet-harvest timed out or finished"

  # 4. COLLECT FILES
  real_file="tweets-data/${fname}"
  
  # Only add if file exists AND has size > 0
  if [[ -f "${real_file}" && -s "${real_file}" ]]; then
    out_files+=("${real_file}")
  else
    echo "Warning: No data found for this window or file is empty."
  fi

  i=$((i + WINDOW_HOURS))
done

# 5. MERGE FILES
FINAL="${FINAL_DIR}/${SINCE_DATE}.csv"
> "$FINAL" # Create/Clear final file

echo "Merging ${#out_files[@]} files into $FINAL..."

first=true
for f in "${out_files[@]}"; do
  # Double check file exists
  if [[ ! -f "$f" ]]; then continue; fi

  if $first; then
    # Keep header from first file
    cat "$f" >> "$FINAL"
    first=false
  else
    # Skip header (line 1) for subsequent files
    tail -n +2 "$f" >> "$FINAL"
  fi
done

# 6. CLEANUP
# Remove the temp partial files to keep repo clean
rm -f "tweets-data/${PART_DIR}/_part_${SINCE_DATE}_w"*.csv

echo "Final file created: $FINAL"
ls -lh "$FINAL_DIR"

# Explicitly exit 0 so GitHub Action continues to the Commit step
exit 0
