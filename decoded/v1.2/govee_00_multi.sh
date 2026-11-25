#!/usr/bin/env bash

# Fetch, decode, and merge all catalog SKUs. Each per-SKU run remains in the
# independent govee_fcn_00_all.sh stage runner.

set -euo pipefail

SCRIPTDIR="$(cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)"
MODELS=(
  H61A8 # own
  H610A # own
  H706C
  H6022
  H6051
  H6061
  H6065
  H6066
  H6072
  H6076
  H6079
  H6092
  H6167
  H7039 # own
)

for model in "${MODELS[@]}"; do
  bash "${SCRIPTDIR}/govee_fcn_00_all.sh" "${model}"
done
