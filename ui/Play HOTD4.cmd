@echo off
setlocal
set "HOTD4_4K_SCRIPT=%~dpnx0"
set "HOTD4_4K_MODE=%~1"
set "HOTD4_NO_LAUNCHER=0"
set "HOTD4_INITIAL_PAGE=MainPage"
if /I "%~1"=="--settings" set "HOTD4_INITIAL_PAGE=OptionsPage"
if /I "%~1"=="--settings" set "HOTD4_4K_MODE="
if /I "%~1"=="--no-launcher" set "HOTD4_NO_LAUNCHER=1"
if /I "%~1"=="--skip-launcher" set "HOTD4_NO_LAUNCHER=1"
if "%HOTD4_NO_LAUNCHER%"=="1" set "HOTD4_4K_MODE=0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -Command "$parts = (Get-Content -Raw -Encoding UTF8 -LiteralPath $env:HOTD4_4K_SCRIPT) -split '(?m)^:PowerShell\r?$', 2; & ([scriptblock]::Create($parts[1]))"
set "HOTD4_EXIT=%ERRORLEVEL%"
if not "%HOTD4_EXIT%"=="0" pause
exit /b %HOTD4_EXIT%

:PowerShell
$ErrorActionPreference = 'Stop'
$gameRoot = Split-Path -Parent $env:HOTD4_4K_SCRIPT
$recompDir = Join-Path $gameRoot 'HOTD4_Recomp'
$diskDir = [IO.File]::ReadAllText((Join-Path $gameRoot 'dump-path.txt')).Trim()
$elfDir = Join-Path $diskDir 'elf'
. (Join-Path $recompDir 'hotd4-native-crosshair.ps1')
[void](Initialize-Hotd4NativeCrosshair $recompDir $diskDir)
$desktopExe = Join-Path $recompDir 'hotd4-desktop.exe'
$originalElf = Join-Path $elfDir 'hod4M.elf'
$expectedHash = '72FDD45830ACD9317EC1E4F97DE35A270C94746068FDAF827381C91BB47AA296'
$defaultNvram = Join-Path $recompDir 'lindbergh_nvram.bin'
$defaultFullscreen = $env:LINDBERGH_FULLSCREEN
$hudFile = Join-Path $recompDir 'hud-profile.txt'
$env:HOTD4_SETTINGS_DIR = $recompDir
$env:HOTD4_SINDEN_PROFILE = Join-Path $recompDir 'sinden-profile.txt'
$env:HOTD4_CROSSHAIR_PROFILE = Join-Path $recompDir 'crosshair-profile.txt'
$env:HOTD4_CROSSHAIR_SIZE_PROFILE = Join-Path $recompDir 'crosshair-size.txt'
$env:HOTD4_CROSSHAIR_COLOR_PROFILE = Join-Path $recompDir 'crosshair-color.txt'

function Get-Hotd4DesktopSize {
    Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public static class Hotd4Display {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")]
    public static extern int GetSystemMetrics(int index);
}
"@
    [void][Hotd4Display]::SetProcessDPIAware()
    $width = [Hotd4Display]::GetSystemMetrics(0)
    $height = [Hotd4Display]::GetSystemMetrics(1)
    if ($width -le 0 -or $height -le 0) { throw 'Could not detect the desktop resolution.' }
    return @($width, $height)
}

function Invoke-Hotd4OperatorMenu {
    $exe=Join-Path $recompDir 'hotd4-testmenu.exe'
    $elf=Join-Path $elfDir 'hod4testM.elf'
    if (!(Test-Path -LiteralPath $exe) -or !(Test-Path -LiteralPath $elf)) {
        throw 'Arcade Test Menu is missing. Re-run Setup with the complete Rev A dump including hod4testM.elf or hod4testM_HD.elf.'
    }
    $saved=@{}
    $override=@{LINDBERGH_WIDTH='640';LINDBERGH_HEIGHT='480';LINDBERGH_DIPSW='00';LINDBERGH_NVRAM=$defaultNvram;HOTD4_OPERATOR_ASSETS=(Join-Path $recompDir 'operator-assets');HOTD4_PAUSE_MENU='0';LINDBERGH_FRAME_TIMINGS=$null}
    try {
        foreach($key in $override.Keys) {
            $saved[$key]=[Environment]::GetEnvironmentVariable($key,'Process')
            [Environment]::SetEnvironmentVariable($key,$override[$key],'Process')
        }
        Write-Host 'Arcade Test Menu: Service moves the selection; Test changes or confirms. Select EXIT to return to the game.'
        $start=[Diagnostics.ProcessStartInfo]::new()
        $start.FileName=$exe;$start.Arguments='"'+$elf+'"';$start.WorkingDirectory=$elfDir
        $start.UseShellExecute=$false;$start.CreateNoWindow=$true
        $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
        $menu=[Diagnostics.Process]::Start($start)
        try {
            $menu.BeginOutputReadLine();$errors=$menu.StandardError.ReadToEnd();$menu.WaitForExit()
            if ($menu.ExitCode -ne 0) {throw ("Arcade Test Menu exited with code {0}.`n{1}" -f $menu.ExitCode,$errors)}
        } finally {$menu.Dispose()}
    } finally {
        foreach($key in $saved.Keys) {[Environment]::SetEnvironmentVariable($key,$saved[$key],'Process')}
    }
}

function Invoke-Hotd4 {
    param([string] $Mode, [string] $Hud, [int] $Width, [int] $Height, [bool] $Windowed, [int] $OutputWidth = $Width, [int] $OutputHeight = $Height, [switch] $Borderless)

    if ($mode -notmatch '^[0-6LT]$') { throw 'Choose 0 for Arcade, 1–6 for a chapter, L for the lighting test, or T for the HD texture test.' }
    $lighting = $mode -eq 'L'
    $hdTextures = $mode -eq 'T'
    if ($lighting -or $hdTextures) { $mode = '1' }
    $env:HOTD4_HD_TEXTURE_DIR = if ($hdTextures) { Join-Path $recompDir 'hotd4-hd-textures' } else { $null }
    if ($hdTextures -and ![IO.Directory]::Exists($env:HOTD4_HD_TEXTURE_DIR)) {
        throw 'The HD texture pack folder is missing.'
    }
    $practice = $mode -ne '0'
    $tempElf = $null
    $practiceNvram = $null
    $exitCode = 1
    $env:HOTD4_EXPERIMENT_LIGHTING = if ($lighting) { '1' } else { $null }
    $env:HOTD4_PRACTICE_CHAPTER = if ($practice) { $mode } else { $null }
    $env:HOTD4_HUD_SCALE = if ($hud -eq '0') { $null } else { $hud }
    $env:HOTD4_PAUSE_MENU = '1'
    $env:HOTD4_HUD_PROFILE = $hudFile
    $env:LINDBERGH_FULLSCREEN = if ($Windowed) { '0' } elseif ($Borderless) { '1' } else { $defaultFullscreen }
    $env:LINDBERGH_NVRAM = $defaultNvram
    $width, $height = Get-Hotd4RenderSize $Width $Height (Get-Hotd4AspectRatio $recompDir)
    $env:LINDBERGH_WIDTH = [string]$width
    $env:LINDBERGH_HEIGHT = [string]$height
    $env:LINDBERGH_WINDOW = '{0}x{1}' -f $OutputWidth, $OutputHeight

    try {
        if (-not (Test-Path -LiteralPath $desktopExe -PathType Leaf)) {
            throw "Could not find $desktopExe"
        }
        $gameImage = [IO.File]::ReadAllBytes($originalElf)
        $sha256 = [Security.Cryptography.SHA256]::Create()
        try {
            $sourceHash = [BitConverter]::ToString($sha256.ComputeHash($gameImage)).Replace('-', '')
        } finally {
            $sha256.Dispose()
        }
        if ($sourceHash -ne $expectedHash) {
            throw 'This version of hod4M.elf is incompatible with the 4K patch.'
        }

        Write-Host "HOTD4 is rendering at ${width}x${height}."
        $wideMode = 20
        $resolutionTable = 0x3FF320
        $wideModeOffset = $resolutionTable + $wideMode * 24
        # This HOTD4 build stores render, window and CRT sizes in the same row.
        for ($field = 0; $field -lt 24; $field += 8) {
            [BitConverter]::GetBytes([int]$width).CopyTo($gameImage, $wideModeOffset + $field)
            [BitConverter]::GetBytes([int]$height).CopyTo($gameImage, $wideModeOffset + $field + 4)
        }
        # Set the initial mode before the engine clamps the off-screen buffer width.
        [BitConverter]::GetBytes($wideMode).CopyTo($gameImage, 0x480DB8)
        [BitConverter]::GetBytes([int]$width).CopyTo($gameImage, 0x480DBC)

        $tempElf = Join-Path ([IO.Path]::GetTempPath()) ('hotd4-4k-' + [Guid]::NewGuid().ToString('N') + '.elf')
        [IO.File]::WriteAllBytes($tempElf, $gameImage)
        if ($practice) {
            $savedNvram = $defaultNvram
            if (!$savedNvram) { $savedNvram = 'lindbergh_nvram.bin' }
            if (![IO.Path]::IsPathRooted($savedNvram)) {
                $savedNvram = Join-Path $elfDir $savedNvram
            }
            $practiceNvram = "$tempElf.nvram"
            $env:LINDBERGH_NVRAM = $practiceNvram
            $keys=Read-Hotd4Controls $recompDir;Write-Host ("Practice mode, Chapter $mode. "+(Get-Hotd4BindingName $keys.Values['restart'])+' restarts; '+(Get-Hotd4BindingName $keys.Values['pause'])+' pauses.')
            if ($lighting) { Write-Host 'F7 switches between original and experimental lighting.' }
        }

        Push-Location -LiteralPath $elfDir
        try {
            do {
                if ($practice) {
                    [IO.File]::Delete($practiceNvram)
                    if ([IO.File]::Exists($savedNvram)) {
                        [IO.File]::Copy($savedNvram, $practiceNvram, $false)
                    }
                }
                $previousTimingPath = $env:LINDBERGH_FRAME_TIMINGS
                $timingPath = $null
                try {
                    if ($env:HOTD4_PERFORMANCE_LOG -eq '1') {
                        $logDir = Join-Path $gameRoot 'Performance Logs'
                        [void][IO.Directory]::CreateDirectory($logDir)
                        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
                        $suffix = [Guid]::NewGuid().ToString('N').Substring(0,8)
                        $timingPath = Join-Path $logDir "HOTD4-$stamp-${width}x${height}-$suffix.csv"
                        $env:LINDBERGH_FRAME_TIMINGS = $timingPath
                        Write-Host "Recording frame times. Exit the game normally to save: $timingPath"
                    }
                    if ($env:HOTD4_GUI_LAUNCH -eq '1') {
                        $gameStart = [Diagnostics.ProcessStartInfo]::new()
                        $gameStart.FileName = $desktopExe
                        $gameStart.Arguments = '"' + $tempElf + '"'
                        $gameStart.WorkingDirectory = $elfDir
                        $gameStart.UseShellExecute = $false
                        $gameStart.CreateNoWindow = $true
                        $gameStart.RedirectStandardOutput = $true
                        $gameStart.RedirectStandardError = $true
                        $game = [Diagnostics.Process]::Start($gameStart)
                        try {
                            $game.BeginOutputReadLine()
                            $gameErrors = $game.StandardError.ReadToEnd()
                            $game.WaitForExit()
                            $exitCode = $game.ExitCode
                            if ($exitCode -notin 0,74,75 -and $gameErrors) { [Console]::Error.WriteLine($gameErrors.TrimEnd()) }
                        } finally {
                            $game.Dispose()
                        }
                    } else {
                        & $desktopExe $tempElf | Out-Host
                        $exitCode = $LASTEXITCODE
                    }
                } finally {
                    $env:LINDBERGH_FRAME_TIMINGS = $previousTimingPath
                }
                if ($timingPath) {
                    if ([IO.File]::Exists($timingPath)) {
                        Write-Host "Saved performance log: $timingPath"
                    } else {
                        Write-Warning 'The game did not save a performance log.'
                    }
                }
                if ($exitCode -eq 75) {
                    Invoke-Hotd4OperatorMenu
                    $exitCode=74
                }
                if ($exitCode -eq 74 -and [IO.File]::Exists($hudFile)) {
                    $savedHud = [IO.File]::ReadAllText($hudFile).Trim()
                    if ($savedHud -match '^(0|75|100|125)$') {
                        $env:HOTD4_HUD_SCALE = if ($savedHud -eq '0') { $null } else { $savedHud }
                    }
                }
            } while ($exitCode -eq 74)
            if ($exitCode -ne 0) {
                [Console]::Error.WriteLine("HOTD4 exited with code $exitCode.")
            }
        } finally {
            Pop-Location
        }
    } finally {
        $env:LINDBERGH_NVRAM = $defaultNvram
        if ($practiceNvram) { [IO.File]::Delete($practiceNvram) }
        if ($tempElf) { [IO.File]::Delete($tempElf) }
    }
    return $exitCode
}

function Invoke-Hotd4Selection {
    param($Selection, [int]$DesktopWidth, [int]$DesktopHeight)
    $width, $height = $DesktopWidth, $DesktopHeight
    $windowed = $Selection.DisplayMode -eq 'Windowed'
    if ($Selection.Resolution -ne 'auto') { $width, $height = $Selection.Resolution.Split('x') }
    $outputWidth, $outputHeight = $width, $height
    if ($windowed) {
        $scale = [Math]::Min(1.0, [Math]::Min(($DesktopWidth - 32) / $width, ($DesktopHeight - 72) / $height))
        $outputWidth = [int][Math]::Floor($width * $scale)
        $outputHeight = [int][Math]::Floor($height * $scale)
    }
    return (Invoke-Hotd4 -Mode $Selection.Mode -Hud $Selection.Hud -Width $width -Height $height -Windowed $windowed -OutputWidth $outputWidth -OutputHeight $outputHeight -Borderless:(!$windowed))
}

try {
    $env:Path = "$recompDir;$env:Path"
    . (Join-Path $recompDir 'hotd4-controls.ps1')
    . (Join-Path $recompDir 'hotd4-display.ps1')
    $env:TEA_DIR = $diskDir
    $env:LINDBERGH_DIPSW = 'e0'
    $env:LINDBERGH_HOTD4_PACE_CUTSCENES = '1'
    $mode = $env:HOTD4_4K_MODE
    if (!$mode -and ($env:HOTD4_GUI_LAUNCH -eq '1' -or ![Console]::IsInputRedirected)) {
        $desktopWidth, $desktopHeight = Get-Hotd4DesktopSize
        . (Join-Path $recompDir 'hotd4-startmenu.ps1')
        $initialPage = if ($env:HOTD4_INITIAL_PAGE -eq 'OptionsPage') { 'OptionsPage' } else { 'MainPage' }
        do {
            $selection = Show-Hotd4StartMenu -RecompDir $recompDir -DesktopWidth $desktopWidth -DesktopHeight $desktopHeight -InitialPage $initialPage
            $initialPage = 'MainPage'
            if (!$selection) { exit 0 }
            $exitCode = Invoke-Hotd4Selection $selection $desktopWidth $desktopHeight
        } while ($exitCode -eq 0)
    } else {
        $hud = '0'
        if ([IO.File]::Exists($hudFile)) {
            $savedHud = [IO.File]::ReadAllText($hudFile).Trim()
            if ($savedHud -match '^(0|75|100|125)$') { $hud = $savedHud }
        }
        if (!$mode) { $mode = '0' }
        if ($env:HOTD4_NO_LAUNCHER -eq '1') {
            $desktopWidth, $desktopHeight = Get-Hotd4DesktopSize
            $resolution = 'auto'; $displayMode = 'Borderless'
            $resolutionFile = Join-Path $recompDir 'display-profile.txt'
            if ([IO.File]::Exists($resolutionFile)) {
                $saved = ConvertTo-Hotd4Resolution ([IO.File]::ReadAllText($resolutionFile).Trim())
                if ($saved) { $resolution = $saved }
                if ($resolution -ne 'auto') { $displayMode = 'Windowed' }
            }
            $displayFile = Join-Path $recompDir 'display-mode.txt'
            if ([IO.File]::Exists($displayFile)) {
                $saved = [IO.File]::ReadAllText($displayFile).Trim()
                if ($saved -in 'Borderless','Windowed') { $displayMode = $saved }
            }
            $selection = @{Mode=$mode;Hud=$hud;Resolution=$resolution;DisplayMode=$displayMode}
            $exitCode = Invoke-Hotd4Selection $selection $desktopWidth $desktopHeight
        } elseif ($env:LINDBERGH_WINDOW -match '^([1-9][0-9]*)x([1-9][0-9]*)$') {
            $width = [int]$Matches[1]
            $height = [int]$Matches[2]
            $exitCode = Invoke-Hotd4 -Mode $mode -Hud $hud -Width $width -Height $height -Windowed $false
        } else {
            $width, $height = Get-Hotd4DesktopSize
            $exitCode = Invoke-Hotd4 -Mode $mode -Hud $hud -Width $width -Height $height -Windowed $false
        }
    }
    exit $exitCode
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
