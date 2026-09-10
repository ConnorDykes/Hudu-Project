# Development

The runbook targets Flutter **3.47.2**, Ruby **4.0.2**, and Rails **8.1.3.1**. Version declarations are in `.flutter-version`, `.ruby-version`, and `api/Gemfile`. Commands below were reconciled with the available setup scripts and Compose source; clean-clone execution remains pending integration verification.

## Repository layout

```text
api/                     Rails API and SQLite persistence
apps/network_lookup/     Independent Flutter desktop application
apps/process_manager/    Independent Flutter desktop application
packages/desktop_core/   Shared presentation and HTTP transport
scripts/                 Setup, checks, and packaging tooling
docs/                    Contracts, architecture, verification, and assets
```

Run Rails and Flutter in separate terminals. The two apps can be evaluated independently against the same API. Application bundles do not contain Rails or its database.

## macOS native setup

Install Flutter 3.47.2, Xcode and its command-line tools, and CocoaPods if needed by the native plugins. Use [Flutter's macOS setup guide](https://docs.flutter.dev/platform-integration/macos/setup) to resolve desktop tooling requirements. Provision Ruby 4.0.2 with your preferred Ruby version manager and activate it before installing gems; do not assume Apple's system Ruby matches the project.

```sh
git clone https://github.com/ConnorDykes/Hudu-Project.git
cd Hudu-Project
flutter --version
flutter doctor -v
ruby --version
bundle --version
```

If Bundler is absent from the active Ruby, install it with `gem install bundler`. From the repository root:

```sh
cd api
bundle install
bin/rails db:prepare
bin/rails server -b 127.0.0.1 -p 3000
```

In another terminal, verify readiness:

```sh
curl --fail http://127.0.0.1:3000/health
```

The expected contract response is `{"status":"ok"}`. This is an expectation, not a report of a completed check.

From the repository root in another terminal, choose one app:

```sh
cd apps/network_lookup
flutter pub get
flutter run -d macos --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

Or, from the repository root:

```sh
cd apps/process_manager
flutter pub get
flutter run -d macos --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

Each app resolves its relative `desktop_core` dependency through `flutter pub get`; it is not a third service to start.

## Windows native client, Rails in WSL2

Install Flutter 3.47.2 **on Windows**, plus Visual Studio with **Desktop development with C++**. Visual Studio Code alone does not supply the Windows native build toolchain. See [Flutter's Windows setup guide](https://docs.flutter.dev/platform-integration/windows/setup).

Use a native Windows checkout for Flutter. In PowerShell:

```powershell
git clone https://github.com/ConnorDykes/Hudu-Project.git
Set-Location Hudu-Project
flutter --version
flutter doctor -v
flutter devices
```

Install WSL2 and a Linux distribution if needed, then provision Ruby 4.0.2 and Bundler inside that distribution. Keep the API checkout and gems in the Linux filesystem. In the WSL shell:

```sh
git clone https://github.com/ConnorDykes/Hudu-Project.git
cd Hudu-Project/api
ruby --version
bundle install
bin/rails db:prepare
bin/rails server -b 127.0.0.1 -p 3000
```

Back in PowerShell at the Windows repository root:

```powershell
Invoke-RestMethod -Uri http://127.0.0.1:3000/health
Set-Location apps/network_lookup
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

For Process Manager, run the same sequence from `apps/process_manager`. The Windows client must run on Windows to inspect Windows neighbors and processes. Running Flutter inside WSL is not the Windows desktop setup.

Windows can normally access a WSL-hosted network app through localhost, but WSL networking mode and firewall configuration can affect connectivity. Verify `/health` from PowerShell before debugging Flutter. Consult [Microsoft's WSL networking guidance](https://learn.microsoft.com/en-us/windows/wsl/networking) if forwarding fails. Prefer restoring localhost connectivity or using the optional container route. Do not make this unauthenticated API publicly reachable as a workaround. This Windows/WSL2 path has not yet been exercised for this project.

## Optional Docker API

Docker is an alternative to a host Ruby installation; Flutter remains native. Install and start Docker with Compose and Linux container support. The following commands match the checked-in `compose.yaml`; a real startup check remains pending:

```sh
# From the repository root.
docker compose up --build --wait api
docker compose ps
docker compose logs api
```

In another terminal:

```sh
curl --fail http://127.0.0.1:3000/health
```

The `api` service builds `api/Dockerfile`, runs Rails in development, and executes `db:prepare` before serving. The `api_storage` volume mounts `/rails/storage`; host publication is `127.0.0.1:3000:3000`. Rails binds to all interfaces **inside** the container while the host port stays on loopback. Source is copied into the image; rebuild after API changes.

Stop the stack with `docker compose down`. Retain the database volume; `down --volumes` would delete persisted history. Keep the API container and native Rails server from competing for port 3000.

## Developer scripts

The [script reference](../scripts/README.md) describes the full interface. These commands run from the repository root and require the pinned toolchains on `PATH`; they do not install toolchains or change shell profiles or PowerShell execution policy.

| Task | macOS / Bash | Windows / PowerShell |
| --- | --- | --- |
| Install dependencies and prepare database | `bash scripts/dev.sh setup` | `./scripts/dev.ps1 setup` (native Ruby required) |
| Flutter dependencies only | `bash scripts/dev.sh setup flutter` | `./scripts/dev.ps1 setup flutter` |
| All checks | `bash scripts/dev.sh check` | `./scripts/dev.ps1 check` (native Ruby required) |
| Flutter checks only | `bash scripts/dev.sh check flutter` | `./scripts/dev.ps1 check flutter` |
| Start native API | `bash scripts/dev.sh api` | `./scripts/dev.ps1 api` (native Ruby required) |
| Run Network Lookup | `bash scripts/dev.sh run network_lookup` | `./scripts/dev.ps1 run network_lookup` |
| Run Process Manager | `bash scripts/dev.sh run process_manager` | `./scripts/dev.ps1 run process_manager` |

For Windows + WSL2, use the `flutter` subset in PowerShell and `bash scripts/dev.sh setup api`, `check api`, or `api` in the Linux checkout. Bash desktop run/build commands require macOS; PowerShell desktop run/build commands require Windows. Setup/check enforce the Flutter lockfiles. API checks include tests, RuboCop, Brakeman, and dependency advisory audit; the advisory refresh accesses the network.

## Configuration and local data

| Setting | Meaning |
| --- | --- |
| `API_BASE_URL` | Flutter compile-time define; defaults to `http://127.0.0.1:3000` |
| API bind / port | Set by `bin/rails server -b 127.0.0.1 -p 3000` |
| Development database | `api/storage/development.sqlite3` |
| Test database | `api/storage/test.sqlite3`, separate from development data |
| Vendor provider | Current adapter uses the fixed `https://api.macvendors.com/` endpoint |

For direct Flutter commands, pass `--dart-define=API_BASE_URL=...` to `flutter run` or `flutter build`; restart/rebuild to change it. The developer scripts explicitly forward the shell's `API_BASE_URL` into that define: set it with `export API_BASE_URL=http://127.0.0.1:3000` in Bash or `$env:API_BASE_URL = 'http://127.0.0.1:3000'` in PowerShell. `.env.example` is a reference, not a file the scripts execute. Do not place credentials in compile-time defines or publish local database files, logs, or process listings. The contract requires no API token.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Ruby version mismatch | Confirm `ruby --version` and `bundle --version` in the terminal used to start Rails |
| API unreachable | Confirm Rails is running; check `/health` from the client host and the compiled API URL |
| Database not ready | Run `bin/rails db:prepare` inside `api/`; inspect the local Rails error without publishing private logs |
| No desktop device / build toolchain failure | Run `flutter doctor -v` and `flutter devices`; resolve the intended desktop platform's diagnostics |
| MAC not found | Check local IPv4 scope and adapter selection; absent ARP data does not mean the device is offline |
| Vendor unknown | A MAC may have no provider match; distinguish `unknown` from provider failure |
| Termination refused or unconfirmed | Check permissions and stale process identity; do not assume a sent request proves exit |
| Terminated but audit pending | Restore API connectivity and retry audit delivery; never repeat termination for logging |

Build and test commands, packaging requirements, and evidence gates are in [testing.md](testing.md).
