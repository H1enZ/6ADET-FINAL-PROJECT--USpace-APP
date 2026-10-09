# Flutter capsule reference and website port

## Active source, inspected before this correction

- `../lib/screens/time_capsules/capsule_view_screen.dart`: `_open` calls `TimeCapsuleService.open` before the screen enters `CapsuleOpeningCeremony`. The ceremony finishes at a **Tap the letter to read it** action; it does not automatically expose the reading screen.
- `../lib/screens/time_capsules/capsule_composer_screen.dart`: uses `CapsuleSealingCeremony` and `CapsuleOpeningCeremony` in its preview flow.
- `../lib/widgets/capsule/candle_ceremony.dart`: active `_Frame`, `_openingAt`, `_sealingAt`, `_Scene`, three-panel letter, ribbon, envelope, candle, drops, and stamp painters. Opening is **6400 ms**, sealing **7000 ms**.
- `../lib/widgets/capsule/monogram_seal.dart`: five-lobed oxblood wax, raised ring, embossed initial, leafy sprigs, warming glow, and growing light seam. Demo initial is U; it represents no real sender.
- `../lib/widgets/capsule/vintage_parchment.dart` and `../lib/theme/us_palette.dart`: aged tan paper, fibres, freckles, and scorched edges. Paper colors `#F3E2C2`, `#E9D3AE`, `#D8B988`; sepia `#2E1B0F`, `#6B4A30`.
- `../lib/theme/app_typography.dart`: Playfair Display headings, La Belle Aurore capsule handwriting.
- Also inspected `../lib/widgets/capsule/envelope.dart` and `../lib/widgets/effects/seal_opening.dart`. The latter is an older **2200 ms** heart-seal animation, **not** the active screen ceremony. It was not used as the new opening reference.

## Exact timeline values ported

`src/capsule-frames.js` ports the active Dart frame functions. Curves use Flutter's cubic control points and its 0.001 x-error stopping criterion, including Interval clamping.

| Opening stage | Fraction of 6400 ms |
| --- | --- |
| Warmth swells | 0–0.12 |
| Seal warms | 0–0.14 |
| Light seam travels through wax | 0.12–0.22 |
| Wax fades and sinks | 0.22–0.30 |
| Flap opens by cosine projection | 0.28–0.38 |
| Optional photo phase | 0.38–0.54 |
| Folded letter rises | 0.54–0.66 |
| Ribbon slips away | 0.66–0.74 |
| Envelope sinks / fades | 0.66–0.92 / 0.70–0.92 |
| Top / bottom panels unfold | 0.74–0.86 / 0.82–0.94 |

The sample has no attached photo, matching Flutter's `photo == null` branch. Original website app screenshots remain untouched and appear automatically when opening completes, per the requested website interaction. The original Flutter reading button is intentionally omitted.

Sealing uses the separate Dart timeline: bottom/top folds 0.06–0.16 / 0.16–0.26, ribbon 0.26–0.36, envelope 0.34–0.42, insertion 0.40–0.52, flap 0.52–0.60, candle 0.60–0.84, three drops 0.67–0.79, stamp 0.84–0.98, emboss 0.89–0.93.

Scene geometry follows `_Scene`: height = width × 1.42, envelope width = width × 0.8, envelope height = envelope width × 0.62, flap apex = envelope height × 0.56, letter width = envelope width × 0.86, panel height = letter width × 0.36, seal size = width × 0.22. Fold rotation uses π × 0.985 and perspective 0.0016.

## Closing is an explicit website extension

The original Flutter active screen has **no reverse-close ceremony**. `Close envelope` reverses the opening frames, including interruptions. `Seal again` separately plays the app's seven-second folding/ribbon/candle/stamp sequence. It resets only this illustrative demo, never a real capsule's status. Ready/locked examples are local fixtures. No protected body is fetched or embedded in the locked example; it draws blank paper and shows only a demo release/countdown.

## Verification and visual limitations

`scripts/compare-capsule-frames.mjs` extracts and executes the **actual Dart frame functions**, using a standalone implementation of Flutter's Cubic evaluator. It compares all 19 frame fields at 101 positions for both ceremonies. The recorded run in `qa/capsule-frame-comparison.json` has **202 frames, maximum difference 0**, and matching 6400/7000 ms durations.

Browser screenshots under `qa/app-capsule-*.png` were reviewed at the sealed, unfolding, open-letter, and candle stages. These are website captures, not a side-by-side Flutter capture. An isolated Flutter harness in ignored `qa/capsule-reference/` could not build: the SDK cache lockfile is outside this session's writable directories. Original Flutter sources were never modified.

This is a source-based Canvas port, not a pixel-identical Flutter renderer. Differences: Canvas shadows/antialiasing; deterministic JS texture distribution instead of Dart Random; a strip-based perspective projection of folding paper; simplified tiny wax wear, drip and stamp details; Georgia italic fallback for the sample letter because La Belle Aurore was not bundled locally and the font download was unavailable. Existing locally bundled Playfair is used for the seal and headings. These differences are disclosed rather than described as an exact visual match.

## Intro flash root cause and correction

Previously `entrance.js` appended the overlay after module loading, and session storage skipped it on refresh. Now `index.html` sets intro state while parsing the head and includes critical inline styles plus the actual intro markup as the first body element. The landing content has `visibility:hidden` until completion. The inline Escape path works even with failed module loading; no-JavaScript and reduced-motion visits expose the page normally.

`window.USPACE_INTRO_MS` in `index.html` configures the default **4000 ms** duration. Rings enter, branding reveals, branding holds, and the overlay fades during the final 20%. Hero children then stagger over 1100 ms with 130 ms offsets. Refresh/document navigation replays it; feature tabs and hash links do not remount it. No auto-scroll is added.
