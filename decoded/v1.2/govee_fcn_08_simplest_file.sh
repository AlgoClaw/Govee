#!/bin/bash

if [ "${1}" == "" ]; then
    exit
fi

MODEL="${1}"
OUTPUT_JSON="${2%}"

SCRIPTDIR=$(dirname $(readlink -f $0))
JSONDIR=$(dirname "${OUTPUT_JSON}")


# final_output
final_output="${JSONDIR}/${MODEL}_final.json"
rm -f "${final_output}"

jq '[.[] | {name: .name, cmd_b64: .cmd_b64}]' "${OUTPUT_JSON}" > "${final_output}"