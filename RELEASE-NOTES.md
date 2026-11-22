# HOTD4 Local Builder v1.3.11

Full Windows release, including all previous desktop features and optional OpenXR.

- **One menu for both games:** HOTD4 and HOTD4 SPECIAL buttons let you open either installed game's menu. Setup registers each installation; nearby folders are also detected. Use **Locate other game...** for other locations. Each game keeps its own chapters, settings, dump paths and saves, and the old menu closes when switching.
- **Current score alongside the record:** **P1 TOTAL**, a separate **P2 TOTAL** when player 2 joins, and the arcade's saved **HI-SCORE**. Totals accumulate across all six chapters of the current run. Practice is labelled separately. **Pause > Settings > Score Display** toggles the overlay. The native scoring/ranking/save rules are unchanged.
- **More reliable Setup:** strict download-size/SHA-256 checks with retries and an official mirror; checks and repair for cached compiler/header/Python dependencies; automatic compiler worker limits based on RAM/CPU; progress messages, phase/error logs, writable/protected-path checks, a 64-bit Windows PowerShell launcher, and locks against overlapping installations.
- **Recovery:** rerun Setup to reuse verified downloads and repair missing packages. `Setup.cmd -RepairTools` preserves the previous MSYS2 cache and creates a fresh one. Full logs are in `%LOCALAPPDATA%HOTD4-BuilderLogs`. No checksum checks are bypassed.

Download **HOTD4-Local-Builder-v1.3.11.zip**, extract it and run **Setup.cmd** with your own supported normal HOTD4 Rev A dump. To update, select the same dump and existing installation path: `Setup.cmd -InstallDir "D:GamesHOTD4-PC"`. Settings, cabinet saves and trophies are preserved. Existing direct-start flags and the performance-logging launcher remain included.

[Download HOTD4 Special v1.0.1 separately](https://github.com/davidptrssvea/HOTD-4-Special-recomp/releases/tag/v1.0.1). Each game needs its own supported arcade dump. The shared menu does not install the other game for you.

Tested: both menu handoff directions with real native game launches; live independent player scores during assisted gameplay; cached updates preserving preferences/cabinet files; Windows PowerShell 5.1 recovery, checksum, lock, path and nested-menu event tests. See BUILD-VERIFICATION.md for exact coverage. Fresh tool downloads/full lifting were not repeated for this update; OpenXR remains experimental and physical headset testing is still needed.

No arcade ELF, game textures, movies, audio, lifted game code, saved state or prebuilt game executable is included. Game processing and menu-image/native-crosshair extraction happen locally from the user's own dump. See README for supported ELF hashes and Windows requirements.
