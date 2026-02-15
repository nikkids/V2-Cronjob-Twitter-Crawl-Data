# Daily Twitter/X Crawler

This repository automatically scrapes Twitter (X) data on a daily schedule using GitHub Actions. It runs incrementally to build a dataset over time without hitting rate limits.

## How It Works

* **Schedule:** Runs daily at 01:00 PM WIB (05:00 UTC).
* **Duration:** Runs for 3 minutes per execution.
* **Logic:** Automatically picks up from the last crawled date found in the `data/` folder.
* **Storage:** Results are saved as CSV files and committed back to the repository.

## Output

Data is saved in the `data/` directory. Each file represents one day of tweets
