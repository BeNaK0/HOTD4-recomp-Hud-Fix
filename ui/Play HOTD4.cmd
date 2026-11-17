@echo off
setlocal
set "HOTD4_4K_SCRIPT=%~dpnx0"
set "HOTD4_4K_MODE=%~1"
powershell.exe -NoProfile -STA -Command "$parts = (Get-Content -Raw -Encoding UTF8 -LiteralPath $env:HOTD4_4K_SCRIPT) -split '(?m)^:PowerShell\r?$', 2; & ([scriptblock]::Create($parts[1]))"
set "HOTD4_EXIT=%ERRORLEVEL%"
if not "%HOTD4_EXIT%"=="0" pause
exit /b %HOTD4_EXIT%

:PowerShell
$ErrorActionPreference = 'Stop'
$gameRoot = Split-Path -Parent $env:HOTD4_4K_SCRIPT
$recompDir = Join-Path $gameRoot 'HOTD4_Recomp'
$diskDir = [IO.File]::ReadAllText((Join-Path $gameRoot 'dump-path.txt')).Trim()
$elfDir = Join-Path $diskDir 'elf'
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

function Invoke-Hotd4 {
    param([string] $Mode, [string] $Hud, [int] $Width, [int] $Height, [bool] $Windowed)

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
    $env:LINDBERGH_FULLSCREEN = if ($windowed) { '0' } else { $defaultFullscreen }
    $env:LINDBERGH_NVRAM = $defaultNvram
    $env:LINDBERGH_WIDTH = [string]$width
    $env:LINDBERGH_HEIGHT = [string]$height
    $env:LINDBERGH_WINDOW = "${width}x${height}"

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
                & $desktopExe $tempElf | Out-Host
                $exitCode = $LASTEXITCODE
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

try {
    $env:Path = "$recompDir;$env:Path"
    . (Join-Path $recompDir 'hotd4-controls.ps1')
    $env:TEA_DIR = $diskDir
    $env:LINDBERGH_DIPSW = 'e0'
    $env:LINDBERGH_HOTD4_PACE_CUTSCENES = '1'
    $mode = $env:HOTD4_4K_MODE
    if (!$mode -and ![Console]::IsInputRedirected) {
        $desktopWidth, $desktopHeight = Get-Hotd4DesktopSize
        . (Join-Path $recompDir 'hotd4-startmenu.ps1')
        do {
            $selection = Show-Hotd4StartMenu -RecompDir $recompDir -DesktopWidth $desktopWidth -DesktopHeight $desktopHeight
            if (!$selection) { exit 0 }
            $width = $desktopWidth
            $height = $desktopHeight
            $windowed = $selection.Resolution -ne 'auto'
            if ($windowed) {
                $width, $height = $selection.Resolution.Split('x')
            }
            $exitCode = Invoke-Hotd4 -Mode $selection.Mode -Hud $selection.Hud -Width $width -Height $height -Windowed $windowed
        } while ($exitCode -eq 0)
    } else {
        $hud = '0'
        if ([IO.File]::Exists($hudFile)) {
            $savedHud = [IO.File]::ReadAllText($hudFile).Trim()
            if ($savedHud -match '^(0|75|100|125)$') { $hud = $savedHud }
        }
        if (!$mode) { $mode = '0' }
        if ($env:LINDBERGH_WINDOW -match '^([1-9][0-9]*)x([1-9][0-9]*)$') {
            $width = [int]$Matches[1]
            $height = [int]$Matches[2]
        } else {
            $width, $height = Get-Hotd4DesktopSize
        }
        $exitCode = Invoke-Hotd4 -Mode $mode -Hud $hud -Width $width -Height $height -Windowed $false
    }
    exit $exitCode
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
