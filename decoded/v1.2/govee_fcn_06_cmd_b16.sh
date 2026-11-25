#!/usr/bin/env bash

# Build padded, checksummed H61A8-style LAN packets in hexadecimal. Packet
# framing remains model-driven through modparams and type fields.

source "$(dirname -- "$(readlink -f -- "$0")")/govee_fcn_lib.sh"
govee_enable_strict_mode
govee_require_commands jq mktemp

if [[ $# -ne 2 || -z "${1}" || -z "${2}" ]]; then
  printf 'Usage: %s DEBUG_JSON MODEL_PROFILE_JSON\n' "$0" >&2
  exit 1
fi

OUTPUT_JSON="${1%/}"
MODEL_PARAMS="$2"
if [[ ! -f "${OUTPUT_JSON}" ]]; then
  printf 'Debug JSON file does not exist: %s\n' "${OUTPUT_JSON}" >&2
  exit 1
fi
if ! jq -e 'type == "object"' <<< "${MODEL_PARAMS}" >/dev/null; then
  printf 'Invalid model profile JSON.\n' >&2
  exit 1
fi

# packet_source holds commands before checksums. packet_lines holds one JSON
# record per packet after checksumming, and packet_groups gathers those packet
# records back into the owning scene. This avoids serializing arrays in Bash.
packet_source="$(govee_temp_for "${OUTPUT_JSON}")"
packet_lines="$(govee_temp_for "${OUTPUT_JSON}")"
packet_groups="$(govee_temp_for "${OUTPUT_JSON}")"
output_temporary="$(govee_temp_for "${OUTPUT_JSON}")"
trap 'rm -f "${packet_source}" "${packet_lines}" "${packet_groups}" "${output_temporary}"' EXIT

# Build all non-checksummed 19-byte command bodies. The final checksum byte
# is intentionally added by the Bash helper below after fixed-width padding.
#
# Effect packets: a3 <index|ff> <up to 17 payload bytes> <zero padding>
# Normal packet:  33 05 04 <little-endian scene code> <suffix> <zero padding>
jq '
  def hex_digit($number): "0123456789abcdef"[$number:$number + 1];
  def decimal_to_hex:
    if . < 16 then hex_digit(.)
    else ((. / 16 | floor) | decimal_to_hex) + hex_digit(. % 16)
    end;
  def pad_left($width):
    . as $value
    | ($width - ($value | length)) as $count
    | if $count > 0 then ([range(0; $count) | "0"] | join("")) + $value else $value end;
  def fixed_hex($number; $width): $number | decimal_to_hex | pad_left($width);
  def pad_command:
    . as $value
    | (38 - ($value | length)) as $count
    | if $count > 0 then $value + ([range(0; $count) | "0"] | join("")) else $value end;
  def indexed_effect_packets:
    . as $payload
    | [range(0; ($payload | length); 34) as $offset | $payload[$offset:($offset + 34)]] as $chunks
    | [
        range(0; ($chunks | length)) as $index
        | (if $index == (($chunks | length) - 1) then "ff" else fixed_hex($index; 2) end)
          + $chunks[$index]
      ];

  map(
    . as $scene
    | if ($scene.params_b16_mod // "") != "" then
        ("01" + $scene.num_lines_b16 + $scene.params_b16_mod) as $payload
        | ($scene.modparams.hex_multi_prefix // "") as $multi_prefix
        | .params_b16_mod = $payload
        | .cmd_b16 = ($payload | indexed_effect_packets | map($multi_prefix + .))
      else
        .cmd_b16 = []
      end
    | ("330504" + .sceneCode_b16_swapped + (.type.normal_command_suffix // "")) as $normal_command
    | .cmd_b16 += [$normal_command]
    | if .modparams.on_command == true then .cmd_b16 = ["330101"] + .cmd_b16 else . end
    | .cmd_b16 |= map(pad_command)
  )
' "${OUTPUT_JSON}" > "${packet_source}"

while IFS=$'\t' read -r index command; do
  # The twentieth byte is the XOR of the preceding 19 padded bytes.
  checksum="$(govee_xor_checksum "${command}")"
  jq -cn --argjson index "${index}" --arg command "${command}${checksum}" \
    '{index: $index, cmd_b16: $command}' >> "${packet_lines}"
done < <(
  jq -r 'to_entries[] | .key as $index | .value.cmd_b16[] | [$index, .] | @tsv' "${packet_source}"
)

# Group one JSON record per packet into the original array ordering.
jq -s '
  group_by(.index)
  | map({index: .[0].index, cmd_b16: map(.cmd_b16)})
' "${packet_lines}" > "${packet_groups}"

# Overlay completed command arrays without changing other debug fields.
jq --slurpfile packet_groups "${packet_groups}" '
  reduce $packet_groups[0][] as $packet (
    .;
    .[$packet.index].cmd_b16 = $packet.cmd_b16
  )
' "${packet_source}" > "${output_temporary}"

mv -- "${output_temporary}" "${OUTPUT_JSON}"
trap - EXIT
rm -f -- "${packet_source}" "${packet_lines}" "${packet_groups}"
