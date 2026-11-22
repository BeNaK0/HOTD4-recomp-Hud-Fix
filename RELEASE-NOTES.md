# HOTD4 Local Builder v1.3.10

Full Windows release with all v1.3.9 features, the original animated Name Entry crosshair and optional OpenXR.

- **Direct Arcade start:** run `"Play HOTD4.exe" --no-launcher` to skip the graphical menu and use your saved resolution, display mode, HUD scale and settings. `--skip-launcher` is an alias. Both flags also work with the CMD launcher and performance-logging entry.
- ELF preparation and cleanup happen automatically, so shortcuts and cabinet frontends do not need the temporary ELF path. Start without the flag for the normal menu. Exiting back to Main Menu closes the game in direct mode.
- README includes troubleshooting for a failed MSYS2 download checksum, with the verified archive link, file size and SHA-256.

Download **HOTD4-Local-Builder-v1.3.10.zip**, extract it and run **Setup.cmd** with your own supported normal HOTD4 Rev A dump. To update, use the same dump and your existing installation path: `Setup.cmd -InstallDir "D:\Games\HOTD4-PC"`. Settings, cabinet saves and trophies are preserved.

[HOTD4 Special has its own full Windows release](https://github.com/davidptrssvea/HOTD-4-Special-recomp/releases/tag/v1.0.0).

This source-only builder contains no arcade ELF, game textures, movies, audio, lifted game code, saved state or prebuilt game executable. All game processing happens locally on the user's PC. See README for supported ELF hashes and system requirements. OpenXR remains experimental and needs physical headset/runtime testing.
