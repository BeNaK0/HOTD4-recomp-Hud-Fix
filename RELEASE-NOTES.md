# HOTD4 v1.3.21 - Launcher fix for older installations

- The launcher can locate the HOTD4 arcade dump in either supported folder layout when the saved path is missing or stale.
- The updater preserves a valid configured dump location and writes the resolved path when installing the update. Existing game files and settings stay in place.

Choose **Updates > Download and install** in a working launcher. If an older launcher reports that `dump-path.txt` is missing, open the release ZIP and run **Setup.cmd** with your existing installation and arcade dump.
