#!/bin/bash
# Fetch continuous 15-minute discharge (cfs, parameter 00060) from the USGS
# Instantaneous Values service for a single site, Jan 1 2020 - Jan 1 2026.
#
# The IV service caps responses to roughly 120 days per request, so the range
# is split into ~4-month chunks. Output is a single clean CSV.
#
# Usage: ./fetch_flow.sh

SITE="04250200"
PARAM="00060"
OUTFILE="flow_${SITE}_2020_2026.csv"

starts=("2020-01-01" "2020-05-01" "2020-09-01" "2021-01-01" "2021-05-01" "2021-09-01" "2022-01-01" "2022-05-01" "2022-09-01" "2023-01-01" "2023-05-01" "2023-09-01" "2024-01-01" "2024-05-01" "2024-09-01" "2025-01-01" "2025-05-01" "2025-09-01")
ends=(  "2020-05-01" "2020-09-01" "2021-01-01" "2021-05-01" "2021-09-01" "2022-01-01" "2022-05-01" "2022-09-01" "2023-01-01" "2023-05-01" "2023-09-01" "2024-01-01" "2024-05-01" "2024-09-01" "2025-01-01" "2025-05-01" "2025-09-01" "2026-01-01")

echo "agency_cd,site_no,datetime,tz_cd,discharge_cfs,qa_code" > "$OUTFILE"

for i in "${!starts[@]}"; do
  echo "Fetching ${starts[$i]} to ${ends[$i]}..."
  curl -sL "https://nwis.waterservices.usgs.gov/nwis/iv/?format=rdb&sites=${SITE}&parameterCd=${PARAM}&startDT=${starts[$i]}&endDT=${ends[$i]}&siteStatus=all" \
    | grep -v '^#' \
    | awk -F'\t' 'NR>2' \
    | awk -F'\t' 'BEGIN{OFS=","} {$1=$1; print}' \
    >> "$OUTFILE"
  sleep 1
done

echo "Done. Total rows: $(wc -l < "$OUTFILE")"
