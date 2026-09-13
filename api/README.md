# Hudu API

Rails **8.1.3.1**, Ruby **4.0.2**, SQLite. Endpoints, payloads, and error codes are in the [API reference](../docs/api.md); design notes are in [Architecture](../docs/architecture.md). No API key or master key is required. The service has no authentication, so keep it bound to loopback.

## Run

```sh
bundle install
bin/rails db:prepare
bin/rails server -b 127.0.0.1 -p 3000
curl http://127.0.0.1:3000/health
```

History lives in `storage/development.sqlite3`. `db:prepare` seeds about thirty manufacturer OUIs into `vendors` on a fresh database; `bin/rails db:seed` adds them to an existing one without overwriting user-named vendors.

## Check

```sh
bin/rails test
bin/rubocop
bin/brakeman --no-pager
bin/bundler-audit check --update
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 FORCE_SSL=false bin/rails zeitwerk:check
```

WebMock blocks all network access in tests; the vendor provider is always stubbed. `json` is constrained below version 3 because Rails 8.1.3.1 calls its parser with a positional options hash.

## Container

The root `compose.yaml` builds `Dockerfile`, runs Rails in development, prepares SQLite on startup through `bin/docker-entrypoint`, and persists `/rails/storage` in a named volume. See [Development](../docs/development.md#optional-docker-api).
