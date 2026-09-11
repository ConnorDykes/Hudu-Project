# Implementation contracts

This is the shared contract used by the API and desktop workers. All paths are relative to `API_BASE_URL` (default `http://127.0.0.1:3000`). Requests and responses use JSON. No authentication. UTC ISO 8601 timestamps. Error envelope: `{"error":{"code":"invalid_input","message":"Readable explanation"}}`. Optional `data` on lookup-provider errors contains the persisted lookup.

## Lookup

`POST /lookups`: `{"mac":"00:1B:63:84:45:E6","ip":"192.168.1.10"}`. IP optional but if supplied must be IPv4. MAC normalize uppercase colon format, accept canonical colon/hyphen or 12 hex digits. Accept syntactically valid 48-bit MAC addresses, including locally administered addresses; return unknown when the vendor service has no match. Discovery adapters should ignore incomplete/zero neighbor entries.

Success `201`: `{"data":{"id":1,"ip":"192.168.1.10","mac":"00:1B:63:84:45:E6","vendor":"Apple, Inc.","status":"resolved","created_at":"2026-09-10T18:00:00.000Z"}}`.

Unknown vendor: `201`, same record with `vendor:null,status:"unknown"` (a completed lookup with no vendor is not a missing HTTP resource). Provider error: `502` code `vendor_unavailable`; timeout `504` code `vendor_timeout`; provider rate limit `503` code `vendor_rate_limited`. Persist with status `failed`, vendor null, return record in optional `data`. Invalid input `422` and no persisted row. Do not persist ARP misses here: these are client-local discovery failures without a MAC to submit.

`GET /lookups?mac=...&ip=...`: same behavior and body as `POST /lookups` but answers `200`; provided so the brief's illustrated form works verbatim.

`GET /lookups?limit=30&offset=0`: `{"data":[...records],"meta":{"limit":30,"offset":0,"total":1}}`; order created_at desc then id desc. Default limit 30, max 100, offset >=0; invalid pagination 422.

## Process events

`POST /process_events`: `{"event_id":"UUID","process_name":"sleep","pid":123,"occurred_at":"2026-09-10T18:00:00.000Z"}`. Occurrence time is confirmed exit time, not audit transmission time. Response `201`: `{"data":{"id":1,"event_id":"UUID","process_name":"sleep","pid":123,"occurred_at":"2026-09-10T18:00:00.000Z","created_at":"2026-09-10T18:00:01.000Z"}}`. Identical duplicate event ID returns existing record with `200`; ID reused with differing attributes returns `409` code `event_conflict`. Database unique index enforces event ID uniqueness. Invalid input `422`.

`GET /process_events?limit=30&offset=0`: same pagination envelope; order occurred_at desc then id desc.

`GET /health`: `200 {"status":"ok"}` with DB readiness check. Unknown API route returns JSON 404; malformed JSON returns JSON 400; an unexpected server failure returns JSON 500 with code `internal_error`.

## Client conventions

- Flutter stable, Riverpod. App entrypoints `NetworkLookupApp` and `ProcessManagerApp` inside their app libraries. Avoid code generation unless it reduces real complexity.
- Base URL from compile-time `String.fromEnvironment('API_BASE_URL', defaultValue:'http://127.0.0.1:3000')`; tests inject dependencies.
- Shared `desktop_core` package owned by main agent will expose `AppTheme.dark`, `AppTheme.light`, `DesktopShell`, `SectionCard`, `StatusPill`, `EmptyState`, `ApiClient`, `ApiException`. Consult actual implementation before consuming constructors. Workers may build their own app-local UI pieces.
- Visual direction: a quiet desktop utility, not a marketing page. Neutral graphite (dark) or paper (light) surfaces following the system theme, one restrained blue accent, hairline borders, sentence-case labels, and Inter plus JetBrains Mono for identifiers. Status is a dot and a word, never a badge. No taglines or explainer cards; the view title names the view and the header carries only its actions. Motion is 120–260 ms eased cross-fades and hover transitions, never bouncy. Responsive at 960x680 through 1440x1000. Shared tokens and components live in `desktop_core` (`AppColors`, `AppMotion`, `AppText`, `DesktopShell`, `SectionCard`, `StatusPill`, `InlineNotice`, `EmptyState`, `StateSwitcher`, `SkeletonRows`, `SpinningIcon`, `DetailField`, `TableLabel`).
- OS commands use validated argument arrays, bounded execution, no user input interpolated into a shell. A shell with a fixed script and validated numeric arguments may be used for OS-specific structured data.
- API is only persistence/vendor lookup; all local ARP/process access runs on the Flutter client's machine.
- Native adapters are owned within each app directory. Main agent alone owns `packages/desktop_core` and root files. Workers must not change other workers' directories or commit/push.
