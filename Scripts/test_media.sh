#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -swift-version 5 NovaEditor/Timeline.swift NovaEditor/VideoCompositor.swift \
  NovaEditor/MediaEngine.swift Tests/MediaSmokeTests.swift \
  -framework AVFoundation -framework CoreImage -framework Metal \
  -o "$TEST_DIR/media-tests"
"$TEST_DIR/media-tests"
