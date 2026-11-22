# HOTD4 Local Builder v1.3.9

Full Windows release, including the optional OpenXR build and all v1.3.8 features and fixes.

- New **Name Entry (Original)** crosshair: the arcade game’s original red P1 / blue P2 sprites, idle pulse and firing animation. Select it in Settings > Crosshair Style. Size, color and animated preview are supported.
- Original crosshair textures and animation data are read locally from your own normal HOTD4 dump. No game assets or lifted code are shipped.
- HOTD4 Special now has its own [separate full Windows release](https://github.com/davidptrssvea/HOTD-4-Special-recomp/releases/tag/v1.0.0).

Download and extract **HOTD4-Local-Builder-v1.3.9.zip**, then run **Setup.cmd** with your supported extracted Rev A arcade dump. For an update, use the same dump and select your existing HOTD4-PC installation (`Setup.cmd -InstallDir "C:\Path\To\HOTD4-PC"`). Settings, saves and trophies are preserved. Choose Yes when asked about OpenXR if you want the optional VR build.

Requirements: Windows 10/11 x64, Windows PowerShell 5.1/.NET Framework 4.x, a supported normal HOTD4 Rev A dump, writable folders, internet for first-time tool downloads, and approximately 10 GB free beyond the dump. OpenGL driver support is needed for gameplay; OpenXR additionally requires a compatible runtime/headset. See README for supported ELF hashes and details.

The ZIP contains source, scripts, tools and original/procedural project artwork only. No arcade ELF, texture, movie, audio, generated game code, prebuilt game executable or cabinet state is included. All arcade processing happens on your PC.
