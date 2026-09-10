[CmdletBinding()]
param(
    [ValidateSet('setup', 'check', 'api', 'run', 'build', 'doctor', 'help')]
    [string]$Command = 'help',
    [string]$Target = 'all'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path -Parent $PSScriptRoot

function Invoke-Checked {
    param([string]$Program, [string[]]$Arguments)
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed with exit code $LASTEXITCODE." }
}
function Assert-Tool {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Install $Name and add it to PATH; see scripts/README.md."
    }
}
function Assert-Ruby {
    Assert-Tool ruby
    Assert-Tool bundle
    $expected = (Get-Content (Join-Path $projectRoot '.ruby-version') -Raw).Trim()
    $actual = & ruby -e 'print RUBY_VERSION'
    if ($LASTEXITCODE -ne 0 -or $actual -ne $expected) {
        throw "Ruby $expected required; found $actual. Select it with your version manager."
    }
}
function Assert-Flutter {
    Assert-Tool flutter
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
function Invoke-RailsEnvironment {
    param([string]$Environment, [scriptblock]$Action)
    $previous = $env:RAILS_ENV
    try { $env:RAILS_ENV = $Environment; & $Action }
    finally { $env:RAILS_ENV = $previous }
}

$packages = @('packages/desktop_core', 'apps/network_lookup', 'apps/process_manager')
switch ($Command) {
    { $_ -in 'setup', 'check' } {
        if ($Target -notin 'all', 'api', 'flutter') { throw 'Target must be all, api, or flutter.' }
        if ($Target -ne 'flutter') { Assert-Ruby }
        if ($Target -ne 'api') {
            Assert-Flutter
            foreach ($package in $packages) {
                if (-not (Test-Path (Join-Path $projectRoot "$package/pubspec.yaml"))) {
                    throw "Missing $package/pubspec.yaml. Complete the app scaffold first."
                }
            }
        }
        if ($Target -ne 'flutter') {
            Invoke-InDirectory api {
                if ($Command -eq 'setup') {
                    Write-Host 'Installing API dependencies and preparing the development SQLite database.'
                    & bundle check
                    if ($LASTEXITCODE -ne 0) { Invoke-Checked bundle @('install') }
                    Invoke-RailsEnvironment development { Invoke-Checked bundle @('exec', 'rails', 'db:prepare') }
                } else {
                    Invoke-RailsEnvironment test { Invoke-Checked bundle @('exec', 'rails', 'db:prepare', 'test') }
                    Invoke-Checked bundle @('exec', 'rubocop')
                    Invoke-Checked bundle @('exec', 'brakeman', '--no-pager')
                    Invoke-Checked bundle @('exec', 'ruby', 'bin/bundler-audit', 'check', '--update')
                }
            }
        }
        if ($Target -ne 'api') {
            foreach ($package in $packages) {
                Invoke-InDirectory $package {
                    if ($Command -eq 'setup') {
                        Write-Host "Resolving dependencies for $package."
                    }
                    Invoke-Checked flutter @('pub', 'get', '--enforce-lockfile')
                    if ($Command -eq 'check') {
                        Invoke-Checked flutter @('analyze', '--no-pub', '--fatal-infos')
                        Invoke-Checked flutter @('test', '--no-pub')
                    }
                }
            }
        }
    }
    api {
        if ($Target -ne 'all') { throw 'api takes no target.' }
        Assert-Ruby
        Invoke-InDirectory api {
            Invoke-RailsEnvironment development {
                Invoke-Checked bundle @('exec', 'rails', 'db:prepare')
                Invoke-Checked bundle @('exec', 'rails', 'server', '-b', '127.0.0.1', '-p', '3000')
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
        Assert-Ruby
        Assert-Flutter
        Invoke-Checked flutter @('doctor', '-v')
    }
    help {
        Write-Host './scripts/dev.ps1 setup|check [all|api|flutter]'
        Write-Host './scripts/dev.ps1 api'
        Write-Host './scripts/dev.ps1 run|build network_lookup|process_manager'
        Write-Host './scripts/dev.ps1 doctor|help'
        Write-Host 'setup installs project dependencies and prepares the development DB.'
        Write-Host 'Requires pinned toolchains on PATH; see scripts/README.md for Docker.'
    }
}
