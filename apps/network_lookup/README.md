# Hudu Network Lookup

Flutter desktop utility for passive local IPv4/MAC discovery, vendor identification,
and Rails-backed lookup history. Run the Rails service separately using the root
project instructions. No authentication is required. Uses the shared
`../../packages/desktop_core` shell, Inter typography, theme, and HTTP client.

From this directory, with Flutter 3.47.2 / Dart 3.13.2:

```sh
flutter pub get
flutter run -d macos
# On Windows:
flutter run -d windows
# Optional API override (also applies to flutter build):
flutter run -d macos --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

Enter an IPv4 address and press Enter, or use **Use my IP** to fill the suggested
default-route interface address. The interface menu lets you resolve ambiguity
across adapters. Cmd/Ctrl+L focuses the input; Cmd/Ctrl+R refreshes interface/history
data. Both runners enforce a 960×680 minimum client size; content scrolls.

Discovery semantics:

- macOS reads `ifconfig -a`, `route -n get default`, and numeric `arp -an` output.
  Windows reads structured PowerShell `Get-NetIPAddress`, `Get-NetAdapter`,
  `Get-NetRoute`, and `Get-NetNeighbor` output. Commands are fixed argument arrays;
  user input is never interpolated into a shell or PowerShell script.
- Own-IP resolution uses the local interface MAC, without requiring an ARP entry.
  VPN interfaces may have no hardware MAC; this is explained in the result.
  If no default route exists, the first active IPv4 is explicitly suggested as a
  fallback. With multiple interfaces, users can override the suggestion.
- Only exact IPv4 cache matches resolve. Incomplete, zero, multicast, and broadcast
  MACs do not identify a device. Conflicting MACs across adapters require selection.
  Abbreviated macOS hex octets are normalized to uppercase two-digit colon format.
- Cache misses do **not** establish that a device is offline. ARP covers the local
  link; the gateway MAC is never substituted for a remote IP. No probing, scanning,
  cache modification, or IPv6 discovery occurs.
- Only attempts with a resolved MAC are sent to `POST /lookups`. A `201` unknown
  vendor is a saved result. Provider failures preserve the failed record returned
  by Rails, including `502`, `503`, and `504` response data. When delivery cannot
  be confirmed, the discovered MAC stays visible and persistence is marked
  unconfirmed. There are no automatic POST retries; check history before repeating.
- History is fetched with `GET /lookups?limit=30&offset=0`; no local fake history or
  optimistic invented rows. OS errors, lookup failures, and history failures are
  independently presented. Riverpod 3 providers support injected adapters,
  repositories, and transport for testing.
- Windows discovery shares a 30-second deadline across its native commands,
  including process startup, to accommodate slow first-use initialization.
  macOS retains eight-second command limits within a 24-second discovery budget.
  Output is limited to 1 MiB per stream. Timeout cleanup attempts to stop only
  the app's own command children and releases their pipes, including late starts;
  it does not claim an observed exit. Raw errors are hidden because they can
  contain private machine information. No automatic command retries are used.

macOS Debug/Profile and Release are intentionally **unsandboxed desktop utility**
builds, with network-client entitlement, because the app executes native tools.
They are not an App Store distribution claim. The display title is **Hudu Network
Lookup**; predictable bundle/executable names remain `network_lookup`.

Verification:

```sh
flutter analyze
flutter test
dart run tool/native_smoke.dart
flutter build macos --release
# On Windows with the native toolchain:
flutter build windows --release
```

The native smoke reads real interface/cache data and checks canonical identities
and own-IP metadata resolution, without probing or logging addresses. Both the
standalone smoke and `test/native_smoke_test.dart` skip unsupported Linux hosts.
Deterministic macOS and Windows parser fixtures run on all platforms. Windows
native behavior and packaging must be verified on a Windows runner; a macOS
build does not establish Windows build success.

Optional integration checks (POSIX shell syntax; in PowerShell set the equivalent
`$env:NAME='true'` variables):

```sh
# Requires Rails; GET history + invalid POST/422, no vendor-service dependency.
HUDU_API_SMOKE=true flutter test test/api_smoke_test.dart
# Also POST the synthetic Apple sample MAC and verify the persisted record via GET.
# Creates a history row and calls the configured external vendor service.
HUDU_API_SMOKE=true HUDU_LIVE_VENDOR=true flutter test test/api_smoke_test.dart
# Render the actual app's production widgets with synthetic injected dependencies.
UPDATE_GOLDENS=true flutter test --update-goldens test/screenshots_test.dart
```

Golden comparisons are opt-in so default cross-platform tests do not depend on
platform rasterization. `test/screenshots_test.dart` loads the shared bundled OFL
Inter font and Flutter Material Icons before rendering; the output is
`test/goldens/network-lookup.png`. Its IPs, interface details, vendors, and history
are synthetic test fixtures, never a capture of private host data. Production
uses only the real OS adapter and Rails repository.
