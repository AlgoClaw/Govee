#!/usr/bin/env bash

# Add Base64 LAN command arrays alongside the hexadecimal command arrays.

source "$(dirname -- "$(readlink -f -- "$0")")/govee_fcn_lib.sh"
govee_enable_strict_mode
govee_require_commands jq xxd base64 mktemp

if [[ $# -ne 1 || -z "${1}" ]]; then
  printf 'Usage: %s DEBUG_JSON\n' "$0" >&2
  exit 1
fi

OUTPUT_JSON="${1%/}"
if [[ ! -f "${OUTPUT_JSON}" ]]; then
  printf 'Debug JSON file does not exist: %s\n' "${OUTPUT_JSON}" >&2
  exit 1
fi

# Like stage 06, use JSON Lines for a safe Bash-to-jq boundary: one converted
# command per line, then group them back into each scene's command array.
command_lines="$(govee_temp_for "${OUTPUT_JSON}")"
command_groups="$(govee_temp_for "${OUTPUT_JSON}")"
output_temporary="$(govee_temp_for "${OUTPUT_JSON}")"
trap 'rm -f "${command_lines}" "${command_groups}" "${output_temporary}"' EXIT

while IFS=$'\t' read -r index command; do
  # Home Assistant and the Govee LAN payload use Base64 packet strings.
  command_b64="$(govee_hex_to_b64 "${command}")"
  jq -cn --argjson index "${index}" --arg command_b64 "${command_b64}" \
    '{index: $index, cmd_b64: $command_b64}' >> "${command_lines}"
done < <(
  jq -r 'to_entries[] | .key as $index | .value.cmd_b16[] | [$index, .] | @tsv' "${OUTPUT_JSON}"
)

# Preserve packet order while rebuilding cmd_b64 per scene.
jq -s '
  group_by(.index)
  | map({index: .[0].index, cmd_b64: map(.cmd_b64)})
' "${command_lines}" > "${command_groups}"

jq --slurpfile command_groups "${command_groups}" '
  reduce $command_groups[0][] as $command_group (
    .;
    .[$command_group.index].cmd_b64 = $command_group.cmd_b64
  )
' "${OUTPUT_JSON}" > "${output_temporary}"

mv -- "${output_temporary}" "${OUTPUT_JSON}"
trap - EXIT
rm -f -- "${command_lines}" "${command_groups}"
