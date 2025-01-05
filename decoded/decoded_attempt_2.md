| Model | Model Prefix (MP) | Last Multi-Line Suffix |
| ----- | ----------------- | ---------------------- |
| H6079 | [none] | 02? |
| H61A8, H7039, H805A, H6172, H619C, H70C2, H6072, H61A2, H7075, H6039<br>(and probably many more) | 02 | [none] |
| H6066 | 04<br>("12 00 00 00 00" overwritten for Mirage) | 1d? |
| H6022 | 58 5a<br>("5a" overwrites sceneParam[0]) <br>(sceneParam[0] always "41"?) |  |
|  |  |  |
| H6063 | ?? |  |
| H6052 | ?? |  |
| H6078 | ?? |  |

From the Govee API for any given

| Abbreviation | Description |
| ------------ | ----------- |
| NN | Number of multi-command lines<br>(lines starting with "a") |
| MP | Model Prefix<br>(dependent on the model?) |
| CH | XOR checksum for line |
|  |  |

Multi-Command Format Layout:

| Line | Hex | Notes |
| ---- | --- | ----- |
| 1 | a3 00 01 **NN** **MP** [hex of "scenceParam" beginning] **CH** | MP is not present for all models (H6079) |
| 2 | a3 01 [... continuation of hex of "scenceParam"...] **CH** |  |
|  | ... |  |
| N-1 | a3 ff \[end of hex of "scenceParam"\] \[zero padding\] **CH** | last multi-command line |
| N | **33 05 04 [code hex, byte swap] 00 CH** | I think this line is optional.<br>It only seems to change the selection in the app. |

\*\*\*
Prerequisites to calculate the LAN command for a scene:

1. the model number (and the "MP" lookup table)
2. the "scenceParam" for the scene (for that model)
3. the "sceneCode" for the scene (for that model)

\*\*\*
Generic Steps and Method:

1. Get the prerequisites (model number, "scenceParam", and "sceneCode")
2. Convert "scenceParam" to hex
3. Convert "sceneCode" to hex
4. 


Example 1:

<br>
<br>
<br>
<br>
