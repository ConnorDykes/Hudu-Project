# Developer commands

Run from the repository root. Scripts also resolve project files correctly when
called from another directory. They require the versions in `.flutter-version`
and `.ruby-version` on `PATH`; setup installs project dependencies, prepares the
development SQLite database, and does not install toolchains, change shell
profiles, change PowerShell execution policy, or write `.env`.

Install Flutter 3.47.2 and, for a native API, Ruby 4.0.2 plus Bundler. Rails
8.1.3.1 comes from `api/Gemfile.lock`. macOS builds require Xcode and its command
line tools; Windows builds require Visual Studio's **Desktop development with
C++** workload and a Windows SDK. Run `flutter doctor -v` to inspect native
prerequisites. Install CocoaPods if Flutter reports that a plugin requires it.
Each app builds on its matching operating system.

## macOS (Bash)

```bash
bash scripts/dev.sh setup
bash scripts/dev.sh check
bash scripts/dev.sh api
# In a second terminal:
bash scripts/dev.sh run network_lookup
# Or:
bash scripts/dev.sh run process_manager
```

## Windows (PowerShell)

With native Ruby and Flutter available:

```powershell
./scripts/dev.ps1 setup
./scripts/dev.ps1 check
./scripts/dev.ps1 api
# In a second terminal:
./scripts/dev.ps1 run network_lookup
# Or:
./scripts/dev.ps1 run process_manager
```

If PowerShell blocks script execution, review your machine's execution policy
and use your organization's approved way to run local scripts. No script changes
that policy. The optional Docker route below avoids installing native Ruby on
Windows; WSL can also run the Bash API commands while Flutter runs on Windows.

## Optional container API (either platform)

Install and start Docker with Compose and Linux container support, then run:

```text
docker compose up --build --wait api
docker compose ps
docker compose logs api
docker compose down
```

The service uses `api/Dockerfile` with development gems available. Rails runs in
development, prepares its DB before serving, and exposes
`http://127.0.0.1:3000/health`. Source is copied into the image: rerun the build
after API changes. The `api_storage` named volume persists `/rails/storage`
across service restarts and `docker compose down`. Do not add `--volumes` unless
you intend to delete the saved lookup and process history.

Use `bash scripts/dev.sh setup flutter` / `check flutter` or
`./scripts/dev.ps1 setup flutter` / `check flutter` for desktop dependencies and
tests without Ruby. Run Rails checks inside the image with:

```text
docker compose run --rm -e RAILS_ENV=test api bundle exec rails db:prepare test
docker compose run --rm api bundle exec rubocop
docker compose run --rm api bundle exec brakeman --no-pager
docker compose run --rm api bundle exec ruby bin/bundler-audit check --update
```

Tests use the separate test SQLite database. Vendor tests must stub the provider;
the advisory audit intentionally accesses the network to refresh vulnerability
data. Both `setup` and `check` resolve Flutter dependencies with
`--enforce-lockfile`, requiring the committed versions and content hashes.
`check` requires API dependencies from `setup` and exits on the first failed
command. `setup api` / `check api` select only the native API.

## Configuration and release bundles

The default API URL is `http://127.0.0.1:3000`. To override it before `run` or
`build`, use `export API_BASE_URL=http://127.0.0.1:3000` in Bash, or
`$env:API_BASE_URL = 'http://127.0.0.1:3000'` in PowerShell. `.env.example` is a
reference; scripts never execute it. Flutter embeds this setting at compile time,
so rebuild/restart the app after changing it. The API remains a separate service.

```bash
bash scripts/dev.sh build network_lookup
bash scripts/package-macos.sh network_lookup /tmp/hudu-release
```

```powershell
./scripts/dev.ps1 build network_lookup
./scripts/package-windows.ps1 -App network_lookup -OutputDirectory "$env:TEMP/hudu-release"
```

Substitute `process_manager` for the other app. Use a fresh output directory for
each packaging run. macOS zips contain the full `.app` with framework symlinks
and executable permissions. Windows zips contain the complete Release bundle,
including the executable, DLLs, and data. Extract the entire archive together.
Windows x64 machines require the [Microsoft Visual C++ x64 Redistributable](https://aka.ms/vs/17/release/vc_redist.x64.exe)
installed before launching either bundle. These archives do not package an
app-local VC++ runtime. An ARM64 build instead needs the matching ARM64 runtime.
These are unsigned development bundles; signing/notarization and installers are
outside this workflow.

CI runs API tests/lint/security, analyzes and tests all three Flutter packages,
then tests and builds each app on macOS and Windows. Artifacts have app, OS,
runner architecture, and commit names, and are retained for 14 days. CI requires
committed `pubspec.lock` files for all three Flutter packages. Download the
artifact and extract its enclosed release zip. GitHub release attachment is a
separate main-agent operation; this workflow has read-only repository access.
The native jobs run each app's `test/native_smoke_test.dart` through the
normal `flutter test` invocation. These tests run on macOS and Windows and skip
on Linux. Screenshot
generation in `test/screenshots_test.dart` is opt-in through `UPDATE_GOLDENS`,
which CI does not set, to avoid comparing platform-specific font rendering.
Passing unit tests alone is not evidence of native smoke or interactive UI
verification.
