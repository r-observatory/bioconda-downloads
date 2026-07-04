# bioconda Downloads

Daily per-package download statistics for R packages on [bioconda](https://bioconda.github.io/), the community-maintained conda channel built for bioinformatics. bioconda carries two families of R packages: the `r-*` slice (CRAN packages rebuilt for the bioconda channel, `origin = 'cran'`) and the `bioconductor-*` slice (Bioconductor packages, `origin = 'bioc'`). This pipeline tracks both. The counts come from Anaconda's public [anaconda-package-data](https://github.com/anaconda/anaconda-package-data) dataset, a set of anonymous, publicly readable Parquet files on S3 that record CDN download events for every conda channel Anaconda serves. This pipeline aggregates the bioconda `r-*` and `bioconductor-*` package rows to one download count per package per UTC day, resolves each name against the current CRAN package index and the current Bioconductor release VIEWS, and publishes the result as SQLite shard files attached to a single rolling GitHub release tag (`current`).

> [!IMPORTANT]
> **What these numbers mean, and what they do not.**
>
> - **Counts are downloads served through Anaconda's CDN, best-effort deduped by Anaconda.** The exact bot-filtering and deduplication rules are not published. These counts miss independent third-party mirrors (for example prefix.dev, and corporate or university mirrors that sync bioconda), so they are not absolute install counts, only a lower-bound view of CDN traffic.
> - **Per-platform splits are dropped.** Counts are summed across all platforms (`linux-64`, `osx-64`, `noarch`, and so on) rather than broken out per platform.
> - **This pipeline covers two distinct origins on one channel.** `origin = 'cran'` is the `r-*` slice: CRAN packages rebuilt for bioconda. `origin = 'bioc'` is the `bioconductor-*` slice: Bioconductor packages, which conda-forge does not carry at all. `origin = 'other'` marks `r-*` names that are not CRAN packages, chiefly the `r-base` meta-package and other conda-native R tooling.
> - **`origin = 'cran'` counts overlap conceptually with [conda-forge-downloads](https://github.com/r-observatory/conda-forge-downloads).** The same CRAN packages are frequently available on both channels; the two pipelines count independent CDN traffic on different channels, not a single combined total.
> - **The daily grain and 30/90/365-day windows match `cran-downloads`, but the absolute numbers are not directly comparable across sources.** bioconda, conda-forge, CRAN, r2u, COPR, and autoOBS each serve a different population over different infrastructure with different counting methods. Use each source for its own trend, not for cross-source magnitude comparisons.

## Data Access

All shards live as assets on the [`current` release](https://github.com/r-observatory/bioconda-downloads/releases/tag/current). Each daily run uploads only the shards that changed; the rest remain unchanged.

### Recent data (last 400 days)

For most use cases this is the only file you need. It holds the rolling 400-day window of `bioconda_downloads_daily` plus the full `bioconda_downloads_summary` and `bioconda_packages` tables.

```bash
gh release download current \
  --repo r-observatory/bioconda-downloads \
  --pattern "bioconda-downloads-recent.db"
```

```r
url <- "https://github.com/r-observatory/bioconda-downloads/releases/download/current/bioconda-downloads-recent.db"
download.file(url, "bioconda-downloads-recent.db", mode = "wb")

library(RSQLite)
con <- dbConnect(SQLite(), "bioconda-downloads-recent.db")

# Daily downloads for the Bioconductor package DESeq2 over the last 30 days
dbGetQuery(con, "
  SELECT date, count
  FROM bioconda_downloads_daily
  WHERE package = 'bioconductor-deseq2'
  ORDER BY date DESC LIMIT 30
")

# Top 20 packages by 30-day downloads, across both origins
dbGetQuery(con, "
  SELECT package, origin, canonical_name, total_30d, rank_30d
  FROM bioconda_downloads_summary
  ORDER BY rank_30d LIMIT 20
")

dbDisconnect(con)
```

```python
import urllib.request, sqlite3
url = "https://github.com/r-observatory/bioconda-downloads/releases/download/current/bioconda-downloads-recent.db"
urllib.request.urlretrieve(url, "bioconda-downloads-recent.db")

con = sqlite3.connect("bioconda-downloads-recent.db")
for row in con.execute("""
    SELECT package, origin, canonical_name, total_30d, rank_30d
    FROM bioconda_downloads_summary
    ORDER BY rank_30d LIMIT 10"""):
    print(row)
con.close()
```

### Per-year archives

Each calendar year of the daily series has its own shard (history begins in April 2017, when Anaconda's dataset starts tracking bioconda):

```bash
gh release download current \
  --repo r-observatory/bioconda-downloads \
  --pattern "bioconda-downloads-2026.db"
```

### Full history (all years)

```bash
gh release download current \
  --repo r-observatory/bioconda-downloads \
  --pattern "bioconda-downloads-*.db"
```

### Summary only

For top-package lists, ranks, and the current windows without the daily series:

```bash
gh release download current \
  --repo r-observatory/bioconda-downloads \
  --pattern "bioconda-downloads-summary.db"
```

### Manifest

`manifest.json` lists which shards changed in the most recent run, the source kind (`hourly` for a live read, `frozen` for a heartbeat when the source was unreachable), per-shard coverage, and freshness timestamps.

```bash
gh release download current \
  --pattern manifest.json \
  --repo r-observatory/bioconda-downloads
cat manifest.json
```

## Example Queries

### Top packages by 30-day downloads, across both origins

```sql
SELECT package, origin, canonical_name, total_30d, rank_30d
  FROM bioconda_downloads_summary
 ORDER BY rank_30d
 LIMIT 50;
```

### Daily series joined to summary identity

```sql
SELECT d.date, d.package, s.canonical_name, s.origin, d.count
  FROM bioconda_downloads_daily d
  JOIN bioconda_downloads_summary s ON s.package = d.package
 WHERE d.package = 'bioconductor-deseq2'
 ORDER BY d.date DESC
 LIMIT 30;
```

### Bioconductor-only packages, ranked

```sql
SELECT package, canonical_name, total_30d, rank_30d
  FROM bioconda_downloads_summary
 WHERE origin = 'bioc'
 ORDER BY total_30d DESC
 LIMIT 50;
```

### CRAN-rebuild-only packages, ranked

```sql
SELECT package, canonical_name, total_30d, rank_30d
  FROM bioconda_downloads_summary
 WHERE origin = 'cran'
 ORDER BY total_30d DESC
 LIMIT 50;
```

## Schema

### `bioconda_downloads_daily`

One row per package per day. The count is the sum of Anaconda's hourly-binned `counts` column for that package and UTC day, across all platforms and versions. Present in `bioconda-downloads-recent.db` (last 400 days) and each `bioconda-downloads-YYYY.db` archive.

| Column | Type | Description |
|---|---|---|
| `package` | TEXT | bioconda package name, e.g. `r-data.table` or `bioconductor-deseq2` (PK part 1) |
| `date` | TEXT | The UTC day the downloads occurred, `YYYY-MM-DD` (PK part 2) |
| `count` | INTEGER | Downloads on that day, summed across all platforms and versions |

### `bioconda_downloads_summary`

Per-package standing, rebuilt each run from the accumulated daily series. Present in `bioconda-downloads-recent.db` and `bioconda-downloads-summary.db`.

| Column | Type | Description |
|---|---|---|
| `package` | TEXT | bioconda package name (PK) |
| `package_lower` | TEXT | Lowercased helper column for case-insensitive joins |
| `origin` | TEXT | `cran` if a stripped `r-` name matches a current CRAN package, `bioc` for `bioconductor-*` packages, else `other` |
| `canonical_name` | TEXT | The CRAN or Bioconductor canonical-case name, e.g. `data.table` or `DESeq2`; `NULL` when `origin = 'other'` |
| `total_30d` | INTEGER | Downloads in the trailing 30 days ending on the latest date in the series |
| `total_90d` | INTEGER | Downloads in the trailing 90 days |
| `total_365d` | INTEGER | Downloads in the trailing 365 days |
| `rank_30d` | INTEGER | Rank by `total_30d` (1 = most downloaded) |
| `rank_90d` | INTEGER | Rank by `total_90d` |
| `rank_365d` | INTEGER | Rank by `total_365d` |
| `avg_daily_30d` | REAL | `total_30d` divided by 30 |
| `trend` | REAL | Percent change: last 30 days vs the prior 30 days; `NULL` until roughly 60 days of history exist |
| `first_date` | TEXT | Earliest date this package appears in the daily series (`YYYY-MM-DD`) |
| `last_date` | TEXT | Latest date this package appears in the daily series (`YYYY-MM-DD`) |

### `bioconda_packages`

The package-name identity cache, carried inside `bioconda-downloads-recent.db` so a transient CRAN or Bioconductor name-index outage falls back to the prior run's mapping instead of blanking every origin.

| Column | Type | Description |
|---|---|---|
| `package` | TEXT | bioconda package name (PK) |
| `origin` | TEXT | `cran`, `bioc`, or `other`, as in the summary table |
| `canonical_name` | TEXT | CRAN or Bioconductor canonical-case name, or `NULL` when `origin = 'other'` |

## How it works

A daily GitHub Actions job (05:15 UTC) reads Anaconda's public `anaconda-package-data` hourly Parquet files directly from S3 with an anonymous DuckDB connection (`httpfs`, no AWS credentials required), filtered to `data_source = 'bioconda'` and package names matching `r-%` or `bioconductor-%`. Rows are aggregated to one `(package, date, count)` triple per UTC day and merged into the accumulated history. Each package is resolved to an `origin` and canonical name: `bioconductor-*` names are stripped and matched against the current Bioconductor release VIEWS (across the `bioc`, `data/annotation`, `data/experiment`, and `workflows` categories), while `r-*` names are stripped and matched against the current CRAN package index (`available.packages()`); anything left unmatched is `other`. The affected year shard plus the rolling `bioconda-downloads-recent.db` and `bioconda-downloads-summary.db` are rebuilt, and only the changed shards are uploaded to the `current` release (with `manifest.json` uploaded last, so a crash mid-publish leaves the prior state authoritative). When the S3 source or a name index is unreachable, the run degrades gracefully: a source outage produces a heartbeat that refreshes `last_checked` and leaves the release untouched, and a name-index outage falls back to the cached `bioconda_packages` mapping from the last successful run.

## Attribution

Download counts are read from Anaconda's public [anaconda-package-data](https://github.com/anaconda/anaconda-package-data) dataset on S3; the packages themselves are built and maintained by the [bioconda](https://bioconda.github.io/) community. This repository provides only the daily aggregation and packaging into SQLite. Please respect Anaconda's public data infrastructure and terms.

## License

The pipeline code in this repository is proprietary. Copyright (c) 2026 HJJB, LLC. All rights reserved; see [LICENSE](LICENSE). The underlying download counts originate from Anaconda's anaconda-package-data.
