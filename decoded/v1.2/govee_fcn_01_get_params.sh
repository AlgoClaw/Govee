#!/usr/bin/env bash

# Print the model profile JSON used by later stages. Use --refresh to update
# model_specific_parameters.json atomically from the repository reference.

source "$(dirname -- "$(readlink -f -- "$0")")/govee_fcn_lib.sh"
govee_enable_strict_mode
govee_require_commands curl jq mktemp

SCRIPTDIR="$(govee_script_dir)"
PROFILE_FILE="${SCRIPTDIR}/model_specific_parameters.json"
PROFILE_URL="https://raw.githubusercontent.com/AlgoClaw/Govee/refs/heads/main/decoded/v1.2/model_specific_parameters.json"

refresh_profiles() {
  local temporary
  # Download to a neighboring temporary file. The existing profile survives a
  # failed download or invalid response because mv occurs only after jq checks
  # the expected profile structure.
  temporary="$(govee_temp_for "${PROFILE_FILE}")"
  trap 'rm -f "${temporary}"' EXIT

  curl --fail --silent --show-error --location "${PROFILE_URL}" -o "${temporary}"
  # Each profile needs a model list and one or more prefix-transform types.
  jq -e '
    type == "array"
    and all(.[]; (.models | type == "array") and (.type | type == "array"))
  ' "${temporary}" >/dev/null

  mv -- "${temporary}" "${PROFILE_FILE}"
  trap - EXIT
}

if [[ $# -eq 1 && "${1}" == "--refresh" ]]; then
  refresh_profiles
  printf '%s\n' "${PROFILE_FILE}"
  exit 0
fi

if [[ $# -ne 1 || -z "${1}" ]]; then
  printf 'Usage: %s SKU | --refresh\n' "$0" >&2
  exit 1
fi

MODEL="$1"
if [[ ! -f "${PROFILE_FILE}" ]]; then
  # First use can bootstrap the tracked input. Later normal pipeline runs use
  # the local file and require --refresh for a network update.
  refresh_profiles
fi

# Prefer the explicit SKU entry. "null" is the intentional generic fallback
# profile for models with no dedicated entry. del(.models) makes the value
# suitable for passing as one compact command-line JSON argument downstream.
jq -ce --arg model "${MODEL}" '
  (
    [ .[] | select((.models // []) | index($model)) | del(.models) ][0]
    // [ .[] | select((.models // []) | index("null")) | del(.models) ][0]
    // error("No model profile and no null fallback profile")
  )
' "${PROFILE_FILE}"
