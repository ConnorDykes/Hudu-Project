# Verification results

This file records checks actually performed during implementation. The automated workflow is the repeatable source of test and build evidence; a compiled binary alone is not a manual UI check.

| Area | Current evidence |
| --- | --- |
| Shared Flutter package | `flutter analyze`: no issues. `flutter test`: 7 passing tests, covering HTTP behavior and desktop layout/navigation at two window sizes. |
| Rails API | Main independently reran 39 tests / 438 assertions, all passing; RuboCop clean, Brakeman zero warnings, dependency audit clean. Live HTTP: health 200; vendor lookup 201 with persisted Apple result; disposable-process audit 201, identical retry 200, conflicting retry 409, and history readback. |
| Network Lookup | Main independently passed analysis, 31 tests (three opt-in cases skipped by default), native macOS interface/cache and own-IP checks, and two real Rails repository checks including a live vendor lookup. Worker release build completed; production-widget preview rendered and inspected. |
| Process Manager | Implementation and native verification in progress. |
| Windows builds | Native CI verification pending. |
| macOS builds | Both workers produced release apps. Main inspected the native executables and Dart App frameworks: both contain x86_64 and arm64 slices. Final hosted build/artifact checks pending. |
| Documentation | Original SVG banner and both production-widget previews rendered and visually inspected. Clean-clone instructions pending. |

## Integration findings

- The main agent found that the live Rails server rejected a syntactically valid JSON POST while its health endpoint worked. Rails 8.1.3.1's parser call was incompatible with JSON 3. The API worker constrained JSON below 3, added raw-request regression coverage, and the main agent restarted the server and verified the original request returned 201 with persisted vendor data.
- Main review caught an audit timestamp precision mismatch between microsecond client timestamps and millisecond API serialization. The process worker normalized event creation timestamps and added a regression; main verified the test exists, with final execution results pending below.

## Boundaries

- Process tests only target disposable children spawned by the test harness.
- Public UI previews use the real production Flutter widgets with synthetic data. Live machine/network details are not included in repository screenshots.
- Signed/notarized installers and App Store submission are outside this development-artifact release.
- Interactive native UI inspection is currently blocked by the locked Mac. The user has been asked to unlock it. Automated widget rendering, native adapter checks, and build inspection are separate evidence and continue without claiming an interactive review.
