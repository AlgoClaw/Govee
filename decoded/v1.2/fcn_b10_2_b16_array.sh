#!/bin/bash

# sudo bash "/Scripts/govee/b10_2_b16_array.sh" "/Scripts/govee/JSONs/H6065_debug.json" "sceneId_b10" "sceneId_b16" "/Scripts/govee/JSONs/H6065_debug_2.json"

if [ "${1}" == "" ]; then
    exit
fi

JSON_input_file="${1}"
variable_in="${2}"
variable_out="${3}"
JSON_output_file="${4}"

SCRIPTDIR=$(dirname $(readlink -f $0))

JSONcontent=$(cat "${JSON_input_file}")

unset b10_array
mapfile -t b10_array < <(jq -r '.[] | .'"${variable_in}"' ' <<< "${JSONcontent}")

#echo "${b10_array[@]}"

###############################################################
# Create bash array of "b16_array" values

unset num_elements
num_elements=$((${#b10_array[@]}-1))

unset b16_array

for i in $(seq 0 ${num_elements}); do

	unset dec_val
	unset hex_val
	
	dec_val=$(echo ${b10_array[($i)]})
    hex_val=$("${SCRIPTDIR}/fcn_b10_2_b16.sh" ${dec_val})
	
	b16_array[($i)]=$hex_val
done

#echo "${b16_array[@]}"

###############################################################
# Add "b16_array" to "variable_out" in JSON_output_file

jq --args 'to_entries | map(.value.'"${variable_out}"' = $ARGS.positional[.key] | .value)' <<< "$JSONcontent" -- "${b16_array[@]}" > "${JSON_output_file}"