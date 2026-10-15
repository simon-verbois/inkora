#!/usr/bin/env bash
# VERSION is authoritative for Android release/debug build metadata.
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$INKORA_ROOT"
if [[ $# -eq 0 ]]; then
  echo 'Usage: scripts/build.sh apk|appbundle [Flutter build options]' >&2
  exit 2
fi
case "$1" in apk|appbundle) ;; *) echo 'Unsupported build target.' >&2; exit 2 ;; esac
for argument in "$@"; do
  case "$argument" in --build-name*|--build-number*|--config-only) echo 'Version overrides/config-only are not accepted by this build wrapper.' >&2; exit 2 ;; esac
  # Flutter's pub phase also regenerates the native plugin registrant for the
  # selected build mode. Skipping it after host tests retains development plugins
  # that Gradle excludes from release, causing Java compilation to fail.
  case "$argument" in --no-pub*|--pub|--pub=*) echo 'Native plugin preparation is required; omit pub switches.' >&2; exit 2 ;; esac
done
metadata="$(python3 scripts/release_metadata.py version)"
version_name="${metadata%%$'\n'*}"
version_number="${metadata##*$'\n'}"
flutter build "$@" --build-name="$version_name" --build-number="$version_number"
