# HOTD4 Local Builder

Run **Setup.cmd**, select your own extracted arcade dump, then wait for the local build. When finished, open **HOTD4-PC\Play HOTD4.cmd**. All menus are in English.

Requirements: Windows 10/11 x64, an OpenGL-capable graphics driver, internet for the initial tool download, and your own complete, extracted **normal The House of the Dead 4** arcade dump. Allow approximately 10 GB free for tools, generated code, build files and the installed game. No separately installed Python, compiler or administrator account is required.

Supported layout: `disk0/elf/hod4M.elf`, `disk0/fs/`, `disk0/drv/`. Select disk0, elf, or their usual parent game folder. The supported unmodified ELF SHA-256 is:

`72FDD45830ACD9317EC1E4F97DE35A270C94746068FDAF827381C91BB47AA296`

Special, other revisions, patched executables, encrypted disc images and compressed archives are not accepted. Setup checks the version before downloading tools. It does not decrypt or download the game.

## What happens on your PC

1. Verify this package and your ELF.
2. Download the official self-extracting MSYS2 archive, verify its pinned SHA-256, and install signed build dependencies using pacman. The archive extracts without a system xz utility.
3. Lift your own ELF to C locally, generate OpenGL bindings, and compile the Windows executable locally.
4. Copy your dump into the chosen installation folder and add the launcher, runtime DLLs, menus and original project artwork. The source dump stays unchanged.
5. Run the locally built game in a hidden window with isolated temporary settings, muted audio and fresh temporary cabinet state. Render the Chapter 1 zombie scene at 1920x1080 and save it locally as the menu background. This usually adds about one minute. Your controls, trophies and cabinet saves are untouched.

The first build can take several minutes and uses multiple gigabytes of temporary disk space. Later runs reuse the tools and unchanged generated code. Build tools default to `%LOCALAPPDATA%\HOTD4-Builder\msys64`. Game settings, cabinet NVRAM and local trophies live in the installation's `HOTD4_Recomp` directory; rerunning setup preserves them. Existing game data is refreshed from the selected dump.

## Included features

Resolution selection up to 4K, chapter practice, HUD scale, native pause menu, Trophies gallery with 12 base-game goals, Sinden border with selectable thickness, crosshair style/size/color previews, Raw Input device selection, and selectable MSAA. The default Pause key is Esc; it can be changed. Experimental Remix and replacement zombie textures are not included.

This package contains hand-maintained source, build tools/scripts, procedural crosshair previews and newly generated metallic star artwork. It contains **no arcade ELF, game assets, game movies, game audio, textures from the game, prebuilt game executable, lifted game code, saved progress or cabinet NVRAM**. The game is never uploaded. Only the build tools and their dependencies are downloaded.

The menu background is created on the user's PC from their own dump. No screenshot or game artwork is included in the distribution. Existing menu backgrounds are preserved on reinstall. If the optional render fails (for example without working OpenGL graphics), installation completes with a plain background and a local menu-background.log; rerun Setup to retry.

## Key bindings and controls overview

Open **Settings > Key Bindings** to change Add Coin, Start, Shoot, Reload / Shake, Grenade, Fire Mode, Test Menu, Service, Mute, Pause, Restart, Fullscreen, Toggle Crosshair and Mouse Lock. P1 and P2 have separate coin/start bindings. Click an action and press the desired key, then choose **Save & Back**. Mouse buttons can be assigned to the four shooting actions. Duplicate assignments are rejected. **Reset Defaults** restores the factory keys; save to apply.

The start menu displays all current controls, including Add Coin and Start. The chapter-selection hint also follows the selected Restart key. In the native pause menu, open **Settings > Input & Anti-Aliasing > Key Bindings**; changes there apply and save immediately. Esc goes back inside menus or cancels a pending capture; use Cancel when binding Esc to Pause.

In **Settings > Input & Anti-Aliasing**, select **Mouse (Raw Relative)** to adjust **Raw Mouse Speed** (0.50x to 8.00x) and **Raw Mouse Smoothing** (Off, Low, High). Both settings update live from the pause menu.

Profiles are stored locally in `HOTD4_Recomp/controls-profile.txt` and survive restarts and reinstalls. Once a custom profile is saved, legacy coin/start aliases and Alt+Enter are disabled so that the overview lists the actual bindings. Keyboard bindings work in all input modes. In Raw Lightgun mode, the selected lightgun's trigger/buttons keep their direct device mapping; mouse bindings apply to mouse input modes. Menu navigation remains arrow keys, Enter and Esc.

## Optional OpenXR PC VR

Select **Yes** when Setup asks whether to build the OpenXR version. For unattended setup, pass `-OpenXR`. Setup builds a separate VR executable from the same local dump and installs **Play HOTD4 (VR OpenXR).cmd** next to the desktop launcher.

Connect your PC VR headset and start an OpenXR runtime that supports OpenGL before using the VR launcher. Aim with a tracked controller, pull the trigger to shoot, squeeze the grip to reload and click the thumbstick to start. VR uses its own headset menu, controller bindings and cabinet save.

## Lower GPU load

On the desktop, select **960 × 540 (performance, windowed)** or **1280 × 720** under **Settings > Resolution**. Turn MSAA off under **Settings > Input & Anti-Aliasing** and restart the game to apply it.

## Recording the Chapter 1 elevator slowdown

1. Run **Play HOTD4 (Performance Log).cmd** from your installed game folder.
2. Use the settings you want to test. For the reported elevator slowdown, select 1080p (Desktop resolution on a 1080p display) and turn MSAA **Off** under **Settings > Input & Anti-Aliasing**.
3. Choose **Chapter Select > Chapter 1** and play through the elevator fight. If FPS drops, finish the fight or stop just afterwards, then use **Pause > Main Menu** and **Quit** so the game writes the recording.
4. Open **Performance Logs** in your installation folder and share the newest CSV. The launcher opens the folder when it closes. Mention where the slowdown started, your CPU and GPU, graphics settings, and whether you were playing in fullscreen. GPU utilization during the dip is useful if you already have it.

Each game run writes a separate CSV with frame numbers and `frame_ms`, the time in milliseconds between completed presents. The file records timing data only. Long pauses appear as gaps in the timeline.

## Command-line options

```powershell
.\setup.ps1 -DumpPath 'E:\My dump\disk0' -InstallDir 'E:\Games\HOTD4' -Jobs 4
.\setup.ps1 -DumpPath 'E:\My dump\disk0' -ValidateOnly
.\setup.ps1 -DumpPath 'E:\My dump\disk0' -NoDownload
```

`-ToolchainPath` selects another isolated MSYS2 directory. `-NoDownload` requires a previously initialized toolchain. Use a writable installation directory. Keep the full extracted builder package together. **Do not redistribute the locally built game folder, generated source, build directory or copied dump.** To share the builder, use the original distribution ZIP.

## Credits and licenses

Based on lindbergh-recomp-ports, lindberghrecomp and pcrecomp by sp00nz and contributors (including the lialan ports). MIT license notices are retained in source. Runtime dependency license notices are copied from the downloaded toolchain into the local game's licenses directory. dlmalloc's public-domain notice is in its source. Metallic stars are newly generated project artwork; crosshair previews are rendered from our procedural drawing code. System fonts are used without bundling font files.

The House of the Dead 4 is a Sega property. This independent local build project provides no game content and is not affiliated with Sega or PSN. Local trophies do not synchronize with PlayStation accounts.


Sinden border thickness is selectable in Settings and in Esc > Settings > Border Width. The default is Thin, 1.5% of screen height (half the previous 3%). Choices are 0.75%, 1.5%, 2.25% and 3% (original). The black inner edge scales too. The choice is saved in HOTD4_Recomp/sinden-width.txt and is applied immediately from the pause menu. Existing On/Off preferences are preserved; profiles without a saved thickness use 1.5%.
