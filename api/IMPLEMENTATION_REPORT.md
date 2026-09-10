# API implementation handoff — 2026-09-10

All implementation changes are inside `api/`. No commits or pushes performed.
Root contracts and other workers' directories were not changed.

## Changed files

Paths below are relative to `api/`; unchanged scaffold files are omitted.

- `Gemfile`, `Gemfile.lock`: Ruby/Rails versions, JSON compatibility constraint,
  HTTP and test dependencies; Linux ARM64/x86-64 lockfile platforms.
- `app/controllers/application_controller.rb`, `health_controller.rb`,
  `lookups_controller.rb`, `process_events_controller.rb`: top-level strong
  parameters, validation/errors, database health, creation and paginated history.
- `app/models/lookup.rb`, `process_event.rb`: normalization, validation,
  contract serialization, event payload comparison.
- `app/services/pagination.rb`, `vendor_lookup.rb`: bounded pagination and
  HTTPS provider adapter with safe error mapping and bounded execution.
- `db/migrate/20260910000001_create_lookups.rb`,
  `db/migrate/20260910000002_create_process_events.rb`, `db/schema.rb`:
  persisted histories, sort indexes, event-ID unique index and DB constraints.
- `db/seeds.rb`: opt-in synthetic display fixtures; empty default preparation.
- `config/application.rb`, `config/database.yml`,
  `config/environments/development.rb`, `config/routes.rb`, `config/ci.rb`:
  API-only configuration, SQLite paths, routes and checks.
- `test/test_helper.rb`, `test/integration/api_errors_test.rb`,
  `test/integration/lookups_test.rb`, `test/integration/process_events_test.rb`,
  `test/models/lookup_test.rb`, `test/models/process_event_test.rb`,
  `test/models/seeds_test.rb`, `test/services/vendor_lookup_test.rb`:
  deterministic request/model/service coverage with all external network calls
  disabled by WebMock.
- `Dockerfile`, `.dockerignore`, `bin/docker-entrypoint`: optional Ruby 4.0.2
  development container, automatic DB preparation, `/rails/storage` persistence.
- `README.md`, `IMPLEMENTATION_REPORT.md`: run commands and verification handoff.

Removed unused generated `app/jobs/application_job.rb`, `bin/thrust`,
`config/initializers/cors.rb`, `config/credentials.yml.enc`, and
`config/master.key`. The generated credentials were unused; development boots
without them. New credentials can be generated if a future deployment needs them.

## Checks actually run

- `bundle install`: succeeded; JSON locked to 2.21.2.
- `bundle lock --add-platform x86_64-linux aarch64-linux`: succeeded.
- `bin/rails db:prepare`: succeeded against development and isolated smoke DBs.
- `CI=1 bin/rails test`: **39 runs, 438 assertions, 0 failures, 0 errors, 0 skips**.
  Includes real raw-JSON parsing, persisted provider failures, malformed JSON,
  pagination, timestamp precision, database uniqueness enforcement and simulated
  insert-race handling, conflicting retries, and opt-in seed idempotency.
- `bin/rubocop --format simple`: **34 files inspected, no offenses**.
- `bin/rails zeitwerk:check`: **All is good**.
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`:
  **0 errors, 0 security warnings**, Brakeman 8.0.6.
- `bin/bundler-audit check --update`: **No vulnerabilities found** using advisory
  database commit `93b32f641f84282183ce58ab1d7204bee50885bd`.
- `bundle check`: dependencies satisfied.
- `sh -n bin/docker-entrypoint`: passed.
- Fresh development boot with both `SECRET_KEY_BASE` and `RAILS_MASTER_KEY`
  unset: `GET /health` returned 200; no credentials file exists.
- Independent development Puma on localhost port 3101 accepted the exact raw
  `{"mac":"001B638445E6"}` JSON body and returned 201 with normalized MAC,
  `Apple, Inc.`, and a persisted resolved lookup. Its isolated SQLite file is
  ignored under `storage/`. Only that temporary server was stopped; the main
  agent's port-3000 server was untouched.
- Provider primary documentation at <https://macvendors.com/api> was checked.
  Separate direct HTTPS and implemented-adapter smoke checks returned
  `Apple, Inc.` for `00:1B:63:84:45:E6`. No live provider calls are in the test suite.

## Integration notes and limitations

- A server started before the dependency fix must be restarted. Rails 8.1.3.1
  calls `JSON.parse(json, options)`; JSON 3.0.2 rejects the positional options
  hash, causing valid requests to look like malformed JSON. `json < 3` fixes
  this at dependency resolution; raw request tests guard against regression.
- Every syntactically valid 48-bit MAC is accepted; no semantic rejection of
  zero, broadcast, multicast, or locally administered addresses was added.
- Timestamps accept an explicit timezone and up to six fractional digits,
  persist microseconds, and serialize UTC milliseconds. Retries retain their
  original payload; UUID case and equivalent timezone offsets normalize.
- Process names are nonblank strings capped at 255 characters. PIDs are
  positive JSON integers within SQLite's signed 64-bit range. Optional IP may
  be omitted/null. Pagination outside the documented bounds returns 422.
- Vendor requests have no automatic retries or client-facing upstream bodies.
  The free provider's documented limits are one request/second and 1,000/day.
- Docker is unavailable on this host: the Dockerfile/entrypoint and Linux
  lockfile are supplied, but an image build and container runtime were **not
  verified**. Infrastructure's root Compose owns localhost port publishing.
