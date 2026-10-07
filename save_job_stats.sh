#!/usr/bin/env bash

set -euo pipefail

# Get config file from first argument, default to config/default.sh
CONFIG_FILE="${1:-config/default.sh}"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "Error: Config file not found: ${CONFIG_FILE}" >&2
    exit 1
fi

# Load configuration
. "${CONFIG_FILE}"

SUMMARY_DIR="${BASE_DIR}/summary"
mkdir -p "${SUMMARY_DIR}"

report_since="${2:-$(date +%F)}"
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
    # add fields relating to -n -N --cpus-per-task --mem
    NNodes
    NTasks
    ReqCPUS
    AllocCPUS
)
format_fields+=("${@:3}")
final_format=$(IFS=,; echo "${format_fields[*]}")

sacct -S "${report_since}" -u "${USER:-$(whoami)}" \
    --format="${final_format}" > \
    "${SUMMARY_DIR}/job_stats.txt"