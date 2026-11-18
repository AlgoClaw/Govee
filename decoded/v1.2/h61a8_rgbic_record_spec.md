# H61A8 RGBIC scene-parameter specification — draft 0.2

This document specifies a static, length-checked parser for the H61A8
`sceneType: 2` / RGBIC parameter format. It deliberately separates three
things that are easy to conflate:

1. packet transport and checksums;
2. the stable binary record grammar; and
3. the visual meaning of individual modes and control bytes.

The first two are sufficient to parse, display, edit, and re-encode a scene
without analyzing that scene visually. The third category is an incremental
dictionary of semantics, not a requirement for parsing.

`sceneType` is API metadata and is not sent as a standalone byte in the LAN
command. It is nevertheless useful as a source-format dispatch hint.

## 1. Scope and conformance

This draft applies to an H61A8 API `scenceParam` after base64 decoding and
before the H61A8 transport prefix `02` is added.

The current `JSONs/H61A8_debug.json` corpus contains:

| API scene type | Count | Parser disposition |
| --- | ---: | --- |
| `0` | 12 | Empty `scenceParam`; mode command only. |
| `1` | 2 | `Legacy-83` frame/palette format (`Halloween-A`, `Sweet`). |
| `2` | 226 | All conform to the `RGBIC-R1` grammar below. |

Thus, the H61A8 parser dispatches to `empty`, `legacy-83`, or `rgbic-r1`.
All 240 entries in the current H61A8 debug catalog parse exactly and receive a
structural label for every byte; there are no per-scene offset rules. An input
that violates the relevant length invariant returns `unknown` and retains its
raw bytes rather than being guessed at or rewritten.

## 2. Vocabulary and integer convention

All values are unsigned one-byte integers unless stated otherwise. Offsets are
zero-based from the beginning of the decoded `scenceParam` -- not from an
`a3` packet.

* **Parameter**: the decoded API `scenceParam`, such as `01 26 ...` for
  Cha-Cha-B.
* **Record**: one self-delimiting RGBIC effect segment inside a parameter.
* **Opaque control**: a byte with a stable structural position but an
  unconfirmed visual meaning. A parser reads and preserves it verbatim.
* **Speed field**: a field structurally identified by the RGBIC serializer;
  changing its visual effect still depends on the scene and device.

## 3. `RGBIC-R1` binary grammar

The grammar is self-delimiting. `recordBodyLength` is the number of bytes after
its own length byte; the total encoded record size is therefore
`1 + recordBodyLength`.

```text
rgbicR1Parameter := recordCount:u8 record[recordCount]

record := recordBodyLength:u8 recordBody[recordBodyLength]

recordBody :=
    packedArea:u8
    colorType:u8
    typeA:u8
    typeB:u8
    brightnessJ:u8
    brightnessCount:u8
    brightnessEffect[brightnessCount]
    colorEffect
    inAreaMovement
    areaMovement

brightnessEffect :=
    control0:u8
    control1:u8
    control2:u8
    speed:u8
    control4:u8
    control5:u8

colorEffect :=
    icControl:u8
    speed:u8
    control:u8
    colorCount:u8
    rgb[colorCount]

rgb := red:u8 green:u8 blue:u8

inAreaMovement := packedArea:u8 mode:u8 speed:u8
areaMovement   := packedArea:u8 mode:u8 speed:u8 control:u8
```

For each record, a conforming parser must calculate and require:

```text
recordBodyLength ==
    6                              // fixed record-body header
  + 6 * brightnessCount
  + 4 + 3 * colorCount             // ColorEffect header and RGB triples
  + 3                              // InAreaMovement
  + 4                              // AreaMovement
```

It must also require that the last record ends exactly at the end of the
parameter. Those two checks distinguish real `rgbic-r1` input from a byte
sequence that merely happens to start with a plausible count.

### 3.1 Cha-Cha-B worked parse

Cha-Cha-B's parameter is:

```text
01 26 00 03 01 01 00 01 FF 00 00 80 14 14 01 80 14 05
FF 00 00  FF 07 F4  09 0E FF  08 FE FC  08 FF 0A
00 00 80  10 03 F5 00
```

It parses without any scene-specific exception:

| Parameter offsets | Bytes | `RGBIC-R1` field |
| --- | --- | --- |
| `0` | `01` | `recordCount = 1` |
| `1` | `26` | `recordBodyLength = 38` (total record size is 39 bytes) |
| `2` | `00` | record `packedArea` |
| `3` | `03` | `colorType` |
| `4-5` | `01 01` | `typeA`, `typeB` |
| `6` | `00` | `brightnessJ` |
| `7` | `01` | `brightnessCount = 1` |
| `8-13` | `FF 00 00 80 14 14` | one six-byte `brightnessEffect` |
| `14-17` | `01 80 14 05` | `colorEffect`: controls plus `colorCount = 5` |
| `18-32` | five triples | `rgb[0..4]` |
| `33-35` | `00 00 80` | `inAreaMovement` |
| `36-39` | `10 03 F5 00` | `areaMovement` |

The length invariant is `6 + (1 * 6) + 4 + (5 * 3) + 3 + 4 = 38`, exactly
matching `0x26`.

The palette is structurally five RGB triples:

```text
#FF0000, #FF07F4, #090EFF, #08FEFC, #08FF0A
```

The RGB channel order is confirmed on H61A8 by the Meteor red/green/blue
experiments. The effect engine's palette ordering, interpolation, blending,
and brightness behavior are independent questions; the parser must not assume
that a palette entry maps to a fixed LED position.

### 3.2 Meteor worked parse

Meteor begins `01 20`, meaning one record with a 32-byte body. Its three RGB
triples occupy parameter offsets `18-20`, `21-23`, and `24-26`; all follow
directly from `colorCount = 3`, not from Meteor-specific offset rules.

Meteor's visible motion speed was confirmed at its `areaMovement.speed` field,
parameter offset `32`. That is a useful semantic confirmation of this grammar:
the field is found by parsing the record, regardless of a scene's name or
length.

### 3.3 Cha-Cha-A visual correlation — hypothesis, not a parser rule

Cha-Cha-A has `recordCount = 3`. The scene visibly begins as three separately
crawling color sections, which strongly supports the interpretation that its
three records are independently evaluated effect segments. This is not yet an
individual record-to-physical-region mapping.

Its parsed color-bearing fields are:

| Record | First three brightness-block bytes | Color-effect palette | Relevant visual observation |
| --- | --- | --- | --- |
| `0` | `FF FB 02` (bright yellow candidate) | `#0000FF`, `#FF5407` | Blue and orange occur during the crawl. |
| `1` | `FF F0 00` (yellow candidate) | `#FF0000`, `#07FF5E` | Red and a green/teal-like color occur. |
| `2` | `7F 7F 00` (olive/puke-green candidate) | `#0000FF`, `#FF0000`, `#00FF00` | Blue, red, green, and the observed olive/puke-green color occur. |

This gives two useful hypotheses:

* Cha-Cha-A's pink need not be stored as a literal pink RGB triple: its third
  record contains blue and red, so interpolation can create magenta/pink.
* `#07FF5E` is the best stored candidate for the observed teal-like phase.

The whiteish phase remains unresolved. The parser establishes where the fields
are, but the current observation alone cannot distinguish a brightness envelope
from RGB interpolation or a mode-specific effect behavior.

### 3.4 Cha-Cha-A brightness-block test result

`AAA - Test - Cha-Cha-A - Brightness Magenta` changed only record 2 offsets
`68-70`, from `7F 7F 00` to `FF 00 FF`. The observed result was:

* the olive/puke-green phase disappeared;
* approximately one third of the string -- consistent with record 2 -- became
  off roughly 25-35% of the time; and
* magenta may have appeared more often, but not as a direct, stable replacement.

This confirms that those bytes are **record-local brightness/transition
parameters**, not a normal static RGB palette triple. They may still contain
color-related information, but the three-byte group must not be labeled RGB
until its individual byte roles are isolated.

The next experiments must change one byte at a time from the original
`7F 7F 00` value:

| Candidate test | Single change | Purpose |
| --- | --- | --- |
| A | offset `68`: `7F -> FF` | Test the first brightness/transition control. |
| B | offset `69`: `7F -> 00` | Test the second brightness/transition control. |
| C | offset `70`: `00 -> FF` | Test the third brightness/transition control. |

Each variant must retain the original values in the other two positions. This
will determine whether one byte controls the off duty cycle and whether another
one contributes to the apparent color change.

### 3.5 Direct-palette color test

Because the brightness-block change takes a full animation cycle to evaluate,
the next test targets a direct, statically parsed RGB palette entry instead.
`AAA - Test - Cha-Cha-A - Record 1 Red to White` is based on the unmodified
Cha-Cha-A command and changes only record 1's first palette entry at parameter
offsets `48-50`, from `FF 00 00` (red) to `FF FF FF` (white). This is one
semantic color-field change; every other parameter byte and the selected-scene
packet remain original. If record 1 owns one of the initial crawl sections,
that section should become white immediately and provide a clearer record-to-
visual-region mapping.

Observed result: the opening red changed to white. The original opening had
red, blue, and pink; the test opened with white and blue, without a clearly
separate third color. This confirms that record 1 palette 1 is a real
initial-color source. Because the physical string crosses over itself, visual
reports do **not** establish a reliable left-to-right order or a direct mapping
from a record to one physical string section.

The next direct-palette test is `AAA - Test - Cha-Cha-A - Record 0 Blue to
Cyan`. It changes record 0 palette 1, offsets `18-20`, from `00 00 FF` (blue)
to `00 FF FF` (cyan). Since the red and blue components were already `00` and
`FF`, respectively, its only non-identical byte is offset `19`, `00 -> FF`.
All other parameter values and the mode packet are retained from Cha-Cha-A.

Observed result: the opening contained red, white, and cyan. The physical order
of those colors is unknown because the string crosses over itself. The result
is consistent with component-wise RGB interpolation: red (`FF 00 00`) mixed
with cyan (`00 FF FF`) can produce neutral gray, which the device presents as
white. It is evidence that record 0 palette 1 and record 1 palette 1 may be
paired inputs to a transition/gradient, but it does not prove a spatial midpoint
or a full record-to-region mapping.

`AAA - Test - Cha-Cha-A - Record 1 Red to Yellow` is the next confirmation
test. It changes record 1 palette 1 from `FF 00 00` to `FF FF 00` (yellow).
Only parameter offset `49` changes, `00 -> FF`; the red and blue components,
all other parameter bytes, and the mode packet are original. It opened with
yellow, white, and blue. That observation is consistent with the same color
mixing hypothesis, but—again—does not establish their physical order.

### 3.6 Legacy-83 (`sceneType: 1`) grammar

`Halloween-A` and `Sweet` use a second static layout. Both begin with marker
`83`, followed by a count of five-byte frames and then an RGB palette. The
same structure appears in the repository's H61A8 raw capture and in other
Govee-model captures, but this specification claims conformance only for the
two H61A8 entries.

```text
legacy83Parameter := 83 frameCount:u8 frame[frameCount] paletteCount:u8 rgb[paletteCount]

frame := red:u8 green:u8 blue:u8 timingOrControl0:u8 timingOrControl1:u8
rgb   := red:u8 green:u8 blue:u8
```

The required exact length is:

```text
3 + (5 * frameCount) + (3 * paletteCount)
```

`Sweet` starts `83 01`, contains one five-byte frame, then palette count `04`
and four RGB triples; its exact length is `3 + 5 + (3 * 4) = 20`. `Halloween-A`
starts `83 06`, contains six frames and four palette triples; its exact length
is `3 + (5 * 6) + (3 * 4) = 45`.

The RGB triple boundaries are structural and editable. The two frame-tail
bytes have a stable position but an unconfirmed timing/control meaning, so the
parser labels them without assigning a visual behavior.

## 4. Static parsing algorithm

The top-level H61A8 parser is deterministic:

```text
parseH61A8Parameter(parameter):
    if parameter is empty: return empty
    if parameter[0] == 83: return parseLegacy83(parameter)
    return parseRgbicR1(parameter)
```

Both nonempty decoders use bounds-checked reads and exact length invariants;
neither searches for color values or makes visual guesses. `parseRgbicR1` is:

```text
parseRgbicR1(parameter):
    cursor = 0
    recordCount = readU8(cursor)
    records = []

    repeat recordCount times:
        recordStart = cursor
        bodyLength = readU8(cursor)
        bodyEnd = cursor + bodyLength

        packedArea      = readU8(cursor)
        colorType       = readU8(cursor)
        typeA           = readU8(cursor)
        typeB           = readU8(cursor)
        brightnessJ     = readU8(cursor)
        brightnessCount = readU8(cursor)

        brightness = repeat brightnessCount times:
            read six bytes as { control0, control1, control2,
                                speed, control4, control5 }

        color = {
            icControl:  readU8(cursor),
            speed:      readU8(cursor),
            control:    readU8(cursor),
            colorCount: readU8(cursor),
            palette:    repeat colorCount times: read { red, green, blue }
        }

        inAreaMovement = read { packedArea, mode, speed }
        areaMovement   = read { packedArea, mode, speed, control }

        require cursor == bodyEnd
        records.append(all values, including recordStart and bodyLength)

    require cursor == parameter.length
    return { format: 'rgbic-r1', recordCount, records }
```

`readU8` must fail if it would pass `bodyEnd` or the end of the parameter. On a
failure, return `unknown` and leave the original bytes unmodified. This is
important: a parser should never reinterpret an unknown format and then write
the resulting guess back to a device.

`parseLegacy83` reads `frameCount` at offset `1`, computes the palette-count
offset as `2 + (5 * frameCount)`, then requires the exact length stated above.
It labels the marker, both counts, every frame RGB/tail byte, and every palette
RGB byte.

## 5. Static encoder and edit rules

The encoder is the inverse of the parser:

1. Serialize every opaque field exactly as read.
2. Serialize each brightness block, palette triple, and movement block.
3. Recalculate each record's `recordBodyLength` from its serialized body.
4. Recalculate `recordCount` from the number of records.
5. Rebuild the H61A8 transport packets and their XOR checksums.

An editor may safely change a palette RGB triple or one of the identified speed
fields without knowing the meaning of `colorType`, `typeA`, `typeB`, or any
opaque control. It should preserve all byte positions and record lengths unless
the user explicitly adds or removes a palette item or brightness block.

For research tests, change one semantic field at a time. Changing RGB is a
three-byte color-field edit, not three unrelated byte experiments. Changing a
speed is a single-byte edit.

## 6. LAN `a3` transport decoding and encoding

For H61A8 scenes with a parameter, the grammar is embedded as follows:

```text
unframed scene payload := 01 packetCount 02 scenceParam
```

`02` is H61A8's model-specific added prefix, configured in
`model_specific_parameters.json`; it is not part of the API `scenceParam` and
must be stripped before invoking `parseRgbicR1`.

To decode a command array:

1. Base64-decode each command and require exactly 20 bytes.
2. Validate each packet's XOR checksum over bytes `0-18`.
3. Collect the `a3` packets in their packet-index order (`00`, `01`, ..., then
   final index `ff`).
4. Concatenate bytes `2-18` from those packets: each contributes 17 payload
   bytes.
5. Require `01`, the stated packet count, and H61A8 prefix `02`.
6. Parse the remaining bytes using `parseH61A8Parameter`. Its exact structural
   length removes any trailing transport-padding zeroes.

To encode, prepend `01`, the computed packet count, and `02`; split into
17-byte chunks; zero-pad each to 17 bytes; then emit:

```text
a3 packetIndex chunk[17] xorChecksum
```

The final scene-data packet uses index `ff`. The existing v1.2 generator
already implements this packet construction.

## 7. Independent normal-scene mode packet

The optional final packet has a separate purpose:

```text
33 05 04 sceneCodeLittleEndian zeroPadding xorChecksum
```

It sets app reporting/selected-scene state. In a multi-line effect, the `a3`
payload is the visual effect. This packet should be parsed and displayed, but
it must not be used to infer RGBIC field meanings.

## 8. Field-semantics status

| Parsed field | Structural confidence | Visual/behavioral confidence |
| --- | --- | --- |
| Empty parameter / mode-only scene | Confirmed across all 12 type-0 entries | The mode packet selects the built-in effect |
| Legacy-83 marker, frame boundaries, palette boundaries | Confirmed across both H61A8 type-1 entries | RGB triples are editable; frame-tail bytes remain opaque |
| Record count and lengths | Confirmed across all 226 H61A8 type-2 entries | Not visual; framing only |
| Brightness block count and six-byte boundaries | High | Its first three bytes are record-local brightness/transition controls; the fourth byte is known to be a speed field |
| Color palette count and RGB boundaries | High | RGB channel order confirmed on Meteor |
| `colorEffect.speed` | High | Candidate for color-transition rate; needs a dedicated visual result |
| `inAreaMovement.speed` | High | Not individually confirmed on H61A8 |
| `areaMovement.speed` | High | Confirmed visible Meteor speed field at offset 32 |
| Packed-area and mode/control fields | High boundary confidence | Direction, spread, and effect-mode meanings unknown |

`Heartbeat-A` supplies the first direct whole-strip brightness observation. Its
only RGBIC record has the brightness block `FF 00 02 D9 0A 01`, and the device
briefly turns the entire string off about twice per second. This is behavioral
evidence that the six-byte `BrightnessEffect` block controls temporal
intensity—not just color or movement. The fourth byte, `D9`, is the
structurally confirmed brightness-effect speed field.

The scene-lab animation therefore reads every parsed `BrightnessEffect` block
from every RGBIC record, rather than matching a scene name. Its preview model
uses the first two controls as intensity endpoints, `D9 / 100` as an
approximately 2.17 Hz cadence, and the final `0A:01` pair as an on/off duty
ratio. Those interpretations reproduce Heartbeat-A's global flash, but the
firmware's exact mode and waveform semantics remain unconfirmed; this is an
explicitly approximate visual model, not a change to the lossless parser or
encoder.

## 9. What still benefits from device testing

No visual experiment is required to statically parse or label the current
H61A8 catalog: each byte now has a format-derived location and field name.
Experiments are only needed to attach **behavioral** names to opaque controls.

The most useful next tests are four one-byte changes on one simple RGBIC-R1
scene, each based on the original command rather than on another test:

1. `brightnessEffect.speed`
2. `colorEffect.speed`
3. `inAreaMovement.speed`
4. `areaMovement.speed` (already confirmed for Meteor)

This distinguishes brightness cadence, palette-transition rate, in-area
motion, and area motion without changing any color field. Packed-area,
mode, and opaque control bytes can be tested afterward, one named field at a
time. Their semantics are not prerequisites for lossless parsing or editing.

The field boundaries and speed positions align with a separately
reverse-engineered Govee RGBIC serializer and its scene-speed rewriter. That is
supporting evidence, not a substitute for H61A8 behavior tests:
<https://github.com/algrym/govee-ble-h617a/blob/master/custom_components/govee-ble-lights/govee_scene_speed.py>

## 9. What visual descriptions would help next

Visual descriptions are valuable for assigning meanings to the opaque fields,
not for parsing the next scene. The highest-signal observations are:

1. Does the effect move within a fixed LED region, across the whole strip, or
   both?
2. Does movement reverse, bounce, wrap, spread, or remain stationary?
3. Do palette colors step, cross-fade, pulse in brightness, or change randomly?
4. Which field changed in the tested command, and what was the before/after
   behavior?

For each test, a short video is ideal; otherwise record the scene name, the
single parsed field changed, its old/new hex values, and the observed behavior.
That evidence can update the semantic table without changing the grammar or
the static parser.
