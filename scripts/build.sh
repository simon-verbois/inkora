#!/usr/bin/env bash
# VERSION is authoritative for Android release/debug build metadata.
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$INKORA_ROOT"
if [[ $# -eq 0 ]]; then
  echo 'Usage: scripts/build.sh apk|appbundle [--dev|--unsigned] [Flutter build options]' >&2
  exit 2
fi
case "$1" in apk|appbundle) ;; *) echo 'Unsupported build target.' >&2; exit 2 ;; esac
build_options=()
for argument in "$@"; do
  if [[ "$argument" == --unsigned ]]; then
    export INKORA_UNSIGNED_BUILD=true
    continue
  fi
  if [[ "$argument" == --dev ]]; then
    export INKORA_DEVELOPMENT_BUILD=true
    continue
  fi
  build_options+=("$argument")
  case "$argument" in
    integration_test/*.dart|*/integration_test/*.dart|--target=integration_test/*.dart|lib/main_development.dart|--target=lib/main_development.dart)
      export INKORA_DEVELOPMENT_BUILD=true ;;
  esac
  case "$argument" in --build-name*|--build-number*|--config-only) echo 'Version overrides/config-only are not accepted by this build wrapper.' >&2; exit 2 ;; esac
  # Flutter's pub phase also regenerates the native plugin registrant for the
  # selected build mode. Skipping it after host tests retains development plugins
  # that Gradle excludes from release, causing Java compilation to fail.
  case "$argument" in --no-pub*|--pub|--pub=*) echo 'Native plugin preparation is required; omit pub switches.' >&2; exit 2 ;; esac
done
if [[ "${INKORA_UNSIGNED_BUILD:-false}" == true ]]; then
  if [[ "$1" != apk || " ${build_options[*]} " != *" --release "* ||
        " ${build_options[*]} " == *" --debug "* || " ${build_options[*]} " == *" --profile "* ||
        "${INKORA_DEVELOPMENT_BUILD:-false}" == true || "${INKORA_REQUIRE_RELEASE_SIGNING:-false}" == true ]]; then
    echo 'Unsigned builds require an explicit release APK and cannot use development identity or distribution signing.' >&2
    exit 2
  fi
  for signing_variable in INKORA_KEYSTORE_PATH INKORA_KEYSTORE_PASSWORD INKORA_KEY_ALIAS INKORA_KEY_PASSWORD; do
    if [[ -n "${!signing_variable:-}" ]]; then
      echo 'Unsigned builds cannot receive signing credentials.' >&2
      exit 2
    fi
  done
fi
if [[ "${INKORA_DEVELOPMENT_BUILD:-false}" == true && "${INKORA_REQUIRE_RELEASE_SIGNING:-false}" == true ]]; then
  echo 'Distribution signing cannot be combined with a development build.' >&2
  exit 2
fi
metadata="$(python3 scripts/release_metadata.py version)"
version_name="${metadata%%$'\n'*}"
version_number="${metadata##*$'\n'}"
flutter build "${build_options[@]}" --build-name="$version_name" --build-number="$version_number"
