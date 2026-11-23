$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
. (Join-Path $repo 'ui/hotd-update.ps1')

function Write-FixtureFile([string]$Path,[string]$Text) {
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path))
    [IO.File]::WriteAllText($Path,$Text)
}

$base=Join-Path ([IO.Path]::GetTempPath()) ('HOTD dump update '+[guid]::NewGuid().ToString('N'))
$root=Join-Path $base "Old HOTD4 & O'Brien"
$game=Get-HotdUpdateGame Normal
$app=Join-Path $root $game.App
$dump=Join-Path $root 'The House of the Dead 4\disk0'
$record=Join-Path $root $game.DumpRecord
Write-FixtureFile (Join-Path $dump $game.Elf) 'old dump'
Write-FixtureFile (Join-Path $dump 'fs/keep.txt') 'user game data'
Write-FixtureFile (Join-Path $app $game.Exe) 'old build'
Write-FixtureFile (Join-Path $app 'hotd-update-version.txt') 'v1.0.0'
Write-FixtureFile (Join-Path $app 'display-mode.txt') 'Windowed'
if ((Find-HotdUpdateDump $root $game) -ne $dump) { throw 'Legacy installation without a dump record was not understood.' }

$external=Join-Path $base 'External archive'
Write-FixtureFile (Join-Path $external $game.Elf) 'other dump'
Write-FixtureFile (Join-Path $external 'fs/keep.txt') 'other game data'
Write-FixtureFile $record $external
if ((Find-HotdUpdateDump $root $game) -ne $external) { throw 'A configured dump should take precedence.' }
Write-FixtureFile $record (Join-Path $base 'Moved archive')
if ((Find-HotdUpdateDump $root $game) -ne $dump) { throw 'A stale record blocked recovery.' }
[IO.File]::Delete($record)

$bundle=Join-Path $base $game.Bundle
$setup=@'
param([string]$DumpPath,[string]$InstallDir,[switch]$StageUpdate)
$ErrorActionPreference='Stop'
if (!$StageUpdate -or $DumpPath -notlike '*The House of the Dead 4\disk0') { throw 'Setup received the wrong dump.' }
$app=Join-Path $InstallDir 'HOTD4_Recomp'
[void][IO.Directory]::CreateDirectory($app)
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'ui/hotd-update.ps1') -Destination $app
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'ui/Play HOTD4.cmd') -Destination $InstallDir
[IO.File]::WriteAllText((Join-Path $app 'hotd4-desktop.exe'),'built')
[IO.File]::WriteAllText((Join-Path $InstallDir 'Play HOTD4.exe'),'launcher')
'@
Write-FixtureFile (Join-Path $bundle 'setup.ps1') $setup
Write-FixtureFile (Join-Path $bundle 'package-manifest.json') '{"files":[{"path":"ui/hotd-update.ps1"},{"path":"ui/Play HOTD4.cmd"}]}'
$ui=Join-Path $bundle 'ui'
[void][IO.Directory]::CreateDirectory($ui)
Copy-Item -LiteralPath (Join-Path $repo 'ui/hotd-update.ps1'),(Join-Path $repo 'ui/Play HOTD4.cmd') -Destination $ui
$testArchive=Join-Path $base 'verified-test-package.zip'
Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::Open($testArchive,'Create')
try {
    foreach ($path in 'setup.ps1','package-manifest.json','ui/hotd-update.ps1','ui/Play HOTD4.cmd') {
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,(Join-Path $bundle $path),"$($game.Bundle)/$path")
    }
} finally { $zip.Dispose() }

function Receive-HotdUpdateArchive([string]$Url,[string]$Destination) {
    [IO.File]::Copy($testArchive,$Destination)
}
function Start-Process([string]$FilePath,[string]$WorkingDirectory) {
    if ($FilePath -ne (Join-Path $root $game.Launcher) -or $WorkingDirectory -ne $root) { throw 'Unexpected launcher restart.' }
    $restart.Requested=$true
}

$work=Join-Path $root '.hotd-update-1234567890'
[void][IO.Directory]::CreateDirectory($work)
$applyFile=Join-Path $work 'apply.txt'
$writeStatus=${function:Set-HotdUpdateStatus}
function Set-HotdUpdateStatus([string]$Status,[string]$Text) {
    & $writeStatus $Status $Text
    if ($Text -eq 'Ready') { [IO.File]::WriteAllText($applyFile,'apply') }
}

$ownerInfo=[Diagnostics.ProcessStartInfo]::new()
$ownerInfo.FileName=Get-HotdPowerShell
$ownerInfo.Arguments='-NoProfile -Command "$age=[Diagnostics.Stopwatch]::StartNew(); while (![IO.File]::Exists($env:HOTD_TEST_HANDOFF) -and $age.Elapsed.TotalSeconds -lt 30) { Start-Sleep -Milliseconds 100 }"'
$ownerInfo.EnvironmentVariables['HOTD_TEST_HANDOFF']=$applyFile
$ownerInfo.UseShellExecute=$false
$ownerInfo.CreateNoWindow=$true
$owner=[Diagnostics.Process]::Start($ownerInfo)
$restart=@{Requested=$false}
try {
    $tag='v1.0.1'
    $package=@{
        Tag=$tag
        Url="https://github.com/davidptrssvea/$($game.Repo)/releases/download/$tag/$($game.Bundle)-$tag.zip"
        Hash=(Get-FileHash -LiteralPath $testArchive).Hash.ToLowerInvariant()
        Size=(Get-Item -LiteralPath $testArchive).Length
    }
    $request=Join-Path $work 'request.json'
    Write-FixtureFile $request (@{App=$app;Owner=$owner.Id;Game='Normal';Package=$package} | ConvertTo-Json -Compress)
    Invoke-HotdUpdateWorker $request
    $status=Read-HotdUpdateStatus (Join-Path $work 'status.txt')
    if ($status -ne "Installed $tag" -or !$restart.Requested) { throw "The updater did not finish and reopen the launcher: $status" }
    if ([IO.File]::ReadAllText($record) -ne $dump) { throw 'The update did not install the legacy dump record.' }
    if ([IO.File]::ReadAllText((Join-Path $app 'display-mode.txt')) -ne 'Windowed' -or
        [IO.File]::ReadAllText((Join-Path $dump 'fs/keep.txt')) -ne 'user game data') {
        throw 'The staged update changed existing game data or settings.'
    }
    $env:HOTD4_4K_SCRIPT=Join-Path $root 'Play HOTD4.cmd'
    $entry=([IO.File]::ReadAllText($env:HOTD4_4K_SCRIPT) -split '(?m)^:PowerShell\r?$',2)[1]
    $entry=$entry.Substring(0,$entry.IndexOf('$elfDir =', [StringComparison]::Ordinal))
    $resolved=& { . ([scriptblock]::Create($entry)); $diskDir }
    if ($resolved -ne $dump) { throw 'The updated launch script did not use the repaired dump record.' }
    # A previous updater can install this launcher before it knows how to write the record.
    [IO.File]::Delete($record)
    $resolved=& { . ([scriptblock]::Create($entry)); $diskDir }
    if ($resolved -ne $dump) { throw 'The updated launch script still requires a dump record.' }
} finally {
    if (!$owner.HasExited) { $owner.Kill() }
    $owner.Dispose()
}
Write-Host 'PASS: an old installation was updated, its dump record was installed and the new launcher found its game data.'
