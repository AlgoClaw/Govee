## Initial Notes:
The bash/shell scripts in [this directory](https://github.com/AlgoClaw/Govee/tree/main/decoded/v1.2) programatically perform the steps described below.

Modify the [govee_00_multi.sh script](https://github.com/AlgoClaw/Govee/blob/main/decoded/v1.2/govee_00_multi.sh) to include the desired models you desire and execute to generate output JSONs.

**There are likely mistakes in [model_specific_parameters.json](https://github.com/AlgoClaw/Govee/blob/main/decoded/v1.2/model_specific_parameters.json). Please let me if you have any changes to make. For troubleshooting, debugging, decoding, these parameters should be easy to correct with a few empirical examples.***

## Generic Structure for Scene Commands:
```
[                             ON COMMAND                            ]    <----- "On" command. Works on all models. Included in scene cmds for H6079.
a30001[num_lines][hex_prefix_add][   scenceParam_hex_mod  ][Checksum]    <----- First "multi-line" command
a301[                 scenceParam_hex_mod                 ][Checksum]
a302[                 scenceParam_hex_mod                 ][Checksum]
...
a3ff[     scenceParam_hex_mod     ][     zero padding     ][Checksum]    <----- Last "multi-line" command
330504[code_byte_swap][normal_command_suffix][zero padding][Checksum]    <----- "Standard" command changes the selected scene in the Govee app.
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
From the JSON downloaded from Govee, convert "scenceParam" (`.data.categories[].scenes[].lightEffects[].scenceParam`) from base64 to base16 (hexadecimal).

The H6065 JSON fron Govee provides the "scenceParam" (for "Star") in base64 as:

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
  
* If the "scenceParam" scene starts with something other than the specified in any "hex_prefix_remove", that scene does not match any "type_entry" and therefore does not have an associated "hex_prefix_add" or "normal_command_suffix" to add later on.
  
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
Get length of base16 data (from step 7, after removing "hex_prefix_remove" and adding "hex_prefix_add")
```
len(0427150f030001050008001289001289001289ffd831ffd831001289001289001289) = 68
```

Later, the data from step 7 will be prepended with `01` (2 hex chars, for multi-packet start) and `num_lines` (2 hex chars, the value being calculated here).
So, the total length of data to be segmented is len(data_from_step7) + 4
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

The data from Step 9 (length 72 in this example) is broken into chunks.
Each chunk will form the payload of a command line.
Each command line has a structure like `a3xx[34-char-payload]CH`

Underscores provided as placeholders
```
____01030427150f0300010500080012890012__
____89001289ffd831ffd83100128900128900__
____1289________________________________
```
### 11. Add line index in base16 to each line.
First line starts with "00", last line starts with "ff".
```
__0001030427150f0300010500080012890012__
__0189001289ffd831ffd83100128900128900__
__ff1289________________________________
```
### 12. Add "hex_multi_prefix" ("a3") to the beginning of each line
(this always "a3" except for H70C4??)
This value is provided in "model_specific_parameters.json"
```
a30001030427150f0300010500080012890012__
a30189001289ffd831ffd83100128900128900__
a3ff1289________________________________
```
***
### 13. Calculate and add "standard" command ("modeCmd")
This is the command that updates the scene in the Govee app, but is not required for multi-line comamnds.

This can be set to a "standard command" for a different scene, which will update the app to (incorrectly) indicate that different scene has been selected.

#### 13.1 Initial bytes
For setting a scene, the standard command starts with `330504`

#### 13.2 Convert "code" and reverse the bytes
"code" = value at `.data.categories[].scenes[].lightEffects[].sceneCode`
- 13.2.1. Convert the "code" for the scene from base10 to base16 
- 13.2.2. Break the base16 code into bytes (2 character) segments.
- 13.2.3. Reverse those bytes.
- 13.2.4. Combine the reversed bytes.

Example 1 (trivial example, if "code" (base10) = `165`)
- Converted to base16 (`a5`)
- Break into single byte (2 character) segments (`a5`)
- Reverse (`a5`)
- Combine (`a5`)

Example 2 (for "Star" of H6065, the code (in base10) is `2899`)
- Converted to base16 (`0b53`)
- Break into single byte (2 character) segments (`0b` and `53`)
- Reverse (`53` and `0b`)
- Combine (`530b`)

Example 3 (if "code" (base10) = `10875518`)
- Converted to base16 (`a5f27e`)
- Break into single byte (2 character) segments (`a5`, `f2`, and `7e`)
- Reverse (`7e`, `f2`, and `a5`)
- Combine (`7ef2a5`)

This applies to any "code" (covert, break, reverse, and combine).

#### 13.3 Append "normal_command_suffix" (see Step 4)

If a "normal_command_suffix" is available in the assocaited scene type, that is appended.

For "Star", the "normal_command_suffix" is `0047`

##### 13.4 Append them together
```
330504 + 530b + 0047` --> `330504530b0047
```

##### 13.5 Add to Multi-Line Command
```
a30001030427150f0300010500080012890012__
a30189001289ffd831ffd83100128900128900__
a3ff1289________________________________
330504530b0047__________________________
```
***
### 14. Add the "on command" (if applicable)
If "on_command" = true (only for H6079?), add the "on command".

Example **if** this were the H6079 (**do not do this** for the H6065)
```
330101__________________________________
a30001030427150f0300010500080012890012__
a30189001289ffd831ffd83100128900128900__
a3ff1289________________________________
330504530b0047__________________________
```
***
### 15. Pad each line with zeros, except for the last 2 characters (1 byte)
Pad the data portion of each line with trailing zeros so that the total length of prefix + index + data_payload_with_padding is 38 characters (or 19 bytes).
The final 2 characters (1 byte) will be the checksum.
```
a30001030427150f0300010500080012890012__
a30189001289ffd831ffd83100128900128900__
a3ff1289000000000000000000000000000000__
330504530b0047000000000000000000000000__
```
### 16. Calculate the checksum for each line (8-bit XOR sum)
See https://github.com/AlgoClaw/Govee/blob/main/decoded/v1.2/fcn_b16_checksum.sh
```
a30001030427150f03000105000800128900121e
a30189001289ffd831ffd83100128900128900b0
a3ff1289000000000000000000000000000000c7
330504530b00470000000000000000000000002d
```
### 17. Convert each line from base16 to base64
```
owABAwQnFQ8DAAEFAAgAEokAEh4=
owGJABKJ/9gx/9gxABKJABKJALA=
o/8SiQAAAAAAAAAAAAAAAAAAAMc=
MwUEUwsARwAAAAAAAAAAAAAAAC0=
```
