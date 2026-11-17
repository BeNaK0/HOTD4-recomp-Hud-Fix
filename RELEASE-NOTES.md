# HOTD4 Windows Performance Test

This preview focuses on the Windows desktop build. It includes optimized lifted gameplay code, a selectable 960 × 540 performance resolution, and bit-exact SSE2 operations for the video decoder. The decoder reduced CPU time per frame from 6.01 to 4.81 ms in one 4K cutscene test. The Chapter 1 elevator slowdown reported at 1080p with MSAA off is under investigation.

Download the **HOTD4 Local Builder ZIP**, extract it, and run **Setup.cmd** with your own supported, extracted HOTD4 arcade dump. Setup builds the game locally. The ZIP includes the installer and source code. It contains no arcade game data, Sega artwork or compiled game executable.

## Recording the Chapter 1 elevator slowdown

1. Run **Play HOTD4 (Performance Log).cmd** from your installed game folder.
2. Use the settings you want to test. For the reported elevator slowdown, select 1080p (Desktop resolution on a 1080p display) and turn MSAA **Off** under **Settings > Input & Anti-Aliasing**.
3. Choose **Chapter Select > Chapter 1** and play through the elevator fight. If FPS drops, finish the fight or stop just afterwards, then use **Pause > Main Menu** and **Quit** so the game writes the recording.
4. Open **Performance Logs** in your installation folder and share the newest CSV. The launcher opens the folder when it closes. Mention where the slowdown started, your CPU and GPU, graphics settings, and whether you were playing in fullscreen. GPU utilization during the dip is useful if you already have it.

Each game run writes a separate CSV with frame numbers and `frame_ms`, the time in milliseconds between completed presents. The file records timing data only. Long pauses appear as gaps in the timeline.
