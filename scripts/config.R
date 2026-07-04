# bioconda-downloads configuration.
# This file is the ONLY thing that differs between this repo and its sibling
# R-conda-channel download-tracking repo. helpers.R and update.R read these
# constants and are identical across both repos.

PUBLISH_REPO   <- "r-observatory/bioconda-downloads"
SHARD_PREFIX   <- "bioconda-downloads"      # release-asset filename stem
TABLE_PREFIX   <- "bioconda"                # SQLite table-name stem
FORCE_REBUILD_ENV <- "BIOCONDA_FORCE_REBUILD"

DAILY_TABLE    <- paste0(TABLE_PREFIX, "_downloads_daily")
SUMMARY_TABLE  <- paste0(TABLE_PREFIX, "_downloads_summary")
PACKAGES_TABLE <- paste0(TABLE_PREFIX, "_packages")

DATA_SOURCE    <- "bioconda"                # anaconda-package-data `data_source` value
NAME_FILTER    <- "(pkg_name LIKE 'r-%' OR pkg_name LIKE 'bioconductor-%')"   # SQL predicate applied in the DuckDB fetch
NAME_PREFIXES  <- c("r-", "bioconductor-")  # prefixes this repo ingests
LOAD_BIOC_MAP  <- TRUE                      # bioconda hosts bioconductor-* packages too

S3_HOURLY_BASE <- "s3://anaconda-package-data/conda/hourly"
S3_REGION      <- "us-east-1"
HISTORY_START  <- "2017-04"                 # first month with data in the anaconda-package-data archive (YYYY-MM)

RECENT_WINDOW   <- 400L                      # days retained in the recent shard
REVISION_WINDOW <- 10L                       # trailing days re-fetched each incremental run
CRAN_REPO       <- "https://cloud.r-project.org"
BIOC_VIEWS_BASE <- "https://bioconductor.org/packages/release"
BIOC_VIEWS_CATEGORIES <- c("bioc", "data/annotation", "data/experiment", "workflows")

SUMMARY_COLS <- c(
  "package", "package_lower", "origin", "canonical_name",
  "total_30d", "total_90d", "total_365d",
  "rank_30d", "rank_90d", "rank_365d",
  "avg_daily_30d", "trend", "first_date", "last_date"
)

RELEASE_CAVEAT <- paste(
  "Counts are bioconda CDN downloads (served through Anaconda's infrastructure,",
  "best-effort deduped by Anaconda) for both r-* CRAN rebuilds and bioconductor-*",
  "packages. r-* counts overlap conceptually with the CRAN packages tracked by this",
  "project's other conda-channel pipeline, per-platform detail is dropped, and totals",
  "are not directly comparable across sources.")
