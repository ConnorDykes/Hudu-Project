# Testing and delivery evidence

This page separates commands to run from results supplied during development. The main-owned [verification results](verification-results.md) are the authoritative current evidence record, including integration findings and retests. A build is not manual UI verification; a synthetic widget render is not live OS integration. Pending checks must not be converted into passing claims without their actual output and context.

## Current evidence

| Area | Status | Evidence / remaining work |
| --- | --- | --- |
| `desktop_core` static analysis | Passed, reported by main agent | No analysis issues; see [verification results](verification-results.md) |
| `desktop_core` unit tests | 7 passed, reported by main agent | HTTP behavior and desktop layout/navigation; see [verification results](verification-results.md) |
| Rails request / model / vendor tests | 39 tests, 438 assertions passed, reported by API worker via main | Main-agent independent rechecks pending |
| Rails lint / security | Clean, reported by API worker via main | Main-agent independent rechecks pending |
| Live JSON POST correction | Worker fix and raw POST regression reported | `json < 3`, locked 2.21.2; independent live retest pending |
| Audit timestamp precision correction | In progress | Normalize at event creation and test millisecond API response acknowledgement |
| API container HTTP / restart persistence | CI job configured; execution pending | Requires successful `api-container` run; no Docker verification claim |
| Network Lookup analysis / tests | Pending | App implementation in progress |
| Process Manager analysis / tests | Pending | App implementation in progress |
| macOS native builds, both apps | Pending | Record native build and packaged artifact evidence |
| Windows native builds, both apps | Pending | Record Windows-runner build and artifact evidence |
| Native OS adapter checks | Pending | Separate macOS and Windows results |
| Real client/API integration | Pending | Verify history persistence and failure/recovery paths |
| macOS manual UI inspection | Pending | Main agent will inspect live native applications |
| Windows manual UI inspection | Not established | Do not infer it from CI, parser tests, or screenshots |
| Public UI previews | Pending | Production Flutter widgets with injected synthetic sample data |
| Original SVG banner | Rendered and visually inspected by main agent | `rsvg-convert` render; SVG XML validation also passed |
| Clean-clone macOS / Windows / Docker setup | Pending | Execute documented setup in the relevant environment |
| CI artifacts / release downloads | Pending | Supply successful run URLs and actual downloadable files |

## Deterministic checks

From `api/`, using Ruby 4.0.2:

```sh
bundle install
RAILS_ENV=test bin/rails db:prepare
bundle exec rails test
```

The Rails suite should cover request validation, normalization, persistence, pagination order, JSON/status contracts, timestamp handling, duplicate event IDs, and conflicts. Vendor service tests should stub resolved, unknown, malformed, unavailable, timed-out, and rate-limited responses. They should not require the external provider to be online.

The full check scripts additionally run RuboCop, Brakeman, and the dependency advisory audit. From the repository root, use `bash scripts/dev.sh check` on macOS, or `./scripts/dev.ps1 check flutter` on Windows when Ruby runs in WSL2. In the WSL checkout, `bash scripts/dev.sh check api` covers Rails. Complete setup first. For the container route, API tests can run with `docker compose run --rm -e RAILS_ENV=test api bundle exec rails db:prepare test`.

Run the following from **each** of `packages/desktop_core/`, `apps/network_lookup/`, and `apps/process_manager/`:

```sh
flutter pub get
flutter analyze
flutter test
```

Client coverage should exercise state transitions, stale async results, empty/error states, sorting/search, refresh overlap, confirmation, identity changes, unconfirmed exits, and audit retry. Adapter fixtures should include spaces/Unicode in process names, incomplete ARP entries, and multiple interfaces. These are acceptance targets; the table above is the source of reported results.

## Native and integration checks

OS termination tests may terminate **only disposable child processes created by their own harness**. Record the child identity and ensure cleanup cannot target an unrelated user process. Do not test termination by selecting an arbitrary application or by copying a PID from a screenshot.

The integration review should establish:

1. Each real desktop app reaches Rails on the configured host and port.
2. Lookup success, unknown-vendor, provider failure, and local discovery failure remain distinct; ARP misses create no API record.
3. Confirmed process exit produces the expected event; permission denial, stale identity, or an unconfirmed exit does not claim success.
4. After an API outage, a pending audit survives app restart and retries with the same UUID and original occurrence time. Duplicate delivery adds no duplicate history and performs no OS action.
5. Both histories survive an API restart. Pagination ordering matches [contracts.md](contracts.md).
6. Each native app handles resize, keyboard focus, loading, errors, and recovery. Inspect macOS release launch from Finder separately from `flutter run`.

Record live vendor smoke checks separately from deterministic test results, including the date and outcome. Do not publish private host data as evidence.

## Release builds

From each app directory on a **macOS host**:

```sh
flutter pub get
flutter build macos --release --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

From each app directory on a **Windows host**, in PowerShell:

```powershell
flutter pub get
flutter build windows --release --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

The intended output matrix is Network Lookup/macOS, Process Manager/macOS, Network Lookup/Windows, and Process Manager/Windows. Verify all four independently. Do not claim a Windows build from a macOS Flutter command.

macOS builds normally produce an `.app` under the app's `build/macos/Build/Products/Release/` directory. Windows produces a release bundle under `build/windows/<architecture>/runner/Release/`; retain the executable, all required DLLs, and the `data/` directory. The final architecture, bundle names, and CI archive names must be taken from successful build outputs.

The desktop binaries require a separately running API. Planned downloads are unsigned development artifacts; signing and notarization are not verified. [GitHub Actions](https://github.com/ConnorDykes/Hudu-Project/actions) is the CI destination and [Releases](https://github.com/ConnorDykes/Hudu-Project/releases) the release destination. No available artifact is claimed until an actual run or release link is supplied.

After successful builds, the packaging scripts archive the complete bundles. From the repository root:

```sh
# macOS; choose a fresh output directory.
bash scripts/package-macos.sh network_lookup /tmp/hudu-release
bash scripts/package-macos.sh process_manager /tmp/hudu-release
```

```powershell
# Windows; choose a fresh output directory.
./scripts/package-windows.ps1 -App network_lookup -OutputDirectory "$env:TEMP/hudu-release"
./scripts/package-windows.ps1 -App process_manager -OutputDirectory "$env:TEMP/hudu-release"
```

Archive names follow `hudu-<app>-macos-<architecture>.zip` or `hudu-<app>-windows-<architecture>.zip`. Windows packaging defaults to x64; use its `-Architecture` parameter only for a matching actual build. Follow the [script reference](../scripts/README.md) for the required Windows Visual C++ runtime and extraction instructions. Both packagers refuse to overwrite an existing archive.

The checked-in CI workflow declares Rails checks, an API container HTTP/persistence job, Flutter checks for all three packages, and four native app/platform build jobs. The `api-container` job builds Compose, creates a synthetic audit record over HTTP expecting `201`, restarts the API, and resubmits the same payload expecting `200` and an identical response. This exercises API persistence and retry behavior without terminating any process. Docker execution remains unverified until a successful CI run is supplied.

Uploaded artifact names include the app, platform, runner architecture, and commit SHA; retention is configured for 14 days. Download an artifact from a successful run and extract its enclosed release zip. Release publication is a separate main-agent step. This describes workflow configuration, not evidence that a run has succeeded.

## Screenshot provenance

Planned public previews use real production Flutter widgets rendered through golden tests with injected synthetic sample data. Use the caption **“Actual Flutter UI rendered with synthetic sample data”**. These previews show implemented UI rendering; they do not demonstrate live network discovery, real process termination, or Windows manual UI testing.

Reserve `docs/assets/network-lookup.png` and `docs/assets/process-manager.png` for the supplied renders. The original `banner.svg` is illustrative project branding. Before publishing previews, inspect them for layout and accidental personal data; record the originating test and app revision. Main-agent live native-app inspection is a separate evidence row above.

## Final evidence handoff

For each completed check, record the command, platform/toolchain, revision, result, and available log or CI URL in [verification results](verification-results.md). For artifacts, add the actual download URL and architecture. For manual UI work, describe the actions actually exercised and any untested platform. Update this page's summary and README only after the main agent supplies evidence; passing shared-package tests do not imply passing application integration.
