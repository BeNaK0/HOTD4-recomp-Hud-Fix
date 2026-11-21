# HOTD4 Local Builder v1.3.4 for Windows

Fixes Setup stopping with `target not found: mingw-w64-x86_64-python-pyelftools`.

MSYS2 removed the ELF-reader package from its active MINGW64 repository. Setup now downloads a pinned, SHA-256-verified pyelftools wheel from PyPI and prepares it automatically inside HOTD4's isolated build-tool cache. No manual edits, pip commands, separate Python installation or changes to system Python are required. Cached builds and `-NoDownload` remain supported once dependencies are available. A missing or damaged offline cache produces an explicit repair instruction.

This is an installer hotfix. It retains the Windows game, launcher, Photo Mode, Model Viewer, trophies, Sinden settings, performance logging and optional experimental OpenXR build from v1.3.3.

Tested on Windows 11 with a new isolated toolchain: complete local build, game startup, locally rendered menu background and CSV timing output. An offline reinstall preserved settings, trophies, cabinet save and background.

## Install or update

Extract **HOTD4-Local-Builder-v1.3.4.zip** into a new folder and run **Setup.cmd** with your own complete, extracted **The House of the Dead 4 (Export), Rev A (DVP-0003A)** arcade dump. Original Rev A, the supported HD variant and automatic `hod4Ms_HD.elf` selection remain supported.

If an older Setup failed, simply use this new builder with the same dump. To update an existing working installation and keep settings, saves and trophies, run `Setup.cmd -InstallDir "C:\Path\To\HOTD4-PC"` and select that same dump. Start from **Play HOTD4.exe**.

The ZIP contains source and the local builder, with **no game assets, arcade ELF, lifted game code, prebuilt game executable, saves or cabinet NVRAM**. All game preparation happens on your PC. **SHA256SUMS.txt** covers the ZIP. See the [README](https://github.com/davidptrssvea/HOTD4-recomp/blob/v1.3.4/README.md) for system requirements and supported dump hashes/layouts.
