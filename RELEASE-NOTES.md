# HOTD4 Local Builder v1.3.12

Full Windows release with desktop solo character selection, all v1.3.11 features and optional OpenXR.

- **Play solo as James or Kate:** open **Settings > Gameplay > Solo Player**, choose **James (P1)** or **Kate (P2)**, and **Save**. Start Arcade using your normal primary Start button (default **1 / Enter**). Your primary mouse or Raw Input lightgun, crosshair, Shoot, Reload/Shake, Grenade, Coin and Start follow the selected character automatically.
- **Pause-menu support:** the same choice is available under **Pause > Settings > Gameplay**. Restart Arcade/Chapter to apply a change made during play.
- **Clearer controls:** the start-menu control guide, device labels and native key-binding labels follow the selected character. James is the default. The dedicated mixed co-op modes keep their existing P1/P2 assignments and disable the solo override. This selector is for normal HOTD4 desktop; Special and OpenXR input are unchanged.
- **Full package:** retains the shared HOTD4/Special game selector, live P1/P2 totals and saved HI-SCORE, installer recovery improvements, Photo Mode, animated Model Viewer, local viewer HD textures, Trophies, Sinden/crosshair controls, performance logging and direct-start flags.

Download **HOTD4-Local-Builder-v1.3.12.zip**, extract it and run **Setup.cmd** with your own supported normal HOTD4 Rev A dump. To update, select the same dump and existing installation path, for example `Setup.cmd -InstallDir "D:/Games/HOTD4-PC"`. Settings, cabinet saves and trophies are preserved. The selector defaults to James until you choose Kate.

Testing includes saved/reopened launcher choices, character-aware control/device labels, co-op isolation, native assisted runs for James with mouse and Kate with absolute mouse, Raw Relative mouse and synthesized Raw Input lightgun packets. Only the chosen native player was active; shooting, reload and grenade consumption were verified. The production executable was rebuilt without private test hooks. A physical lightgun/headset was not tested for this update. See BUILD-VERIFICATION.md for coverage.

No arcade ELF, game textures, movies, audio, lifted game code, saved state or prebuilt game executable is included. Game processing happens locally from your own dump. See README for supported ELF hashes and system requirements. OpenXR remains experimental.

[HOTD4 Special is available separately](https://github.com/davidptrssvea/HOTD-4-Special-recomp/releases/tag/v1.0.1). Each game requires its own supported dump.
