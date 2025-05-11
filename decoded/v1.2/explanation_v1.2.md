The bash/shell scripts in this directory (https://github.com/AlgoClaw/Govee/tree/main/decoded/v1.2) programatically perform the steps described below.

Simply modify the "govee_00_multi.sh" (https://github.com/AlgoClaw/Govee/blob/main/decoded/v1.2/govee_00_multi.sh) script, as needed, and execute to generate the desired output JSONs.

Model specific paramters may not be correct in "model_specific_parameters.json" (https://github.com/AlgoClaw/Govee/blob/main/decoded/v1.2/model_specific_parameters.json). However, these parameters should be easy to update/add/correct with minimal samples of emperical examples.
***
### Generic Structure for Scene Commands:
```
[              ON COMMAND              ]    <----- "On" command. Works for all models. Always included in scene command for H6127.
a30001[NN][hxpreadd][hex(scenceParam)]CH    <----- First "multi-line" command
a301[        hex(scenceParam)        ]CH
a302[        hex(scenceParam)        ]CH
...
a3ff[hex(scenceParam)][ zero padding ]CH    <----- Last "multi-line" command
330504[BS][??????][   zero padding   ]CH    <----- Command to change scene in the Govee app. This command is *optional* (and can be set to the incorrect scene).
```
***
### 0. Prerequesites
Know the model number/identifier of the model (e.g., H61A8, H7039, H610A).
***
### 1. Get JSON from Govee's Public API
Example using H61A8
```bash
curl "https://app2.govee.com/appsku/v1/light-effect-libraries?sku=H61A8" -H 'AppVersion: 9999999' -s > H61A8_raw.json
```
***
### 2. Get JSON of Model-Specific Changes 
```bash
curl "https://raw.githubusercontent.com/AlgoClaw/Govee/refs/heads/main/decoded/v1.2/model_specific_parameters.json" -o model_specific_parameters.json
```
***
### 3. Convert 
Convert "scenceParam" (.data.categories[].scenes[].lightEffects[].scenceParam) from base64 to base16 (hexadecimal)
***
### 4. Match "type" of Model
If "type" data is present in model_specific_parameters.json, match the "type" for each scene using "hex_prefix_remove".

As an example, for model H6065, a "scenceParam" (converted to base16) may start with "12000c000f", "1200000000", or somehting else.
If the "scenceParam" for a specific scene starts with "12000c000f", that scene matches "type_entry": 0.
If the "scenceParam" for a specific scene starts with "1200000000", that scene matches "type_entry": 1.
If the "scenceParam" for a specific scene starts with something other tha nthe specified "hex_prefix_remove", that scene does not matche any "type_entry".
