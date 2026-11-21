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


## Original Rev A support

The Windows desktop installer completed all 111 build steps using a fresh package and install directory, an extracted original DVP-0003A dump in the hod4prog/hod4data/hod4drv layout, and a cached MSYS2 toolchain. The source ELF retained its SHA-256. The installed copy matched the previously supported HD ELF byte for byte. Setup generated the menu background from the local dump. The installed launcher ran Chapter 1 for 1,675 frames, with a verified 3840x2160 framebuffer capture. Preflight also accepted the original ELF in the disk0 layout and the previously supported HD ELF, and rejected a modified ELF.


## Desktop launcher hotfix v1.2.3

Reproduced the v1.2.2 `hotd4-controls.ps1` startup error with a Restricted policy inherited by the launcher. With the process-scoped launcher fix, the existing Windows installation ran Chapter 1 successfully through both the desktop and Performance Log launchers. The performance run saved its CSV.

## Windows desktop v1.3.0

- Extracted the release builder to an empty directory and ran Setup on Windows 11 x64 with the original Rev A (DVP-0003A) dump and a cached MSYS2 toolchain. All 111 game compile/link steps completed. Setup built both graphical launchers and rendered the local menu background. The source ELF SHA-256 was unchanged. A cached reinstall preserved test settings, trophies, a cabinet save and the background.
- Ran a Chapter 1 smoke test with the installed executable. Photo Mode saved five 3840 × 2160 PNGs covering camera movement and roll, the four filters, and resume on the same frame.
- Verified the graphical launchers without a console and validated 1,166 model records and 1,833 skeletal clips. The viewer applied locally enhanced textures to James Taylor, Kate Green and Justice in both static and animated previews. Three original diffuse texture references could not be resolved.
- The changed host sources compiled with the optional OpenXR configuration. The new features were exercised on the Windows desktop. VR headset testing was outside this release check.
- The manifest and ZIP were checked for game assets, lifted code and compiled binaries. The only bundled artwork is the existing trophy and crosshair illustrations.

## Windows desktop v1.3.1

- Built and installed from a freshly extracted builder on Windows 11 x64 with an original Rev A (DVP-0003A) dump and a cached MSYS2 toolchain. Setup compiled both graphical launchers and created the local menu background. The installed build completed 1,300 frames in Chapter 1 on both 2560 × 1440 and 3440 × 1440 outputs.
- Exercised the resolution field and display mode in the packaged start menu. Verified custom input, saving and reopening settings, and migration of a saved v1.3.0 windowed resolution.
- Checked the gameplay viewport and aim mapping at 1280 × 720, 2560 × 1440, 3440 × 1440, and 3840 × 2160. Verified 720p rendered into 1440p output. A 3440 × 1440 framebuffer capture showed a full-height 2560 × 1440 gameplay area with the HUD in its intended position and two 440-pixel side bars.
- The updated SDL host also compiled in the optional OpenXR configuration. Display and aim checks used the desktop build.

## Windows desktop v1.3.2

- Captured the SEGA startup screen in the desktop build at 1920 × 1080 and 3840 × 2160. The startup artwork and serial numbers share a centered 4:3 canvas.
- Triggered the native grab state during Chapter 1 using a local test hook. Before-and-after 1280 × 720 captures show the gauge end caps, track, fill and target label aligned, with the shake prompt centered.
- Entered the Justice encounter directly and shot through its shield. The health and cancel gauge sprites stayed together as the game applied damage.

## Windows installer v1.3.3

- Checked both dump layouts through PowerShell Setup and the Python builder. Tested the stock ELF, the supported HD primary ELF, a matching HD fallback, a mismatched HD fallback, and an absent HD fallback.
- Installed from a fresh builder with cached tools and a test dump containing a modified primary ELF and a matching `hod4Ms_HD.elf`. Setup built the desktop executable and rendered the menu background. The installed `hod4M.elf` matched the HD fallback byte for byte. Both files in the original dump retained their filenames and content.


## Installer dependency hotfix v1.3.4 (2026-11-21)

- Confirmed the current MINGW64 repository no longer contains `mingw-w64-x86_64-python-pyelftools`. Removed that pacman target; the remaining compiler/runtime packages installed in a new isolated MSYS2 tree created from the pinned official archive.
- Tested the final installer on Windows 11 x64 (build 26300) using Windows PowerShell 5.1, that freshly initialized toolchain, a newly extracted builder and an empty game-install directory containing spaces. The toolchain's Python imported pyelftools 0.33 from the private HOTD4 cache. The local lift produced 67 C translation units, all 111 compilation/link steps completed, both graphical launchers built, and Setup rendered a 1920x1080 menu image from the local dump. No separate system Python or pip installation was used for the game build.
- The newly installed executable then ran scripted Chapter 1 for 1,301 frames, rendered a verified 1920x1080 framebuffer and wrote 1,301 timing samples to CSV. This is a startup/render/logging smoke test, not a new full campaign or VR-headset test.
- Reran Setup with `-NoDownload` and unreachable HTTP/HTTPS proxies. The cached build reported no work to do and completed successfully. Hashes of nine files were unchanged: INI, custom controls, crosshair size, raw mouse speed, Sinden state/width, trophies, native cabinet NVRAM and the locally generated background.
- Verified fresh dependency download, cached offline use, damaged-wheel rejection, online repair and offline repair of incomplete modules with the new MSYS2 Python. An older toolchain that already has pyelftools 0.33 also passed dependency setup without downloading it.
- Six automated dependency tests cover checksum rejection before module installation, offline cache reuse/repair, legacy caches and unsafe archive paths. A changed bootstrap helper was rejected by Setup's package integrity check before installation. The six release-publishing tests also pass.
- The original dump ELF retained SHA-256 `72FDD45830ACD9317EC1E4F97DE35A270C94746068FDAF827381C91BB47AA296`. Game and frontend sources are unchanged from v1.3.3. The manifest-only distribution excludes dump data, lifted C, game binaries, runtime DLLs, game media, test output and player progress. Only installer/bootstrap code and documentation changed. No new Windows 10 VM or VR-headset test was performed for this hotfix.


## Windows desktop v1.3.5 - mouse shaking (2026-11-21)

Reused Special's motion detector with the normal Rev A player's own grab flags (CPlayerMgr::GetCatchType offsets 0x54, 0x74 and 0x7c). The detector consumes SDL motion before aim sensitivity or cursor clamping. Button filtering is consistent across cabinet board reads and direct acceleration reads; pending synthetic reload acceleration is cleared during mouse grabs. Raw lightgun mode bypasses the gesture filter, and the game hook is excluded from OpenXR.

Separate temporary QA executables fed real SDL mouse-motion and button events into the runtime. Controlled Chapter 1 checkpoints invoked the original CatchPlayer function and restored player health only to keep comparisons alive. Mouse Absolute and Raw Relative each reduced resistance from 4.5 to 0 and released the player in 31 frames. Straight motion and held right mouse generated no shake pulses and left resistance at 4.5 through frame 4490. Outside grabs, real SDL firing/reload events changed ammunition 30 -> 27 -> 30. These are controlled integration checks, not unassisted campaign or every-boss verification.

The production desktop executable was rebuilt without QA code and ran 2901 frames in Chapter 1 at 3840x2160 with MSAA 4x and the existing installed DLLs. Its own framebuffer showed the 3D scene and HUD filling the 4K frame. The native gesture regression test covers both axes, straight sweeps, jitter, rate limiting, pulse expiry, reset and SDL clock wrap. Release-publishing and dependency tests passed. Source manifest and English PowerShell menu syntax checks passed. Local installation preserved existing settings, trophies and cabinet save hashes. No physical lightgun or headset test was performed for this change.


Release-package validation for v1.3.5: extracted the complete manifest-only ZIP to a new folder and ran Setup into an empty installation directory with spaces, using the supported local arcade dump and the previously downloaded isolated toolchain (`-NoDownload`). Setup regenerated all 67 game C units, completed all 111 compilation/link steps, installed the desktop/frontend launchers, and rendered its own 1920x1080 menu background. The original source ELF hash was unchanged. The resulting installed executable completed a separate 1301-frame Chapter 1 startup/render smoke test and wrote 1301 CSV frame-timing samples. No temporary QA hooks or prebuilt game files were included in the source package.


## v1.3.6 desktop issue fixes (2026-11-21)

Issue 6: isolated the original CST6BOSSAI::DamageGetNodeLevel function with a native executable and the user's local ELF. Index -1 reproduced exit 49 with an unlifted jump to 0x0811f149. The lifter had converted the signed first table index to 0xffffffff and rejected the valid negative slot. Keeping the range bias signed generated the missing local branch; 84 native input cases then matched the original ELF's case table. Five synthetic, asset-free generator tests cover negative, zero and positive first slots, a rejected oversized bias and emitted local case labels. A subsequent assisted live-boss integration test converted an original hit message into grenade node -1 and lowered the boss HP to 0.01 to force the finisher. The previous generated classifier reproduced exit 49 at 0x0811f149 in that fight. With the corrected classifier, both phases (initial HP 330 and 240) survived the grenade-damage call, reached HP 0, entered ST6BOSS_Dead_B_Init (0x081d567c), and the 6000-frame run exited 0. These were injected grenade hit messages, not manually thrown grenades or an unassisted complete playthrough.

Launcher diagnostics: full error text is now retained in unique local log files rather than only showing its final 1200 characters. Native .NET tests verify full content and exit codes, bounded dialog text with the log location, non-overwriting file names and graceful failure if the log directory cannot be written.

Issue 8 was reproduced at frames 700 and 2800: the original game requests the external arcade test environment, calls system("touch /tmp/segaboot/test"), and exits normally. This is a missing test-program handoff, not a key-binding conflict. The supplied hod4testM.elf contains Game Difficulty and Life Setting menus. The installer now builds the separate operator executable locally, verifies its ELF SHA-256, and generates missing boot-font resources from Windows system fonts. Exit 75 hands off to that program; leaving its main menu restarts the game. Native tests navigated Game Assignments, changed difficulty and lives, exited and re-entered the menu, then verified the settings through the main game's own getters. The operator's ICC register-argument GetRegion entry needed the same override as its regular entry; otherwise the main game rejected its saved settings as belonging to another region. The full game -> menu -> game test passed in chapter practice, including refresh of the temporary practice NVRAM. The standalone menu's 4:3 projection was visually checked in a 1280x720 window after explicitly fitting its viewport.


Issue 5 / supersampling: reproduced tiny UI in the upper-left corner with a 3840x2160 game framebuffer presented in a 1280x720 window. The HUD compared the physical GL viewport width with the logical render width and skipped the layout transform. It now maps that viewport back to game coordinates before the comparison, leaving offscreen framebuffer sizes alone. Separate subtitle CFont instances retain a centered layout rather than being anchored according to their first glyph; constructor reuse clears stale font tags. Native visual checks passed at 2560x1440 and 3840x2160, 4K -> 720p and 4K -> 1440p downscaling, and 720p -> 1440p upscaling. A final clean-install 3300-frame run resized its window from 2560x1440 to 1280x720 at frame 1800; gameplay HUD and subtitles remained correctly placed. Diagnostic default-framebuffer captures now read actual drawable dimensions instead of undefined pixels outside the window.

Clean installer validation: a new source-only package folder and an initially empty installation directory were tested with the user's Rev A HD dump and the previously verified offline MSYS2 toolchain. Setup regenerated all 67 game C units and all 4 operator units, built both native executables, installed the launchers and generated a 317929-byte menu background locally. Setup exited 0. The original game ELF still has SHA-256 72fdd45830acd9317ec1e4f97de35a270c94746068fdaf827381c91bb47aa296. The final source refresh and cached reinstall also passed. No temporary QA hooks, generated game code, original operator ELF, locally generated fonts or game assets are included in the source package.

Automated checks: five signed-switch generator tests, four verified operator-ELF discovery tests, six Python dependency tests and six release-packaging tests passed. The native .NET launcher tests passed full-log retention, bounded dialog previews, unique filenames and an unwritable-directory fallback. OpenXR rendering, CRT modes and independent Parsec player routing were outside this Windows desktop validation.


Final operator checks: the main game's original getters returned difficulty 3 (Medium Hard), initial lives 4 and maximum lives 6 after editing them in the clean installation's operator menu. A held Test button during the first 45 menu frames was suppressed until release; subsequent Service/Test input still reached Game Assignments and rendered frame 300 normally. This prevents the launch key from immediately selecting the menu's initially highlighted EXIT item.


Local deployment: the tested desktop and operator executables, generated operator font resources and matching compiler runtime DLLs were installed under D:/Emulatorer/HOTD4/HOTD4_Recomp. The existing legacy `Spela HOTD4 i 4K.cmd` received the same operator handoff without changing its original dump or cabinet-save location. Nine files were installed, with backups under HOTD4_Recomp/backups/issue-fixes-20261121-175544; all 16 existing profile/save files were unchanged. Both original cabinet-save timestamps remained unchanged after the shadow-save tests. A separate 1000-frame 4K-to-720p smoke test of the installed binary exited 0, and the local legacy launcher's full game -> operator -> game test passed using a separate test NVRAM. These validated desktop changes are included in v1.3.6.


## v1.3.7: mixed lightgun and remote mouse input (2026-11-21)

- Built the Windows desktop runtime with separate raw P1 device routing and injected remote P2 mouse routing. A dedicated Win32 hook thread queues events while the game loads assets; focus/pause releases and queue overflow clear held P2 switches.
- Assisted native gameplay checks started both players in Chapter 1. A raw P1 trigger phase consumed 30 P1 rounds and zero P2 rounds; an injected-packet P2 trigger phase consumed zero P1 rounds and 30 P2 rounds. Verified absolute mode at 1920x1080 and relative mode at 2560x1440. These use simulated device packets in a temporary QA executable, not a physical gun or a real Parsec stream.
- Native 3840x2160 checks verified independent mapped positions, physical/own-warp exclusion, pause/focus release, queue overflow handling, and separately rendered red P1 / blue P2 sights (read-back center pixels 249/38/51 and 45/161/255).
- Compiled and ran `.release/test_coop_mouse.c` with GCC warnings as errors: isolated cursor deltas, physical-motion baselines, relative sensitivity, absolute off-screen positions, bounds, smoothing and tick wrap passed. Example: `gcc -std=c11 -Wall -Wextra -Werror .release/test_coop_mouse.c -lm -o test-coop-mouse`.
- Loaded and rendered the WPF frontend offscreen using Windows PowerShell 5.1. Tested all five modes, P1/P2 device availability, tuning availability, automatic remote P2 label and saved mode persistence. Ordinary input modes keep their existing defaults. A clean desktop build also completed a 3,300-frame single-player mouse regression at 1920x1080. All three reticle models were checked with Original / Red / Blue color settings so P2 stays distinguishable.
- The execution environment has no interactive foreground window. Real Windows-injected event delivery over Parsec, physical Sinden/DolphinBar hardware, simultaneous remote play and off-screen reload with that hardware remain unverified. This feature is experimental until that testing is completed.


## Unreleased: original arcade High Scores (2026-11-21)

- Added a compact in-game HI-SCORE display and native Pause > High Scores page with all ten original ranking entries and initials. The native pause settings toggle persists independently of the ranking.
- Verified the Rev A rank reader against ConfigMgr_GetRankDataPtr: config + 0x14 points to the backup record, records start after its 12-byte header, and ten entries use a 24-byte stride. Initials are the original 0..26 letter indices. The feature only reads these records; the game owns insertion, qualification, ordering and saving.
- In isolated cabinet copies, inserted controlled test records 230123/COD and then 245234/COD into the live game table and invoked the game's original ConfigMgr_ReqRankDataUpdate routine. Separate process launches reloaded the exact points and initials from the original game's NVRAM save pipeline. The other nine ranking entries stayed unchanged. This was an assisted persistence test, not an unassisted complete run or legitimately earned leaderboard result. The personal cabinet save and source dump were not used as write targets.
- Native 1080p/1440p/4K runs exercised the reader, display and ranking refresh. Rendered and inspected the full native score page, navigated in and out using keyboard events, and resumed the game. Toggled High Score Display off through the actual pause Settings menu and verified that another process loaded the saved Off preference without losing the ranking.
- The standalone native regression checks original letter decoding, ordering, limits and rejected malformed records. Practice keeps the existing temporary NVRAM behavior; the display uses that session's copy and labels it accordingly.

Local installation verification: built clean production desktop and operator executables with no QA hooks, installed them under D:/Emulatorer/HOTD4/HOTD4_Recomp with a backup under backups/high-scores-20261121-201602, then ran the installed desktop binary for 3,300 frames at 3840x2160 displayed in a 1280x720 window. It reached interactive Chapter 1 gameplay with shooting/reload inputs and exited 0. All 17 protected personal profile/save/source-ELF hashes were unchanged after this test. No release was published for this development change.


## v1.3.8-openxr-preview.1: Windows stereo fixes (2026-11-21)

- Reproduced the black right eye in a native stereo run using a private dump: left mean RGB 69.570, right 0.000 at frame 3200, with complete framebuffer status for both. The GLX switch was outside the replay recording, so both passes targeted the left buffer.
- Explicit eye selection exposed stale model data and side-pass contamination. Added multi-draw/index and GLSL uniform snapshots, secondary-color arrays, live pointer restoration, independent eye clear bookkeeping, isolated pbuffer side passes, scaled native framebuffer-to-texture copies, and current-frame full-screen composite suppression.
- Native 3300-frame retest reached Chapter 1 with complete nonblack eye buffers (mean RGB 70.304/70.385). Inspected both images: animated zombies and environment matched across the eyes, without the floating scene rectangle seen in the baseline. No recording-overflow reports.
- Built the actual PC OpenXR target against the OpenXR SDK. A private, unregistered OpenXR test DLL supplied real GL swapchain textures, fixed eye/controller poses and scripted inputs. The actual host_xr path rendered and submitted distinct left/right swapchains; at frame 3200 their mean RGB was 70.723/70.508. Inspected both submitted images, including gun and animated zombies. Tested with LINDBERGH_GL_THREAD=1. This validates the application pipeline with a simulated runtime, not headset tracking, optical comfort or VDXR/SteamVR behavior.
- Eleven distinct scripted off-hand X presses across 3300 frames produced zero capture requests, with no recording overflow. The first startup/loading interval still had a multi-second stall; this is not a blanket claim of hitch-free performance. Added a portable regression covering the diagnostic opt-in, rising edge, menu and dual-wield guards.
- The VR launcher creates session logs and captures stdout/stderr. Tested a path containing spaces using a harmless executable fixture. The mock runtime and instrumentation are confined to validation folders and excluded from the package. Final production executables were rebuilt from source without the eye-dump QA hook.
- Existing publish, dependency, ELF selection, mouse-shake, co-op and high-score regressions passed locally. Windows Setup -NoDownload -OpenXR built/installed desktop, operator and OpenXR targets from the user's own dump in a separate validation install. All package files are hash checked and distributed through the existing source-only allowlist.
- No physical headset test has been performed. Quest 3 with Virtual Desktop (both VDXR and SteamVR) still needs reporter testing. Restart corruption after Alt+F4, room-specific brown obstruction, cutscene FPS, orientation and shake sensitivity are not declared fixed by this preview.

Production follow-up: the clean OpenXR executable completed the same threaded simulated-runtime test (3301 frames, exit 0), submitting two distinct swapchains with mean RGB 71.045/70.933 at frame 3200. Both production images were visually inspected: animated zombies, environment and gun appeared in each eye without the duplicate scene rectangle. No capture or recording-overflow messages occurred. The simulation included eleven off-hand X presses, plus a separate thumbstick Start hold.

The clean installed desktop binary also completed a 3300-frame 3840x2160 rendering regression (1280x720 window), reaching Chapter 1 gameplay and exiting 0. This is a desktop compatibility check, not a headset FPS measurement.
