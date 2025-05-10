#!/bin/bash

if [ "${1}" == "" ]; then
    exit
fi

OUTPUT_JSON="${1%}"

SCRIPTDIR=$(dirname $(readlink -f $0))
JSONDIR=$(dirname "${OUTPUT_JSON}")

##############
##############
# 
# tempfile_07_010
tempfile_07_010="${JSONDIR}/07_010_input_file.json"
rm -f "${tempfile_07_010}"

cp "${OUTPUT_JSON}" "${tempfile_07_010}"

##############
# 
# tempfile_07_020
tempfile_07_020="${JSONDIR}/07_020_b16_multi_checksum.json"
rm -f "${tempfile_07_020}"

declare -a cmd_b16
mapfile -t cmd_b16 < <(jq -r '.[] | .cmd_b16 | join(",")' "${tempfile_07_010}")

declare -a modified_bash_array
unset modified_bash_array

counter=0

for original_string in "${cmd_b16[@]}"; do
  IFS=',' read -r -a cmd_b16 <<< "$original_string"
  num_values=${#cmd_b16[@]}

  unset modified_values
  declare -a modified_values
  
  for (( i=0; i<num_values; i++ )); do
		current_value="${cmd_b16[i]}"
		b64=$("${SCRIPTDIR}/fcn_b16_2_b64.sh" ${current_value})

		modified_values[($i)]="${b64}"
		
  done
  
  modified_bash_array[($counter)]=$(printf "%s," "${modified_values[@]}")

  counter=$(($counter+1))
  
done

# Fix annoying bash and jq stuff --> add to JSON

unset json_array_string
json_array_string=$(printf '["%s"] ' "${modified_bash_array[@]}")
json_array_string="${json_array_string%,}"
json_array_string=${json_array_string//','/'","'}
json_array_string=${json_array_string//'",""]'/'"]'}
json_array_string=(`echo ${json_array_string[0]}`)

unset JSON_to_merge
JSON_to_merge=$(printf "%s\n" "${json_array_string[@]}" | jq -nR '[inputs | {cmd_b64: .}]')
JSON_to_merge=${JSON_to_merge//'"['/'['}
JSON_to_merge=${JSON_to_merge//']"'/']'}
JSON_to_merge=${JSON_to_merge//'\"'/'"'}

echo "${JSON_to_merge[@]}" > "${tempfile_07_020}"

#JSON_output=$(cat "${OUTPUT_JSON}" "${tempfile_07_020}" | jq -n '[inputs] | transpose | map(add)')
#echo "${JSON_output}" > "${OUTPUT_JSON}"
jq -n '[inputs] | transpose | map(add)' "${tempfile_07_010}" "${tempfile_07_020}" > "${OUTPUT_JSON}"

#exit

# CLEANUP
rm -f "${tempfile_07_010}"
rm -f "${tempfile_07_020}"