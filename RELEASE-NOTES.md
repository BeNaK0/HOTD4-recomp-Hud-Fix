# HOTD4 Local Builder v1.0.0

First complete private release of the local Windows builder for the normal The House of the Dead 4 arcade game.

- Configurable keyboard controls in Settings and in the native pause menu, with duplicate protection, mouse button capture, default reset and saved profiles.
- Always-visible start-menu overview of Add Coin, Start and all configured controls.
- Resolution up to 4K, selectable MSAA, AF, cutscene pacing/aspect corrections and adjustable HUD.
- Native pause menu, chapter practice, 12 local trophies with metallic stars and galleries.
- Sinden border with four widths, Raw Input device selection, crosshair style/size/color and live preview.
- Menu background rendered locally from the user's dump. No game image is distributed.

Download **HOTD4-Local-Builder-v1.0.0.zip**, extract the entire folder and run **Setup.cmd**. The only game input is your own supported extracted arcade dump; setup obtains the build tools and creates the executable locally. See README.md for the required dump layout and SHA-256.

The archive contains no game executable, lifted game code or Sega assets. Experimental RTX Remix is excluded. Local trophies do not connect to PSN. This release remains in a private repository.

Validation: complete clean local build from the supported dump; actual WPF input capture and save/reload; live runtime remapping, native conflict protection, restart persistence, fullscreen/crosshair controls. Earlier full clean-install checks cover trophies, pause, Sinden, Raw Input and AA. Physical lightgun calibration is not part of these automated checks.
