# Testing and verification

[Verification results](verification-results.md) records the checks actually performed, their limits, and the tested revisions. The [CI workflow](https://github.com/ConnorDykes/Hudu-Project/actions/workflows/ci.yml) runs API checks, client tests, native builds, and packaging.

## Run the test suites

After setting up the pinned toolchains and dependencies:

```sh
# Repository root, macOS or a Linux API checkout.
bash scripts/dev.sh check

# API only.
bash scripts/dev.sh check api

# Flutter only.
bash scripts/dev.sh check flutter
```

On Windows with Rails in WSL2 or Docker, use `./scripts/dev.ps1 check flutter` in PowerShell and run the API checks in the Linux checkout. The scripts enforce the checked-in Flutter lockfiles.

Individual package commands:

```sh
# Inside api/
RAILS_ENV=test bundle exec rails db:prepare
bundle exec rails test

# Inside either app or packages/desktop_core/
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
```

The API suite covers validation, MAC normalization, persisted outcomes, history ordering, timestamps, event deduplication/conflicts, and upstream errors. WebMock disables external network calls in that suite. Full API checks also run RuboCop, Brakeman, and a dependency advisory audit.

Client tests cover state transitions, stale results, sorting/search, refresh scheduling, confirmation, identity changes, outbox persistence/recovery, and error presentation. Windows and macOS parser fixtures run on every host.

## Native and HTTP integration

Default app tests include `test/native_smoke_test.dart` on Windows and macOS, skipping it on Linux:

- Network Lookup reads real interfaces and neighbor-cache entries and verifies canonical identities and own-IP metadata. It performs no probes or scans and logs no addresses.
- Process Manager creates its own disposable `sleep` or PowerShell child, finds its identity, terminates that child through the actual adapter, and observes exit. It never selects an existing user process.

With Rails running at the configured API URL, run from either app directory:

```sh
HUDU_API_SMOKE=true flutter test test/api_smoke_test.dart
```

PowerShell equivalent:

```powershell
$env:HUDU_API_SMOKE = 'true'
flutter test test/api_smoke_test.dart
Remove-Item Env:HUDU_API_SMOKE
```

The network HTTP smoke reads history and checks a rejected malformed request without depending on the vendor service. The process HTTP smoke terminates a new harness child, sends its event through the real repository, retries the same event, and verifies one history row.

For a separate live vendor check, from Network Lookup:

```sh
HUDU_API_SMOKE=true HUDU_LIVE_VENDOR=true flutter test test/api_smoke_test.dart
```

This opt-in check calls the vendor provider with synthetic sample data and creates a persisted lookup. Provider errors/unknown results are distinct from an API transport failure.

## CI matrix

| Check | Environment |
| --- | --- |
| Rails tests, lint, security/dependency checks | Ubuntu |
| Docker Compose startup, JSON POST, idempotent retry, persistence after restart | Ubuntu |
| Shared package and both Flutter suites | Ubuntu |
| Native adapter tests and release builds for each app | Windows and macOS |
| Real Flutter repository-to-Rails integration | macOS |
| Complete app archive creation and upload | Windows and macOS |

The container test uses a synthetic audit fixture and does not terminate any process. Desktop jobs package the complete application: macOS bundles retain framework symlinks, and Windows bundles include the executable, Flutter/plugin DLLs, and data directory. Artifacts are retained for 14 days; published releases provide durable download links.

Documentation-only pushes do not rebuild the binaries. Pull requests and manual workflow dispatches still run the workflow. A release's notes identify the code revision used for its artifacts.

## Build and package locally

From each app directory, on its native host:

```sh
flutter build macos --release
# Windows:
flutter build windows --release
```

From the repository root, choose a fresh output directory:

```sh
bash scripts/package-macos.sh network_lookup /tmp/hudu-release
bash scripts/package-macos.sh process_manager /tmp/hudu-release
```

```powershell
./scripts/package-windows.ps1 -App network_lookup -OutputDirectory "$env:TEMP/hudu-release"
./scripts/package-windows.ps1 -App process_manager -OutputDirectory "$env:TEMP/hudu-release"
```

The macOS packager inspects the executable and labels a dual Intel/Apple Silicon build `universal`. Windows packaging defaults to x64. Both refuse to overwrite an existing archive. Windows requires the [Visual C++ runtime described in the development guide](development.md#packaging-release-bundles); retain the entire extracted bundle.

These are development artifacts, without verified Developer ID signing/notarization or store publication. The Rails API remains a separate service.

## Screenshot provenance

The README previews are the actual production Flutter widgets rendered in the dark theme with injected synthetic records, the bundled OFL Inter and JetBrains Mono fonts, and Material icons. They contain no private machine/network data. They demonstrate implemented UI rendering, not live OS operation or Windows manual testing.

From each app, on the rendering host:

```sh
UPDATE_GOLDENS=true flutter test --update-goldens test/screenshots_test.dart
# Compare without updating:
UPDATE_GOLDENS=true flutter test test/screenshots_test.dart
```

Outputs are `test/goldens/network-lookup.png` and `network-lookup-name-vendor.png` for Network Lookup, and `process-manager.png`, `process-manager-confirm.png`, and `process-manager-history.png` for Process Manager, copied into `docs/assets/` after visual inspection. Golden tests are opt-in to avoid cross-platform rasterization differences.

Interactive app inspection is recorded separately in [verification results](verification-results.md). Native test success or a compiled binary is not described as manual UI verification.
