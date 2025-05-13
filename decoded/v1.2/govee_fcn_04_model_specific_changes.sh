#!/bin/bash

if [ "${1}" == "" ]; then
    exit
fi

OUTPUT_JSON="${1%}"
modelparams="${2}"

type=$(echo $modelparams | jq '.type')

SCRIPTDIR=$(dirname $(readlink -f $0))
JSONDIR=$(dirname "${OUTPUT_JSON}")

modparamsnotype=$(echo $modelparams | jq 'del(.type)')

###############################################################
# Add "mod_params" (without "type") to each scene
# tempfile_04_010
tempfile_04_010="${JSONDIR}/04_010_with_params.json"
rm -f "${tempfile_04_010}"

jq 'map(.modparams = '"${modparamsnotype}"')' "${OUTPUT_JSON}" > "${tempfile_04_010}"

###############################################################
# Determine "type" (match "hex_prefix_remove" to determine "type")
# tempfile_04_020
# tempfile_04_030
tempfile_04_020="${JSONDIR}/04_020_add_type.json"
tempfile_04_030="${JSONDIR}/04_030_add_type.json"
rm -f "${tempfile_04_020}"
rm -f "${tempfile_04_030}"

cp "${tempfile_04_010}" "${tempfile_04_020}"

type_count=$(echo $modelparams | jq '.type | length')

# if there is no "type"
if [ $type_count == 0 ]; then
	cp "${tempfile_04_010}" "${tempfile_04_030}"
fi


for (( i=0; i<type_count; i++ )); do
	
	type_data=$(echo $modelparams | jq '.type.['"${i}"']')
	pref_rem=$(echo $modelparams | jq '.type.['"${i}"'].hex_prefix_remove')
	pref_rem_num=$(echo "${#pref_rem}")
	pref_rem_num=$(("${pref_rem_num}" -2 ))
	
	
	jq 'map(
		if .params_b16[0:'"${pref_rem_num}"'] == '"${pref_rem}"' then
			.type = '"${type_data}"'
		end
	)' "${tempfile_04_020}" > "${tempfile_04_030}"
	
	cp "${tempfile_04_030}" "${tempfile_04_020}"
	
done

###############################################################
# Add "params_b16_mod" = "params_b16"
# tempfile_04_040
tempfile_04_040="${JSONDIR}/04_040_b16_mod.json"
rm -f "${tempfile_04_040}"

jq 'map(.params_b16_mod = .params_b16)' "${tempfile_04_030}" > "${tempfile_04_040}"

###############################################################
# Remove "hex_prefix_remove" (if present) and add "hex_prefix_add"
# tempfile_04_050
tempfile_04_050="${JSONDIR}/04_050_b16_prefix.json"
rm -f "${tempfile_04_050}"

jq 'map(
	if .params_b16_mod != "" then
		(.type.hex_prefix_remove | length ) as $len |
			.params_b16_mod = .type.hex_prefix_add + .params_b16_mod[$len:]
	end
)' "${tempfile_04_040}" > "${tempfile_04_050}"

###############################################################

cat "${tempfile_04_050}" > "${OUTPUT_JSON}"

#exit

# CLEANUP
rm -f "${tempfile_04_010}"
rm -f "${tempfile_04_020}"
rm -f "${tempfile_04_030}"
rm -f "${tempfile_04_040}"
rm -f "${tempfile_04_050}"