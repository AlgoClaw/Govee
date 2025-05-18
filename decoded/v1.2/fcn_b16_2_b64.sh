#!/bin/bash

if [ "${1}" == "" ]; then
    exit
fi

b16="${1}"

if [ ${b16} == "" ]; then
	b64=""
else
	b64=$(echo "${b16}" | xxd -r -p | base64)
fi

echo $b64