# Hudu Network Lookup

Flutter desktop utility: enter an IPv4 address, resolve its MAC from local interface or neighbor-cache data, send the MAC to the Rails API for a vendor, and show the API's lookup history. **Use my IP** fills in the primary active interface address. Discovery semantics, limits, and the audit of what is and is not claimed live in [Architecture](../../docs/architecture.md); the API surface is in the [API reference](../../docs/api.md).

## Run

With Flutter 3.47.2 on `PATH` and the Rails API running (see the root README):

```sh
flutter pub get
flutter run -d macos --dart-define=API_BASE_URL=http://127.0.0.1:3000
# On Windows:
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

The define defaults to `http://127.0.0.1:3000` and also applies to `flutter build`. The macOS build is intentionally unsandboxed because the app executes native network utilities; this is a desktop utility, not an App Store distribution claim.

## Verify

```sh
flutter analyze
flutter test
flutter build macos --release   # or: flutter build windows --release
```

`test/native_smoke_test.dart` reads the real interface and neighbor tables on macOS and Windows without probing or logging addresses, and skips elsewhere. Opt-in checks, documented in [Testing](../../docs/testing.md):

```sh
HUDU_API_SMOKE=true flutter test test/api_smoke_test.dart
HUDU_API_SMOKE=true HUDU_LIVE_VENDOR=true flutter test test/api_smoke_test.dart
UPDATE_GOLDENS=true flutter test --update-goldens test/screenshots_test.dart
```
