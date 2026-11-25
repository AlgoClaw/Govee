#!/usr/bin/env bash

# Download both public catalogs for one SKU. The combined raw file feeds the
# decoder, while the individual v1 and v2 captures remain available to inspect.

source "$(dirname -- "$(readlink -f -- "$0")")/govee_fcn_lib.sh"
govee_enable_strict_mode
govee_require_commands curl jq mktemp

if [[ $# -ne 1 || -z "${1}" ]]; then
  printf 'Usage: %s SKU\n' "$0" >&2
  exit 1
fi

MODEL="$1"
SCRIPTDIR="$(govee_script_dir)"
JSONDIR="${SCRIPTDIR}/JSONs"
mkdir -p -- "${JSONDIR}"

V1_RAW_FILE="${JSONDIR}/${MODEL}_raw_v1.json"
V2_RAW_FILE="${JSONDIR}/${MODEL}_raw_v2.json"
COMBINED_RAW_FILE_PATH="${JSONDIR}/${MODEL}_raw_combined.json"
COMBINED_PRETTY_FILE="${JSONDIR}/${MODEL}_raw_combined_pretty.json"

download_catalog() {
  local url="$1"
  local output="$2"
  local temporary

  # Never overwrite a known-good API capture with a partial/error response.
  temporary="$(govee_temp_for "${output}")"
  if ! curl --fail --silent --show-error --location \
    -H 'AppVersion: 9999999' \
    "${url}" -o "${temporary}"; then
    rm -f -- "${temporary}"
    printf 'Could not download %s\n' "${url}" >&2
    return 1
  fi

  # v1/v2 sometimes wrap the catalog in .data and sometimes do not. Both
  # forms must contain categories before the capture is accepted.
  if ! jq -e '((.data? // .) | (.categories? | type) == "array")' "${temporary}" >/dev/null; then
    rm -f -- "${temporary}"
    printf 'Invalid scene catalog from %s\n' "${url}" >&2
    return 1
  fi

  mv -- "${temporary}" "${output}"
}

# Govee's two endpoints contain partly overlapping catalogs. Both raw files
# are retained for inspection; stage 03 removes duplicate effects.
download_catalog "https://app2.govee.com/appsku/v1/light-effect-libraries?sku=${MODEL}" "${V1_RAW_FILE}"
download_catalog "https://app2.govee.com/appsku/v2/scences?sku=${MODEL}" "${V2_RAW_FILE}"

combined_temporary="$(govee_temp_for "${COMBINED_RAW_FILE_PATH}")"
pretty_temporary="$(govee_temp_for "${COMBINED_PRETTY_FILE}")"
trap 'rm -f "${combined_temporary}" "${pretty_temporary}"' EXIT

# *_raw_combined.json contains one categories array from both API responses.
jq -s '
  def catalog: .data? // .;
  { categories: [ .[] | catalog | .categories[]? ] }
' "${V1_RAW_FILE}" "${V2_RAW_FILE}" > "${combined_temporary}"

# Keep a human-readable copy without relying on an external formatter.
jq . "${combined_temporary}" > "${pretty_temporary}"
mv -- "${combined_temporary}" "${COMBINED_RAW_FILE_PATH}"
mv -- "${pretty_temporary}" "${COMBINED_PRETTY_FILE}"
trap - EXIT

printf '%s\n' "${COMBINED_RAW_FILE_PATH}"
