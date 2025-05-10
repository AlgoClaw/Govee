#!/bin/bash

if [ "${1}" == "" ]; then
    exit
fi

MODEL="${1}"

SCRIPTDIR=$(dirname $(readlink -f $0))
JSONDIR="${SCRIPTDIR}/JSONs"

###############################################################
# Download Reference JSON

RAW_FILE_PATH="${JSONDIR}/${MODEL}_raw.json"


if [ ! -e ${RAW_FILE_PATH} ]; then
  curl "https://app2.govee.com/appsku/v1/light-effect-libraries?sku=${MODEL}" -H 'AppVersion: 9999999' -s -o ${RAW_FILE_PATH} 2>/dev/null
fi

jq . ${RAW_FILE_PATH} > "${JSONDIR}/${MODEL}_raw_pretty.json"

###############################################################
# Echo Output
echo ${RAW_FILE_PATH}