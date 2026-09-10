# Hudu Process Manager

Flutter desktop process inspection with confirmed-exit auditing. Local OS operations run in the client; the separate Rails API stores audit history. The UI uses the shared `desktop_core` theme, shell and HTTP client, with Riverpod controllers and injectable OS, clock, audit and outbox dependencies.

## Run

With Flutter 3.47.2 on PATH and the root Rails API running:

```sh
flutter pub get
flutter run -d macos
# On Windows:
flutter run -d windows
```

The API defaults to `http://127.0.0.1:3000`. Override at build/run time with `--dart-define=API_BASE_URL=http://127.0.0.1:3000`. Process listing works while Rails is offline. Audit history reports its own connection error.

Search by name or PID, click column headers to sort (PID sorts numerically), select a row and confirm termination. Auto-refresh is configurable to off, 5, 10 or 30 seconds for the current session. Concurrent refreshes are suppressed; selection survives only when the process identity matches. Short windows hide summary cards to preserve table space.

## Termination and audit semantics

- No process trees, permission elevation, nonpositive PIDs or self termination. Protected Windows processes may be listed with unavailable identity and cannot be selected for termination.
- macOS uses argument-safe `/bin/ps` with fixed output columns and C locale. It rechecks creation time and command immediately before SIGTERM, then observes exit for up to four seconds. A zombie counts as exited. A changed executable name alone does not count as exit. PID reuse between verification and signaling cannot be eliminated, and `ps` creation timestamps have one-second precision. No force-kill fallback is used.
- Windows lists structured process data through a bounded, fixed PowerShell script. Termination opens a kernel handle with query, terminate and synchronize rights. Creation time validation, `TerminateProcess` and exit waiting use that same retained handle, closed in `finally`. This is forced termination, not a Unix graceful signal. PowerShell is needed for listing; blocked helpers surface an OS error.
- Only confirmed exits create audit events. Already exited, identity changed, access denied and unconfirmed timeout outcomes create none. A process that exits after the observation deadline is not automatically audited.
- Each confirmed event captures one UUID and its original UTC occurrence time in milliseconds. Local files are flushed and atomically renamed before transmission. Retries preserve the event payload and call only the audit endpoint; they never repeat a kill. Rails deduplicates event IDs. API acknowledgements are compared at the server's millisecond timestamp precision.
- The outbox is under the platform application-support directory in `audit-outbox/`. Events retry on startup, every 30 seconds and through **Retry audit**. Complete temporary event files are recovered after restart. Corrupt files are preserved and block further termination until repaired. API rejection or conflict stays visibly pending; it is never silently discarded.
- Storage is checked before termination. A disk failure after exit leaves the event in memory with a visible warning to keep the app open. OS termination and disk persistence cannot form one transaction: an abrupt crash between confirmed exit and a durable write can lose the event. A disk or power failure can also exceed normal flush/rename guarantees.

The macOS app is intentionally unsandboxed in Debug/Profile/Release. This is a local desktop utility without an App Store, signing or notarization claim.

## Verification

```sh
flutter analyze
flutter test
flutter test test/native_smoke_test.dart
flutter build macos --release
# Run on a Windows host:
flutter build windows --release
```

`test/native_smoke_test.dart` uses the real OS and terminates only its own disposable `sleep` (macOS) or PowerShell `Start-Sleep` child (Windows). It skips other platforms. Unit tests use injected adapters to exercise permissions, identity reuse, handle lifetime, timeouts, parser errors and audit recovery.

With the isolated verification Rails API running, the separate opt-in HTTP test terminates a new harness child and verifies real repository POST, retry and GET behavior:

```sh
HUDU_API_SMOKE=true flutter test test/api_smoke_test.dart
```

PowerShell equivalent: `$env:HUDU_API_SMOKE='true'; flutter test test/api_smoke_test.dart`.

The public preview is an actual production-widget golden with synthetic process records and a fixed injected clock. It loads the same bundled OFL Inter font as the app plus Material icons; it contains no machine process data and requires no screenshot mode in the production app. Normal cross-platform tests skip golden comparisons.

```sh
UPDATE_GOLDENS=true flutter test --update-goldens test/screenshots_test.dart
# Same rendering host, compare without updating:
UPDATE_GOLDENS=true flutter test test/screenshots_test.dart
```

The image is `test/goldens/process-manager.png`. The native display name is **Hudu Process Manager**; build products remain `process_manager.app` and `process_manager.exe`.
