#!/usr/bin/env bash

# Select a model profile type from the raw parameter prefix, then apply that
# type's remove/add transformation to params_b16_mod.

source "$(dirname -- "$(readlink -f -- "$0")")/govee_fcn_lib.sh"
govee_enable_strict_mode
govee_require_commands jq mktemp

if [[ $# -ne 2 || -z "${1}" || -z "${2}" ]]; then
  printf 'Usage: %s DEBUG_JSON MODEL_PROFILE_JSON\n' "$0" >&2
  exit 1
fi

OUTPUT_JSON="${1%/}"
MODEL_PARAMS="$2"
if [[ ! -f "${OUTPUT_JSON}" ]]; then
  printf 'Debug JSON file does not exist: %s\n' "${OUTPUT_JSON}" >&2
  exit 1
fi
# MODEL_PARAMS is one object from model_specific_parameters.json. It contains
# general transport settings plus a .type list that maps source prefixes to
# prefix removal/addition rules.
if ! jq -e 'type == "object" and (.type | type == "array")' <<< "${MODEL_PARAMS}" >/dev/null; then
  printf 'Invalid model profile JSON.\n' >&2
  exit 1
fi

temporary="$(govee_temp_for "${OUTPUT_JSON}")"
trap 'rm -f "${temporary}"' EXIT

# When several type entries match a source parameter prefix, select the final
# matching entry. An unmatched prefix remains untouched, which is needed by
# profiles such as H6066.
jq --argjson profile "${MODEL_PARAMS}" '
  def matching_type($types; $params):
    [
      $types[]?
      | . as $candidate
      | select(($params | startswith($candidate.hex_prefix_remove // "")))
    ]
    | if length == 0 then null else .[-1] end;

  ($profile | del(.type)) as $modparams
  | map(
      . as $scene
      | matching_type($profile.type; ($scene.params_b16 // "")) as $type
      | ($type // {hex_prefix_remove: "", hex_prefix_add: ""}) as $transform
      | .modparams = $modparams
      | if $type == null then del(.type) else .type = $type end
      | if ($scene.params_b16 // "") == "" then
          .params_b16_mod = ""
        else
          .params_b16_mod = (
            ($transform.hex_prefix_add // "")
            + (
                ($scene.params_b16 // "") as $params
                | ($transform.hex_prefix_remove // "") as $remove
                | if $remove == "" then $params else ($params | ltrimstr($remove)) end
              )
          )
        end
    )
' "${OUTPUT_JSON}" > "${temporary}"

mv -- "${temporary}" "${OUTPUT_JSON}"
trap - EXIT
