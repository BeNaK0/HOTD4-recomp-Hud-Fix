# Verification of the local builder

Tested 2026-11-16 on Windows x64 with the supported unmodified normal HOTD4 dump.

- Initialized a separate MSYS2 tree from the pinned archive, updated it and installed dependencies automatically; no existing compiler or Python installation was used for the game build.
- Lifted all 26,636 game functions from the user's ELF locally into 67 C units. Generated GL bindings from the downloaded Windows GLEW header. Built and linked all 111 compilation/link steps successfully with the new GCC 16.2.0 toolchain.
- Installed to a separate directory containing spaces. Started its own launcher with fresh cabinet state and ran Chapter 1 through 1,300 frames. Verified the resulting 1280x720 frame, 3D characters and cutscene aspect mapping. A second launcher run completed 1,300 frames at 3840x2160; its captured framebuffer was 3840x2160, the GL pbuffer was 3840x2160, AF was 16x, and measured frame rates in this smoke test were approximately 60 fps. This is a startup/render smoke test, not a full campaign test.
- Ran the installed frontend offscreen without the development game-art menu image: trophy counts, all three filters, saved dates, scrolling, empty/full states and Back passed.
- Reinstalled with downloads disabled: cached build reported no work to do; custom crosshair size and existing local trophies were preserved.
- Wrong ELF, missing dump and modified package tests all stopped with an error before installation.
- The original source ELF's SHA-256 was unchanged.
- The release archive is built only from an explicit file manifest. Its contents have no ELF, prebuilt game executable, object code, lifted game C, game media, cabinet NVRAM or player progress. The test installation, generated files, screenshots, build directory and caches are excluded.

The native pause gallery was separately checked with a 3840x2160 panel, filter counts, pointer targets, scrolling, Escape navigation and successful game resume. Only the 12 normal-game trophies are shown. The existing real-play trophy verification covers ESCAPE, LOST and EAT THIS!!!; the other nine goals have not all been earned in an actual complete playthrough.


## Local menu background

Setup now runs tools/menu_background.py after the local game build and installation. This renders Chapter 1 with the locally built executable, original verified ELF and copied dump, using a hidden window, muted/null audio, scripted input and isolated temporary controls, trophies and cabinet NVRAM. It captures frame 1220 at 1920x1080 through the renderer's own GL framebuffer, encodes JPEG with Windows' built-in codec, and saves the result only in the user's installation. A source/hash record and log are stored beside it. No desktop/window capture service is started.

Verified an actual Setup run with the downloaded MSYS2 Python and existing local compiler cache, including successful background creation. Compared trophy and crosshair preference hashes before/after: unchanged. Existing backgrounds are retained on reinstall; a failed optional render leaves the playable installation and plain menu available for retry. No Pillow, FFmpeg, screenshot, game image or extra media download is required by this step.


## Sinden thickness update (2026-11-17)

The desktop and experimental Remix targets rebuilt successfully. The start-menu tests passed for default and invalid/missing saved values, all four thicknesses, live preview, Save, reopen and Back without saving. Controls were rendered and checked for clipping. The actual updated desktop executable was then driven through its native pause menu and its GL framebuffer captured at 3840x2160. Measured white widths were 17, 33, 49 and 65 pixels; corresponding black inner edges were 3, 6, 9 and 11 pixels. Default Thin was 33 pixels versus the original 65 (integer rounding of 1.5% versus 3%). Native changes, cycling and saved Medium after a new game process were verified. No physical Sinden hardware was used in these checks. The installer contains the same verified runtime source and frontend.


## Extra white cursor fix (2026-11-17)

The runtime previously installed SDL_SYSTEM_CURSOR_CROSSHAIR independently of the configurable in-game overlay, leaving a small OS cross in absolute mouse / raw-lightgun modes. Windows desktop gameplay now explicitly hides the OS cursor and uses SDL_SYSTEM_CURSOR_ARROW for the pointer temporarily shown in the native pause menu. The existing configurable game sight remains controlled by Crosshair/F2. Both desktop and experimental Remix targets rebuilt.

The actual new desktop executable passed 30 SDL cursor-visibility observations across absolute mouse, raw relative mouse and Raw Input lightgun modes: gameplay with Crosshair On and Off, F1 lock changes, pause/settings, Resume and a second pause/resume. The cursor was hidden in every gameplay observation and visible in menus. F2 On/Off and normal pause/resume were also confirmed in runtime logs. Tests observed the process without changing the installed executable on disk; no Windows screen-capture service was used.


## Configurable controls release (2026-11-17)

A new empty package/build/install directory regenerated all 26,636 functions in 67 translation units from the supported user dump and completed all 111 compilation/link steps using the separately downloaded isolated toolchain. Setup rendered its own local menu background. The final UI/event-redraw update was then rebuilt through the same installer, preserving the background.

Actual WPF routed-key and mouse events verified capture, duplicate rejection, modifiers, numpad/F24 conversion, mouse XButton binding, Escape cancellation, Reset Defaults, Save/reload, discarded unsaved changes, all 16 start-menu rows and dynamic chapter hints. Default and custom menus were rendered and visually inspected.

The installed executable from that clean source build was exercised through SDL input and observed through its GL framebuffer. Custom Coin/Start/Shoot/Grenade/Pause/Restart/Crosshair/Fullscreen/Mouse Lock actions worked, old aliases were disabled after saving a custom profile, and the native editor rejected conflicts without firing Restart. Reload was rebound to B, applied immediately and persisted across a new process. The resumed game rendered normally. Custom Start also auto-started Chapter 1 practice; binding capture while paused did not trigger the practice restart watcher. The executable hash on disk was unchanged by observation. No desktop capture service was used. Tests used isolated profiles and did not replace the player's control preferences.

Both the desktop and experimental Remix targets compiled; Remix remains outside this stable builder release. All distribution files are enumerated and hash-checked; the package audit excludes game ELF/data, game images/audio/movies, generated/lifted game C, compiled executables, runtime DLLs and player saves.


## Windows desktop v1.2.0 (2026-11-18)

Scripted Chapter 1 gameplay verified an immediate reload voice request at each of two empty-magazine events, with a refill in between and one request per empty magazine. Frame captures confirmed a steady red warning. Both route choices registered at their visible targets, and 3840x2160 framebuffer captures verified centered panels and aligned route previews.

Windows SDL tests verified fractional mouse movement, proportional speed changes and convergence to the same aim point with smoothing enabled. The WPF menu correctly enabled the controls for Mouse (Raw Relative) and saved the selected speed and smoothing level. A clean desktop executable built from the release source completed a scripted 4K gameplay smoke test with the existing arcade dump.


## Installer hotfix v1.2.1 (2026-11-18)

Tested a clean Microsoft Windows 10 Enterprise LTSC 2021 x64 evaluation VM (build 19044.1288). Its system tar reported libarchive 3.3.2 and zlib without liblzma, and xz.exe was absent from PATH before Setup. The installer downloaded and verified the pinned self-extracting MSYS2 archive, installed the compiler and dependencies, lifted 26,636 functions from the supported arcade dump, and completed all 111 desktop build steps. The installed executable and launcher were verified. A cached reinstall with downloads disabled returned exit code 0.

The optional menu background renderer exited with an access violation under the VM's virtual graphics. Setup finished with its plain-menu fallback. The VM test covers installer and build compatibility. Gameplay rendering was outside this test.
