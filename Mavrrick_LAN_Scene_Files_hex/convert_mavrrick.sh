#!/bin/bash

DIR="/path/to/Mavrrick_LAN_Scene_Files"

#########################
#########################
# Fix/Clean JSON Files

find "${DIR}" -type f -exec sed -i 's/\\\\=\\\"\"/=\"/g' {} +
find "${DIR}" -type f -exec sed -i 's/\"\\\"/\"/g' {} +
find "${DIR}" -type f -exec sed -i 's/\"\[/\[/g' {} +
find "${DIR}" -type f -exec sed -i 's/\\\"/\"/g' {} +
find "${DIR}" -type f -exec sed -i 's/\s/ /g' {} +
find "${DIR}" -type f -exec sed -i 's/\", \"/\",\n\"/g' {} +
find "${DIR}" -type f -exec sed -i 's/\[\"/\[\n\"/g' {} +
find "${DIR}" -type f -exec sed -i 's/\"\]/\"\n\]/g' {} +
find "${DIR}" -type f -exec sed -i 's/\[{/\[\n{/g' {} +
find "${DIR}" -type f -exec sed -i 's/{\[/{\n\[/g' {} +
find "${DIR}" -type f -exec sed -i 's/\"\"/\"/g' {} +
find "${DIR}" -type f -exec sed -i 's///g' {} +
find "${DIR}" -type f -exec sed -i 's/\\\\\\\\u003d/\=/g' {} +
find "${DIR}" -type f -exec sed -i 's/\]\"/\]/g' {} +
find "${DIR}" -type f -exec sed -i 's/\=\]/\=\"\n\]/g' {} +
find "${DIR}" -type f -exec sed -i 's/{m/{\"m/g' {} +
find "${DIR}" -type f -exec sed -i 's/\\\\\//\//g' {} +
find "${DIR}" -type f -exec sed -i 's/cmd/cmd_b64/g' {} +
find "${DIR}" -type f -name "*.json" -exec sh -c 'jq . "{}" > "{}.tmp" && mv "{}.tmp" "{}"' \;

# Add blank "cmd_hex" field to each file
find "${DIR}" -type f -name "*.json" -exec sh -c '
for file in "$@"; do
    cat $file  | jq "[.[].[].[] | {name: .name, cmd_b64: .cmd_b64, cmd_hex: []}]" > ${file}.tmp
    mv  ${file}.tmp  ${file}
done
' sh {} \;

# Remove Empty null field at end
find "${DIR}" -type f -name "*.json" -exec sh -c '
for file in "$@"; do
    	jq "map(select(.name != null))" $file > $file.tmp
    mv  ${file}.tmp  ${file}
done
' sh {} \;


#########################
######################### 
# Make File of B64 Commands, each scene per line

find "${DIR}" -type f -name "*.json" > "${DIR}"/filelist.txt
readarray -t files < "${DIR}"/filelist.txt
rm -f "${DIR}"/filelist.txt
num_files="${#files[@]}"

for filename in $(seq 1 $num_files); do

    FILE="${files[$(($filename-1))]}"

    b64_commands=$(jq -r ".[] | .cmd_b64" $FILE)
    b64_commands="${b64_commands//\[/}"
    b64_commands="${b64_commands//\]/}"
    b64_commands=$(echo $b64_commands | tr -d '\n')
    b64_commands="${b64_commands//, /,}"
    echo ${b64_commands} > "${DIR}"/file.tmp
    while IFS=' ' read -r -a words; do
        for word in "${words[@]}"; do
            echo "$word"
        done
    done < "${DIR}"/file.tmp > "${DIR}"/file2.tmp
    mv "${DIR}"/file2.tmp "${DIR}"/file.tmp
    

    ##### Generate Hex File, new line separating commands
    
    DIR="/home/ubuntu/Mavrrick_LAN_Scene_Files"
    
    rm -f "${DIR}"/file_hex.json
    unset hex_temp
    unset hex_line_temp
    unset hex_out
    unset num_scenes
    
    num_scenes=$(wc -l < "${DIR}"/file.tmp)
    
    for p in $(seq 1 $num_scenes); do 
    
    		if [ $p == 1 ]; then
    			echo "[" >> "${DIR}"/file_hex.tmp
    		fi
    
        echo '{"cmd_hex" :[' >> "${DIR}"/file_hex.tmp
    
        for base64_str in $(awk "NR==${p}" "${DIR}"/file.tmp | tr ',' '\n'); do
            #echo $FILE
            #echo $base64_str
            hex_temp=$(echo ${base64_str//\"/} | base64 -d | od -t x1 -An -w20)
            echo '"'"${hex_temp}"'"', >> "${DIR}"/file_hex.tmp
        done
    
    		if [ $p -lt $num_scenes ]; then
            echo "]}," >> "${DIR}"/file_hex.tmp
    	  else
            echo "]}" >> "${DIR}"/file_hex.tmp
            echo "]" >> "${DIR}"/file_hex.tmp
    		fi
    
    done
    
    ##### Remove spaces
    tr -d ' ' < "${DIR}"/file_hex.tmp > "${DIR}"/file_hex2.tmp
    
    ##### Remove trailing comma for last command in each scene
    tr -d '\n' < "${DIR}"/file_hex2.tmp > "${DIR}"/file_hex3.tmp
    find "${DIR}"/file_hex3.tmp -type f -exec sed -i 's/\",\]/\"\]/g' {} +
    
    rm -f "${DIR}"/file.tmp
    rm -f "${DIR}"/file_hex.tmp
    rm -f "${DIR}"/file_hex2.tmp

    ##### Merge
    fn=$(basename "$FILE")
    mkdir -p ${DIR}/withhex
    jq -s 'transpose | map(add)' $FILE "${DIR}"/file_hex3.tmp > ${DIR}/withhex/${fn}
    
    ##### Remove last temp file
    rm -f "${DIR}"/file_hex3.tmp
    
done
