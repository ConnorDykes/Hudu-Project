# Hudu Project

Read `IMPLEMENTATION_PLAN.md` and `docs/contracts.md` before implementation. This is an explicitly authorized public take-home project implementing both options with subagent collaboration.

- Main agent owns contracts, shared packages, root configuration, integration, Git commits/pushes and final review.
- API worker owns `api/`; lookup worker owns `apps/network_lookup/`; process worker owns `apps/process_manager/`. Coordinate all cross-scope changes.
- Use `apply_patch` for authored files. Framework generators and formatters are permitted.
- No fabricated test results, UI screenshots, experience claims, or build support claims.
- OS tests may terminate only disposable child processes created by the harness.
- Keep credentials, local database contents, and private machine data out of source and public screenshots.
- Every worker reports changed paths, checks actually run, and remaining issues. Do not commit or push unless you are the main agent.
