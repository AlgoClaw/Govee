#!/bin/bash

if [ "${1}" == "" ]; then
    exit
fi

MODEL="${1}"
OUTPUT_JSON="${2%}"

SCRIPTDIR=$(dirname $(readlink -f $0))
JSONDIR=$(dirname "${OUTPUT_JSON}")


# The optional third argument lets the full pipeline keep the historical
# _final.json intact while writing a fresh API result to _final_current.json.
final_output="${3:-${JSONDIR}/${MODEL}_final_current.json}"
rm -f "${final_output}"

jq '[.[] | {name: .name, cmd_b64: .cmd_b64}]' "${OUTPUT_JSON}" > "${final_output}"
