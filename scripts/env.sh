#!/usr/bin/env bash
# Source this file; does not change global shell configuration.
INKORA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export INKORA_ROOT
export FLUTTER_ROOT="${INKORA_FLUTTER_ROOT:-$INKORA_ROOT/.tooling/flutter}"
export JAVA_HOME="${INKORA_JAVA_HOME:-$INKORA_ROOT/.tooling/jdk}"
export ANDROID_HOME="${INKORA_ANDROID_HOME:-$INKORA_ROOT/.tooling/android-sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_USER_HOME="${INKORA_ANDROID_USER_HOME:-$INKORA_ROOT/.tooling/android-user}"
export ANDROID_AVD_HOME="${INKORA_ANDROID_AVD_HOME:-$INKORA_ROOT/.tooling/avd}"
export ANDROID_EMULATOR_HOME="$ANDROID_USER_HOME"
export PUB_CACHE="${INKORA_PUB_CACHE:-$INKORA_ROOT/.tooling/pub-cache}"
export GRADLE_USER_HOME="${INKORA_GRADLE_USER_HOME:-$INKORA_ROOT/.tooling/gradle}"
export PATH="$FLUTTER_ROOT/bin:$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
