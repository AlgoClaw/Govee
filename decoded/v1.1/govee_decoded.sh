#!/bin/bash

MODEL=H61A8

############
# Pull the scene data from Govee. The publicly available (no-key-required) API works. Write to file "govee_MODEL_scenes_raw.json".

curl "https://app2.govee.com/appsku/v1/light-effect-libraries?sku=${MODEL}" -H 'AppVersion: 9999999' -s > govee_${MODEL}_scenes_raw.json

############
# Generate a "pretty" version of the raw data for debugging, decoding, troubleshooting, etc.

#jq . <govee_${MODEL}_scenes_raw.json >govee_${MODEL}_scenes_raw_pretty.json

############
# Filter for needed data ("sceneName", "scenceName", "sceneCode", and "scenceParam"). Write the output to "govee_MODEL_scenes_filtered.json".

#rm govee_${MODEL}_scenes_filtered.json
cat govee_${MODEL}_scenes_raw.json | jq '[.data.categories[].scenes[] | {name: .sceneName, data: .lightEffects[] | {subname: .scenceName, code: .sceneCode, params_b64: .scenceParam}}]' > govee_${MODEL}_scenes_filtered.json

############
# Generate "params_hex" by converting "params_b64" from base64 to hexadecimal

#rm govee_${MODEL}_scenes_b64only.json
cat govee_${MODEL}_scenes_filtered.json | jq '.[] | .data.params_b64' > govee_${MODEL}_scenes_b64only.json

readarray -t params_b64 < govee_${MODEL}_scenes_b64only.json

unset params_hex
#rm govee_${MODEL}_scenes_hexonly.json
for b64 in "${params_b64[@]}"; do
	if [ ${b64} == "" ]; then
		hex=""
	else
		hex=$(echo ${b64//\"/} | base64 -d | od -t x1 -An)
	fi
	params_hex+=("${hex}")
	echo -e "${hex}" >> govee_${MODEL}_scenes_hexonly.json
done

############
# Count scenes for major loop

#rm govee_${MODEL}_hex_commands.json
unset num_scenes
num_scenes=$(wc -l < govee_${MODEL}_scenes_b64only.json)
#echo ${num_scenes}

for p in $(seq 1 $num_scenes); do 

	############
	# Count number of lines/commands and convert to hex
	hex_line=${params_hex[$(($p-1))]//[[:space:]]}

	num_chars=$((${#hex_line}+6+26))
	num_cmds=$((${num_chars}/34))
	num_cmds_hex=$(printf "%0*x\n" 2 $num_cmds)

	############
	# Add overall prefix and suffixes
	hex_prefix="01"${num_cmds_hex}"02"
	hex_suffix="00000000000000000000000000"
	hex_cmd=${hex_prefix}${hex_line}${hex_suffix}

	############
	# Add prefix to command/line

	unset hex_cmnds_temp
	for i in $(seq 1 $num_cmds); do 

		unset prefix_count
		unset start_index
		unset hex_cmd_temp

		if [ $i == $num_cmds ]; then
			prefix_count="ff"
		else
			prefix_count=$(printf "%0*x\n" 2 $(($i-1)))
		fi

		start_index=$((($i-1)*34))
		
		hex_cmd_temp=$(echo "a3"${prefix_count}${hex_cmd:$start_index:34})
		
		hex_cmnds_temp[(($i-1))]="${hex_cmd_temp}"
		
	done

	############
	# Calculate Standard Command

	# Scene code and switcheroo
	#rm govee_${MODEL}_scenes_codeonly.json
	cat govee_${MODEL}_scenes_filtered.json | jq '.[] | .data.code' > govee_${MODEL}_scenes_codeonly.json
	readarray -t code_only < govee_${MODEL}_scenes_codeonly.json


	code_hex=$(printf "%0*x\n" 4 ${code_only[$(($p-1))]})
	code_hex=$(echo ${code_hex:2:2}${code_hex:0:2})

	#echo ${code_hex}

	hex_prefix_code="330504"
	padding_code="0000000000000000000000000000"

	hex_cmnds_temp[$num_cmds]=${hex_prefix_code}${code_hex}${padding_code}

	#echo ${hex_cmnds_temp[@]}

	############
	# Calculate checksums for all commands and append as suffix

	unset byteArray
	unset hex_cmnds
	for i in $(seq 1 $((num_cmds + 1))); do 
		
		unset checksum
		
		byteArray=${hex_cmnds_temp[(($i-1))]}
		checksum=0x00
		q=0

		while [ $q -lt ${#byteArray} ]; do
			byte="0x${byteArray:$q:2}"
			checksum=$((checksum ^ byte))
			q=$((q + 2))
		done

		checksum=$(printf "%0*x\n" 2 $checksum)
		
		hex_cmnds[(($i-1))]='"'${byteArray}${checksum}'"'
		
		#echo ${hex_cmnds[(($i-1))]}

	done

	unset hex_to_write
	hex_to_write=$(echo ${hex_cmnds[@]})

	echo '['${hex_to_write[@]// /,}']' >> govee_${MODEL}_hex_commands.json

done

############
# Calculate base64 arrays

unset hex_commands
readarray -t hex_commands < govee_${MODEL}_hex_commands.json
#echo ${hex_commands}

unset p
for p in $(seq 1 $num_scenes); do 
	
	hex_codes=${hex_commands[$(($p-1))]}

	# Remove leading bracket ([)
	hex_codes="${hex_codes//[/''}"

	# Remove trailing bracket (])
	hex_codes="${hex_codes//]/''}"

	# Convert to proper array
	readarray -t hex_codes < <(awk -F ',' '{for (i=1; i<=NF; i++) print $i}' <<< "$hex_codes")

	#### Generate output

	b64_out="["

	for hex in "${hex_codes[@]}"; do

	  b64=$(echo "$hex" | xxd -r -p | base64)
	  
	  # output each results on separate line
	  #echo ${b64}
	  
	  b64_out=${b64_out}',"'${b64}'"'
	  
	done

	b64_out=${b64_out}"]"

	# Remove leading comma
	b64_out="${b64_out//[,/[}"

	echo ${b64_out} >> govee_${MODEL}_b64_commands.json

done

unset b64_commands
readarray -t b64_commands < govee_${MODEL}_b64_commands.json


############
# Format JSON
cat govee_${MODEL}_scenes_filtered.json | jq '[.[] | {name: .name, subname: .data.subname, code: .data.code, params_b64: .data.params_b64}]' > govee_${MODEL}_scenes_filtered2.json
filtered2=$(cat govee_${MODEL}_scenes_filtered2.json)
filtered2=${filtered2//'"'subname'"': '""',/}
echo $filtered2 > govee_${MODEL}_scenes_filtered3.json
filtered3=$(cat govee_${MODEL}_scenes_filtered3.json)
filtered3=${filtered3//'"', '"'subname'"': '"'/-}
echo $filtered3 > govee_${MODEL}_scenes_filtered4.json
jq . govee_${MODEL}_scenes_filtered4.json > govee_${MODEL}_scenes_filtered5.json
jq '.[] += {hex_cmd: "", b64_cmd: ""}' govee_${MODEL}_scenes_filtered5.json > govee_${MODEL}_scenes_filtered6.json

############
# Add hex and b64 commands
filtered6=$(cat govee_${MODEL}_scenes_filtered6.json)
unset p
for p in $(seq 1 $num_scenes); do 

	filtered6=$(echo ${filtered6/'"'hex_cmd'"': '""'/'"'hex_cmd'"': "${hex_commands[$(($p-1))]}"})
	filtered6=$(echo ${filtered6/'"'b64_cmd'"': '""'/'"'b64_cmd'"': "${b64_commands[$(($p-1))]}"})
	
done

echo $filtered6 > govee_${MODEL}_scenes_filtered7.json
jq . govee_${MODEL}_scenes_filtered7.json > govee_${MODEL}_scenes_with_commands.json


############
# Cleanup
rm govee_${MODEL}_scenes_b64only.json
rm govee_${MODEL}_scenes_hexonly.json
rm govee_${MODEL}_scenes_codeonly.json
rm govee_${MODEL}_hex_commands.json
rm govee_${MODEL}_b64_commands.json
rm govee_${MODEL}_scenes_filtered.json
rm govee_${MODEL}_scenes_filtered2.json
rm govee_${MODEL}_scenes_filtered3.json
rm govee_${MODEL}_scenes_filtered4.json
rm govee_${MODEL}_scenes_filtered5.json
rm govee_${MODEL}_scenes_filtered6.json
rm govee_${MODEL}_scenes_filtered7.json
