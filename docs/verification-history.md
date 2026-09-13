# Historical verification record

These are historical checks from the development passes on September 10 and 11, 2026, newest first. Counts and revisions below describe those checkpoints. See [current verification results](verification-results.md) for the submission revision, release artifacts, and current test totals.

## Rails review (September 11, 2026)

Reviewed the API controllers, models, services, migrations/schema, seeds, test suite, environment configuration, dependencies, bin scripts, Docker setup, and Rails CI checks. This source follow-up builds on published v1.1.0; it does not create a new desktop release.

### Corrections

| Finding | Change and evidence |
| --- | --- |
| Production could not boot: `64.megabytes` was evaluated before the numeric extension loaded. | Explicitly require the extension. Fresh production database preparation, server startup, and autoload checks pass; CI now includes production autoloading. |
| `rescue_from StandardError` intercepted Rails' normal exception handling and hid unexpected test failures. | Use `config.exceptions_app` to format production JSON errors. Rails retains logging/reporting and unexpected test exceptions propagate. Integration tests cover 400/405/406/500, malformed query structure, and HEAD responses without bodies. |
| Vendor normalization accepted malformed input such as `0:21:12:2` and mixed separators. | Validate the complete OUI/MAC syntax before normalization. Supported colon, hyphen, and unseparated forms still work. Invalid model/API input is rejected. |
| Only successful provider responses had a body-size limit; Net::HTTP could buffer unread error bodies. | Stream every response status through the same 1 KiB limit and discard error text. Oversized 404/429/500 regressions pass. Reject premature EOF for declared response lengths. |
| Reloading seeds redefined a top-level constant and emitted warnings. | Use a local seed-data variable; repeated loads are silent and preserve user-named vendors. |
| Advisory configuration contained a placeholder ignored CVE. | Use an empty ignore list; the advisory audit passes with no exceptions. |

The exception handling follows Rails' guidance against catching `StandardError` in controllers and uses its documented exception application hook. [Rails controller guidance](https://guides.rubyonrails.org/action_controller_advanced_topics.html#rescue-from), [ShowExceptions](https://api.rubyonrails.org/classes/ActionDispatch/ShowExceptions.html).

### Verification

- **57 Rails tests / 630 assertions**, zero failures, errors, or skips. Added coverage includes the corrections, vendor insertion races, database uniqueness, cache expiry, and local vendor precedence over cached unknown results.
- **40 Ruby files** pass the repository's Rails Omakase RuboCop configuration. Brakeman and the refreshed dependency advisory audit report no findings.
- Development and production `zeitwerk:check` pass. A fresh isolated production database was prepared and served on loopback with TLS redirects disabled for that local check.
- Both real desktop repository smoke suites pass against that production API: two Network Lookup cases (including a seeded-vendor POST/history round trip), and a Process Manager disposable-child termination, audit delivery, duplicate retry, and history readback.
- A separate production-mode Rails process returns the expected sanitized JSON 500 envelope and an empty HEAD response body for an injected exception.
- All **31** seed prefixes were found in the [IEEE OUI registry](https://standards-oui.ieee.org/oui/oui.csv). The existing display labels are human-readable manufacturer labels and can differ in capitalization or corporate naming from the registry.
- The Flutter application code and v1.1.0 download archives were not changed. The production CI step was exercised locally with its configured environment; hosted results are recorded in [verification results](verification-results.md).

### Decisions to explain in the interview

- **Thin controllers, model validation, service boundary:** controllers coordinate requests, models enforce data rules, and the vendor service owns external HTTP behavior. Explicit serialization keeps internal fields out of the API. The app uses the Rails-generated Omakase style rather than a separate custom style system.
- **Strict JSON types:** selected validations inspect `*_before_type_cast` so Rails does not silently accept a numeric process name or a string PID through coercion. This is why these checks are more explicit than presence/numericality alone.
- **Idempotency:** a stable event UUID and a database unique index protect retries. An identical request returns 200; conflicting reuse returns 409. The index is essential under concurrent requests; a model uniqueness check alone would not eliminate the race. [Rails uniqueness guidance](https://guides.rubyonrails.org/active_record_validations.html#uniqueness).
- **GET compatibility:** `GET /lookups?mac=...` exists to match the brief. The desktop uses POST because a lookup creates a history record; plain GET reads history.
- **Deliberate limits:** SQLite and a per-process memory cache suit this local take-home. Cache entries expire after 24 hours, but the cache is not a global provider-rate limiter. HTTP timeouts limit inactivity, not total elapsed request time; no hard wall-clock deadline is claimed. The API trusts client-reported exits and provides no authentication, so it stays on loopback.

This review is evidence of specific checks and corrections, not a guarantee of defect-free software. The published release's broader platform and GUI verification limits remain in [verification results](verification-results.md).

## Revisions and CI

- Initial implementation: [35a1f56](https://github.com/ConnorDykes/Hudu-Project/commit/35a1f566dafac6e4970e934d7004b53675259140). [All nine CI jobs passed](https://github.com/ConnorDykes/Hudu-Project/actions/runs/34513399505), including four native app/platform builds.
- Audit review fixes: [7a4ecb8](https://github.com/ConnorDykes/Hudu-Project/commit/7a4ecb8e6c59de2e88f038562b4c6c79cf562288). Its [CI run](https://github.com/ConnorDykes/Hudu-Project/actions/runs/34514570473) passed eight jobs but exposed the Windows network command's eight-second timeout. This failure was investigated, not skipped or hidden by a retry.
- v1.0.0 code: [3f43162](https://github.com/ConnorDykes/Hudu-Project/commit/3f4316293561a240d7d53c87cdf8ac4e80c1a7b1), adding bounded Windows cold-start headroom and cleanup regressions. [All nine v1.0.0 CI jobs passed](https://github.com/ConnorDykes/Hudu-Project/actions/runs/34515948693), including all four release builds and artifact uploads.
- The v1.0.0 tag added documentation only after that code revision. Later hardening, design, scope, and feature passes below changed application code and are not included in the v1.0.0 binaries.

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
- **Container:** the image now runs as an unprivileged `rails` user (uid 1000) with only `storage`, `tmp`, `log`, and `db` writable. Docker was unavailable on the review host, so this is verified by the hosted Compose CI job rather than locally. SQLite remains the store; `DATABASE_URL` switches adapters without code changes once the matching gem is added.

## Design pass (September 10, 2026)

The first-pass UI was rebuilt as a quiet desktop utility: neutral graphite/paper surfaces that follow the system theme, one blue accent, hairline borders, sentence-case labels, Inter plus bundled JetBrains Mono for identifiers, and status shown as a dot and a word. Taglines, explainer cards, metric tiles, and per-row badges were removed; the header names the view and carries only its actions. Motion is limited to 120–260 ms eased cross-fades between result states, hover and selection transitions, a spinning refresh glyph, a thin busy bar, and skeleton rows while history loads. Process Manager gained keyboard control: Cmd/Ctrl+F focuses search, Escape clears it and returns focus to the table, arrow keys move the selection, Cmd/Ctrl+R refreshes. Controllers, repositories, and adapters were not changed. All widget suites pass against the new UI (9 shared, 41 network, 40 process); the README previews are regenerated dark-theme goldens.

## Scope pass (September 10, 2026)

The apps and API were re-read against the brief and trimmed to what it asks for:

- **Network Lookup** is one view: address field, "Use my IP" (the optional primary-address challenge), the result, and the API history. The interface picker, the separate History tab, keyboard shortcuts, and the copy button were removed; the adapter no longer takes an interface parameter.
- **Process Manager** keeps its two views (processes, audit history) and its keyboard control; the sidebar footer slogan and the long dialog note were cut.
- **Rails** now also serves `GET /lookups?mac=...` as the brief illustrates, alongside the client's `POST /lookups`; demo seeds were removed.
- **Shell** hides the sidebar when there is only one view. Evidence: Rails **40 tests**, RuboCop and Brakeman clean; Flutter **9 + 41 + 40 = 90 tests**, analysis clean; goldens regenerated.

## Feature pass (September 10, 2026)

- **Local vendors:** a `vendors` table keyed by OUI answers lookups before the public provider. `db/seeds.rb` loads about thirty IEEE OUI registrations for common manufacturers idempotently; `POST /vendors` lets a user name a vendor for a MAC that nothing recognized, and the desktop app offers this after an `unknown` result, then repeats the lookup. Rails **46 tests / 502 assertions**, RuboCop and Brakeman clean.
- **Batch termination:** Process Manager rows have a checkbox and an inline Terminate button; a select-all header checkbox and a footer action terminate the selection in one confirmed pass. Each confirmed exit is audited on its own and one refusal never stops the others. The Status column was removed; protected, exited, and self rows are annotated inline and cannot be terminated. Flutter **9 + 45 + 44 = 98 tests**, analysis clean; goldens regenerated.

## Remaining boundaries

- Interactive native GUI inspection was blocked by the locked Mac. No lock bypass was attempted. Neither Mac interactive review nor Windows manual GUI testing is claimed.
- Windows native adapters and binaries are tested in hosted CI; the Windows/WSL2 developer-networking instructions have not been manually exercised.
- Archives are development bundles without verified Developer ID signing, notarization, Windows Authenticode signing, or installers. The API runs separately and has no authentication; keep it on loopback.
- Public vendor availability/rate limits may change. Deterministic API tests stub that service.
- macOS PID signaling retains a race after identity validation. A crash between observing exit and durable outbox persistence can lose an audit event. File recovery is tested, not a claim of atomic OS termination plus storage.
