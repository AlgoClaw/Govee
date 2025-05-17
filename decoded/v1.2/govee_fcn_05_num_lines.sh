#!/bin/bash

if [ "${1}" == "" ]; then
    exit
fi

OUTPUT_JSON="${1%}"

SCRIPTDIR=$(dirname $(readlink -f $0))
JSONDIR=$(dirname "${OUTPUT_JSON}")

###############################################################
# Add "num_lines_b10" field
# tempfile_05_010
tempfile_05_010="${JSONDIR}/05_010_num_lines_b10_added.json"
rm -f "${tempfile_05_010}"

# Add 4 (2 hex bytes) to account for first line "01" and "line count" bytes
# Divide by 34, which is the length of standard line minus the first 4 characters (ax xx) and last 2 characters (checksum).
# Round up (ceiling)

jq 'map(if .params_b16_mod != "" then (.num_lines_b10 = ((((.params_b16_mod | length) + 4) / 34) | ceil)) else .num_lines_b10 = 0 end)' "${OUTPUT_JSON}" > "${tempfile_05_010}"

###############################################################
# Add empty "num_lines_b16" entries
# tempfile_05_020
tempfile_05_020="${JSONDIR}/05_020_num_lines_b16.json"
rm -f "${tempfile_05_020}"

jq 'map(.num_lines_b16 = "")' "${tempfile_05_010}" > "${tempfile_05_020}"

###############################################################
# Create bash array of "num_lines_b10_array" values

"${SCRIPTDIR}/fcn_b10_2_b16_array.sh" "${tempfile_05_020}" "num_lines_b10" "num_lines_b16" "${OUTPUT_JSON}"

#exit

# CLEANUP
rm -f "${tempfile_05_010}"
rm -f "${tempfile_05_020}"