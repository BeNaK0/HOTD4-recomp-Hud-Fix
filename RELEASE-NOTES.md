# HOTD4 Local Builder v1.2.1

This Windows installer hotfix uses the official self-extracting MSYS2 archive. Setup can bootstrap the compiler on Windows systems whose built-in tar cannot unpack XZ archives. Setup also prints a message while it waits for the optional OpenXR choice. The clean desktop install and a cached reinstall passed on Windows 10 Enterprise LTSC 2021 x64.

This stable Windows release improves reload feedback, route selection and raw mouse controls.

- The reload voice plays once as soon as the magazine runs empty during play. The red RELOAD warning stays visible while the gun needs a reload and gameplay allows it.
- Route selection panels are centered at widescreen resolutions. Each preview fits its frame, and the on-screen choices align with their hit targets.
- **Raw Mouse Speed** (0.50x to 8.00x) and **Raw Mouse Smoothing** (Off, Low, High) are available under **Settings > Input & Anti-Aliasing** in **Mouse (Raw Relative)** mode. Changes made from the pause menu apply immediately.
- Includes the v1.1.0 performance improvements and the **Play HOTD4 (Performance Log).cmd** launcher for recording frame times as a CSV.

Download and extract **HOTD4-Local-Builder-v1.2.1.zip**, then run **Setup.cmd**. To update an existing installation, run `Setup.cmd -InstallDir "C:\path\to\HOTD4-PC"` with your existing installation path and select the same supported, extracted arcade dump. Setup rebuilds the game locally and preserves your settings and trophies. The release ZIP contains no game assets or executable. Windows desktop is the default build, with experimental OpenXR available as an optional build.

## Recording the Chapter 1 elevator slowdown

1. Run **Play HOTD4 (Performance Log).cmd** from your installed game folder.
2. Use the settings you want to test. For the reported elevator slowdown, select 1080p (Desktop resolution on a 1080p display) and turn MSAA **Off** under **Settings > Input & Anti-Aliasing**.
3. Choose **Chapter Select > Chapter 1** and play through the elevator fight. If FPS drops, finish the fight or stop just afterwards, then use **Pause > Main Menu** and **Quit** so the game writes the recording.
4. Open **Performance Logs** in your installation folder and share the newest CSV. The launcher opens the folder when it closes. Mention where the slowdown started, your CPU and GPU, graphics settings, and whether you were playing in fullscreen. GPU utilization during the dip is useful if you already have it.

Each game run writes a separate CSV with frame numbers and `frame_ms`, the time in milliseconds between completed presents. The file records timing data only. Long pauses appear as gaps in the timeline.
