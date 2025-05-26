#!/bin/bash

if [ "${1}" == "" ]; then
    exit
fi

MODEL="${1}"

SCRIPTDIR=$(dirname $(readlink -f $0))

###############################################################
# Download Reference JSON

mkdir -p "${SCRIPTDIR}"
FILE="${SCRIPTDIR}/model_specific_parameters.json"
rm -f "${FILE}"

curl https://raw.githubusercontent.com/AlgoClaw/Govee/refs/heads/main/decoded/v1.2/model_specific_parameters.json -o "${FILE}" 2>/dev/null

###############################################################
# Get Params

unset model_params

model_params=$(cat "${FILE}" | jq '.[] | select(.models | index("'${MODEL}'")) | del(.models) | .')

# if absent, default to "null"

if [ -z "${model_params}" ]; then
	model_params=$($0 "null")
fi

###############
# Echo Output
echo ${model_params}
