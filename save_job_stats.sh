#!/usr/bin/env bash

set -euo pipefail

today=$(date +%F)
report_since="${2:-${today}}"

echo "job_stats/${report_since}_to_${today}.txt"

format_fields=(
    JobID
    JobName%30
    Start
    TotalCPU
    Elapsed
    Timelimit
    MaxRSS
    ReqMem
    State
    NNodes
    NTasks
    ReqCPUS
    AllocCPUS
)
format_fields+=("${@:3}")
final_format=$(IFS=,; echo "${format_fields[*]}")

sacct -S "${report_since}" -u "${USER:-$(whoami)}" \
    --format="${final_format}" > \
    "job_stats/${report_since}_to_${today}.txt"