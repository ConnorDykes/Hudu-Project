# Hudu API

Rails **8.1.3.1**, Ruby **4.0.2**, SQLite. Run from this directory:

```sh
# Homebrew Ruby on Apple Silicon, when using that installation:
export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/4.0.0/bin:$PATH"
bundle install
bin/rails db:prepare
bin/rails server -b 127.0.0.1 -p 3000
```

No API key, master key, or production secret is required in development. History
lives in `storage/development.sqlite3`. `db:prepare` seeds about thirty manufacturer
OUIs into `vendors` on a fresh database; run `bin/rails db:seed` to add them to an
existing one (user-named vendors are never overwritten). This is
an unauthenticated local API; keep the host binding on localhost.

```sh
curl http://127.0.0.1:3000/health
curl -X POST http://127.0.0.1:3000/lookups \
  -H 'Content-Type: application/json' \
  -d '{"mac":"00:1B:63:84:45:E6","ip":"192.0.2.10"}'
curl 'http://127.0.0.1:3000/lookups?limit=30&offset=0'
```

See [shared contracts](../docs/contracts.md) for every endpoint and response.
`POST /lookups` creates a history entry, including unknown/failed provider outcomes;
invalid input creates none. Accepted MAC formats are colon, hyphen, or 12 hex
digits, with no semantic address rejection. Optional IP is a plain IPv4 address
(omitted/null is allowed). POST fields are top-level; extra fields are ignored.
Pagination rejects limits outside 1–100 and negative/non-integer offsets.

`POST /process_events` uses a database-unique UUID (normalized lowercase).
Identical retries return 200; different payloads for that ID return 409. Names
must be nonblank strings of at most 255 characters; PIDs must be positive JSON
integers within SQLite's signed 64-bit range. Explicit timezone timestamps accept
up to six fractional digits, persist microseconds, and return UTC milliseconds.
Retries must retain the original occurrence timestamp and payload. Equivalent
timezone offsets compare equal. The API never terminates a process.

Vendor lookup uses [MACVendors' documented API](https://macvendors.com/api): plain
text on 200, unknown on 404, rate-limited on 429. The free service documents one
request per second and 1,000/day; requests are not automatically retried. The
adapter has 2-second connect and 3-second read/write timeouts, a bounded response
body, TLS verification, and no redirect following. Resolved and unknown results
are cached per MAC for 24 hours in `Rails.cache` so repeated lookups of one device
do not spend the provider's rate limit; failures are never cached. Provider error
bodies are never sent to clients, and failures are logged by error class only.
An unexpected server failure returns the same JSON envelope with `500` and code
`internal_error`. A live smoke on 2026-09-10 returned
`Apple, Inc.` for the example MAC; automated tests never use the live provider.

## Checks

```sh
bin/rails test
bin/rails zeitwerk:check
bin/rubocop
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bin/bundler-audit check --update
```

WebMock prohibits all network access in tests. `json` is constrained below version
3 because Rails 8.1.3.1 calls its parser with a positional options hash.

## Optional development container

```sh
docker build -t hudu-api-dev .
docker run --rm -p 127.0.0.1:3000:3000 \
  -v hudu-api-storage:/rails/storage hudu-api-dev
```

The Ruby 4.0.2 development image prepares SQLite on startup and persists it in
`/rails/storage`. No production credentials are copied or required. The root
Compose configuration uses this Dockerfile. Native desktop apps run on the host.
