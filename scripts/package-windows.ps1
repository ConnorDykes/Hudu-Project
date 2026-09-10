[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('network_lookup', 'process_manager')]
    [string]$App,
    [Parameter(Mandatory)]
    [string]$OutputDirectory,
    [ValidateSet('x64', 'arm64')]
    [string]$Architecture = 'x64'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path -Parent $PSScriptRoot
$bundle = Join-Path $projectRoot "apps/$App/build/windows/$Architecture/runner/Release"
foreach ($required in @("$App.exe", 'flutter_windows.dll', 'data')) {
    if (-not (Test-Path (Join-Path $bundle $required))) { throw "Incomplete Windows bundle: missing $required in $bundle." }
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$archive = Join-Path (Resolve-Path $OutputDirectory).Path "hudu-$App-windows-$Architecture.zip"
if (Test-Path $archive) { throw "Refusing to overwrite $archive; choose a fresh output directory." }
# Zip the whole Release directory contents, including plugin DLLs and Flutter data.
# .NET includes hidden files too; Compress-Archive would silently omit them.
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($bundle, $archive)
$zip = [System.IO.Compression.ZipFile]::OpenRead($archive)
try {
    $names = @($zip.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
    if ("$App.exe" -notin $names -or 'flutter_windows.dll' -notin $names -or
        -not ($names | Where-Object { $_ -like 'data/*' })) {
        throw 'Archive is missing required Windows runtime files.'
    }
} finally { $zip.Dispose() }
Write-Host $archive
