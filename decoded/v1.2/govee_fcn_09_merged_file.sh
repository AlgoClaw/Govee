#!/bin/bash

# Merge a fresh Govee scene file into a durable master scene file.
#
# Usage:
#   govee_fcn_09_merged_file.sh MASTER_JSON GENERATED_JSON MERGED_JSON
#
# MASTER_JSON is never modified.  MERGED_JSON is written atomically and can
# be passed as MASTER_JSON on the next run.

set -euo pipefail

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

mkdir -p "$(dirname "${MERGED_JSON}")"
TEMP_OUTPUT=$(mktemp "${MERGED_JSON}.tmp.XXXXXX")
trap 'rm -f "${TEMP_OUTPUT}"' EXIT

jq -n --slurpfile master "${MASTER_JSON}" --slurpfile generated "${GENERATED_JSON}" '
  # cmd_b64 is an array in v1.2.  JSON serialization compares the whole
  # command sequence, including packet order, without relying on its name.
  def command_key: .cmd_b64 | tojson;

  # A command may be rediscovered on later runs.  Keep each alias only once,
  # including when the original name is the leading portion of "Foo (Bar)".
  def append_alias($alias):
    . as $current
    | if $current == $alias
         or ($current | startswith($alias + " ("))
         or ($current | contains(" (" + $alias + ")"))
      then $current
      else $current + " (" + $alias + ")"
      end;

  # Existing names are immutable.  A fresh command using one gets the first
  # unused suffix: Foo, Foo-2, Foo-3, and so on.
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

  ($master[0]) as $master_scenes
  | ($generated[0]) as $generated_scenes
  | reduce $generated_scenes[] as $scene (
      $master_scenes;
      ($scene | command_key) as $scene_command
      | [ .[] | select((command_key) == $scene_command) ] as $same_command
      | if ($same_command | length) > 0 then
          map(
            if (command_key) == $scene_command then
              .name |= append_alias($scene.name)
            else
              .
            end
          )
        else
          ([ .[].name ]) as $used_names
          | next_available_name($scene.name; $used_names) as $new_name
          | . + [($scene | .name = $new_name)]
        end
    )
' > "${TEMP_OUTPUT}"

mv "${TEMP_OUTPUT}" "${MERGED_JSON}"
trap - EXIT
