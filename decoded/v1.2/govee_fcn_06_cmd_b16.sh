#!/bin/bash

if [ "${1}" == "" ]; then
    exit
fi

OUTPUT_JSON="${1%}"
modelparams="${2}"

SCRIPTDIR=$(dirname $(readlink -f $0))
JSONDIR=$(dirname "${OUTPUT_JSON}")

###############################################################
# Add "01" and "num_lines_b16" value to "params_b16_mod"
# tempfile_06_010
tempfile_06_010="${JSONDIR}/06_010_b16_changes.json"
rm -f "${tempfile_06_010}"

jq 'map(if .params_b16_mod != "" then (.params_b16_mod = "01" + .num_lines_b16 + .params_b16_mod) else . end)' "${OUTPUT_JSON}" > "${tempfile_06_010}"

###############################################################
# Break "params_b16_mod" into 34 character (17 byte) arrays ("cmd_b16")
# tempfile_06_020
tempfile_06_020="${JSONDIR}/06_020_b16_multi.json"
rm -f "${tempfile_06_020}"

length=34

jq 'map(
	if .params_b16_mod != "" then
		. + {cmd_b16: (.params_b16_mod | [scan(".{1,'$length'}")])}
	else
		. + {cmd_b16: [""]}
	end
)' "${tempfile_06_010}" > "${tempfile_06_020}"

###############################################################
# THERE IS PROBABLY A BETTER WAY TO DO THIS STEP
# Add line index prefixes in hex (00, 01, 02, ... ff)
# tempfile_06_030
tempfile_06_030="${JSONDIR}/06_030_b16_multi_indexed.json"
rm -f "${tempfile_06_030}"

# create array in bash, each entry is comma separated
declare -a hex_array 

mapfile -t hex_array < <(jq -r '.[] | .cmd_b16 | join(",")' "${tempfile_06_020}")
#echo ${hex_array[@]}

unset modified_bash_array

for original_string in "${hex_array[@]}"; do
  IFS=',' read -r -a hex_values <<< "$original_string"
  num_values=${#hex_values[@]}

  declare -a modified_values
  unset modified_values

  for (( i=0; i<num_values; i++ )); do
    if [[ -v "hex_values[i]" ]]; then
        current_value="${hex_values[i]}"
		#echo $current_value
        counter=""
        if [[ $i -eq $((num_values - 1)) ]]; then
          counter="ff"
        else
          counter=$(printf "%02x" "$i")
        fi
		# add "a#" and index to each line
        modified="${counter}${current_value}"
        modified_values+=("$modified")
    fi
  done

  if [[ ${#modified_values[@]} -gt 0 ]]; then
    modified_string=$(printf "%s," "${modified_values[@]}")
    modified_string="${modified_string%,}"

    modified_bash_array+=("$modified_string")
  else
     modified_bash_array+=("")
  fi

done

# Fix annoying bash and jq stuff --> add to JSON

json_array_string=$(printf '["%s"] ' "${modified_bash_array[@]}")
json_array_string="${json_array_string%,}"
json_array_string=(${json_array_string[@]//','/'","'})

#echo "${json_array_string[@]}"

unset tempjson1

tempjson1=$(cat "${tempfile_06_020}" | jq --args 'to_entries | map(.value.cmd_b16 = ($ARGS.positional[.key] | fromjson)) | map(.value)' -- "${json_array_string[@]}")

tempjson1=${tempjson1//'"['/'['}
tempjson1=${tempjson1//']"'/']'}
tempjson1=${tempjson1//'\"'/'"'}

# make pretty and save to file
echo "${tempjson1}" | jq . > "${tempfile_06_030}"

###############################################################
# Add "hex_multi_prefix" ("a3") to the beginning of each "cmd_b16" line
# tempfile_06_040
tempfile_06_040="${JSONDIR}/06_040_b16_multi_prefix.json"
rm -f "${tempfile_06_040}"

jq 'map(.modparams.hex_multi_prefix as $prefix | if .cmd_b16 != [""] then .cmd_b16 |= map($prefix + .) end)' "${tempfile_06_030}" > "${tempfile_06_040}"

###############################################################
# Calculate and add standard command
# tempfile_06_050
tempfile_06_050="${JSONDIR}/06_050_b16_multi_standard.json"
rm -f "${tempfile_06_050}"

# create "code_only" bash array

mapfile -t code_only < <(jq -r '.[].code' "${tempfile_06_040}")
mapfile -t norm_suffix < <(jq -r '.[].type.normal_command_suffix' "${tempfile_06_040}")

#echo "${code_only[@]}"
#echo "${norm_suffix[@]}"

unset num_elements
num_elements=$((${#code_only[@]}-1))

code_cmd_prefix="330504"

unset hex_code_byte_swap

for i in $(seq 0 ${num_elements}); do

	unset dec_val
	unset hex_val
	
	dec_val=$(echo ${code_only[i]})
	#echo $dec_val
    hex_val=$("${SCRIPTDIR}/fcn_b10_2_b16.sh" ${dec_val} 2)
	#echo $hex_val
	
	#swap the bytes
	hex_code_byte_swap=$(echo ${hex_val:2:2}${hex_val:0:2})
	
	unset suffix
	
	#echo ${norm_suffix[i]} 
	
	if [ "${norm_suffix[i]}" == "null" ]; then
		suffix=""
	else
		suffix=$(echo ${norm_suffix[i]})
	fi
	
	standard_command[($i)]=${code_cmd_prefix}${hex_code_byte_swap}${suffix}
done

#echo "${standard_command[@]}"

###################
# Add standard command to "cmd_b16"

unset JSON_output
unset JSON_input
JSON_input=$(cat "${tempfile_06_040}")

JSON_output=$(jq --args '
  [
    range(length) as $index |
    .[$index] as $original_object |
    $ARGS.positional[$index] as $bash_element |

    $original_object + {
      cmd_b16: (
        $original_object.cmd_b16 |
        if . == [""] then
          [$bash_element]
        else
          . + [$bash_element]
        end
      )
    }
  ]
' <<< "$JSON_input" "${standard_command[@]}")

echo "${JSON_output}" | jq . > "${tempfile_06_050}"

###############################################################
# Add "on" command to "cmd_b16"
# tempfile_06_060
tempfile_06_060="${JSONDIR}/06_060_on_command.json"
rm -f "${tempfile_06_060}"

on_command=$(jq '.[0].modparams.on_command' "${tempfile_06_050}") #this is a bad

if [ $on_command == true ]; then

	jq '(.[].cmd_b16) |= (["330101"] + .)' "${tempfile_06_050}" > "${tempfile_06_060}"

else

	cat "${tempfile_06_050}" > "${tempfile_06_060}"

fi

###############################################################
# Pad lines of "cmd_b16" with "0" to length
# tempfile_06_070
tempfile_06_070="${JSONDIR}/06_070_b16_multi_padded.json"
rm -f "${tempfile_06_070}"

unset length
length=38
pad_char="0"

jq --argjson tl "$length" --arg pc "$pad_char" '
map(
  if .cmd_b16 != [""] then
    .cmd_b16 = (
      .cmd_b16 | map(
        . as $val | ($val | length) as $len |
        if $len < $tl then
          ($tl - $len) as $pad_len | ([range($pad_len)] | map($pc) | join("")) as $padding | $val + $padding
        else
          $val
        end
      )
    )
  end
)' "${tempfile_06_060}" > "${tempfile_06_070}"

###############################################################
# Checksum
# tempfile_06_080
tempfile_06_080="${JSONDIR}/06_080_b16_multi_checksum.json"
rm -f "${tempfile_06_080}"

# create array in bash, each entry is comma separated
declare -a hex_array 
mapfile -t hex_array < <(jq -r '.[] | .cmd_b16 | join(",")' "${tempfile_06_070}")

#echo "${hex_array[@]}"

# Create arrays, add checksum, etc, etc.

declare -a modified_bash_array
unset modified_bash_array

counter=0

for original_string in "${hex_array[@]}"; do
  IFS=',' read -r -a hex_values <<< "$original_string"
  num_values=${#hex_values[@]}

  unset modified_values
  declare -a modified_values
  
  for (( i=0; i<num_values; i++ )); do
		current_value="${hex_values[i]}"
		checksum=$("${SCRIPTDIR}/fcn_b16_checksum.sh" ${current_value})
		
		modified_values[($i)]="${current_value}${checksum}"
		
  done
  
  modified_bash_array[($counter)]=$(printf "%s," "${modified_values[@]}")

  counter=$(($counter+1))
  
done

# "${modified_bash_array[@]}" is good to this point

# Fix annoying bash and jq stuff --> add to JSON

unset json_array_string
json_array_string=$(printf '["%s"] ' "${modified_bash_array[@]}")
json_array_string="${json_array_string%,}"
json_array_string=${json_array_string//','/'","'}
json_array_string=${json_array_string//'",""]'/'"]'}
json_array_string=(`echo ${json_array_string[0]}`)

unset JSON_to_merge
JSON_to_merge=$(printf "%s\n" "${json_array_string[@]}" | jq -nR '[inputs | {cmd_b16: .}]')
JSON_to_merge=${JSON_to_merge//'"['/'['}
JSON_to_merge=${JSON_to_merge//']"'/']'}
JSON_to_merge=${JSON_to_merge//'\"'/'"'}

echo "$JSON_to_merge" > "${tempfile_06_080}"

cat "${tempfile_06_010}" "${tempfile_06_080}" | jq -n '[inputs] | transpose | map(add)' > "${OUTPUT_JSON}"

#exit

# CLEANUP
rm -f "${tempfile_06_010}"
rm -f "${tempfile_06_020}"
rm -f "${tempfile_06_030}"
rm -f "${tempfile_06_040}"
rm -f "${tempfile_06_050}"
rm -f "${tempfile_06_060}"
rm -f "${tempfile_06_070}"
rm -f "${tempfile_06_080}"