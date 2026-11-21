# HOTD4 v1.3.8 OpenXR Preview 1 for Windows

An experimental OpenXR builder targeting the Quest 3 / Virtual Desktop reports. **This prerelease needs headset testing; other reported VR issues remain under investigation.** Stable desktop remains v1.3.7.

## Changes

- **Black right eye:** select the second eye's render target explicitly and snapshot multi-draw indices, vertex data and animation/material uniforms for its replay.
- **Duplicate gameplay rectangle:** suppress the native full-screen scene composite during immersive gameplay, rescale eye-to-texture copies and isolate small glare/reflection passes. Flat menus remain available.
- **X-button stall:** normal X presses no longer trigger expensive diagnostic eye/texture dumps. Developers can enable those with `LINDBERGH_XR_DEBUG_CAPTURE=1`.
- **Automatic VR logs:** each session writes a new log under **HOTD4_Recomp\VR Logs**.
- PC OpenXR now uses the Windows lifted-code and movie-decoder compiler optimizations already used by desktop. Headset FPS gains have not been measured.
- Includes existing desktop features and mixed lightgun/Parsec co-op, plus the new desktop **HI-SCORE** display and **Pause > High Scores** page reading the original cabinet ranking.

## Install or update

1. Extract **HOTD4-Local-Builder-v1.3.8-openxr-preview.1.zip**.
2. Run **Setup.cmd**, select your own extracted normal **Rev A (DVP-0003A)** dump and existing installation folder, then select **Yes** for OpenXR. Settings, saves and trophies are preserved. Back up your installation if you want to compare older builds.
3. Connect the headset, start your OpenXR runtime and run **Play HOTD4 (VR OpenXR).cmd** from **HOTD4-PC**.

Executable checks and changes happen locally. Supported original Rev A and verified HD variants are accepted; a valid **hod4Ms_HD.elf** is found automatically when **hod4M.elf** is unsupported. See README for exact hashes and installation requirements.

## Please test

- Check both eyes separately during gameplay and cutscenes, including animated zombies.
- Check for the extra flat gameplay rectangle over the scene.
- Press X repeatedly and check for the reported freeze.
- Send the newest **HOTD4_Recomp\VR Logs\OpenXR-*.log**, headset/GPU and runtime (VDXR or SteamVR). Mention whether restart corruption after Alt+F4, brown room obstruction, cutscene FPS, orientation and shake problems remain.

## Validation and limits

Reproduced the original all-black right-eye buffer. Native stereo and simulated OpenXR integration now render and submit separate nonblack left/right images with animated zombies and no duplicate scene rectangle in the tested Chapter 1 corridor. Simulated X presses do not request diagnostic captures. The local simulated runtime does not validate headset tracking, optics or Virtual Desktop compatibility. **No physical-headset test has been completed.**

The package contains builder/runtime source, scripts and original project UI. **No Sega game assets, ELF files, generated game code, prebuilt game executables or arcade media are included.** Your own supported extracted arcade dump is required; updates also rebuild locally.
