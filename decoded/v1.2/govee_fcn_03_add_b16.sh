#!/usr/bin/env bash

# Normalize both API catalog shapes, deduplicate overlapping effects, and add
# the hexadecimal forms consumed by the packet-building stages.

source "$(dirname -- "$(readlink -f -- "$0")")/govee_fcn_lib.sh"
govee_enable_strict_mode
govee_require_commands jq base64 od mktemp

if [[ $# -ne 1 || -z "${1}" ]]; then
  printf 'Usage: %s RAW_CATALOG_JSON\n' "$0" >&2
  exit 1
fi

RAWFILE="${1%/}"
if [[ ! -f "${RAWFILE}" ]]; then
  printf 'Raw catalog file does not exist: %s\n' "${RAWFILE}" >&2
  exit 1
fi

JSONDIR="$(dirname -- "${RAWFILE}")"
FILENAME="$(basename -- "${RAWFILE}")"
if [[ "${FILENAME}" == *_raw.json ]]; then
  MODEL="${FILENAME%_raw.json}"
else
  MODEL="${FILENAME%.*}"
fi
OUTPUT_FILE="${JSONDIR}/${MODEL}_debug.json"

normalized_temporary="$(govee_temp_for "${OUTPUT_FILE}")"
conversion_temporary="$(govee_temp_for "${OUTPUT_FILE}")"
output_temporary="$(govee_temp_for "${OUTPUT_FILE}")"
trap 'rm -f "${normalized_temporary}" "${conversion_temporary}" "${output_temporary}"' EXIT

# Normalize the two catalog response shapes to a single scene record schema.
# Govee's field spelling really is "scence" in this API, so it is preserved
# throughout this repository. scene_key includes all API fields used to build
# a command, allowing overlap between v1/v2 to be removed without losing two
# same-named effects that have different commands.
jq '
  def catalog: .data? // .;
  def scene_key:
    [.name, .sceneId_b10, .scenceParamId_b10, .sceneType_b10, .sceneCode_b10, .params_b64]
    | tojson;

  [
    (catalog).categories[]?.scenes[]? as $scene
    | $scene.lightEffects[]? as $effect
    | {
        name: ((($scene.sceneName // "") + "-" + ($effect.scenceName // ""))
               | gsub(" "; " ")
               | if endswith("-") then .[0:-1] else . end),
        sceneId_b10: $scene.sceneId,
        sceneId_b16: "",
        scenceParamId_b10: $effect.scenceParamId,
        scenceParamId_b16: "",
        sceneType_b10: $effect.sceneType,
        sceneType_b16: "",
        sceneCode_b10: $effect.sceneCode,
        sceneCode_b16: "",
        sceneCode_b16_swapped: "",
        params_b64: $effect.scenceParam
      }
  ]
  | reduce .[] as $scene (
      {seen: {}, scenes: []};
      ($scene | scene_key) as $key
      | if .seen[$key] then . else .seen[$key] = true | .scenes += [$scene] end
    )
  | .scenes
' "${RAWFILE}" > "${normalized_temporary}"

while IFS=$'\t' read -r index scene_id param_id scene_type scene_code params_b64; do
  # Decimal fields use the pipeline's even-width hex representation. The
  # scene code is reversed into little-endian order for the mode packet, and
  # scenceParam is decoded from the Base64 byte string returned by Govee.
  scene_id_b16="$(govee_decimal_to_even_width_hex "${scene_id}")"
  param_id_b16="$(govee_decimal_to_even_width_hex "${param_id}")"
  scene_type_b16="$(govee_decimal_to_even_width_hex "${scene_type}")"
  scene_code_b16="$(govee_decimal_to_even_width_hex "${scene_code}")"
  scene_code_swapped="$(govee_reverse_hex_bytes "${scene_code_b16}")"
  params_b16="$(govee_b64_to_hex "${params_b64}")"

  # Emit a small JSON object per input record rather than constructing JSON
  # in Bash. The final jq reduce below joins these converted fields by index.
  jq -cn \
    --argjson index "${index}" \
    --arg scene_id_b16 "${scene_id_b16}" \
    --arg param_id_b16 "${param_id_b16}" \
    --arg scene_type_b16 "${scene_type_b16}" \
    --arg scene_code_b16 "${scene_code_b16}" \
    --arg scene_code_swapped "${scene_code_swapped}" \
    --arg params_b16 "${params_b16}" \
    '{
      index: $index,
      sceneId_b16: $scene_id_b16,
      scenceParamId_b16: $param_id_b16,
      sceneType_b16: $scene_type_b16,
      sceneCode_b16: $scene_code_b16,
      sceneCode_b16_swapped: $scene_code_swapped,
      params_b16: $params_b16
    }' >> "${conversion_temporary}"
done < <(
  # TSV is safe here: all source values are numeric or Base64 and thus cannot
  # contain a tab. It avoids a separate jq process for every single field.
  jq -r '
    to_entries[]
    | [.key, .value.sceneId_b10, .value.scenceParamId_b10,
       .value.sceneType_b10, .value.sceneCode_b10, .value.params_b64]
    | @tsv
  ' "${normalized_temporary}"
)

# Overlay each conversion result on the normalized API record, keeping all
# original decimal/debug fields visible in *_debug.json.
jq --slurpfile converted "${conversion_temporary}" '
  reduce $converted[] as $conversion (
    .;
    .[$conversion.index] += ($conversion | del(.index))
  )
' "${normalized_temporary}" > "${output_temporary}"

mv -- "${output_temporary}" "${OUTPUT_FILE}"
trap - EXIT
rm -f -- "${normalized_temporary}" "${conversion_temporary}"

printf '%s\n' "${OUTPUT_FILE}"
