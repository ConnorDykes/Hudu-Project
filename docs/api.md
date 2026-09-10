# API reference

The canonical definition is [contracts.md](contracts.md). This reference explains that contract; examples are synthetic payloads, not captured runtime results. Completed API and client integration checks are recorded in [verification results](verification-results.md).

Base URL: `http://127.0.0.1:3000`. Use JSON request bodies and `Content-Type: application/json`. There is no authentication. Timestamps in responses are UTC ISO 8601. The service handles vendor lookup and persistence only; it has no endpoint to inspect or terminate OS processes.

## Endpoints

| Method | Path | Purpose | Normal response |
| --- | --- | --- | --- |
| `GET` | `/health` | Database readiness | `200 {"status":"ok"}` |
| `POST` | `/lookups` | Perform and persist a MAC vendor lookup | `201` resolved or unknown record |
| `GET` | `/lookups` | Read newest lookup history | `200` paginated records |
| `POST` | `/process_events` | Persist a client-reported confirmed termination | `201` new; `200` identical duplicate |
| `GET` | `/process_events` | Read termination audit history | `200` paginated records |

The assignment illustrates lookup using GET. Here, performing a lookup creates history, so **POST performs the operation** and **GET reads history**. A query such as `GET /lookups?mac=...` is not a vendor-lookup command. The canonical contract does not define an alias for the assignment example.

## Create a lookup

```sh
curl --fail-with-body http://127.0.0.1:3000/lookups \
  -H 'Content-Type: application/json' \
  -d '{"mac":"00:1B:63:84:45:E6","ip":"192.168.1.10"}'
```

`mac` is required. Accept syntactically valid 48-bit MAC addresses in colon-separated, hyphen-separated, or 12 unseparated hex form and normalize to uppercase colon notation. `ip` is optional; if supplied, it must be IPv4. Locally administered addresses are allowed and may have no known vendor. Discovery adapters should ignore incomplete or zero neighbor entries before submitting a lookup.

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

An unknown vendor is not an HTTP missing-resource error. Accepted provider failures are persisted; error responses may contain that record in `data`. A local ARP miss must not call this endpoint with a fabricated MAC. Repeating `POST /lookups` creates another accepted attempt; this endpoint does not share process-event idempotency.

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
| `400` | Malformed JSON; JSON error response |
| `404` | Unknown API route; JSON error response |
| `409` | `event_conflict`: event ID reused with a different payload |
| `422` | `invalid_input`: invalid request or pagination |
| `502` | `vendor_unavailable` |
| `503` | `vendor_rate_limited` |
| `504` | `vendor_timeout` |

Do not require `data` on every error. Do not infer a failed termination from an audit HTTP failure: the OS action and its delivery are separate operations. Database-readiness failure behavior beyond the health success payload should be checked against the final implementation.
