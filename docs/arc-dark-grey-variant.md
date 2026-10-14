# Arc Dark Grey — variant notes

**Read this before selecting `Arc Dark Grey`.** This is a complete variant, not a
proof of concept: all three payloads are recolored.

## What this variant is

A darker grey built from `Arc Neutral Grey` by `bin\Recolor-IconTheme.ps1`, with
**k = 0.55** and a per-icon **luminance floor of 64**. Every RT_ICON bitmap of all
three payloads is recolored; nothing is copied through at Neutral Grey brightness.

| file | state | RT_ICON entries | sha256 | size (B) |
| --- | --- | --- | --- | --- |
| `Windhawk Resources\zipfldr.dll` | recolored | 10 (10 DIB) | `0F3D177FB765C9866DC2126D332849B87ABCA7C85180810B0083AA9F4F2251ED` | 577024 |
| `Windhawk Resources\imagesp1.dll` | recolored | 45 (45 DIB) | `82F3ACC48C6886B45A9F574A92DA944CCA32CE3242E409BDD1DF7144ED758BFD` | 2594816 |
| `Windhawk Resources\imageres.dll` | recolored | 1251 (1134 32bpp DIB, 2 24bpp DIB, 56 indexed DIB, 59 PNG) | `71D8F33D46A23047C6375CDEA327E502A784996F83486ADA6ECF6F5BA1E0A635` | 48730112 |
| `theme.ini` | byte-identical copy of `Arc Neutral Grey\theme.ini` | - | - | - |

1306 RT_ICON entries total, 0 unsupported, 0 skipped.

## What the recolor does

- **RGB multiply, alpha untouched.** Every pixel is `round(channel * kEff)`.
  Alpha, the AND mask, palette indices, headers and every other byte keep their
  exact source value.
- **Palette bitmaps (1/4/8bpp) are multiplied through the color table**, which is
  the RGB source of those bitmaps; the indices stay as they are. That is the same
  operation as the pixel multiply, and it is why 16 px shell icons (which ship as
  indexed DIBs) darken with everything else.
- **PNG entries are decoded, multiplied and re-encoded** (System.Drawing/GDI+).
  A re-encode changes the entry's byte length, so the `RT_GROUP_ICON` directory
  entry that declares that length is updated in the same write session (57 groups
  in `imageres.dll`). The destination is re-checked afterwards: all 1306
  directory entries declare the true RT_ICON length.

## The luminance floor: 64

A blanket k = 0.55 drives already-dark icons toward black, which is exactly what
this variant must not do. Measured on the Neutral Grey payload:

- the **Hard drive** family (icons #125-#129) sits at mean luminance 78-91, so
  k = 0.55 alone lands it at 43-50 — near black;
- the **Disc** family (#277-#281) sits at 99-118, landing at 54-65.

So each entry gets its own effective factor:

```
kEff = min(1, max(K, Floor / meanLuminance))
```

- an icon whose result would fall below the floor is multiplied *less*;
- an icon already darker than the floor is left at `kEff = 1` (byte-identical);
- the factor stays a single scalar per icon, so every channel is scaled by the
  same number and **hue and saturation ratios are preserved exactly — this
  variant never desaturates**;
- mean luminance is measured over **visible** pixels only (alpha >= 128 for
  32bpp/PNG, the AND mask for 24bpp and palette bitmaps), so a transparent
  background cannot drag the mean down.

64 = `#404040` at 25% luminance: unambiguously grey (a black pixel is 0),
comfortably above the ~48 that reads as black, and below the ~95 this variant
produces for the light grey family — so it only catches icons that were already
dark.

**How many icons the floor touched** (out of 1306): 205 entries in
`imageres.dll`; 0 in `imagesp1.dll`; 0 in `zipfldr.dll`.
Of those 205, **189 were clamped** (multiplied less than 0.55) and **16 were held
at kEff = 1** because they were already at or below the floor (the red
document-family icons #482-#489 at luminance 40-46, and #1050-#1063 at 57-64).
10 further entries have no pixel with alpha >= 128 at all (3 fully transparent
32bpp placeholders, 2 indexed, 5 PNG); they take the plain factor and are
multiplied anyway, which is invisible by construction.

A **per-pixel** floor was rejected on purpose: clamping each channel separately
lands all three channels on the same value, which *is* desaturation.

## Provenance

- Derived from `theme\Arc Neutral Grey\Windhawk Resources\` (zipfldr
  `73E8194ADD24BCE4D8B639B74946BB1C101066C1E87CC45F2A034B16BC13185C`, imagesp1
  `157C34B59516F3E1789CA7AA99C81AF5707CC87BF5E4F024E902CACF52A1A4FC`, imageres
  `AEF60C8D353511BFA751063FB7AF1612A00720529999A18A9FF1C46D362C3B58`) by
  `bin\Recolor-IconTheme.ps1`.
- The payloads were read back and checked independently: every one of the 1306
  entries equals `round(sourceChannel * kEff)`, with alpha untouched and no other
  byte moved.
- `zipfldr.dll` at k = 0.55 is byte-identical to the earlier proof-of-concept
  output (`0F3D177F...`) — the floor did not touch that payload, so the DIB path
  is unchanged.
- There is no upstream archive for this payload (it is generated, not
  downloaded), so the variant table row carries an empty `Archive` field and
  `installed-manifest.json` records no archive for it.

## Regenerate

```powershell
foreach ($f in 'zipfldr.dll','imagesp1.dll','imageres.dll') {
  pwsh -NoProfile -File .\bin\Recolor-IconTheme.ps1 `
    -Source ".\theme\Arc Neutral Grey\Windhawk Resources\$f" `
    -Dest   ".\theme\Arc Dark Grey\Windhawk Resources\$f" `
    -K 0.55 -Floor 64
}
```

Add `-DryRun` to plan without writing. `-K` is the RGB multiply factor
(0 < k <= 1): `1.0` is a byte-identical copy, lower is darker. `-Floor` is the
per-icon mean-luminance floor in 0..255 (`0` disables it and restores a plain
blanket multiply).

## Known gaps

- No `Extra\preview.png` for this variant (the Neutral variants ship one).
- The tool fails loudly, writing nothing, if it meets an RT_ICON entry it has no
  recolor path for — it never skips an icon silently.
- Not this variant's payload, but found while checking it: a merged
  `imageres.dll.mun` can declare stale sizes for a small number of
  `RT_GROUP_ICON` directory entries (group `BLANK1`, groups #1040/#1043) after
  `bin\Merge-IconTheme.ps1`'s collision-remap step. The theme payloads themselves
  are 1306/1306 correct.
