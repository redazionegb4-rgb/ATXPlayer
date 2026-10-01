#!/bin/sh
set -eu

cd "$CI_PRIMARY_REPOSITORY_PATH"

echo "ATX Player: resolving KSPlayer/FFmpegKit packages..."
xcodebuild \
  -resolvePackageDependencies \
  -project ATXPlayer.xcodeproj \
  -scheme ATXPlayer

echo "Swift packages resolved."
