# Rails review — September 11, 2026

Reviewed the API controllers, models, services, migrations/schema, seeds, test suite, environment configuration, dependencies, bin scripts, Docker setup, and Rails CI checks. This source follow-up builds on published v1.1.0; it does not create a new desktop release.

## Corrections

| Finding | Change and evidence |
| --- | --- |
| Production could not boot: `64.megabytes` was evaluated before the numeric extension loaded. | Explicitly require the extension. Fresh production database preparation, server startup, and autoload checks pass; CI now includes production autoloading. |
| `rescue_from StandardError` intercepted Rails' normal exception handling and hid unexpected test failures. | Use `config.exceptions_app` to format production JSON errors. Rails retains logging/reporting and unexpected test exceptions propagate. Integration tests cover 400/405/406/500, malformed query structure, and HEAD responses without bodies. |
| Vendor normalization accepted malformed input such as `0:21:12:2` and mixed separators. | Validate the complete OUI/MAC syntax before normalization. Supported colon, hyphen, and unseparated forms still work. Invalid model/API input is rejected. |
| Only successful provider responses had a body-size limit; Net::HTTP could buffer unread error bodies. | Stream every response status through the same 1 KiB limit and discard error text. Oversized 404/429/500 regressions pass. Reject premature EOF for declared response lengths. |
| Reloading seeds redefined a top-level constant and emitted warnings. | Use a local seed-data variable; repeated loads are silent and preserve user-named vendors. |
| Advisory configuration contained a placeholder ignored CVE. | Use an empty ignore list; the advisory audit passes with no exceptions. |

The exception handling follows Rails' guidance against catching `StandardError` in controllers and uses its documented exception application hook. [Rails controller guidance](https://guides.rubyonrails.org/action_controller_advanced_topics.html#rescue-from), [ShowExceptions](https://api.rubyonrails.org/classes/ActionDispatch/ShowExceptions.html).

## Verification

- **57 Rails tests / 630 assertions**, zero failures, errors, or skips. Added coverage includes the corrections, vendor insertion races, database uniqueness, cache expiry, and local vendor precedence over cached unknown results.
- **40 Ruby files** pass the repository's Rails Omakase RuboCop configuration. Brakeman and the refreshed dependency advisory audit report no findings.
- Development and production `zeitwerk:check` pass. A fresh isolated production database was prepared and served on loopback with TLS redirects disabled for that local check.
- Both real desktop repository smoke suites pass against that production API: two Network Lookup cases (including a seeded-vendor POST/history round trip), and a Process Manager disposable-child termination, audit delivery, duplicate retry, and history readback.
- A separate production-mode Rails process returns the expected sanitized JSON 500 envelope and an empty HEAD response body for an injected exception.
- All **31** seed prefixes were found in the [IEEE OUI registry](https://standards-oui.ieee.org/oui/oui.csv). The existing display labels are human-readable manufacturer labels and can differ in capitalization or corporate naming from the registry.
- The Flutter application code and v1.1.0 download archives were not changed. The production CI step was exercised locally with its configured environment; hosted results are recorded separately in [verification results](verification-results.md).

## Decisions to explain in the interview

- **Thin controllers, model validation, service boundary:** controllers coordinate requests, models enforce data rules, and the vendor service owns external HTTP behavior. Explicit serialization keeps internal fields out of the API. The app uses the Rails-generated Omakase style rather than a separate custom style system.
- **Strict JSON types:** selected validations inspect `*_before_type_cast` so Rails does not silently accept a numeric process name or a string PID through coercion. This is why these checks are more explicit than presence/numericality alone.
- **Idempotency:** a stable event UUID and a database unique index protect retries. An identical request returns 200; conflicting reuse returns 409. The index is essential under concurrent requests; a model uniqueness check alone would not eliminate the race. [Rails uniqueness guidance](https://guides.rubyonrails.org/active_record_validations.html#uniqueness).
- **GET compatibility:** `GET /lookups?mac=...` exists to match the brief. The desktop uses POST because a lookup creates a history record; plain GET reads history.
- **Deliberate limits:** SQLite and a per-process memory cache suit this local take-home. Cache entries expire after 24 hours, but the cache is not a global provider-rate limiter. HTTP timeouts limit inactivity, not total elapsed request time; no hard wall-clock deadline is claimed. The API trusts client-reported exits and provides no authentication, so it stays on loopback.

This review is evidence of specific checks and corrections, not a guarantee of defect-free software. The published release's broader platform and GUI verification limits remain in [verification results](verification-results.md).
