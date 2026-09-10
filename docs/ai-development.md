# AI-assisted development

This project uses a main coordinating agent and subagents with disjoint file ownership. The log records supplied facts and visible work; it does not invent review conversations, human corrections, or test outcomes. The project implements both take-home options at the user's request.

## Responsibility split

| Owner | Scope |
| --- | --- |
| Main agent | Canonical contracts, shared package, root configuration, integration, final review, Git operations |
| API worker | `api/` implementation and API checks |
| Network Lookup worker | `apps/network_lookup/` implementation and app checks |
| Process Manager worker | `apps/process_manager/` implementation and app checks |
| Build worker | Shell/PowerShell tooling, CI and packaging within its assigned scope |
| Documentation worker | README, architecture/API/development/testing/AI notes, and original visual assets |

Workers must report changed paths, checks actually run, and remaining issues. Cross-scope changes go through the main agent. Documentation does not alter the implementation plan or canonical contracts. Workers do not commit or push.

## Development record · 2026-09-10

| Event | Basis / status |
| --- | --- |
| Both options assigned to independent apps, sharing `desktop_core` and a Rails API | Implementation plan and canonical contracts |
| Public repository created at `ConnorDykes/Hudu-Project` | Reported by main agent in the documentation handoff |
| Flutter 3.47.2, Ruby 4.0.2, Rails 8.1.3.1 selected | Handoff and version declarations inspected in source |
| API, app, build, and documentation scopes delegated | Main-agent handoff; app workers subsequently reported started |
| Shared package analysis and seven tests pass | Reported by main agent; not independently rerun by documentation worker |
| Documentation drafted against plan, contracts, and available source | Documentation worker read root instructions, plan, contracts, API source, and shared transport |
| Original SVG banner authored | Vector source created directly; no corporate logo, generated screenshot, or copied assignment artwork |
| Public preview approach clarified | Main agent specified production-widget golden renders with injected synthetic sample data; live native inspection remains separate |
| Setup and packaging documentation reconciled | Documentation worker inspected Bash/PowerShell scripts, Compose, Dockerfile, and CI source after the build worker supplied them; execution remains pending |
| Banner visually reviewed | Main agent reported rendering with `rsvg-convert` and inspecting the result; documentation worker validated the SVG XML |
| API worker completed its checks | Main-agent handoff reports 39 passing tests, 438 assertions, and clean lint/security checks; main-agent independent rechecks remain pending |
| Live JSON request compatibility corrected | Main review found valid JSON receiving HTTP 400; backend constrained `json < 3`, locked 2.21.2, and added a raw POST regression; independent live retest remains pending |
| Audit timestamp precision mismatch found | Main review caught client microsecond timestamps compared against API millisecond responses; process worker is normalizing timestamps at event creation and adding a regression |
| Container HTTP verification added to CI | Inspected `api-container` job builds Compose, checks create `201`, restarts the API, and checks identical retry `200` with the same response; execution evidence remains pending |
| MAC validation contract clarified | Current canonical contract accepts syntactically valid 48-bit addresses and directs discovery adapters to ignore incomplete/zero entries |

The lookup uses POST because it persists an attempt; GET reads history. This is an explicit design decision in the plan, not a correction invented after review. Process-event retries preserve event identity and occurrence time to separate confirmed local termination from network delivery.

## Corrections from main-agent review

The live API accepted health requests but returned `400` for a syntactically valid JSON POST. The reported cause was Rails 8.1.3.1's positional JSON options being incompatible with JSON 3. The API worker constrained the dependency to `json < 3`, locked version 2.21.2, and added a raw JSON POST regression. The dependency constraint and lock were inspected in source; the reported 39 tests and 438 assertions are worker results, not a completed independent live retest.

Main review also identified a mismatch between microsecond-precision timestamps held by the process client and millisecond-precision timestamps returned by the API. Comparing them without consistent precision could prevent a valid audit response from being acknowledged. The process worker was assigned to normalize the occurrence timestamp at event creation and add a regression. Completion and independent verification of that correction remain pending.

To exercise the HTTP boundary in a container, the main agent added an `api-container` CI job. It builds and starts Compose, posts a synthetic process event expecting `201`, restarts the API, and resends the same event expecting `200` and an identical response. This checks request parsing, duplicate handling, and persistence across restart without terminating an OS process. The job's presence is configuration evidence only; Docker support is not marked verified until a successful CI run is supplied.

## Review and evidence still required

Main-agent integration review is in progress; independent rerun results, native builds, live app inspection, clean-clone setup, and final artifacts remain pending. The corrections above came from main-agent review; no human correction history or separate independent reviewer conclusion has been supplied. Add actual findings and their resolutions when available, with a source revision or check result where practical. The main-owned [verification results](verification-results.md) records current integration findings; independent live verification of the JSON correction remains pending.

Setup/compose commands were reconciled with available source and need a final drift check if build tooling changes. [testing.md](testing.md) holds the check runbook and screenshot provenance requirements. Canonical API behavior remains in [contracts.md](contracts.md).
