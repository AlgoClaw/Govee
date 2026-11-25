#!/usr/bin/env bash

# Extract the replaceable current API result. The durable library is managed
# separately by govee_fcn_09_merged_file.sh.

source "$(dirname -- "$(readlink -f -- "$0")")/govee_fcn_lib.sh"
govee_enable_strict_mode
govee_require_commands jq mktemp

if [[ $# -lt 2 || $# -gt 3 || -z "${1}" || -z "${2}" ]]; then
  printf 'Usage: %s SKU DEBUG_JSON [FINAL_CURRENT_JSON]\n' "$0" >&2
  exit 1
fi

MODEL="$1"
OUTPUT_JSON="${2%/}"
if [[ ! -f "${OUTPUT_JSON}" ]]; then
  printf 'Debug JSON file does not exist: %s\n' "${OUTPUT_JSON}" >&2
  exit 1
fi

# final_current is deliberately disposable: it is only this run's API scene
# set. The next stage merges it into the durable final_merged library.
JSONDIR="$(dirname -- "${OUTPUT_JSON}")"
FINAL_OUTPUT="${3:-${JSONDIR}/${MODEL}_final_current.json}"
temporary="$(govee_temp_for "${FINAL_OUTPUT}")"
trap 'rm -f "${temporary}"' EXIT

# Omit decoder internals. This is the compact scene schema consumed by HA and
# by the merge stage: user-visible name plus complete command packet array.
jq -e '[.[] | {name: .name, cmd_b64: .cmd_b64}]' "${OUTPUT_JSON}" > "${temporary}"

mv -- "${temporary}" "${FINAL_OUTPUT}"
trap - EXIT
printf '%s\n' "${FINAL_OUTPUT}"
