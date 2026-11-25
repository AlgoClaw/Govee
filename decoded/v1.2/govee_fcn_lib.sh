#!/usr/bin/env bash

# Shared helpers for the independent v1.2 pipeline stages. This file is
# sourced by those stages; it is not an executable pipeline stage itself.

govee_enable_strict_mode() {
  set -euo pipefail
  IFS=$'\n\t'
}

govee_require_commands() {
  local command_name
  for command_name in "$@"; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
      printf 'Required command is unavailable: %s\n' "${command_name}" >&2
      return 1
    fi
  done
}

govee_script_dir() {
  cd -- "$(dirname -- "${BASH_SOURCE[1]}")" && pwd
}

govee_temp_for() {
  local target="$1"
  mkdir -p -- "$(dirname -- "${target}")"
  mktemp "${target}.tmp.XXXXXX"
}

# Convert a decimal integer to lowercase hex. The output width is the next
# even number of characters based on the decimal digit count: 205 becomes
# 00cd, while 12 becomes 0c.
govee_decimal_to_even_width_hex() {
  local value="$1"
  if ! [[ "${value}" =~ ^[0-9]+$ ]]; then
    printf 'Expected a non-negative decimal integer, received: %s\n' "${value}" >&2
    return 1
  fi

  local width=$(( ((${#value} + 1) / 2) * 2 ))
  printf "%0*x" "${width}" "${value}"
}

govee_reverse_hex_bytes() {
  local hex="$1"
  if ! [[ "${hex}" =~ ^([[:xdigit:]]{2})*$ ]]; then
    printf 'Expected an even-length hexadecimal string, received: %s\n' "${hex}" >&2
    return 1
  fi

  local reversed=""
  local position
  for ((position = ${#hex} - 2; position >= 0; position -= 2)); do
    reversed+="${hex:position:2}"
  done
  printf '%s\n' "${reversed}"
}

govee_xor_checksum() {
  local hex="$1"
  if ! [[ "${hex}" =~ ^([[:xdigit:]]{2})*$ ]]; then
    printf 'Cannot checksum non-byte-aligned hexadecimal data: %s\n' "${hex}" >&2
    return 1
  fi

  local checksum=0
  local offset
  local byte
  for ((offset = 0; offset < ${#hex}; offset += 2)); do
    byte="${hex:offset:2}"
    checksum=$((checksum ^ 16#${byte}))
  done
  printf '%02x\n' "${checksum}"
}

govee_b64_to_hex() {
  local b64="$1"
  if [[ -z "${b64}" ]]; then
    return 0
  fi
  printf '%s' "${b64}" | base64 -d | od -An -tx1 -v | tr -d ' \n'
}

govee_hex_to_b64() {
  local hex="$1"
  if [[ -z "${hex}" ]]; then
    return 0
  fi
  if ! [[ "${hex}" =~ ^([[:xdigit:]]{2})*$ ]]; then
    printf 'Cannot Base64 encode non-byte-aligned hexadecimal data: %s\n' "${hex}" >&2
    return 1
  fi
  printf '%s' "${hex}" | xxd -r -p | base64 | tr -d '\n'
}
