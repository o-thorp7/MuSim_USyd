#!/usr/bin/env bash
# Source this AFTER loading the config (needs RUN_MODE, MAX_JOBS, SLEEP_TIME).
# Usage: wait_for_slot <job-name-prefix>
wait_for_slot() {
    local prefix="$1" running out
    while true; do
        if [[ "${RUN_MODE}" == "local" ]]; then
            running=$(jobs -rp | wc -l)
        else
            # if squeue hiccups, wait and retry rather than assuming 0 jobs
            if ! out=$(squeue -u "${USER}" -h -t PD,R,CF -o %j 2>/dev/null); then
                echo "squeue failed; retrying in ${SLEEP_TIME} seconds..." >&2
                sleep "${SLEEP_TIME}"; continue
            fi
            running=$(grep -c "^${prefix}" <<< "${out}" || true)
        fi
        [[ "${running}" -lt "${MAX_JOBS}" ]] && return 0
        echo "Currently ${running} jobs running; max ${MAX_JOBS}). Waiting for slot..."
        sleep "${SLEEP_TIME}"
    done
}