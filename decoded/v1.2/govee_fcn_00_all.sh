#!/bin/bash

# /path/to/govee_00_all.sh "H61A8"

if [ "${1}" == "" ]; then
    exit
fi

MODEL="${1}"

# Directory this script is in
SCRIPTDIR=$(dirname $(readlink -f $0))

# Make JSONs subdir (if not exist)
sudo mkdir -p ${SCRIPTDIR}/JSONs/

# Delete non-JSONs in subdir
sudo find ${SCRIPTDIR}/JSONs/ -type f  ! -name "*.*" -delete

################
# 01
# Get Parameters for Model
modelparams=$(bash ${SCRIPTDIR}/govee_fcn_01_get_params.sh "${MODEL}")

#echo $modelparams

################
# 02
# Get Scenes JSON for Model (via Govee's public API)
RAW_JSON_PATH=$(bash ${SCRIPTDIR}/govee_fcn_02_get_scene_json.sh "${MODEL}")

#echo $RAW_JSON_PATH

################
# 03
# Add *Raw* b16 (hex) Commands to JSON and Get File Path
OUTPUT_FILE_PATH=$(bash ${SCRIPTDIR}/govee_fcn_03_add_b16.sh "${RAW_JSON_PATH}")  

#echo $OUTPUT_FILE_PATH

################
# 04
# Add Model-Specific Stuff
bash ${SCRIPTDIR}/govee_fcn_04_model_specific_changes.sh "${OUTPUT_FILE_PATH}" "${modelparams}"

################
# 05
# Count number of lines and add to JSON
bash ${SCRIPTDIR}/govee_fcn_05_num_lines.sh "${OUTPUT_FILE_PATH}"

################
# 06
# Create Multiline b16 (hex) Commands
bash ${SCRIPTDIR}/govee_fcn_06_cmd_b16.sh "${OUTPUT_FILE_PATH}" "${modelparams}"

################
# 07
# Create Multiline base64 Commands
bash ${SCRIPTDIR}/govee_fcn_07_cmd_b64.sh "${OUTPUT_FILE_PATH}"

################
# 08
# Create Final File
bash ${SCRIPTDIR}/govee_fcn_08_simplest_file.sh "${MODEL}" "${OUTPUT_FILE_PATH}"