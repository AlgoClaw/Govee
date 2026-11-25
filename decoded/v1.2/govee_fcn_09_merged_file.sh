#!/bin/bash

# Merge a fresh Govee scene file into a durable master scene file.
#
# Usage:
#   govee_fcn_09_merged_file.sh MASTER_JSON GENERATED_JSON MERGED_JSON
#
# MASTER_JSON is never modified.  MERGED_JSON is written atomically and can
# be passed as MASTER_JSON on the next run.

source "$(dirname -- "$(readlink -f -- "$0")")/govee_fcn_lib.sh"
govee_enable_strict_mode
govee_require_commands jq mktemp

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 MASTER_JSON GENERATED_JSON MERGED_JSON" >&2
    exit 1
fi

MASTER_JSON="$1"
GENERATED_JSON="$2"
MERGED_JSON="$3"

if [ ! -f "${MASTER_JSON}" ]; then
    echo "Master scene file does not exist: ${MASTER_JSON}" >&2
    exit 1
fi

if [ ! -f "${GENERATED_JSON}" ]; then
    echo "Generated scene file does not exist: ${GENERATED_JSON}" >&2
    exit 1
fi

validate_scene_file() {
    # A valid merged input has the minimum data needed to compare complete
    # command sequences and preserve a scene under its user-visible name.
    jq -e '
      type == "array"
      and all(.[]; type == "object" and (.name | type == "string") and has("cmd_b64"))
    ' "$1" >/dev/null
}

if ! validate_scene_file "${MASTER_JSON}"; then
    echo "Invalid master scene file: ${MASTER_JSON}" >&2
    exit 1
fi

if ! validate_scene_file "${GENERATED_JSON}"; then
    echo "Invalid generated scene file: ${GENERATED_JSON}" >&2
    exit 1
fi

# Write beside the destination then rename atomically, so an interrupted merge
# cannot leave the durable library as a truncated JSON file.
mkdir -p "$(dirname "${MERGED_JSON}")"
TEMP_OUTPUT=$(mktemp "${MERGED_JSON}.tmp.XXXXXX")
trap 'rm -f "${TEMP_OUTPUT}"' EXIT

# Merge rules implemented by the jq program below:
# - The full cmd_b64 packet array is the scene identity, not its name.
# - A duplicate command retains the first record and appends a name alias.
# - A distinct command whose name is occupied gains -2, -3, and so on.
# - Existing master scenes are kept even when Govee no longer returns them.
# - Existing duplicate commands are normalized before adding fresh scenes.
jq -n --slurpfile master "${MASTER_JSON}" --slurpfile generated "${GENERATED_JSON}" '
  def command_key: .cmd_b64 | tojson;

  def append_alias($alias):
    . as $current
    | if $current == $alias
         or ($current | startswith($alias + " ("))
         or ($current | contains(" (" + $alias + ")"))
      then $current
      else $current + " (" + $alias + ")"
      end;

  def next_available_name($base; $used):
    if ($used | index($base)) == null then $base
    else
      first(
        range(2; 1000000) as $number
        | ($base + "-" + ($number | tostring)) as $candidate
        | select(($used | index($candidate)) == null)
        | $candidate
      )
    end;

  def add_or_alias($scene):
    ($scene | command_key) as $scene_command
    | [to_entries[] | select((.value | command_key) == $scene_command) | .key] as $matches
    | if ($matches | length) > 0 then
        $matches[0] as $index
        | .[$index].name |= append_alias($scene.name)
      else
        . + [$scene]
      end;

  def merge_generated_scene($scene):
    ($scene | command_key) as $scene_command
    | [to_entries[] | select((.value | command_key) == $scene_command) | .key] as $matches
    | if ($matches | length) > 0 then
        $matches[0] as $index
        | .[$index].name |= append_alias($scene.name)
      else
        ([ .[].name ]) as $used_names
        | next_available_name($scene.name; $used_names) as $new_name
        | . + [($scene | .name = $new_name)]
      end;

  ($master[0]) as $master_scenes
  | ($generated[0]) as $generated_scenes
  | reduce $master_scenes[] as $scene ([]; add_or_alias($scene))
  | reduce $generated_scenes[] as $scene (. ; merge_generated_scene($scene))
' > "${TEMP_OUTPUT}"

mv "${TEMP_OUTPUT}" "${MERGED_JSON}"
trap - EXIT
