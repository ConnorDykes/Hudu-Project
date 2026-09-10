# AI-assisted development

Both take-home options were implemented at Connor's request using a main orchestration agent and scoped implementation/review subagents. This log describes actual work on September 10, 2026; it does not imply human review or independent authorship.

## Delegation and integration

| Owner | Responsibility |
| --- | --- |
| Main orchestrator | Requirements, canonical contracts, shared Flutter package, toolchains, integration tests, review, GitHub delivery |
| API worker | Rails endpoints, vendor service, SQLite persistence, API tests |
| Network worker | Flutter lookup UI, macOS/Windows network adapters, tests and preview |
| Process worker | Flutter process UI, native adapters, audit outbox, tests and preview |
| Build worker | Bash/PowerShell scripts, native CI matrix, archive packaging |
| Documentation worker | README, architecture/API/setup documentation, original SVG banner |
| Independent API/shared/build reviewer | Read-only source review and separate API checks |
| Independent app reviewer | Read-only app review and targeted re-review of corrections |

The main agent established contracts before parallel app implementation. Workers had disjoint directory ownership, returned concrete test evidence, and did not commit or push. Cross-cutting changes went through the main agent. The main agent inspected the changes, reran meaningful checks, tested real HTTP boundaries, and integrated the work.

## Review findings and corrections

| Finding | Correction and evidence |
| --- | --- |
| A valid live JSON POST returned 400 although health worked | Rails 8.1.3.1's positional parser options conflicted with JSON 3. The API worker constrained JSON below 3, locked 2.21.2, and added a raw-request regression. Main live retest returned 201 with persisted vendor data. |
| Client microsecond timestamps could disagree with millisecond API acknowledgments | Normalize event creation to milliseconds and retain stable event identity/time for retries. Regression tests and real repository-to-Rails tests pass. |
| A delivery-triggered history refresh could be dropped behind an older request | The app reviewer identified the interleaving. The process worker serialized requests and queued a follow-up refresh; a controlled delayed-response regression passes. Reviewer re-review accepted the fix. |
| An older audit upload could clear a newer event's storage warning | Evaluate the live queue before clearing the warning. A delayed-upload regression proves a newly failed disk write remains visible and blocks further termination. Reviewer re-review accepted the fix. |
| The UI could label a memory-only event as saved locally | Prioritize the storage warning, explicitly say the event is only in memory, and add widget regressions both with and without a simultaneous network error. |
| Preview fonts/icons differed from intended production rendering | Bundle the OFL Inter font and load both it and Material icons in golden tests. Main visually inspected the resulting production-widget previews. |
| Runner CPU labels need not match a universal macOS binary | Inspect Mach-O slices during packaging and label dual-architecture archives universal. Main inspected app and Dart framework architectures. |
| Windows native network smoke exceeded the original eight-second watchdog | Reopened the network worker's scope. Windows discovery now shares one 30-second budget including startup, with explicit loading text and no retries. Main independently passed deadline, controller, widget, native, and real API tests. |
| Late-start timeout cleanup could retain unread output pipes | The independent reviewer identified the resource edge case. The worker added cancellation of both pipes, buffered-output/refused-termination regressions, and truthful timeout wording. Targeted re-review accepted the correction. |

The independent API/shared/build reviewer returned no actionable findings. The app review's two concurrency findings and subsequent timeout-cleanup finding were corrected before final delivery. Test results are not substituted for review: both source inspection and runtime checks were performed.

## Verification and public delivery

The main agent independently ran API tests, lint/security checks, Flutter analysis/tests, real vendor requests, idempotent audit requests, and native macOS adapter tests. Process tests use disposable harness children only. A fresh public clone passed the documented setup/check script and a macOS release build; after the review fixes, the updated clean clone passed both final app suites.

GitHub Actions additionally runs Linux API/client checks, Docker HTTP/persistence checks, native macOS and Windows tests, and all four release builds. Exact counts, tested revision, workflow evidence, and verification limits are recorded in [verification results](verification-results.md). Reproducible commands are in [testing](testing.md).

The README uses original SVG project artwork and real production-widget renders with synthetic data. No private machine/network data or copied corporate artwork was published.

## Deliberate limits

The Mac was locked during attempted interactive inspection; this was reported and no lock bypass was attempted. Manual native GUI verification is not claimed. Windows/WSL2 developer networking was documented but not manually exercised. The release contains development bundles, not signed/notarized installers, and the Rails API runs separately.

The public vendor service is an external dependency. Process exit and local audit persistence cannot form a single transaction: a crash in that gap can lose an event. macOS identity revalidation reduces but cannot eliminate PID reuse races. These limits are documented rather than hidden behind a success message.
