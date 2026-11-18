[CmdletBinding()]
param([string]$DumpPath,[string]$InstallDir,[string]$ToolchainPath,[int]$Jobs=4,[switch]$ValidateOnly,[switch]$NoDownload,[switch]$OpenXR)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
function Get-Sha256([string]$Path) {
    $stream=[IO.File]::OpenRead($Path);$sha=[Security.Cryptography.SHA256]::Create()
    try{return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}finally{$stream.Dispose();$sha.Dispose()}
}
function Invoke-Checked([string]$Exe,[string[]]$Arguments) {
    & $Exe @Arguments
    if($LASTEXITCODE -ne 0){throw "Command failed ($LASTEXITCODE): $Exe"}
}
try {
    $manifest=Get-Content -LiteralPath "$PSScriptRoot\package-manifest.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach($file in $manifest.files){
        $path=Join-Path $PSScriptRoot $file.path
        if(!(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Sha256 $path) -ne $file.sha256){throw "Package integrity check failed: $($file.path). Extract a fresh copy."}
    }
    $interactive = !$DumpPath
    if($interactive){
        Add-Type -AssemblyName System.Windows.Forms
        $picker=New-Object Windows.Forms.FolderBrowserDialog
        $picker.Description='Select your extracted normal HOTD4 arcade dump (disk0 or its parent folder)'
        if($picker.ShowDialog() -ne [Windows.Forms.DialogResult]::OK){Write-Host 'Setup cancelled.';exit 0}
        $DumpPath=$picker.SelectedPath;$picker.Dispose()
    }
    $DumpPath=(Resolve-Path -LiteralPath $DumpPath).Path
    $candidates=@($DumpPath,(Join-Path $DumpPath 'disk0'),(Join-Path $DumpPath 'The House of the Dead 4\disk0'))
    if((Split-Path $DumpPath -Leaf) -eq 'elf'){$candidates+=Split-Path $DumpPath -Parent}
    $dump=$null
    foreach($candidate in $candidates){if(Test-Path -LiteralPath (Join-Path $candidate 'elf\hod4M.elf') -PathType Leaf){$dump=$candidate;break}}
    if(!$dump){throw 'Cannot find elf\hod4M.elf. Select an extracted arcade dump. Encrypted disc images are not supported.'}
    if((Get-Sha256 (Join-Path $dump 'elf\hod4M.elf')) -ne '72FDD45830ACD9317EC1E4F97DE35A270C94746068FDAF827381C91BB47AA296'){throw 'Unsupported arcade revision. Special and patched executables are not supported.'}
    foreach($part in 'fs','drv'){
        $dir=Join-Path $dump $part
        if(!(Test-Path -LiteralPath $dir -PathType Container) -or !(Get-ChildItem -LiteralPath $dir -File -Recurse | Select-Object -First 1)){throw "Incomplete dump: missing $part files."}
    }
    Write-Host 'Verified: The House of the Dead 4 (normal arcade version).'
    if($ValidateOnly){Write-Host 'Package and dump validation passed. Nothing was installed.';exit 0}
    if($interactive -and !$OpenXR){
        Write-Host "Waiting for the OpenXR choice in the HOTD4 Setup dialog. Use Alt+Tab if it is behind this window."
        $choice = [Windows.Forms.MessageBox]::Show(
            'Build the optional OpenXR version alongside the desktop game? You will need a compatible PC VR headset and an active OpenXR runtime to play it.',
            'HOTD4 Setup', 'YesNo', 'Question', 'Button2')
        $OpenXR = $choice -eq [Windows.Forms.DialogResult]::Yes
    }
    if(!$InstallDir){$InstallDir=Join-Path $PSScriptRoot 'HOTD4-PC'}
    if(!$ToolchainPath){$ToolchainPath=Join-Path $env:LOCALAPPDATA 'HOTD4-Builder\msys64'}
    $ToolchainPath=[IO.Path]::GetFullPath($ToolchainPath)
    $bash=Join-Path $ToolchainPath 'usr\bin\bash.exe'
    if(!(Test-Path -LiteralPath $bash)){
        if($NoDownload){throw 'Build tools are missing. Run without -NoDownload to install them automatically.'}
        $parent=Split-Path $ToolchainPath -Parent
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        $name='msys2-base-x86_64-20260927.sfx.exe'
        $archive=Join-Path $parent $name
        $expected='AD336CCCFDA47758B5E15CDA993FBBA421115CB0B126697DAEF1EE4DFE37209F'
        if (!(Test-Path -LiteralPath $archive) -or (Get-Sha256 $archive) -ne $expected) {
            Write-Host 'Downloading the isolated MSYS2 build tools...'
            Invoke-WebRequest -UseBasicParsing -Uri "https://repo.msys2.org/distrib/x86_64/$name" -OutFile "$archive.partial"
            if ((Get-Sha256 "$archive.partial") -ne $expected) {
                throw 'Build-tools download failed its SHA-256 check.'
            }
            Move-Item -LiteralPath "$archive.partial" -Destination $archive -Force
        }

        Write-Host 'Extracting the isolated MSYS2 build tools...'
        $stage=Join-Path $parent ('.hotd4-msys2-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $stage | Out-Null
        $extractor=Start-Process -FilePath $archive -ArgumentList @('-y', ('-o"{0}"' -f $stage)) -WindowStyle Hidden -PassThru -Wait
        $extracted=Join-Path $stage 'msys64'
        if ($extractor.ExitCode -ne 0 -or !(Test-Path -LiteralPath (Join-Path $extracted 'usr\bin\bash.exe') -PathType Leaf)) {
            throw "MSYS2 extraction failed (exit $($extractor.ExitCode)). Extraction folder: $stage"
        }

        # A previous failed extraction may have left this directory without bash.
        # Keep that directory recoverable and install the complete verified tree.
        $backup=$null
        if (Test-Path -LiteralPath $ToolchainPath) {
            $backup=Join-Path $parent ('.hotd4-msys2-incomplete-' + [Guid]::NewGuid().ToString('N'))
            [IO.Directory]::Move((Resolve-Path -LiteralPath $ToolchainPath).Path, $backup)
        }
        try {
            [IO.Directory]::Move((Resolve-Path -LiteralPath $extracted).Path, $ToolchainPath)
        } catch {
            if ($backup) { [IO.Directory]::Move($backup, $ToolchainPath) }
            throw
        }
        [IO.Directory]::Delete($stage)
        if ($backup) { Write-Host "Previous incomplete toolchain preserved at $backup" }
    }
    $env:MSYSTEM='MINGW64';$env:CHERE_INVOKING='1';$env:MSYS2_PATH_TYPE='minimal'
    $ready=Join-Path $ToolchainPath '.hotd4-tools-ready-v1'
    if(!(Test-Path -LiteralPath $ready)){
        if($NoDownload){throw 'Build dependencies are not installed. Run without -NoDownload.'}
        Write-Host 'Updating build tools and installing compiler, Python, SDL2 and OpenAL...'
        # A core MSYS2 update can close this first shell; always reopen and
        # require the second complete update and dependency install to succeed.
        & $bash '--login' '-c' 'pacman -Syu --noconfirm'
        Invoke-Checked $bash @('--login','-c','pacman -Syu --noconfirm && pacman -S --needed --noconfirm mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja mingw-w64-x86_64-python mingw-w64-x86_64-python-capstone mingw-w64-x86_64-python-pyelftools mingw-w64-x86_64-SDL2 mingw-w64-x86_64-glew mingw-w64-x86_64-openal mingw-w64-x86_64-zlib')
        Set-Content -LiteralPath $ready -Value '1'
    }
    if($OpenXR -and !(Test-Path -LiteralPath (Join-Path $ToolchainPath 'mingw64\lib\cmake\openxr\OpenXRConfig.cmake'))){
        if($NoDownload){throw 'OpenXR SDK is missing. Run without -NoDownload to install it automatically.'}
        Write-Host 'Installing the OpenXR build dependency...'
        Invoke-Checked $bash @('--login','-c','pacman -S --needed --noconfirm mingw-w64-x86_64-openxr-sdk')
    }
    $python=Join-Path $ToolchainPath 'mingw64\bin\python.exe'
    Write-Host 'Generating and compiling HOTD4 locally. This can take several minutes...'
    $buildArgs = @((Join-Path $PSScriptRoot 'tools\build.py'),'--dump',$dump,'--output',$InstallDir,'--toolchain',$ToolchainPath,'--jobs',[string]$Jobs)
    if($OpenXR){$buildArgs += '--openxr'}
    Invoke-Checked $python $buildArgs
    $installedRoot=[IO.Path]::GetFullPath($InstallDir)
    try {
        Invoke-Checked $python @((Join-Path $PSScriptRoot 'tools\menu_background.py'),'--app',(Join-Path $installedRoot 'HOTD4_Recomp'),'--dump',(Join-Path $installedRoot 'game\disk0'))
    } catch {
        Write-Warning 'The game was installed, but the optional menu background could not be rendered. See HOTD4_Recomp\menu-background.log. Run Setup again to retry; the plain menu remains available.'
    }
    if($OpenXR){Write-Host "VR launcher: $(Join-Path $InstallDir 'Play HOTD4 (VR OpenXR).cmd')"}
    Write-Host "Ready. Open: $(Join-Path $InstallDir 'Play HOTD4.cmd')"
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
