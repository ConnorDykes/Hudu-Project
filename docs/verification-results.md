# Verification results

Checks performed on September 10, 2026. A native adapter test, compiled binary, and interactive GUI review are different kinds of evidence; this record does not conflate them.

## Revisions and CI

- Initial implementation: [35a1f56](https://github.com/ConnorDykes/Hudu-Project/commit/35a1f566dafac6e4970e934d7004b53675259140). [All nine CI jobs passed](https://github.com/ConnorDykes/Hudu-Project/actions/runs/34513399505), including four native app/platform builds.
- Audit review fixes: [7a4ecb8](https://github.com/ConnorDykes/Hudu-Project/commit/7a4ecb8e6c59de2e88f038562b4c6c79cf562288). Its [CI run](https://github.com/ConnorDykes/Hudu-Project/actions/runs/34514570473) passed eight jobs but exposed the Windows network command's eight-second timeout. This failure was investigated, not skipped or hidden by a retry.
- Final code: [3f43162](https://github.com/ConnorDykes/Hudu-Project/commit/3f4316293561a240d7d53c87cdf8ac4e80c1a7b1), adding bounded Windows cold-start headroom and cleanup regressions. [All nine final CI jobs passed](https://github.com/ConnorDykes/Hudu-Project/actions/runs/34515948693), including all four release builds and artifact uploads.
- Documentation-only changes after the final code revision do not alter the tested binaries.

## Executed checks

| Area | Evidence |
| --- | --- |
| Rails API | Main independently reran **39 tests / 438 assertions**, zero failures/errors/skips. RuboCop: 34 files clean. Brakeman: zero warnings. Dependency advisory audit: clean. |
| Shared Flutter package | Analysis clean; **7 tests** pass, including HTTP behavior and layout/navigation at two window sizes. |
| Network Lookup | Analysis clean; **41 default tests** pass on macOS, with three opt-in cases skipped. This includes native interfaces/cache and own-IP checks, shared operation deadlines, process-start timing, pipe cleanup, and Windows loading text. Two opt-in real Rails tests pass, including a live vendor lookup; the production-widget golden comparison also passes. |
| Process Manager | Analysis clean; **37 default tests** pass on macOS, with two opt-in cases skipped. Includes a real disposable-child termination, audit outbox recovery, concurrent delivery/history regressions, and storage-warning widget cases. The real Rails audit smoke also passes. |
| Live HTTP | Health 200; lookup 201 with persisted Apple vendor; disposable-child audit 201, identical retry 200, conflicting retry 409, and history readback. |
| Container | Hosted Compose test passes startup, JSON event creation, service restart, identical retry, and persistence readback. |
| Native platforms | Final hosted run passes native adapter tests and release builds for both apps on macOS and Windows. The Windows network interface stage takes 8,491 ms, neighbor cache 816 ms, and own-IP metadata 1,983 ms; every native assertion passes. Only test-harness-created processes are terminated. |
| Local release builds | Both macOS release builds pass. Main inspected the app executables and Dart frameworks: both have Intel x86_64 and Apple Silicon arm64 slices; minimum macOS version 12.0. |
| Downloadable archives | Main downloaded all four final CI archives and passed ZIP integrity, safe-path, runtime/data, and bundled font-license checks. Extracted macOS executables and Dart frameworks are universal with minimum macOS 12.0; Windows executables are PE32+ x86-64. The [v1.0.0 development release](https://github.com/ConnorDykes/Hudu-Project/releases/tag/v1.0.0) includes the original ZIPs and SHA-256 checksums. |
| Clean clone | A fresh clone of the public repository passes `bash scripts/dev.sh setup`, `bash scripts/dev.sh check`, and the Network Lookup macOS release build. Following the reviewed fixes, the updated clean clone separately passes all 37 Process Manager and 41 Network Lookup tests. Main also rebuilt the final Network Lookup macOS release locally. |
| Visuals | Original SVG banner and both actual production-widget previews were rendered and visually inspected. Previews use synthetic records, bundled Inter, and Material icons; they contain no private machine data. |
| Independent review | API/shared/build reviewer: no actionable findings. App reviewer: two concurrency findings, both corrected with regression tests and accepted in targeted re-review. |

The **85-test Flutter total** is 7 shared + 41 network + 37 process tests on macOS. Linux skips native cases; screenshots and real HTTP tests are opt-in and are not included in that default total. These counts are not code-coverage percentages.

## Integration corrections

1. **JSON compatibility:** a real request exposed Rails 8.1.3.1's parser incompatibility with JSON 3. The dependency is constrained below 3 and locked to 2.21.2; raw-request regression and independent live retest pass.
2. **Audit acknowledgment precision:** event creation uses millisecond timestamps matching API serialization; retry identity/time stay stable. Regression and real API tests pass.
3. **Concurrent history refresh:** a queued follow-up prevents an older GET from leaving history stale after audit delivery. Controlled delayed-response regression passes.
4. **Concurrent storage failure:** an older successful upload cannot clear a newer memory-only event's warning. Controller and widget regressions preserve the warning and prevent a false “Saved locally” label.
5. **Windows discovery timeout:** CI proved that an eight-second command deadline was exceeded; cold PowerShell/CIM initialization is the likely explanation, not a measured root-cause guarantee. Windows now has one shared 30-second discovery deadline including startup. No automatic retries or native-test skips were added. A read-only reviewer caught unconsumed pipes on the late-start cleanup path; both pipes are now cancelled, with buffered-output and refused-termination regressions. Targeted re-review found no remaining actionable issue.

## Hardening pass (September 10, 2026, after 3f43162)

A second review pass focused on production readiness rather than features. Changes and the evidence gathered for them:

- **Rails:** removed `Timeout.timeout` around the vendor request (unsafe inside threaded Puma; Net::HTTP phase timeouts already bound the call); resolved and unknown vendor answers are now cached per MAC for 24 hours and failures are logged by error class; a `rescue_from StandardError` returns the same JSON envelope with `500 internal_error` and reports through `Rails.error`; pagination parsing was simplified; production `force_ssl`/`assume_ssl` are controlled by `FORCE_SSL` so a loopback deployment without TLS is not redirected; the silenced health path is `/health`; MAC normalization no longer adds duplicate validation errors.
- **Flutter:** `ApiClient` keeps the HTTP status when an error body is not JSON, treats TLS/socket errors as unreachable, and exposes `isTransient`; the audit retry loop skips a rejected event (4xx) instead of blocking the rest of the queue while still stopping at the first transport failure; audit records from the API are validated instead of cast; native command success is decided by exit code alone, and one unrecognized `arp`/`ps` line no longer fails a whole read.
- **Evidence:** Rails **41 tests / 447 assertions**, RuboCop, Brakeman, and Zeitwerk clean. Flutter **9 shared + 41 network + 39 process = 89 tests**, analysis clean. Both opt-in real-Rails smoke suites pass against a local server. A live `POST /lookups` returned the Apple vendor in 343 ms and the cached repeat in 7 ms; 400/404/422 envelopes were checked by hand. Both apps were launched on macOS against the running API.
- **Not changed:** the Docker image still runs as root because Docker was unavailable on the review host; adding a non-root user is the next container hardening step. SQLite remains the store; `DATABASE_URL` switches adapters without code changes once the matching gem is added.

## Remaining boundaries

- Interactive native GUI inspection was blocked by the locked Mac. No lock bypass was attempted. Neither Mac interactive review nor Windows manual GUI testing is claimed.
- Windows native adapters and binaries are tested in hosted CI; the Windows/WSL2 developer-networking instructions have not been manually exercised.
- Archives are development bundles without verified Developer ID signing, notarization, Windows Authenticode signing, or installers. The API runs separately and has no authentication; keep it on loopback.
- Public vendor availability/rate limits may change. Deterministic API tests stub that service.
- macOS PID signaling retains a race after identity validation. A crash between observing exit and durable outbox persistence can lose an audit event. File recovery is tested, not a claim of atomic OS termination plus storage.
