# HOTD4 Local Builder v1.1.0

This Windows release improves desktop performance and adds a launcher that records frame times for troubleshooting.

- Optimized recompiled gameplay code in the Windows desktop build. The video decoder now uses bit-exact SSE2 operations. In one 4K cutscene test, game-thread CPU time fell from 6.01 to 4.81 ms per frame.
- New **960 × 540** windowed option for lower GPU load, alongside existing resolutions up to 4K and selectable MSAA.
- **Play HOTD4 (Performance Log).cmd** saves a separate CSV per game session, including frame times in milliseconds.
- Includes Chapter Select, the in-game pause and trophies menus, customizable keyboard and mouse bindings, HUD and crosshair settings, and Sinden border and Raw Input options.
- Optional OpenXR PC VR remains experimental. The Windows desktop build is the default.

Download **HOTD4-Local-Builder-v1.1.0.zip**, extract it, and run **Setup.cmd**. Select your own supported, extracted arcade dump. After setup finishes, run **HOTD4-PC/Play HOTD4.cmd**. To update, run the new setup with the same dump and installation folder. Setup builds the executable and renders the menu background locally. The ZIP contains the installer, source code and project artwork. Game files, lifted game code and prebuilt game executables stay on the user's PC.

## Recording the Chapter 1 elevator slowdown

1. Run **Play HOTD4 (Performance Log).cmd** from your installed game folder.
2. Use the settings you want to test. For the reported elevator slowdown, select 1080p (Desktop resolution on a 1080p display) and turn MSAA **Off** under **Settings > Input & Anti-Aliasing**.
3. Choose **Chapter Select > Chapter 1** and play through the elevator fight. If FPS drops, finish the fight or stop just afterwards, then use **Pause > Main Menu** and **Quit** so the game writes the recording.
4. Open **Performance Logs** in your installation folder and share the newest CSV. The launcher opens the folder when it closes. Mention where the slowdown started, your CPU and GPU, graphics settings, and whether you were playing in fullscreen. GPU utilization during the dip is useful if you already have it.

Each game run writes a separate CSV with frame numbers and `frame_ms`, the time in milliseconds between completed presents. The file records timing data only. Long pauses appear as gaps in the timeline.
