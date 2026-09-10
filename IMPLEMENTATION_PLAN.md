# Hudu Project — Implementation Plan

## Objective

Create a public `ConnorDykes/Hudu-Project` repository containing both Hudu take-home options: an IP/MAC/vendor lookup app and a process manager. Each Flutter app will target macOS and Windows, with a shared Rails API providing persistence and the required endpoints.

The assignment asks candidates to choose one option; implementing both is Connor's requested extension. Each option must remain independently runnable and easy to evaluate. The assignment explicitly encourages AI assistance, so the repository will include a factual development log describing delegation, review, corrections, and validation.

Source: [Hudu assignment](https://internal.huducloud.com/shared_article/XhSiLQv7vY2BRNM5vZ9GfKD4/flutter-rails-engineer-take-home-project).

## Verified starting point

- GitHub CLI is authenticated as `ConnorDykes`, and that account is active.
- The proposed `ConnorDykes/Hudu-Project` repository did not resolve during inspection; verify availability again before creation. The README title will be “Hudu Project.”
- The local workspace is an empty Git repository without commits or a remote.
- Xcode 26.6 is available. Flutter and Dart were not found on PATH. The Ruby on PATH is Apple's 2.6.10, so a supported project Ruby must be provisioned separately.
- Native subagent tools are available. One planning reviewer was delegated a read-only platform and verification review.
- This document is the planning deliverable; implementation and public repository creation have not started.

## Architecture

Use one monorepo, two independent Flutter applications, and one API-only Rails service. The desktop clients perform local operating-system operations; Rails handles vendor requests and persisted history. Rails never lists or terminates server processes on behalf of a client.

```text
Hudu-Project/
├── README.md
├── IMPLEMENTATION_PLAN.md
├── api/                         # Rails API, SQLite, migrations, tests
├── apps/
│   ├── network_lookup/          # Flutter app + macOS/Windows runners
│   └── process_manager/         # Flutter app + macOS/Windows runners
├── packages/
│   └── desktop_core/            # Small shared theme and API infrastructure
├── docs/
│   ├── architecture.md
│   ├── api.md
│   ├── development.md
│   ├── testing.md
│   ├── ai-development.md
│   └── assets/                 # Original visuals and actual app screenshots
├── scripts/                    # Shell and PowerShell setup/check commands
└── .github/workflows/           # Rails tests and both desktop build jobs
```

Use Flutter stable with Riverpod and explicit dependencies between widgets, controllers, repositories, and OS adapters. Use Rails API mode with SQLite to keep setup small. Select compatible supported toolchain versions during bootstrap and commit version declarations and lockfiles. Avoid introducing shared packages beyond genuinely common infrastructure.

The API runs as a separate local service without authentication, as requested in the brief, and defaults to local-only access. The desktop application bundles do not contain an embedded Rails server. Provide an optional container route for the API and documented macOS-native and Windows/WSL2 setup routes.

## Work sequence and ownership

| Phase | Owner | Deliverable | Acceptance gate |
| --- | --- | --- | --- |
| 1. Bootstrap and contracts | Main agent | Toolchains, reviewed scaffolds, public repository creation, initial native-build CI, shared theme, endpoint schemas, error types, test strategy | Both empty desktop targets compile on their native runners; API boots and health check succeeds |
| 2A. Rails implementation | Backend subagent | `api/`: lookup integration, persistence, audit endpoints, request/service/model tests | Contract tests pass; external vendor responses are stubbed in automated tests |
| 2B. Lookup application | Lookup subagent | `apps/network_lookup/`: desktop UI, Riverpod state, local network adapters, history, tests | Required flows and error cases pass against contract fixtures |
| 2C. Process application | Process subagent | `apps/process_manager/`: process adapters, sortable/filterable UI, termination flow, audit delivery, tests | Controlled child-process termination and truthful audit behavior pass |
| 3. Integration | Main agent | Real clients connected to Rails, reviewed changes, cross-app consistency | End-to-end journeys pass; no contract drift or unresolved material review findings |
| 4A. CI and packaging | Build subagent | `.github/workflows/` and `scripts/`: reproducible tests, builds, artifact packaging | Rails checks and all four app/platform build combinations pass |
| 4B. Documentation and visuals | Documentation subagent | `README.md`, `docs/`: actual screenshots, diagrams, platform setup and troubleshooting | Main agent verifies commands from a fresh clone and checks rendered documentation |
| 5. Final review and delivery | Main agent, with independent review subagent | Reviewed commit, public repository, verified CI and downloadable build artifacts | Requirement matrix complete; evidence and any remaining platform limitations reported accurately |

Run 2A–2C concurrently only after the main agent freezes the initial contracts and scaffolds. Workers receive disjoint file ownership, explicit acceptance criteria, and instructions to return changed paths, tests, and unresolved issues. Shared files and dependency changes are coordinated by the main agent. Run documentation and build work in parallel with final integration once interfaces and workflows are stable.

The main agent reads all worker changes, independently reruns meaningful checks, and resolves integration defects. A worker's completion message is not sufficient evidence of completion.

## Option 1: Network lookup

- Desktop IP input with validation and clear loading, result, empty, and error states.
- Resolve a corresponding MAC from the client's local ARP/neighbor table using macOS and Windows adapters.
- Treat IPv4 local-link discovery as the supported ARP scope. Explain absent/incomplete entries and remote-network addresses; never present the router's MAC as the remote host's MAC. A cache miss does not establish that a device is offline. IPv6 neighbor discovery is outside the initial scope.
- Normalize MAC formats before calling Rails, and distinguish an unknown vendor from a provider outage.
- Display IP, MAC, vendor, and API-backed recent lookup history.
- Include the optional primary active IPv4 detection with explicit adapter selection/fallback behavior when VPNs or multiple interfaces make the choice ambiguous. Do not assume the machine's own address appears in its ARP table; use local interface metadata for its own MAC or explain that limitation.
- Keep OS access asynchronous and bounded. Use structured native access or argument-safe commands with tested parsing; never interpolate input into a shell command.

Proposed API contract:

| Endpoint | Behavior |
| --- | --- |
| `POST /lookups` | Validate and normalize MAC, call the configured public vendor service, persist the accepted lookup and outcome, return a typed result |
| `GET /lookups` | Return bounded, newest-first persisted lookup history |
| `GET /health` | Provide a lightweight local setup and CI readiness check |

The brief's lookup query URL is an example. A POST is proposed for performing a lookup because it creates a history record; document this decision explicitly. The service adapter must handle provider rate limits, timeouts, malformed responses, and unknown vendors. Use deterministic fixtures for these cases and one separate live smoke check for provider compatibility. Persist valid lookup attempts, including unknown/error outcomes; reject malformed input without creating a misleading record.

## Option 2: Process manager

- List local process names and PIDs in a desktop table with sorting, manual refresh, and configurable auto-refresh.
- Include the optional live search by name and PID.
- Preserve selection by process identity, prevent overlapping refresh requests, and distinguish errors from an empty process list.
- Present termination confirmation with the selected name and PID. Operate within the current user's permissions and surface access-denied or already-exited results.
- Capture process start/creation time and revalidate the selected identity immediately before termination. On Windows, validate and terminate through the same process handle. Document the remaining race in macOS PID-based signaling. Reject nonpositive and self PIDs; do not implicitly terminate process trees or elevate permissions.
- Observe termination before treating it as successful. Do not label a signal/request as confirmed process exit.
- Create a Rails audit event for a confirmed termination and show API-backed audit history.
- If termination succeeds but audit delivery fails, show the true state and persist a retryable event locally with a stable identifier and the original occurrence time, including across app restarts. Server deduplication prevents duplicate history entries after retries. Retrying an audit must never repeat the termination.

Proposed API contract:

| Endpoint | Behavior |
| --- | --- |
| `POST /process_events` | Validate and persist a termination event with process name, PID, UTC occurrence time, and a unique event ID |
| `GET /process_events` | Return bounded, newest-first audit history |

Keep termination and audit failure states separate. Explain platform-specific termination semantics; do not promise Unix graceful-signal behavior on Windows. Automated tests may terminate only disposable child processes created by the test harness. Do not use arbitrary user applications as verification targets.

## Testing and platform verification

1. Rails: request validation, normalization, persistence, history ordering/pagination, timestamp handling, duplicate event handling, and consistent JSON/status codes. Cover unknown vendors, upstream errors, timeouts, and rate limits without depending on the live provider.
2. Flutter: controller/repository tests and widget tests for the main success and failure paths, sorting/search, refresh lifecycle, stale asynchronous results, and audit retries.
3. OS adapters: deterministic fixtures for macOS and Windows output and structured API results, plus native smoke tests. Cover incomplete ARP entries, multiple interfaces, process names with spaces/Unicode, processes exiting mid-refresh, and permission failures.
4. Native builds: compile both apps on macOS and Windows in CI. Package each macOS `.app` and each Windows executable with required DLL/data files, giving four clearly named artifacts.
5. Integration: run each client against the real Rails service; confirm history survives service restart. Exercise success, backend-offline, and recovery behavior. Separate real network checks from deterministic CI tests.
6. UI: inspect the running macOS applications for resize behavior, keyboard focus, loading/errors, and visual quality; run Windows integration tests on a Windows runner and record any limits of interactive UI verification.
7. Reproducibility: validate clone-to-run instructions from a clean checkout, including database setup, API URL configuration, test commands, and release builds.

Plan the macOS process manager as an unsandboxed local desktop app because its purpose requires controlling other processes. Apply this consistently to Debug/Profile/Release and verify a release app launched from Finder. Verify ARP access and networking inside the actual network app before choosing its sandbox settings. These are desktop development/distribution targets, without an App Store compatibility promise.

Unsigned development artifacts are the initial delivery target. Signing, notarization, and store publication require a separate distribution setup and are not assumed. Report compiled, automatically exercised, and manually inspected platforms separately.

## Professional README and supporting documentation

The README should let a reviewer understand the project quickly and run either option without searching through source code:

1. Original project banner, concise purpose, and real build-status badges.
2. Side-by-side application previews using actual running-app screenshots, with synthetic example data for public visuals.
3. Clear option comparison and links to each app's entry point.
4. Compact architecture diagram showing local OS operations, desktop apps, Rails, SQLite, and the vendor service.
5. Prerequisite/version table and copy-paste clone/setup/run commands for macOS and Windows.
6. API startup, database preparation, API URL configuration, and separate commands for each desktop app.
7. Testing and release-build instructions; download links once artifacts exist.
8. Brief engineering decisions, ARP/network limits, process permission behavior, audit retry behavior, and troubleshooting.
9. Factual AI collaboration notes linked to a more detailed development log.

Use readable typography, restrained color, alt text, and working relative links. Visuals must show implemented behavior; avoid placeholder screenshots or claims unsupported by test/build evidence.

## Completion criteria

- Public repository exists under the verified `ConnorDykes` account with the requested display title.
- Both assignment options are implemented, independently runnable, and connected to the Rails API.
- Both apps produce macOS and Windows artifacts, with actual build and test outcomes recorded.
- Required Rails tests and meaningful client/platform tests pass.
- Clean-clone setup instructions work and required configuration is documented.
- README visuals, architecture, API reference, and AI development notes match the final implementation.
- No unresolved material correctness findings; any unverified environment behavior is clearly disclosed.

## Reference documentation

- [Flutter desktop support](https://docs.flutter.dev/platform-integration/desktop)
- [Flutter macOS building and entitlements](https://docs.flutter.dev/platform-integration/macos/building)
- [Flutter Windows building and distribution](https://docs.flutter.dev/platform-integration/windows/building)
- [Rails getting started](https://guides.rubyonrails.org/getting_started.html)
