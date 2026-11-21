# HOTD4 Local Builder v1.3.7 for Windows

A full Windows desktop builder release adding an experimental mixed input mode for **a host Sinden/DolphinBar lightgun as P1 and a Parsec guest mouse as P2**. All previous desktop features and installer fixes are included.

## New: mixed lightgun + remote mouse co-op

- **Co-op: Gun P1 + Mouse P2** keeps the host's selected Raw Input gun on P1 and routes injected remote mouse input to P2. The two players have independent aim, trigger, reload and grenade inputs.
- **Co-op: Gun P1 + Mouse P2 (Relative)** adds a separate relative P2 cursor with adjustable mouse speed and smoothing.
- **Separate sights:** P2 gets its own contrasting sight, including when the Blue Circle model or a blue color is selected. The selected model and size apply to both sights.
- **Input reliability:** a dedicated Windows input hook thread keeps receiving mouse events during asset loading. Focus changes, pause and queue overflow release held switches. Host gun movement and the game's own cursor recentering do not move P2's sight.
- Both the start menu and in-game pause settings expose the new modes. Existing input defaults and saved profiles are preserved.

## Set up P1 and P2

1. Connect the host's Sinden or DolphinBar/Wiimote as a separate Raw Input device. Start the lightgun software and enable the Sinden border if required.
2. Open **Settings > Input & Anti-Aliasing** and select **Co-op: Gun P1 + Mouse P2** (or the **Relative** variant for speed/smoothing controls).
3. Under **Player 1 Device**, explicitly select the host's lightgun. **Auto** only assigns absolute guns; select a relative DolphinBar device explicitly. P2 uses the guest mouse automatically, so no P2 raw device selection is needed. Save and restart the game.
4. In Parsec, allow the guest **mouse and keyboard** access and disable **Exclusive Input**, then restart the stream. See [Parsec's input troubleshooting guide](https://support.parsec.app/hc/en-us/articles/32381827815188-Mouse-and-Keyboard-Isn-t-Working-Correctly-When-Connected).
5. Default **P1 Coin / Start: 5 / 1**. Default **P2 Coin / Start: 6 / 2**. The host gun buttons control P1. The guest uses left mouse to shoot, right mouse to reload and Space for grenades, unless rebound. In these co-op modes, shared keyboard Shoot / Reload / Grenade / Fire Mode bindings control P2; Coin and Start retain their separate P1/P2 bindings.

**Experimental:** local packet-routing checks, native two-player game checks, 4K sight rendering and frontend tests passed. A real two-computer Parsec session with physical Sinden/DolphinBar hardware has not yet been verified. Please report whether both players can aim, fire, reload and throw grenades independently. A host gun which only controls the shared Windows cursor cannot be separated this way; it must expose its own raw device. Remote software or virtual drivers which present guest movement as ordinary physical HID input may need a different input path.

## Install or update

Extract **HOTD4-Local-Builder-v1.3.7.zip** into a new folder and run **Setup.cmd** with your own complete, extracted **The House of the Dead 4 (Export), Rev A (DVP-0003A)** arcade dump. Original Rev A, the supported HD variant and automatic `hod4Ms_HD.elf` discovery remain supported.

To update, run `Setup.cmd -InstallDir "C:\Path\To\HOTD4-PC"` and select the same arcade dump. Setup rebuilds the game locally and keeps your settings, cabinet saves and trophies. Start **Play HOTD4.exe** as usual.

Includes Photo Mode, Model Viewer with original animations and locally generated HD textures, trophies, Sinden options, mouse shaking to escape grabs, configurable controls, resolution selection, performance logging, the original arcade Test Menu and the v1.3.6 World/HUD fixes. This update targets Windows desktop; the optional OpenXR build remains experimental and does not receive this mixed desktop input mode.

## Validation and package contents

Assisted native Chapter 1 tests verified that a raw P1 trigger phase consumed 30 P1 rounds and zero P2 rounds; an injected-packet P2 trigger phase consumed zero P1 rounds and 30 P2 rounds. Absolute input was tested at 1080p, relative input at 1440p, and separate sights and coordinate handling at 4K. The WPF frontend passed mode selection, field availability and saved-settings checks. A clean desktop binary completed a 3,300-frame single-player regression and the installed production build passed startup/shutdown checks. These tests simulate input packets; they are not a real Parsec hardware session. See [BUILD-VERIFICATION.md](https://github.com/davidptrssvea/HOTD4-recomp/blob/v1.3.7/BUILD-VERIFICATION.md).

The ZIP contains source and the local builder, with **no game assets, arcade ELF, lifted game code, prebuilt game executable, saves or cabinet NVRAM**. Game code, copied data and generated menu resources are prepared on your own PC from your own dump. **SHA256SUMS.txt** covers the ZIP. See the [README](https://github.com/davidptrssvea/HOTD4-recomp/blob/v1.3.7/README.md) for system requirements, supported dump hashes and instructions.
