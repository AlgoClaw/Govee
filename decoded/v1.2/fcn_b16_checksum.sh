#!/bin/bash

if [ "${1}" == "" ]; then
    exit
fi

hex="${1}"

checksum=0x00
q=0

while [ $q -lt ${#hex} ]; do
	byte="0x${hex:$q:2}"
	checksum=$((checksum ^ byte))
	q=$((q + 2))
done

checksum=$(printf "%0*x\n" 2 $checksum)

echo "${checksum}"