# HOTD4 Local Builder v1.2.3

This Windows hotfix fixes the startup error that said PowerShell could not load `hotd4-controls.ps1` because script execution was disabled. The desktop launcher sets the policy for its own PowerShell process. No system policy settings need to change. The fix also applies to the Performance Log launcher.

## Quick update for existing v1.2.2 installations

1. Download [Play-HOTD4.cmd](https://github.com/davidptrssvea/HOTD4-recomp/releases/download/v1.2.3/Play-HOTD4.cmd).
2. Rename it to **Play HOTD4.cmd** and replace the old file in your installed **HOTD4-PC** folder, beside **HOTD4_Recomp**.
3. Run the replacement launcher. Your existing game build, settings and trophies are ready to use.

## Full installer

Download and extract **HOTD4-Local-Builder-v1.2.3.zip**, run **Setup.cmd**, and select your own complete, extracted **The House of the Dead 4 (Export), Rev A (DVP-0003A)** arcade dump. Setup prepares the HD executable locally when given the original Rev A ELF. The previously supported HD variant also works. See the [README](https://github.com/davidptrssvea/HOTD4-recomp/blob/v1.2.3/README.md) for both SHA-256 values, the supported dump layouts and the Windows requirements.

Both downloads are free of game assets and prebuilt game executables. **SHA256SUMS.txt** covers the ZIP and the standalone launcher.
