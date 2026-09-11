# Current verification results

## Rails follow-up review — September 11, 2026

The Rails source review after v1.1.0 passes **57 tests / 630 assertions**, with 40 Ruby files clean under RuboCop, no Brakeman warnings or dependency advisories, and successful development/production autoload checks. A fresh isolated production database and server passed both clients' real HTTP smoke suites (two Network Lookup cases, one Process Manager case), using a seeded vendor for the lookup round trip. Production JSON 500 responses and HEAD semantics were also checked in a production-mode Rails process. These are local verification results for the source follow-up; the v1.1.0 download archives are unchanged. See the [Rails review](rails-review.md) for scope, corrections, and limits.

## Published v1.1.0 evidence

Submission release: **v1.1.0**. Checked September 10, 2026 (America/Denver; September 11 UTC). The records below describe that published revision; its 46-test Rails total predates the follow-up review. Historical counts and previous release evidence are kept in the [historical verification record](verification-history.md).

## Revision and release

- Application code: [012c7ba](https://github.com/ConnorDykes/Hudu-Project/commit/012c7ba06add85667b5b17a40d07f019c0ae0669).
- Release CI: **all nine jobs passed** in [run 34561343251](https://github.com/ConnorDykes/Hudu-Project/actions/runs/34561343251), including all four native app/platform builds.
- Distribution: [v1.1.0 development release](https://github.com/ConnorDykes/Hudu-Project/releases/tag/v1.1.0), containing the four unmodified archives from that run and `SHA256SUMS.txt`. The release tag adds documentation only after the application code above. The README links to these current archives; v1.0.0 predates the current UI, vendor naming, and batch termination.

## v1.1.0 local evidence

`bash scripts/dev.sh check` passed with the pinned Ruby 4.0.2 and Flutter 3.47.2 toolchains. Both apps are versioned **1.1.0+2** for the native release builds.

| Area | Result |
| --- | --- |
| Rails API | **46 tests / 502 assertions**, zero failures, errors, or skips; RuboCop: 38 files clean; Brakeman: zero warnings; dependency advisory audit: no vulnerabilities found. |
| Shared Flutter package | **9 tests**, analysis clean. |
| Network Lookup | **45 passing default tests**, analysis clean; includes native macOS interface/cache checks. Four opt-in HTTP/golden cases skipped. |
| Process Manager | **46 passing default tests**, analysis clean; includes native macOS termination of a disposable harness child. Four opt-in HTTP/golden cases skipped. |
| Screenshots | All **three** Process Manager production-widget golden comparisons pass, including the batch confirmation. Existing gallery images still match. |

The default Flutter total is **100 passing tests = 9 shared + 45 network + 46 process** on macOS. Opt-in screenshot and HTTP cases are separate; Linux skips native cases. Test totals are not coverage percentages.

## Hosted and archive evidence

| Area | Result |
| --- | --- |
| Hosted checks | Rails tests/lint/security and all three Flutter package checks pass. |
| API container | Compose startup, JSON event creation, restart, idempotent retry, and persistence checks pass. |
| Native integration | Both apps pass native adapter tests on macOS and Windows. Both macOS jobs also pass the real Flutter repository-to-Rails smoke tests. Process smoke tests terminate only disposable harness children. |
| Release builds | Both apps build and package successfully on macOS and Windows. |
| Archive validation | All four downloaded CI ZIPs pass integrity, relative-path, required runtime/data, bundled font, and font-license checks. SHA-256 checksums accompany the release. |
| Binary metadata | Both macOS executables and Dart App frameworks contain x86_64 and arm64 slices; app metadata reports version 1.1.0, build 2, minimum macOS 12.0. Both Windows executables are PE32+ x86-64. |

## Submission corrections

- **Stop on audit storage failure:** after a confirmed exit cannot be written to disk, the remaining batch targets are not attempted. The original event stays in memory, remaining targets stay selected, and the notice explains that a new confirmation is required after recovery. A regression verifies that retrying delivery preserves the original audit and never terminates the skipped processes.
- **Review every target:** the confirmation lists every selected name and PID in a bounded scrolling area. A 20-process widget test at the minimum 960 x 680 window size scrolls to the final PID, cancels without terminating anything, then confirms a fresh batch and verifies all 20 actions.
- **Matching release:** both apps are rebuilt from the release code above, including the current design, local vendor table and naming, inline/batch termination, and the submission corrections.

## Verification boundaries

- Interactive native GUI inspection remains uncompleted. The earlier attempt was blocked by a locked Mac; this pass used automated widget/golden and native adapter tests. Neither manual macOS nor manual Windows GUI testing is claimed.
- Windows/WSL2 developer networking has not been manually exercised. Fresh-clone setup evidence belongs to the earlier checkpoints linked in the historical record.
- The Rails API runs separately and has no authentication; keep it on loopback. The archives are development bundles without verified Developer ID signing, notarization, Windows Authenticode signing, or installers.
- Public vendor availability and rate limits can change. API tests stub that service; an earlier live vendor check is historical evidence, not a current availability guarantee.
- macOS retains a PID race after identity validation. A crash between observing exit and durable outbox persistence can lose an audit event. The batch fix stops further actions after a detected disk failure; it does not make OS termination and storage atomic.

Reproducible commands and the hosted job matrix are in [Testing](testing.md).
