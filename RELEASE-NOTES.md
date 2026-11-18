# HOTD4 Local Builder v1.2.2

The Windows installer now builds directly from an original **The House of the Dead 4 (Export), Rev A (DVP-0003A)** Sega Lindbergh dump. Setup prepares and verifies the HD version of `hod4M.elf` on your PC. The original dump stays untouched. The previously supported HD variant still works.

## Supported arcade files

| `hod4M.elf` input | SHA-256 |
| --- | --- |
| Original Rev A (DVP-0003A) | `65EC92C55EF48AD5EA565DFDD40FF43759DAACFA2CEBD6D5B83CE0368F9BFE14` |
| Previously supported HD variant | `72FDD45830ACD9317EC1E4F97DE35A270C94746068FDAF827381C91BB47AA296` |

Select the folder with your complete extracted dump. Setup supports `elf/`, `fs/` and `drv/` (usually inside `disk0`), or `hod4prog/`, `hod4data/` and `hod4drv/`.

## Install or update

1. Download and extract **HOTD4-Local-Builder-v1.2.2.zip**.
2. Run **Setup.cmd** and select your extracted Rev A dump.
3. When the local build finishes, open **Play HOTD4.cmd** in the installation folder.

To update in place, run `Setup.cmd -InstallDir "C:\path\to\HOTD4-PC"` with your existing installation path. Setup preserves your settings and trophies. The ZIP contains the local builder, with no arcade files, game assets or prebuilt game executable.

## System requirements

Use Windows 10 or 11 x64 with Windows PowerShell 5.1 and about **10 GB free** beyond the extracted dump. First-time setup requires internet access to download the build tools. Desktop gameplay requires a GPU driver with desktop OpenGL compatibility support. Optional OpenXR requires a compatible headset, tracked controllers, an active OpenXR runtime with OpenGL support, and an OpenGL 4.3 compatibility context. See the [README](https://github.com/davidptrssvea/HOTD4-recomp/blob/v1.2.2/README.md#system-requirements) for details.

The original Rev A dump was verified in a fresh Windows desktop installation using a cached toolchain. Setup generated the menu background locally, and the installed launcher ran Chapter 1 with a verified 3840 × 2160 framebuffer.
