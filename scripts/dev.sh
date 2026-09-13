#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

usage() {
  echo 'Usage: bash scripts/dev.sh setup|check [all|api|flutter]'
  echo '       bash scripts/dev.sh api'
  echo '       bash scripts/dev.sh run|build network_lookup|process_manager'
  echo '       bash scripts/dev.sh doctor|help'
  echo 'setup installs project dependencies and prepares the development DB.'
  echo 'Requires pinned toolchains on PATH; see docs/development.md.'
}

fail() { echo "Error: $*" >&2; exit 1; }
require_command() { command -v "$1" >/dev/null 2>&1 || fail "Install $1 and add it to PATH; see docs/development.md."; }
require_ruby() {
  require_command ruby
  require_command bundle
  local expected actual
  expected="$(tr -d '\r\n' < .ruby-version)"
  actual="$(ruby -e 'print RUBY_VERSION')"
  [[ "$actual" == "$expected" ]] || fail "Ruby $expected required; found $actual. Select it with your version manager."
}
require_flutter() {
  require_command flutter
  local expected actual details
  expected="$(tr -d '\r\n' < .flutter-version)"
  details="$(flutter --version --machine)"
  actual="$(printf '%s\n' "$details" | sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p')"
  [[ "$actual" == "$expected" ]] || fail "Flutter $expected required; found ${actual:-unknown}. Select it before continuing."
}
flutter_packages=(packages/desktop_core apps/network_lookup apps/process_manager)
require_packages() {
  local package
  for package in "${flutter_packages[@]}"; do
    [[ -f "$package/pubspec.yaml" ]] || fail "Missing $package/pubspec.yaml. Complete the app scaffold first."
  done
}

command_name="${1:-help}"
target="${2:-all}"
[[ $# -le 2 ]] || { usage; exit 2; }
case "$command_name" in
  help|-h|--help) usage ;;
  setup|check)
    case "$target" in all|api|flutter) ;; *) fail "Target must be all, api, or flutter." ;; esac
    if [[ "$target" != flutter ]]; then require_ruby; fi
    if [[ "$target" != api ]]; then require_flutter; require_packages; fi
    if [[ "$target" != flutter ]]; then
      (
        cd api
        if [[ "$command_name" == setup ]]; then
          echo 'Installing API dependencies and preparing the development SQLite database.'
          bundle check || bundle install
          RAILS_ENV=development bundle exec rails db:prepare
        else
          RAILS_ENV=test bundle exec rails db:prepare test
          bundle exec rubocop
          bundle exec brakeman --no-pager
          bundle exec ruby bin/bundler-audit check --update
        fi
      )
    fi
    if [[ "$target" != api ]]; then
      for package in "${flutter_packages[@]}"; do
        (
          cd "$package"
          if [[ "$command_name" == setup ]]; then
            echo "Resolving dependencies for $package."
          fi
          flutter pub get --enforce-lockfile
          if [[ "$command_name" == check ]]; then
            flutter analyze --no-pub --fatal-infos
            flutter test --no-pub
          fi
        )
      done
    fi
    ;;
  api)
    [[ $# -le 1 ]] || fail 'api takes no target.'
    require_ruby
    cd api
    RAILS_ENV=development bundle exec rails db:prepare
    RAILS_ENV=development exec bundle exec rails server -b 127.0.0.1 -p 3000
    ;;
  run|build)
    case "$target" in network_lookup|process_manager) ;; *) fail 'Select network_lookup or process_manager.' ;; esac
    [[ "$(uname -s)" == Darwin ]] || fail 'Desktop run/build requires macOS here; use dev.ps1 on Windows.'
    require_flutter
    [[ -f "apps/$target/pubspec.yaml" ]] || fail "Missing apps/$target/pubspec.yaml."
    cd "apps/$target"
    if [[ "$command_name" == run ]]; then
      exec flutter run -d macos "--dart-define=API_BASE_URL=${API_BASE_URL:-http://127.0.0.1:3000}"
    else
      exec flutter build macos --release "--dart-define=API_BASE_URL=${API_BASE_URL:-http://127.0.0.1:3000}"
    fi
    ;;
  doctor)
    [[ $# -le 1 ]] || fail 'doctor takes no target.'
    require_ruby
    require_flutter
    flutter doctor -v
    ;;
  *) usage; exit 2 ;;
esac
