#!/bin/sh
set -e

echo "ATX Build 200 - resolving Swift packages"
cd "$CI_PRIMARY_REPOSITORY_PATH"

rm -f ATXPlayer.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

xcodebuild -resolvePackageDependencies \
  -project ATXPlayer.xcodeproj \
  -scheme ATXPlayer

echo "Package resolution complete"
