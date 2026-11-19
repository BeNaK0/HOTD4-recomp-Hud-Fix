# HOTD4 Local Builder v1.3.3 for Windows

If `hod4M.elf` has an unsupported SHA-256, Setup now checks for `hod4Ms_HD.elf` alongside it. Setup uses the HD file when its SHA-256 matches the supported Rev A HD executable. Keep both files under their original names in your dump.

## Install or update

Extract **HOTD4-Local-Builder-v1.3.3.zip** and run **Setup.cmd** with your own complete, extracted **The House of the Dead 4 (Export), Rev A (DVP-0003A)** arcade dump. Setup also accepts the original Rev A `hod4M.elf` and the previously supported HD variant under that name.

To update and keep your settings, saves and trophies, run `Setup.cmd -InstallDir "C:\Path\To\HOTD4-PC"` with your existing installation path and select the same dump when prompted. Start the game from **Play HOTD4.exe**.

The ZIP contains the local builder and source. Setup builds the Windows executables on your PC. The ZIP contains no game assets or prebuilt game executables. **SHA256SUMS.txt** covers the ZIP. See the [README](https://github.com/davidptrssvea/HOTD4-recomp/blob/v1.3.3/README.md) for system requirements and the supported dump layouts.
