# Hudu Process Manager

Flutter desktop utility: list local processes by name and PID, search and sort them, terminate one or several after a single confirmation, and record each confirmed exit through the Rails API with a local retry queue. Termination and audit semantics, platform differences, and stated limits live in [Architecture](../../docs/architecture.md); the API surface is in the [API reference](../../docs/api.md).

## Run

With Flutter 3.47.2 on `PATH` and the Rails API running (see the root README):

```sh
flutter pub get
flutter run -d macos --dart-define=API_BASE_URL=http://127.0.0.1:3000
# On Windows:
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

The define defaults to `http://127.0.0.1:3000` and also applies to `flutter build`. Process listing works while Rails is offline; audit history reports its own connection error. The macOS build is intentionally unsandboxed because the app controls other processes; this is a desktop utility, not an App Store distribution claim.

Keyboard: Cmd/Ctrl+F focuses search, Cmd/Ctrl+R refreshes the current view, Escape clears the search and then the selection.

## Verify

```sh
flutter analyze
flutter test
flutter build macos --release   # or: flutter build windows --release
```

`test/native_smoke_test.dart` terminates only a disposable `sleep` or PowerShell child that it started itself, and skips outside macOS and Windows. Opt-in checks, documented in [Testing](../../docs/testing.md):

```sh
HUDU_API_SMOKE=true flutter test test/api_smoke_test.dart
UPDATE_GOLDENS=true flutter test --update-goldens test/screenshots_test.dart
```
