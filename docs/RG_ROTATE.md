# RG Rotate maintenance

This fork keeps a small set of Android compatibility fixes for the Anbernic RG Rotate. Development continues on `master`, with `origin` pointing to this fork and `upstream` to [Guandor/Balatro-Lite](https://github.com/Guandor/Balatro-Lite). The upstream project remains the source for general updates.

## Scope

- Keep all five booster pack types usable with the small-screen layout on a 720 × 720 display: clamp the pack area to the bottom of the usable screen and hide the shop while opening a pack.
- Restore the blind's name and icon after Continue when its reward is $0.
- Supply an Android gamepad mapping for the RG Rotate's exact GammaOS controller GUID, without changing mappings for unrelated controllers.

These are the fork's maintenance targets. Local regression checks cover patch behavior; device checks are still needed to confirm the rendered result and physical controls.

## Taking upstream updates

1. Fetch `upstream` and inspect its commits, release notes, and changes to the files patched by this fork. Do not assume upstream is inactive.
2. Merge the upstream update into `master`, or cherry-pick the relevant commits. Resolve overlaps while preserving the fixes above.
3. Run `lua tests/small_screen_packs.lua` and `lua tests/handheld_compatibility.lua`, plus the existing Android patcher/importer checks when their code or packaging changes. Record the upstream revision and actual results with the update. The patch regression workflow runs on pushes and pull requests without game assets.
4. Check the updated build on an RG Rotate: open each booster pack type, return to the shop, load a blind whose reward is $0, and exercise the D-pad, face buttons, shoulders, Start, and Select. Check that touch input still works and that another controller retains its own mapping when available.

Run new regression checks added alongside the HUD and controller fixes as well. A passing script alone does not establish device compatibility; record any device checks that could not be completed.

## Verification — 2026-10-22

Tested on RG Rotate, GammaOS Next Android 14, 720 × 720, with a privately supplied Steam 1.0.1o game. Each launch used the installed app's launcher icon through the physical controller event path.

| Pack | Device check |
| --- | --- |
| Buffoon | All four choices visible; D-pad reaches the last card; both Mega choices work and return to the shop. |
| Arcana | All five choices and the hand visible; select a hand card, apply The Sun, resume the remaining choice, then Skip back to the shop. |
| Spectral | All four choices and the hand visible; apply Aura to a selected hand card, resume the remaining choice, then Skip back to the shop. |
| Standard | All five choices visible; select a card, add it to the deck, and return to the shop. |
| Celestial | All five choices visible; use a planet and return to the shop. |

The shop's cards, buttons, prices and tooltips disappear during packs and return afterward. Test runs used private fixtures; the player's original run and profiles were backed up separately. Actual in-game save writes were checked after returning to the shop. Continue also displayed the Korean Small Blind name and icon with a $0 reward. D-pad navigation and Start pause controls worked with the original Steam controller database and the fork's runtime correction.

Host checks passed: the two Lua regression scripts, Lua syntax checks, and the existing JVM patcher/importer/migrator smoke tests. The patcher exercised all four layout/performance combinations using the privately supplied game.

The device ran the upstream v1.2.2 Android runtime with this fork's generated game patches. A new APK and its upgrade path have not been tested or released. The Android patch schema is bumped to 4 so future builds regenerate older imported patches. Other aspect ratios have host coverage only; 4:3 hand/pack spacing still needs rendered device verification.

## Source and release boundaries

This repository distributes the wrapper and patch source. Each user must supply their own purchased Balatro game file. Do not commit Steam game files, patched game archives, saves, private device data, or APKs containing commercial game assets. Use synthetic fixtures for public tests and omit personal paths and device serial numbers from reports.

Preserve existing notices and component licenses. This repository has no root license file; do not describe the whole fork as MIT-licensed or infer a blanket redistribution grant from the bundled font license.
