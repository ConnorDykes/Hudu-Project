[CmdletBinding()]
param(
    [ValidateSet('setup', 'check', 'run', 'build', 'doctor', 'help')]
    [string]$Command = 'help',
    [string]$Target = 'flutter'
)
# Windows runs the Flutter clients natively; Rails runs in WSL2 (scripts/dev.sh)
# or Docker (compose.yaml). This script therefore covers only the Flutter side.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path -Parent $PSScriptRoot

function Invoke-Checked {
    param([string]$Program, [string[]]$Arguments)
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed with exit code $LASTEXITCODE." }
}
function Assert-Flutter {
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        throw 'Install Flutter and add it to PATH; see docs/development.md.'
    }
    $expected = (Get-Content (Join-Path $projectRoot '.flutter-version') -Raw).Trim()
    $details = & flutter --version --machine
    if ($LASTEXITCODE -ne 0) { throw 'Could not read Flutter version.' }
    $actual = ($details -join "`n" | ConvertFrom-Json).frameworkVersion
    if ($actual -ne $expected) { throw "Flutter $expected required; found $actual." }
}
function Invoke-InDirectory {
    param([string]$Path, [scriptblock]$Action)
    Push-Location (Join-Path $projectRoot $Path)
    try { & $Action } finally { Pop-Location }
}

$packages = @('packages/desktop_core', 'apps/network_lookup', 'apps/process_manager')
switch ($Command) {
    { $_ -in 'setup', 'check' } {
        if ($Target -notin 'all', 'flutter') { throw 'Only the Flutter target is supported on Windows; run API commands in WSL2.' }
        Assert-Flutter
        foreach ($package in $packages) {
            Invoke-InDirectory $package {
                if ($Command -eq 'setup') { Write-Host "Resolving dependencies for $package." }
                Invoke-Checked flutter @('pub', 'get', '--enforce-lockfile')
                if ($Command -eq 'check') {
                    Invoke-Checked flutter @('analyze', '--no-pub', '--fatal-infos')
                    Invoke-Checked flutter @('test', '--no-pub')
                }
            }
        }
    }
    { $_ -in 'run', 'build' } {
        if ($Target -notin 'network_lookup', 'process_manager') { throw 'Select network_lookup or process_manager.' }
        if ($env:OS -ne 'Windows_NT') { throw 'Use dev.sh for native macOS builds.' }
        Assert-Flutter
        $apiUrl = if ($env:API_BASE_URL) { $env:API_BASE_URL } else { 'http://127.0.0.1:3000' }
        Invoke-InDirectory "apps/$Target" {
            if ($Command -eq 'run') {
                Invoke-Checked flutter @('run', '-d', 'windows', "--dart-define=API_BASE_URL=$apiUrl")
            } else {
                Invoke-Checked flutter @('build', 'windows', '--release', "--dart-define=API_BASE_URL=$apiUrl")
            }
        }
    }
    doctor {
        Assert-Flutter
        Invoke-Checked flutter @('doctor', '-v')
    }
    help {
        Write-Host './scripts/dev.ps1 setup|check [flutter]'
        Write-Host './scripts/dev.ps1 run|build network_lookup|process_manager'
        Write-Host './scripts/dev.ps1 doctor|help'
        Write-Host 'Flutter only. Start Rails with scripts/dev.sh in WSL2 or docker compose up api.'
        Write-Host 'Requires the pinned Flutter on PATH; see docs/development.md.'
    }
}
