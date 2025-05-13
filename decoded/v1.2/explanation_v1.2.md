## Initial Notes:
The bash/shell scripts in this directory (https://github.com/AlgoClaw/Govee/tree/main/decoded/v1.2) programatically perform the steps described below.

Simply modify the "govee_00_multi.sh" (https://github.com/AlgoClaw/Govee/blob/main/decoded/v1.2/govee_00_multi.sh) script, as needed, and execute to generate the desired output JSONs.

Model specific paramters may not be correct in "model_specific_parameters.json" (https://github.com/AlgoClaw/Govee/blob/main/decoded/v1.2/model_specific_parameters.json). However, these parameters should be easy to update/add/correct with minimal samples of emperical examples.
***
## Generic Structure for Scene Commands:
```
[              ON COMMAND              ]    <----- "On" command. Works on all models. Included in scene cmds for H6127.
a30001[NN][hxpreadd][hex(scenceParam)]CH    <----- First "multi-line" command
a301[        hex(scenceParam)        ]CH
a302[        hex(scenceParam)        ]CH
...
a3ff[hex(scenceParam)][ zero padding ]CH    <----- Last "multi-line" command
330504[BS][??????][   zero padding   ]CH    <----- Command to change scene in the Govee app.
                                                   This command is *optional* (and can be set to the incorrect scene).
```
***
## Example Walkthrough (using model H6065 and scene "Star")
### 0. Prerequesites
Know the model number/identifier of the model (e.g., H61A8, H7039, H610A).
***
### 1. Get Generic JSON of Model-Specific Changes 
`curl "https://raw.githubusercontent.com/AlgoClaw/Govee/refs/heads/main/decoded/v1.2/model_specific_parameters.json" -o model_specific_parameters.json`
***
### 2. Get Model-Specific JSON from Govee's Public API
Example using H6065:
```bash
MODEL="H6065"
curl "https://app2.govee.com/appsku/v1/light-effect-libraries?sku=${MODEL}" -H 'AppVersion: 9999999' -s > ${MODEL}_raw.json
```
***
### 3. Convert "scenceParam" from base64 to base16
From the JSON downloaded from Govee, convert "scenceParam" (.data.categories[].scenes[].lightEffects[].scenceParam) from base64 to base16 (hexadecimal).

The H6065 JSON fron Govee provides the "scenceParam" (for "Star") as:

`EgAAAAAnFQ8DAAEFAAgAEokAEokAEon/2DH/2DEAEokAEokAEok=`

Converted to base16, this is:

`120000000027150f030001050008001289001289001289ffd831ffd831001289001289001289`
***
### 4. Match "type" to each scene
If "type" data is present in "model_specific_parameters.json", match the "type" for each scene **using "hex_prefix_remove"**.

For the model H6065, a "scenceParam" (converted to base16) may start with "12000c000f", "1200000000", or somehting else.

* If the "scenceParam" starts with "12000c000f", that scene matches "type_entry": 0.
  
* If the "scenceParam" starts with "1200000000", that scene matches "type_entry": 1.
  
* If the "scenceParam" scene starts with something other than the specified "hex_prefix_remove", that scene does not match any "type_entry" and may be remain as is.
  
* Other models (like most string lights) have an empty "hex_prefix_remove" value. In isntances, all sccenes match the provided type.

For "Star", the base16 conversion begins with "1200000000" and therefroe matches the second entry ("type_entry": 1).
```
{
  "type_entry": 1,
  "hex_prefix_remove": "1200000000",
  "hex_prefix_add": "04",
  "normal_command_suffix": "0047"
}
```
***
### 5. Associate the scene with the "type" data
For example, in the v1.2 code, this is accomplished by copying the type entry (with the matching "hex_prefix_remove") to the scene entry.

You will need "hex_prefix_add" and "normal_command_suffix" (from the same type entry) later.

In the provded code, "params_b16" is copied to "params_b16_mod" (largely for debugging).
***
### 6. Remove "hex_prefix_remove" from the coverted base16 data.
For scene "Star" of the H6065, "hex_prefix_remove" is `1200000000`
```
120000000027150f030001050008001289001289001289ffd831ffd831001289001289001289 <---- before removal
          27150f030001050008001289001289001289ffd831ffd831001289001289001289 <---- after removal
```
***
### 7. Add "hex_prefix_add" to the converted base16 data.
For scene "Star" of the H6065, "hex_prefix_add" is `04`
```
  27150f030001050008001289001289001289ffd831ffd831001289001289001289 <---- before adding
0427150f030001050008001289001289001289ffd831ffd831001289001289001289 <---- after adding
```
***
### 8. Count the number of lines for the multi-line command
Get length of base16 data (after removing "hex_prefix_remove" and adding "hex_prefix_add")

`len(0427150f030001050008001289001289001289ffd831ffd831001289001289001289) = 68`

Add 4 (2 hex bytes) to account for first line "01" and "line count" bytes

`68 + 4 = 72`

Divide by 34, which is the length of standard line minus the first 4 characters (ax xx) and last 2 characters (checksum).

`72 / 34 = 2.117...`

Round up (ceiling)

`ceil(2.117...) = 3`

Convert to base16 (hexadecimal)

10 = 0a
11 = 0b
...

