# HOTD4 Local Builder v1.3.5 for Windows

Escape zombie grabs by shaking your mouse back and forth, like the original gun-shaking action. This is a full Windows builder release with all previous desktop features and installer fixes included.

## Mouse shaking

- Works in **Mouse (Absolute)** and **Mouse (Raw Relative)** modes.
- Deliberate back-and-forth movement counts; straight aiming sweeps and small jitter do not.
- During a grab/struggle, **Reload** and **Fire Mode** no longer substitute for mouse shaking. Outside grabs, Reload works normally.
- Existing lightgun controls and the optional experimental OpenXR controller inputs retain their previous behavior. This release does not address the reported experimental VR rendering issues.
- The English input setup guide now explains the gesture.

Verified with real SDL motion/button events in controlled native Chapter 1 grab checkpoints: both mouse modes released the player, while straight motion and held Reload left the resistance meter unchanged. Normal shooting and reloading were also checked, plus a 2,901-frame production run at 3840x2160 with MSAA 4x. These checks do not constitute a full campaign or every-boss playthrough.

## Install or update

Extract **HOTD4-Local-Builder-v1.3.5.zip** into a new folder and run **Setup.cmd** with your own complete, extracted **The House of the Dead 4 (Export), Rev A (DVP-0003A)** arcade dump. Original Rev A, the supported HD variant and automatic `hod4Ms_HD.elf` selection remain supported.

To update an existing installation, run `Setup.cmd -InstallDir "C:\Path\To\HOTD4-PC"` and select the same arcade dump. Setup rebuilds the game locally and keeps your settings, saves and trophies. Start **Play HOTD4.exe** as usual.

Includes the launcher/settings, Photo Mode, Model Viewer with locally generated HD textures, trophies, Sinden options, configurable controls, resolution/HUD fixes and performance-log launcher from previous releases. The automatic pyelftools dependency fix from v1.3.4 is included.

The ZIP contains source and the local builder, with **no game assets, arcade ELF, lifted game code, prebuilt game executable, saves or cabinet NVRAM**. All game preparation happens on your PC. **SHA256SUMS.txt** covers the ZIP. See the [README](https://github.com/davidptrssvea/HOTD4-recomp/blob/v1.3.5/README.md) for system requirements and supported dump hashes/layouts.
