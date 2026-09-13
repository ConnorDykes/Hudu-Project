# API reference

This is the canonical description of the wire contract shared by the Rails API and both desktop clients. Examples are synthetic payloads, not captured runtime results. Completed API and client integration checks are recorded in [verification results](verification-results.md).

Base URL: `http://127.0.0.1:3000`, read by the clients from the compile-time `API_BASE_URL` define. Use JSON request bodies and `Content-Type: application/json`. There is no authentication. Timestamps in responses are UTC ISO 8601 with millisecond precision. The service handles vendor lookup and persistence only; it has no endpoint to inspect or terminate OS processes.

## Endpoints

| Method | Path | Purpose | Normal response |
| --- | --- | --- | --- |
| `GET` | `/health` | Database readiness | `200 {"status":"ok"}` |
| `GET` | `/lookups?mac=…` | Perform and persist a MAC vendor lookup (brief's form) | `200` resolved or unknown record |
| `POST` | `/lookups` | Perform and persist a MAC vendor lookup (client's form) | `201` resolved or unknown record |
| `GET` | `/lookups` | Read newest lookup history | `200` paginated records |
| `POST` | `/vendors` | Name a vendor for a MAC's OUI so future lookups resolve locally | `201`; `409` if the OUI is taken |
| `GET` | `/vendors` | List seeded and user-named vendors | `200` paginated records |
| `POST` | `/process_events` | Persist a client-reported confirmed termination | `201` new; `200` identical duplicate |
| `GET` | `/process_events` | Read termination audit history | `200` paginated records |

`GET /lookups?mac=...` performs a lookup and returns the persisted record with `200`, matching the brief's example. The desktop client uses `POST /lookups`, which does the same work and answers `201`, because the operation creates a history record. Plain `GET /lookups` reads history.

## Create a lookup

```sh
curl --fail-with-body http://127.0.0.1:3000/lookups \
  -H 'Content-Type: application/json' \
  -d '{"mac":"00:1B:63:84:45:E6","ip":"192.168.1.10"}'
```

`mac` is required. Accept syntactically valid 48-bit MAC addresses in colon-separated, hyphen-separated, or 12 unseparated hex form and normalize to uppercase colon notation; mixed separators are rejected. `ip` is optional; if supplied, it must be IPv4. Locally administered addresses are allowed and may have no known vendor. Discovery adapters ignore incomplete or zero neighbor entries before submitting a lookup, and a local ARP miss is not persisted because there is no MAC to submit.

Example `201` response:

```json
{
  "data": {
    "id": 1,
    "ip": "192.168.1.10",
    "mac": "00:1B:63:84:45:E6",
    "vendor": "Apple, Inc.",
    "status": "resolved",
    "created_at": "2026-09-10T18:00:00.000Z"
  }
}
```

| Outcome | HTTP | Record |
| --- | --- | --- |
| Vendor found | `201` | `status: "resolved"`, vendor string |
| Vendor unknown | `201` | `status: "unknown"`, `vendor: null` |
| Provider unavailable / malformed provider reply | `502` | `status: "failed"`, `vendor: null` |
| Provider timeout | `504` | `status: "failed"`, `vendor: null` |
| Provider rate limit | `503` | `status: "failed"`, `vendor: null` |
| Invalid input | `422` | No record created |

Resolution order is the local `vendors` table first (about thirty seeded IEEE OUI registrations for common manufacturers plus any user-named vendors), then the public provider. An unknown vendor is not an HTTP missing-resource error. Accepted provider failures are persisted; error responses may contain that record in `data`. Resolved and unknown provider answers are cached per MAC for 24 hours so repeated lookups of one device do not consume the provider's rate limit; each request still creates its own history record. A local ARP miss must not call this endpoint with a fabricated MAC. Repeating `POST /lookups` creates another accepted attempt; this endpoint does not share process-event idempotency.

## Name a vendor

```sh
curl --fail-with-body http://127.0.0.1:3000/vendors \
  -H 'Content-Type: application/json' \
  -d '{"mac":"02:11:22:33:44:55","name":"Lab sensor"}'
```

`mac` (a full address) or `oui` (the first three octets) identifies the manufacturer prefix; `name` is required, at most 255 characters, and plain text. The vendor is stored by OUI with `source: "user"` and answers every later lookup for that prefix without a provider call. Reusing an OUI returns `409 vendor_exists` with the existing record in `data`. `GET /vendors` lists vendors sorted by name with the standard pagination envelope. The desktop client offers this after a lookup completes as `unknown`, then repeats the lookup so history shows the resolved name.

## Record a process event

The client must have confirmed exit before sending this event. This example only writes an audit record; it does not terminate PID 123.

```sh
curl --fail-with-body http://127.0.0.1:3000/process_events \
  -H 'Content-Type: application/json' \
  -d '{"event_id":"6b344836-621c-41b8-9f35-67f011ce6482","process_name":"sleep","pid":123,"occurred_at":"2026-09-10T18:00:00.000Z"}'
```

Example `201` response:

```json
{
  "data": {
    "id": 1,
    "event_id": "6b344836-621c-41b8-9f35-67f011ce6482",
    "process_name": "sleep",
    "pid": 123,
    "occurred_at": "2026-09-10T18:00:00.000Z",
    "created_at": "2026-09-10T18:00:01.000Z"
  }
}
```

All four request fields are required. Use a stable UUID, a process name, a positive integer PID, and the original confirmed-exit timestamp. `occurred_at` is when exit was confirmed; `created_at` is when the API persisted the record. Preserve `occurred_at` and the event ID across offline retries.

An identical duplicate returns the existing record with `200`. Reusing an event ID with different attributes returns `409 event_conflict`. A database unique index enforces ID uniqueness. Invalid input returns `422`. Retry only the audit submission; never repeat termination to repair a failed upload.

## History and pagination

```sh
curl --fail 'http://127.0.0.1:3000/lookups?limit=30&offset=0'
curl --fail 'http://127.0.0.1:3000/process_events?limit=30&offset=0'
```

Both return `{"data":[],"meta":{"limit":30,"offset":0,"total":0}}` for an empty database. Default limit is 30, maximum is 100, and offset must be nonnegative. Invalid pagination returns `422`. `total` is the total number of records, not the current page length.

Lookup ordering is `created_at DESC, id DESC`; process-event ordering is `occurred_at DESC, id DESC`. Delayed audit delivery therefore keeps the original event chronology. Offset pagination is bounded history retrieval, not a stable snapshot if concurrent writes occur.

## Errors

```json
{
  "error": {
    "code": "invalid_input",
    "message": "Readable explanation"
  }
}
```

| HTTP | Contract meaning |
| --- | --- |
| `400` | Malformed JSON (`invalid_json`) or malformed HTTP parameters (`invalid_input`) |
| `404` | Unknown API route; JSON error response |
| `409` | `event_conflict`: event ID reused with a different payload |
| `422` | `invalid_input`: invalid request or pagination |
| `500` | `internal_error`: unexpected server failure in production; details are logged, never returned |
| `502` | `vendor_unavailable` |
| `503` | `vendor_rate_limited` |
| `504` | `vendor_timeout` |

Development retains Rails' detailed responses for unexpected exceptions, while the test environment raises unexpected exceptions. Production JSON errors are formatted through `config.exceptions_app`, preserving Rails' logging and exception reporting.

Do not require `data` on every error. Do not infer a failed termination from an audit HTTP failure: the OS action and its delivery are separate operations. `/health` returns `503 database_unavailable` when its database readiness query fails.
