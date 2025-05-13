#!/bin/bash

if [ "${1}" == "" ]; then
    exit
fi

RAWFILE="${1%/}"

FILENAME=$(basename "${RAWFILE}")
JSONDIR=$(dirname "${RAWFILE}")

SCRIPTDIR=$(dirname $(readlink -f $0))

mkdir -p "${JSONDIR}"

###############################################################
# Copy Raw File
# tempfile_03_010
tempfile_03_010="${JSONDIR}/03_010_raw.json"
rm -f "${tempfile_03_010}"

cp "${RAWFILE}" "${tempfile_03_010}"

###############################################################
# Filtered file with only "name", "code", and "params_b64" (combine name and subname)
# tempfile_03_020
tempfile_03_020="${JSONDIR}/03_020_filtered_scenes.json"
rm -f "${tempfile_03_020}"
# tempfile_03_030
tempfile_03_030="${JSONDIR}/03_030_filtered_scenes.json"
rm -f "${tempfile_03_030}"
# tempfile_03_040
tempfile_03_040="${JSONDIR}/03_040_filtered_scenes.json"
rm -f "${tempfile_03_040}"
tempfile_03_041="${JSONDIR}/03_041_NBSP_removed.json"
rm -f "${tempfile_03_041}"

#
jq '[.data.categories[].scenes[] | {name: .sceneName, data: .lightEffects[] | {subname: .scenceName, code: .sceneCode, params_b64: .scenceParam, scenetyperaw: .sceneType}}]' "${tempfile_03_010}" > "${tempfile_03_020}"
jq '[.[] | {name: .name, subname: .data.subname, code: .data.code, params_b64: .data.params_b64, scenetyperaw: .data.scenetyperaw}]' "${tempfile_03_020}" > "${tempfile_03_030}"
jq '[.[] | {name: (.name + "-" + .subname), code: .code, params_b64: .params_b64, scenetyperaw: .scenetyperaw}]' "${tempfile_03_030}" > "${tempfile_03_040}"
jq 'walk(if type == "string" then gsub(" "; " ") else . end)' "${tempfile_03_040}" > "${tempfile_03_041}"

###############################################################
# Remove dangling "-" from "name"
# tempfile_03_050
tempfile_03_050="${JSONDIR}/03_050_merged_names.json"
rm -f "${tempfile_03_050}"

namefix1=$(cat "${tempfile_03_041}")
namefix2=${namefix1//'-",'/'",'}
echo "${namefix2}" > "${tempfile_03_050}"

###############################################################
# File with only "params_b64" (one scene per line)
# tempfile_03_060
tempfile_03_060="${JSONDIR}/03_060_params_b64.json"
rm -f "${tempfile_03_060}"

jq '.[] | .params_b64' "${tempfile_03_050}" > "${tempfile_03_060}"

num_lines=$(wc -l < "${tempfile_03_060}")
readarray -t params_b64 < "${tempfile_03_060}"

###############################################################
# File with "params_b16" (only)
# tempfile_03_070
tempfile_03_070="${JSONDIR}/03_070_params_b16.json"
rm -f "${tempfile_03_070}"

for p in $(seq 1 $num_lines); do 

	unset b64

	b64=${params_b64[$((${p}-1))]}
	hex=$("${SCRIPTDIR}/fcn_b64_2_b16.sh" ${b64})

	if [ $p == 1 ]; then
		echo "[" >> "${tempfile_03_070}"
	fi
	
	echo '{' >> "${tempfile_03_070}"
	echo '"params_b16": ' >> "${tempfile_03_070}"
	echo '"'"${hex}"'"' >> "${tempfile_03_070}"
	echo "}" >> "${tempfile_03_070}"
	
	if [ $p -lt $num_lines ]; then
		echo "," >> "${tempfile_03_070}"
	else
		echo "]" >> "${tempfile_03_070}"
	fi
	
done

###############################################################
# Combined File with "params_b16"
# FILE_OUT
FILE_OUT="${JSONDIR}/${FILENAME/raw.json/debug.json}"

jq -s 'transpose | map(add)' "${tempfile_03_050}" "${tempfile_03_070}" > "${FILE_OUT}"

###############################################################
# Echo Output
echo "${FILE_OUT}"

#exit

# CLEANUP
rm -f "${tempfile_03_010}"
rm -f "${tempfile_03_020}"
rm -f "${tempfile_03_030}"
rm -f "${tempfile_03_040}"
rm -f "${tempfile_03_041}"
rm -f "${tempfile_03_050}"
rm -f "${tempfile_03_060}"
rm -f "${tempfile_03_070}"