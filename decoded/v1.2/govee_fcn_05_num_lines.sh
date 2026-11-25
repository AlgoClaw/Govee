#!/usr/bin/env bash

# Add the number of 17-byte transport payload packets required for each scene.

source "$(dirname -- "$(readlink -f -- "$0")")/govee_fcn_lib.sh"
govee_enable_strict_mode
govee_require_commands jq mktemp

if [[ $# -ne 1 || -z "${1}" ]]; then
  printf 'Usage: %s DEBUG_JSON\n' "$0" >&2
  exit 1
fi

OUTPUT_JSON="${1%/}"
if [[ ! -f "${OUTPUT_JSON}" ]]; then
  printf 'Debug JSON file does not exist: %s\n' "${OUTPUT_JSON}" >&2
  exit 1
fi

temporary="$(govee_temp_for "${OUTPUT_JSON}")"
trap 'rm -f "${temporary}"' EXIT

# An effect packet carries 17 bytes = 34 hexadecimal characters after its
# two-byte packet header. The payload later prepends 01 and the line count,
# so the line count is ceil((parameter hex length + 4) / 34).
#
# The line-count value uses the same even-width decimal-to-hex representation
# as the API metadata fields. It therefore has a consistent zero-padding rule.
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
  def decimal_to_even_width_hex:
    . as $number
    | ($number | tostring | length) as $digits
    | (((($digits + 1) / 2) | floor) * 2) as $width
    | ($number | decimal_to_hex | pad_left($width));

  map(
    if (.params_b16_mod // "") != "" then
      ((((.params_b16_mod | length) + 4) / 34) | ceil) as $line_count
      | .num_lines_b10 = $line_count
      | .num_lines_b16 = ($line_count | decimal_to_even_width_hex)
    else
      .num_lines_b10 = 0
      | .num_lines_b16 = (0 | decimal_to_even_width_hex)
    end
  )
' "${OUTPUT_JSON}" > "${temporary}"

mv -- "${temporary}" "${OUTPUT_JSON}"
trap - EXIT
