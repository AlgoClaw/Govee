#!/bin/bash

if [ "${1}" == "" ]; then
    exit
fi

num_dec="${1}"
bytes="${2}"

num_chars=$(($bytes*2))

if ! [[ "$num_dec" =~ ^[0-9]+$ ]]; then
  echo "Error: Input '$num_dec' is not a non-negative integer." >&2
  exit
fi

hex_str=$(printf "%x" "$num_dec") 

width=$(( bytes + (bytes % $num_chars) ))

printf "%0*x\n" "$width" "$num_dec" 