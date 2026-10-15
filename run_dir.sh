#!/usr/bin/env bash
# =========================================================================
# Sourced by every config file. Sets BASE_DIR to a dated run directory:
#
#   results/<config name>/<YYYY-MM-DD>[_N]/
#
# Needs RESULTS_ROOT (set by the config) and picks the directory as follows:
#   1. NEW_RUN=1        -> create a new directory for today. If today's
#                          already exists, append _2, _3, ... (mkdir is atomic,
#                          so two runs started at once never share a folder).
#                          Only submit_prep_density_data.sh sets this.
#   2. RUN_DIR is set   -> use it as-is. Submit scripts pass RUN_DIR into
#                          every Slurm job / local background process, so a
#                          job always writes where it was submitted from,
#                          even if a newer run is created while it waits.
#                          You can also set it yourself to reprocess an older
#                          run, e.g. RUN_DIR=results/default/2026-10-12 ./submit_spline_jobs.sh
#   3. otherwise        -> use the most recent existing run directory.
# =========================================================================

# Stop the calling script, but don't kill an interactive shell that sourced a config
_run_dir_fail() {
    if [[ $- == *i* ]]; then return 1; else exit 1; fi
}

_list_run_dirs() {
    # Print run directories oldest -> newest (version sort puts _10 after _9)
    local d
    shopt -s nullglob
    for d in "${RESULTS_ROOT}"/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*/; do
        basename "${d}"
    done | sort -V
    shopt -u nullglob
}

_create_run_dir() {
    local today name n=1
    today=$(date +%F)
    mkdir -p "${RESULTS_ROOT}"
    name="${today}"
    until mkdir "${RESULTS_ROOT}/${name}" 2>/dev/null; do
        n=$((n + 1))
        name="${today}_${n}"
    done
    echo "${RESULTS_ROOT}/${name}"
}

if [[ "${NEW_RUN:-0}" == "1" ]]; then
    BASE_DIR="$(_create_run_dir)"
    # Record provenance in the run itself rather than in the folder name
    {
        echo "created:  $(date '+%Y-%m-%dT%H:%M:%S%z')"
        echo "config:   ${CONFIG_NAME}"
        echo "git hash: $(git -C "${REPO_ROOT}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
        echo "git dirty: $( [[ -n "$(git -C "${REPO_ROOT}" status --porcelain 2>/dev/null)" ]] && echo yes || echo no )"
        echo "host:     $(hostname)"
    } > "${BASE_DIR}/run_info.txt"
    cp "${BASH_SOURCE[1]:-/dev/null}" "${BASE_DIR}/config_used.sh" 2>/dev/null || true
elif [[ -n "${RUN_DIR:-}" ]]; then
    if ! BASE_DIR="$(cd "${RUN_DIR}" 2>/dev/null && pwd)"; then
        echo "Error: RUN_DIR=${RUN_DIR} does not exist." >&2
        _run_dir_fail || return 1
    fi
else
    _latest="$(_list_run_dirs | tail -n 1)"
    if [[ -z "${_latest}" ]]; then
        echo "Error: no run directory found in ${RESULTS_ROOT}." >&2
        echo "Run ./submit_prep_density_data.sh first to create one." >&2
        _run_dir_fail || return 1
    fi
    BASE_DIR="${RESULTS_ROOT}/${_latest}"
    unset _latest
fi

# Not exported on purpose: submit scripts pass RUN_DIR to their jobs
# explicitly, so sourcing a config in an interactive shell can't silently
# pin later runs to an old directory.
RUN_DIR="${BASE_DIR}"
