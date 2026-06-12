#!/bin/bash
# Fetch continuous 15-minute discharge (cfs, parameter 00060) from the USGS
# Instantaneous Values service for a single site over a user-supplied date range.
#
# The IV service caps responses to roughly 120 days per request, so the range
# is split automatically into ~120-day chunks. Output is a single clean CSV.
#
# Usage: ./fetch_flow.sh --start YYYY-MM-DD --end YYYY-MM-DD [--site SITE_NO]
#   e.g. ./fetch_flow.sh --start 2023-01-01 --end 2024-01-01 --site 04250200

set -euo pipefail

SITE="04250200"   # default site; override with --site
PARAM="00060"
CHUNK_DAYS=120

START=""
END=""

usage() {
  echo "Usage: $0 --start YYYY-MM-DD --end YYYY-MM-DD [--site SITE_NO]" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --start) START="${2:-}"; shift 2 ;;
    --end)   END="${2:-}";   shift 2 ;;
    --site)  SITE="${2:-}";  shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

[[ -n "$START" && -n "$END" ]] || usage
[[ -n "$SITE" ]] || { echo "Error: --site must not be empty." >&2; exit 1; }

# Validate dates and normalize to YYYY-MM-DD (also rejects bad calendar dates).
START="$(date -d "$START" +%Y-%m-%d 2>/dev/null)" || { echo "Invalid --start date" >&2; exit 1; }
END="$(date -d "$END" +%Y-%m-%d 2>/dev/null)"     || { echo "Invalid --end date" >&2; exit 1; }

if [[ "$START" > "$END" || "$START" == "$END" ]]; then
  echo "Error: --start ($START) must be before --end ($END)." >&2
  exit 1
fi

OUTFILE="flow_${SITE}_${START}_${END}.csv"

echo "agency_cd,site_no,datetime,tz_cd,discharge_cfs,qa_code" > "$OUTFILE"

chunk_start="$START"
while [[ "$chunk_start" < "$END" ]]; do
  chunk_end="$(date -d "$chunk_start + ${CHUNK_DAYS} days" +%Y-%m-%d)"
  # Don't run past the requested end date.
  if [[ "$chunk_end" > "$END" ]]; then
    chunk_end="$END"
  fi

  echo "Fetching ${chunk_start} to ${chunk_end}..."
  curl -sL "https://nwis.waterservices.usgs.gov/nwis/iv/?format=rdb&sites=${SITE}&parameterCd=${PARAM}&startDT=${chunk_start}&endDT=${chunk_end}&siteStatus=all" \
    | grep -v '^#' \
    | awk -F'\t' 'NR>2' \
    | awk -F'\t' 'BEGIN{OFS=","} {$1=$1; print}' \
    >> "$OUTFILE"
  sleep 1

  chunk_start="$chunk_end"
done

echo "Done. Total rows: $(wc -l < "$OUTFILE")"
