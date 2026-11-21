# HOTD4 v1.3.8 for Windows

Full Windows local-builder release, with new gameplay options, arcade high scores and an updated optional experimental OpenXR build.

## Changes

- **Lightgun Off-Screen Reload:** configurable in launcher **Settings > Gameplay** and the in-game pause menu. Pull the trigger outside the game area to reload; independent P1/P2 routing suppresses the shot. Enabled by default. Normal relative-mouse movement is unchanged. Guns which retain the last tracked coordinate must send their configured Reload button for off-screen shots.
- **Optional enhanced blood splatter:** choose **Original** or **Enhanced** under Gameplay. Enhanced uses the original dump's stronger body-hit effect variant; Original remains the default. Existing head/dismemberment/special effect choices remain intact. Blood was observed in the original game, so this is not advertised as a confirmed restoration of cut content.
- **High Scores:** in-game HI-SCORE display and **Pause > High Scores** show the arcade's saved ranking and initials. Scores use the original cabinet save and survive normal restarts and updates. Chapter practice keeps its temporary save.
- **OpenXR stereo:** explicit right-eye targeting and replay snapshots for animated models; suppress the duplicate flat gameplay image and keep its classification across room transitions. Rescale scene copies and isolate/reuse glare and reflection passes.
- **VR restart and saves:** release the OpenXR frame/session/instance on exit. Reset Game relaunches after the old process has ended. Cabinet writes now replace complete files atomically to protect the previous save from interrupted writes.
- **VR timing:** avoid unnecessary index-buffer readbacks and apply original-speed 30 Hz cutscene pacing. X no longer requests expensive eye/texture dumps during normal play. Each VR session writes its own log under **HOTD4_Recomp\VR Logs**.
- The headset menu now includes separate off-screen reload and blood settings. Grip reload remains available.
- Includes the existing installer fix for the removed MSYS2 `python-pyelftools` package; no manual package installation is needed.

## Install or update

1. Extract **HOTD4-Local-Builder-v1.3.8.zip**.
2. Run **Setup.cmd**, select your own complete extracted normal **Rev A (DVP-0003A)** arcade dump and your existing installation folder when updating. Setup rebuilds locally and keeps settings, cabinet saves and trophies.
3. Open **Play HOTD4.exe**. To include VR, select **Yes** for OpenXR during setup, then run **Play HOTD4 (VR OpenXR).cmd** with your headset/runtime connected.

The verified HD variant and automatic `hod4Ms_HD.elf` fallback remain supported. See README for supported SHA-256 hashes and installation requirements.

## Validation and limits

Windows checks cover real two-player game ammunition consumption/reload, settings persistence, UI layout, desktop/operator/OpenXR builds, and source-only packaging. Simulated OpenXR tests exercise both submitted eye images, X input, forced termination/relaunch, Reset Game logs and an assisted Chapter 1 corridor walk. Local cutscene timing improved in those controlled tests.

**VR is still experimental and has not been validated in a physical headset.** Please retest both eyes, duplicate images, Alt+F4/relaunch, the glass corridor and cutscenes on Quest 3/VDXR or SteamVR. Send the latest **HOTD4_Recomp\VR Logs\OpenXR-*.log**, headset/runtime/GPU and where the problem occurred. Orientation and shake sensitivity reports remain open. No hardware-independent FPS improvement is promised.

The ZIP contains builder/runtime source, scripts and project-created UI only. **No Sega game assets, ELF files, generated game code, prebuilt game executable, arcade media or player saves are included.** All game data and effect assets are read from the user's own dump locally.
