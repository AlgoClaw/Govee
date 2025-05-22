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
tempfile_03_030="${JSONDIR}/03_030_NBSP_removed.json"
rm -f "${tempfile_03_030}"

jq '
  [
    .data.categories[].scenes[] as $scene |
    $scene.lightEffects[] as $effect |
    {
      name: ($scene.sceneName + "-" + $effect.scenceName),
	  sceneId_b10: $scene.sceneId,
	  sceneId_b16: "",
	  scenceParamId_b10: $effect.scenceParamId,
	  scenceParamId_b16: "",
	  sceneType_b10: $effect.sceneType,
	  sceneType_b16: "",
      sceneCode_b10: $effect.sceneCode,
	  sceneCode_b16: "",
	  sceneCode_b16_swapped: "",
      params_b64: $effect.scenceParam
    }
  ]
' "${tempfile_03_010}" > "${tempfile_03_020}"

# Replace "NBSP" whitespaces with standard spaces 
jq 'walk(if type == "string" then gsub(" "; " ") else . end)' "${tempfile_03_020}" > "${tempfile_03_030}"

###############################################################
# Add b16 conversions
# tempfile_03_040
tempfile_03_040="${JSONDIR}/03_040_b16_conversions.json"
rm -f "${tempfile_03_040}"

"${SCRIPTDIR}/fcn_b10_2_b16_array.sh" "${tempfile_03_030}" "sceneId_b10" "sceneId_b16" "${tempfile_03_040}"
"${SCRIPTDIR}/fcn_b10_2_b16_array.sh" "${tempfile_03_040}" "scenceParamId_b10" "scenceParamId_b16" "${tempfile_03_030}"
"${SCRIPTDIR}/fcn_b10_2_b16_array.sh" "${tempfile_03_030}" "sceneType_b10" "sceneType_b16" "${tempfile_03_040}"
"${SCRIPTDIR}/fcn_b10_2_b16_array.sh" "${tempfile_03_040}" "sceneCode_b10" "sceneCode_b16" "${tempfile_03_030}"
jq 'map(.sceneCode_b16_swapped = (.sceneCode_b16 | if type == "string" then (. as $str | [range(0; ($str | length / 2 | floor)) as $i | ($str | split("")[ ($i*2) : ($i*2 + 2) ] | join("")) ] | reverse | join("")) else .sceneCode_b16 end))' "${tempfile_03_030}" > "${tempfile_03_040}"

###############################################################
# Remove dangling "-" from "name"
# tempfile_03_050
tempfile_03_050="${JSONDIR}/03_050_merged_names.json"
rm -f "${tempfile_03_050}"

namefix1=$(cat "${tempfile_03_040}")
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