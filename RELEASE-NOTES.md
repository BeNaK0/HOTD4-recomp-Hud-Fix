# HOTD4 Local Builder v1.3.13

Full Windows release with corrected co-op result panels, all v1.3.12 features and optional experimental OpenXR.

- **Aligned chapter results and final ranking:** player score digits, accuracy, critical-shot counters, portraits, meters and rating labels now stay together inside the correct P1/P2 panel. Fixes the reported P1 elements appearing in the middle after chapters 5 and 6.
- **Consistent presentation:** result panels retain the original layout when gameplay HUD scale or supersampling is used. Gameplay HUD controls and native score/rank calculations are preserved.
- **Full package:** includes James/P1 or Kate/P2 solo selection, shared HOTD4/Special menu, live P1/P2 totals and saved HI-SCORE, robust installer recovery, Photo Mode, animated Model Viewer and local viewer HD textures, Trophies, Sinden/crosshair settings, mixed co-op, off-screen lightgun reload, mouse-shake escapes, direct-start options and performance logging.

Download **HOTD4-Local-Builder-v1.3.13.zip**, extract it and run **Setup.cmd** with your own supported normal HOTD4 Rev A arcade dump. To update, select the same dump and your existing installation folder, or use `Setup.cmd -InstallDir "D:/Games/HOTD4-PC"`. Existing settings, cabinet saves and trophies are preserved.

Verified with assisted native co-op checkpoints for chapter 5's result and chapter 6's final ranking, before/after captures, native 1440p with HUD 125%, and 4K rendering downsampled to 720p with HUD 75%. These are targeted UI/checkpoint tests, not a new full playthrough or physical Parsec/lightgun/headset test. Production builds contain no private checkpoint hooks. See BUILD-VERIFICATION.md for coverage and limits. OpenXR remains experimental; this release's new result-layout hooks apply to desktop.

No arcade ELF, textures, movies, audio, lifted game code, saved state or prebuilt game executable is included. Game processing and asset extraction happen locally from your own dump. See README for supported ELF SHA-256 values and Windows/system requirements.

[HOTD4 Special v1.0.2 is available separately](https://github.com/davidptrssvea/HOTD-4-Special-recomp/releases/tag/v1.0.2). Each game requires its own supported arcade dump.
