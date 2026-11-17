# HOTD4 Local Builder OpenXR Preview

Local Windows builder for the original The House of the Dead 4 arcade game.

- Optional OpenXR PC VR build with a separate launcher. Setup builds the desktop game and, when selected, also builds the VR version from the same local dump.
- Configurable keyboard controls in Settings and in the native pause menu, with duplicate protection, mouse button capture, default reset and saved profiles.
- Always-visible start-menu overview of Add Coin, Start and all configured controls.
- Resolution up to 4K, selectable MSAA, AF, cutscene pacing/aspect corrections and adjustable HUD.
- Native pause menu, chapter practice, 12 local trophies with metallic stars and galleries.
- Sinden border with four widths, Raw Input device selection, crosshair style/size/color and live preview.
- Menu background rendered locally from the user's dump. No game image is distributed.

Download **HOTD4-Local-Builder ZIP**, extract the entire folder and run **Setup.cmd**. The only game input is your own supported extracted arcade dump; setup obtains the build tools and creates the executable locally. See README.md for the required dump layout and SHA-256.

The archive contains no game executable, lifted game code or Sega assets. Experimental RTX Remix is excluded. Local trophies do not connect to PSN.

Validation: complete clean local build from the supported dump; actual WPF input capture and save/reload; live runtime remapping, native conflict protection, restart persistence, fullscreen/crosshair controls. Earlier full clean-install checks cover trophies, pause, Sinden, Raw Input and AA. Physical lightgun calibration is not part of these automated checks.

For PC VR, use a compatible headset with an active OpenXR runtime that supports OpenGL. The installer and startup checks have been exercised on Windows. Headset rendering and tracked controller play still need hardware verification.

### What to test in VR

1. Download and extract the builder ZIP. Run `Setup.cmd`, select your own extracted HOTD4 arcade dump, and choose **Yes** to build OpenXR.
2. Connect your headset, start an OpenGL-compatible OpenXR runtime, and run `Play HOTD4 (VR OpenXR).cmd`.
3. Check rendering in both eyes, head tracking, aiming, trigger, grip reload, thumbstick Start, and the VR menu. Watch for black screens, stutter or crashes in gameplay and cutscenes.

Please include your headset, OpenXR runtime and GPU when reporting results.
