#!/usr/bin/env bash

# Run the complete v1.2 catalog-to-command pipeline for one Govee SKU.

source "$(dirname -- "$(readlink -f -- "$0")")/govee_fcn_lib.sh"
govee_enable_strict_mode
# Fail before downloading anything if the tools used by downstream stages are
# absent. This script is the one-SKU orchestration entry point.
govee_require_commands curl jq base64 od xxd mktemp

if [[ $# -ne 1 || -z "${1}" ]]; then
  printf 'Usage: %s SKU\n' "$0" >&2
  exit 1
fi

MODEL="$1"
SCRIPTDIR="$(govee_script_dir)"
SKU_JSON_DIR="${SCRIPTDIR}/JSONs/${MODEL}"
# Keep every catalog artifact for a SKU in its own directory.
mkdir -p -- "${SKU_JSON_DIR}"

# The profile is a local, versioned input. Refresh it explicitly with
# govee_fcn_01_get_params.sh --refresh so a normal scene run never replaces
# local model-profile work.
MODEL_PARAMS="$(bash "${SCRIPTDIR}/govee_fcn_01_get_params.sh" "${MODEL}")"

# Stage 02 preserves the raw v1/v2 API responses and prints the combined raw
# catalog path. Stages 03-07 progressively replace fields in *_debug.json.
RAW_JSON_PATH="$(bash "${SCRIPTDIR}/govee_fcn_02_get_scene_json.sh" "${MODEL}")"
OUTPUT_FILE_PATH="$(bash "${SCRIPTDIR}/govee_fcn_03_add_b16.sh" "${RAW_JSON_PATH}")"

# Interpret the model-specific parameter wrapper, calculate packet count,
# create checksummed hexadecimal commands, then add their Base64 equivalents.
bash "${SCRIPTDIR}/govee_fcn_04_model_specific_changes.sh" "${OUTPUT_FILE_PATH}" "${MODEL_PARAMS}"
bash "${SCRIPTDIR}/govee_fcn_05_num_lines.sh" "${OUTPUT_FILE_PATH}"
bash "${SCRIPTDIR}/govee_fcn_06_cmd_b16.sh" "${OUTPUT_FILE_PATH}" "${MODEL_PARAMS}"
bash "${SCRIPTDIR}/govee_fcn_07_cmd_b64.sh" "${OUTPUT_FILE_PATH}"

GENERATED_FILE="${SKU_JSON_DIR}/${MODEL}_final_current.json"
MERGED_FILE="${SKU_JSON_DIR}/${MODEL}_final_merged.json"
EXISTING_FINAL_FILE="${SKU_JSON_DIR}/${MODEL}_final.json"

bash "${SCRIPTDIR}/govee_fcn_08_simplest_file.sh" "${MODEL}" "${OUTPUT_FILE_PATH}" "${GENERATED_FILE}"

# Once present, the merged file is the durable library. If it does not exist,
# an existing _final.json can seed the first merge.
if [[ -f "${MERGED_FILE}" ]]; then
  MASTER_FILE="${MERGED_FILE}"
elif [[ -f "${EXISTING_FINAL_FILE}" ]]; then
  MASTER_FILE="${EXISTING_FINAL_FILE}"
else
  MASTER_FILE="${GENERATED_FILE}"
fi

# This does not modify MASTER_FILE. It writes a new durable merged library
# which keeps commands Govee no longer advertises but the physical device can
# still run.
bash "${SCRIPTDIR}/govee_fcn_09_merged_file.sh" "${MASTER_FILE}" "${GENERATED_FILE}" "${MERGED_FILE}"
