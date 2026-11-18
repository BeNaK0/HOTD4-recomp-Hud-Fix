# HOTD4 Local Builder v1.2.1

This Windows installer hotfix uses the official self-extracting MSYS2 archive. Setup can bootstrap the compiler on Windows systems whose built-in tar cannot unpack XZ archives. Setup also prints a message while it waits for the optional OpenXR choice. The clean desktop install and a cached reinstall passed on Windows 10 Enterprise LTSC 2021 x64.

## Supported arcade dump

Setup requires your own complete, extracted **The House of the Dead 4 (Export), Rev A (DVP-0003A)** Sega Lindbergh dump with the specific **HD variant** at `disk0/elf/hod4M.elf`. The Rev A label identifies the base revision. Setup checks the exact ELF bytes against this SHA-256:

`72FDD45830ACD9317EC1E4F97DE35A270C94746068FDAF827381C91BB47AA296`

Keep `disk0/elf/`, `disk0/fs/` and `disk0/drv/` from the same extracted dump. Select `disk0`, its `elf` directory, or the parent folder that contains `disk0`. Setup rejects a different ELF hash, including other variants of the same revision. It expects extracted files on disk and cannot use a compressed archive or encrypted disc image directly.

## System requirements

- **Operating system:** Windows 10 or Windows 11 on an x64 (Intel or AMD) PC, with Windows PowerShell 5.1 available. Clean setup was verified on Windows 10 Enterprise LTSC 2021 x64 (build 19044.1288) and Windows 11 x64.
- **Disk and permissions:** Allow around **10 GB of free space** beyond your existing dump for the toolchain, build files and installed copy of the game. Use writable folders for the extracted builder and game installation. The toolchain uses `%LOCALAPPDATA%\HOTD4-Builder\msys64` by default, so allow space there as well if the builder is on another drive. Setup can run under a regular user account.
- **Internet:** Required for the first setup to download MSYS2 and its build dependencies. Setup installs its own compiler, Python and runtime dependencies. A separate xz tool is unnecessary.
- **Graphics:** Desktop gameplay and the optional menu background use a GPU driver with desktop OpenGL compatibility support. The desktop build requests an OpenGL 2.1 context with the extensions it uses for rendering. The installer can compile on a VM without working 3D graphics. No minimum CPU, RAM or GPU for gameplay has been benchmarked.
- **Optional OpenXR VR:** A compatible PC VR headset, tracked controllers, an active OpenXR runtime with OpenGL support, and a driver that can create an OpenGL 4.3 compatibility context.

## Included gameplay improvements

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
