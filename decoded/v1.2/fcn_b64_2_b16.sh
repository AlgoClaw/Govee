#!/bin/bash

b64="${1}"

if [ ${b64} == "" ]; then
	hex=""
else
	hex=$(echo ${b64//\"/} | base64 -d | od -t x1 -An -w20 | tr -d '\n' | tr -d ' ')
fi

echo $hex
