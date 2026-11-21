# HOTD4 Local Builder v1.3.6 for Windows

A full Windows desktop builder release with fixes for The World grenade crash, the original arcade Test Menu, and HUD scaling when render and output resolutions differ. All previous desktop features and installer fixes are included.

## Fixes

- **The World grenade crash:** fixed a missing generated jump-table branch used by grenade damage, which could terminate the game with exit code 49. The original boss damage rules and balance are retained.
- **Original arcade Test Menu:** the Test Menu binding (default **T**) now opens the locally rebuilt arcade operator program. **Service** (default **S**) moves the selection and **Test** changes or confirms a value. **Game Assignments** includes difficulty, initial lives and maximum lives. Exit the submenu and then the main operator menu to save and restart the game. Entering Test Menu ends the current run. Custom Test/Service bindings work here too, and holding the launch key no longer immediately selects EXIT.
- **HUD and supersampling:** fixed tiny or misplaced UI when a higher game resolution is displayed in a smaller window. HUD placement now remains consistent across native resolution, downscaling, upscaling and window resizing. Subtitles retain their centered layout.
- **Complete error reports:** EXE launchers now save the full error text under **Crash Logs** beside the launcher, rather than losing the beginning of the report in a shortened dialog.

## Test Menu requirements

The operator program is built locally from your own **hod4testM.elf** or **hod4testM_HD.elf**, located alongside the game ELF in the dump. Its supported SHA-256 is `156761ef42b71ec00872867dfd7bb4ad88318a148a131f302dd60f4bc49135bb`. If this file is absent or unsupported, Setup reports that Test Menu is unavailable; the normal game can still be installed. Missing arcade boot fonts are generated locally from Windows system fonts. No operator executable or font atlas is included in the ZIP.

## Install or update

Extract **HOTD4-Local-Builder-v1.3.6.zip** into a new folder and run **Setup.cmd** with your own complete, extracted **The House of the Dead 4 (Export), Rev A (DVP-0003A)** arcade dump. Original Rev A, the supported HD variant and automatic `hod4Ms_HD.elf` selection remain supported.

To update, run `Setup.cmd -InstallDir "C:\Path\To\HOTD4-PC"` and select the same arcade dump. Setup rebuilds the game locally and keeps your settings, cabinet saves and trophies. Start **Play HOTD4.exe** as usual.

Includes Photo Mode, Model Viewer with original animations and locally generated HD textures, trophies, Sinden options, mouse shaking to escape grabs, configurable controls, resolution selection and the performance-log launcher from previous releases. This update targets Windows desktop; the previous optional OpenXR build remains experimental.

## Validation and package contents

Tested installation from a clean source-only package and an empty install directory, plus native gameplay/HUD checks at 1440p and 4K with downscaling, upscaling and window resizing. Test Menu changes were saved and verified through the main game's own difficulty/life getters. The World regression test reproduced exit 49 with the previous generated function, then completed both boss phases and the final death sequence with the fix. That boss test used injected grenade hit messages and reduced HP to exercise the finisher; it was not an unassisted full playthrough. See [BUILD-VERIFICATION.md](https://github.com/davidptrssvea/HOTD4-recomp/blob/v1.3.6/BUILD-VERIFICATION.md) for details.

The ZIP contains source and the local builder, with **no game assets, arcade ELF, lifted game code, prebuilt game executable, saves or cabinet NVRAM**. Game code, copied data and generated menu resources are prepared on your own PC. **SHA256SUMS.txt** covers the ZIP. See the [README](https://github.com/davidptrssvea/HOTD4-recomp/blob/v1.3.6/README.md) for system requirements, supported dump hashes and instructions.
