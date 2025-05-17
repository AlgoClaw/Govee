#!/bin/bash

if [ "${1}" == "" ]; then
    exit
fi

num_dec="${1}"
bytes="${2}"

if ! [[ "$num_dec" =~ ^[0-9]+$ ]]; then
  echo "Error: Input '$num_dec' is not a non-negative integer." >&2
  exit
fi

char_count="${#num_dec}"

rounded_num=$(( (char_count + 1) / 2 * 2 ))

hex_bytes=$(( rounded_num / 2 ))

width=$(( hex_bytes + (hex_bytes % rounded_num) ))

printf "%0*x\n" "$width" "$num_dec" 