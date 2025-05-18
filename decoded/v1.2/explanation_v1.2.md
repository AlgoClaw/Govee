## Initial Notes:
The bash/shell scripts in [this directory](https://github.com/AlgoClaw/Govee/tree/main/decoded/v1.2) programatically perform the steps described below.

Modify the [govee_00_multi.sh script](https://github.com/AlgoClaw/Govee/blob/main/decoded/v1.2/govee_00_multi.sh) to include the desired models you desire and execute to generate output JSONs.

**There are likely mistakes in [model_specific_parameters.json](https://github.com/AlgoClaw/Govee/blob/main/decoded/v1.2/model_specific_parameters.json). Please let me if you have any changes to make. For troubleshooting, debugging, decoding, these parameters should be easy to correct with a few emperical examples.***

## Generic Structure for Scene Commands:
```
[              ON COMMAND              ]    <----- "On" command. Works on all models. Included in scene cmds for H6079.
a30001[NN][hxpreadd][hex(scenceParam)]CH    <----- First "multi-line" command
a301[        hex(scenceParam)        ]CH
a302[        hex(scenceParam)        ]CH
...
a3ff[hex(scenceParam)][ zero padding ]CH    <----- Last "multi-line" command
330504[BS][??????][   zero padding   ]CH    <----- "Standard" command changes the selected scene in the Govee app.
                                                   This command is *optional* (and can be set to the incorrect scene).
                                                   I think Govee refers to this as the "modeCmd".
```
***
## Example Walkthrough (using model H6065 and scene "Star")
### 0. Prerequesites
Know the model number/identifier of the model (e.g., H61A8, H7039, H610A).
***
### 1. Get Generic JSON of Model-Specific Changes 
```bash
curl "https://raw.githubusercontent.com/AlgoClaw/Govee/refs/heads/main/decoded/v1.2/model_specific_parameters.json" -o model_specific_parameters.json
```
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

The H6065 JSON fron Govee provides the "scenceParam" (for "Star") in base10 as:

```
EgAAAAAnFQ8DAAEFAAgAEokAEokAEon/2DH/2DEAEokAEokAEok=
```

Convert to base16:

```
120000000027150f030001050008001289001289001289ffd831ffd831001289001289001289
```
***
### 4. Match "type" to each scene
If "type" data is present in "model_specific_parameters.json", match the "type" for each scene **using "hex_prefix_remove"**.

For the model H6065, a "scenceParam" (converted to base16) may start with "12000c000f", "1200000000", or something else.

* If the "scenceParam" starts with "12000c000f", that scene matches "type_entry": 0.
  
* If the "scenceParam" starts with "1200000000", that scene matches "type_entry": 1.
  
* If the "scenceParam" scene starts with something other than the specified in any "hex_prefix_remove", that scene does not match any "type_entry" and may remain unmodified.
  
* Other models (like most string lights) have an empty "hex_prefix_remove" value. In those instances, all scenes match the provided type.

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

Later on, "hex_prefix_add" and "normal_command_suffix" (from the same type entry) are needed to finish generating the command.

In the provided code, "params_b16" is copied to "params_b16_mod" (largely for debugging).
***
### 6. Remove "hex_prefix_remove" from the coverted base16 data.
For scene "Star" of the H6065, "hex_prefix_remove" is `1200000000`
```
120000000027150f030001050008001289001289001289ffd831ffd831001289001289001289 <---- before
          27150f030001050008001289001289001289ffd831ffd831001289001289001289 <---- after
```
***
### 7. Add "hex_prefix_add" to the converted base16 data.
For scene "Star" of the H6065, "hex_prefix_add" is `04`
```
  27150f030001050008001289001289001289ffd831ffd831001289001289001289 <---- before
0427150f030001050008001289001289001289ffd831ffd831001289001289001289 <---- after
```
NOTE: "hex_prefix_add" matches "sceneType" from the Govee API *most* of the time. For example, if "sceneType" is "2" or "4, "hex_prefix_add" is "02" or "04, respectively. However, if "sceneType" is "5", "hex_prefix_add" tends to be longer and inconsistent.
***
### 8. Count the number of lines for the multi-line command
Get length of base16 data (after removing "hex_prefix_remove" and adding "hex_prefix_add")
```
len(0427150f030001050008001289001289001289ffd831ffd831001289001289001289) = 68
```

Add 4 (2 hex bytes) to account for first line "01" and "line count" bytes
```
68 + 4 = 72
```

Divide by 34, which is the length of standard line (40 characters) minus the first 4 characters (ax xx) and last 2 characters (checksum).
```
72 / 34 = 2.117...
```

Round up to nearest integer (ceiling)
```
ceil(2.117...) = 3
```

Convert to base16 (hexadecimal) and pad to 2 characters
```
num_lines = b16(3) = 03
```
***
###  9. Add "01" and base16 of "num lines" (03) value to beggining of base16 value
```
    0427150f030001050008001289001289001289ffd831ffd831001289001289001289 <---- before
01030427150f030001050008001289001289001289ffd831ffd831001289001289001289 <---- after
```
***
### 10. Break base16 value into 34 character arrays
Underscores provided as placeholders
```
____01030427150f0300010500080012__
____89001289001289ffd831ffd83100__
____1289001289001289______________
```
### 11. Add "line count" (indexed) in 2 character base16 to each lines
```
__0001030427150f0300010500080012__
__0189001289001289ffd831ffd83100__
__021289001289001289______________
```
### 12. Add "hex_multi_prefix" ("a3") to the beginning of each line
(this always "a3" except for H70C4??)
This value is provided in "model_specific_parameters.json"
```
a30001030427150f0300010500080012__
a30189001289001289ffd831ffd83100__
a3021289001289001289______________
```
***
### 13. Calculate and add "standard" command ("modeCmd")
This is the command that updates the scene in the Govee app, but is not required for multi-line comamnds.

This can be set to a "standard command" for a different scene, which will update the app to (incorrectly) indicate that different scene has been selected.

#### 13.1 Initial bytes
For setting a scene, the standard command starts with `330504`

#### 13.2 Convert "code" and swap the bytes
Convert the "code" for the scene from base10 to base16.

For "Star", the code (in base10) is `2899`. Converted to base16 this is `0b53`

Swap the bytes of base16 of the scene code `0b53` --> `530b`

(This is now performed earlier in the scripts and added to the model data as "sceneCode_b16_swapped")

#### 13.3 Append "normal_command_suffix" (see Step 4)

If a "normal_command_suffix" is available in the assocaited scene type, that is appended.

For "Star", the "normal_command_suffix" is `0047`

##### 13.4 Append them together
```
330504 + 530b + 0047` --> `330504530b0047
```

##### 13.5 Add to Multi-Line Command
```
a30001030427150f0300010500080012__
a30189001289001289ffd831ffd83100__
a3021289001289001289______________
330504530b0047____________________
```
***
### 14. Add the "on command" (if applicable)
If "on_command" = true (only for H6079?), add the "on command".

Example **if** this were the H6079 (**do not do this** for the H6065)
```
330101____________________________
a30001030427150f0300010500080012__
a30189001289001289ffd831ffd83100__
a3021289001289001289______________
330504530b0047____________________
```
***
### 15. Pad each line with zeros, except for the last 2 characters (1 byte)
```
a30001030427150f0300010500080012__
a30189001289001289ffd831ffd83100__
a3021289001289001289000000000000__
330504530b0047000000000000000000__
```
### 16. Calculate the checksum for each line 
```
a30001030427150f03000105000800121e
a30189001289001289ffd831ffd83100b0
a3021289001289001289000000000000c7
330504530b00470000000000000000002d
```
### 17. Convert each line from base16 to base64
```
owABAwQnFQ8DAAEFAAgAEokAEh4=
owGJABKJ/9gx/9gxABKJABKJALA=
o/8SiQAAAAAAAAAAAAAAAAAAAMc=
MwUEUwsARwAAAAAAAAAAAAAAAC0=
```
