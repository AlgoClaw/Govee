#!/bin/bash

# Download both public scene catalogs for a SKU and combine their category
# trees. The v1 and v2 endpoints overlap, but each may also expose scenes the
# other one does not. Exact effect-level deduplication happens in function 03
# after the fields used to generate commands have been normalized.

set -euo pipefail

if [ "$#" -ne 1 ] || [ -z "${1}" ]; then
    echo "Usage: $0 SKU" >&2
    exit 1
fi

MODEL="$1"
SCRIPTDIR="$(dirname "$(readlink -f "$0")")"
JSONDIR="${SCRIPTDIR}/JSONs"
mkdir -p "${JSONDIR}"

V1_RAW_FILE="${JSONDIR}/${MODEL}_raw_v1.json"
V2_RAW_FILE="${JSONDIR}/${MODEL}_raw_v2.json"
RAW_FILE_PATH="${JSONDIR}/${MODEL}_raw.json"

download_catalog() {
    local url="$1"
    local output="$2"
    local temporary

    temporary="$(mktemp "${output}.tmp.XXXXXX")"
    if ! curl --fail --silent --show-error --location \
        -H 'AppVersion: 9999999' \
        "${url}" -o "${temporary}"; then
        rm -f "${temporary}"
        echo "Could not download ${url}" >&2
        return 1
    fi

    # Do not replace the prior capture with an error body or an unexpected
    # response. Both known API response shapes are supported: {data: ...}
    # and the bare catalog object stored by older pipeline runs.
    if ! jq -e '((.data? // .) | (.categories? | type) == "array")' "${temporary}" >/dev/null; then
        rm -f "${temporary}"
        echo "Invalid scene catalog from ${url}" >&2
        return 1
    fi

    mv "${temporary}" "${output}"
}

download_catalog "https://app2.govee.com/appsku/v1/light-effect-libraries?sku=${MODEL}" "${V1_RAW_FILE}"
download_catalog "https://app2.govee.com/appsku/v2/scences?sku=${MODEL}" "${V2_RAW_FILE}"

# Keep a combined raw capture in the historical *_raw.json location so the
# rest of the pipeline still receives one input path. Function 03 accepts
# this bare shape as well as the API's {data: ...} envelope.
temporary_combined="$(mktemp "${RAW_FILE_PATH}.tmp.XXXXXX")"
jq -s '
  def catalog: .data? // .;
  { categories: [ .[] | catalog | .categories[]? ] }
' "${V1_RAW_FILE}" "${V2_RAW_FILE}" > "${temporary_combined}"
mv "${temporary_combined}" "${RAW_FILE_PATH}"

jq . "${RAW_FILE_PATH}" > "${JSONDIR}/${MODEL}_raw_pretty.json"

# stdout is consumed by govee_fcn_00_all.sh.
echo "${RAW_FILE_PATH}"
