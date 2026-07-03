#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRATCH_DIR="${VPSTUDIO_SWIFTPM_SCRATCH:-/tmp/vpstudio-swiftpm-coverage}"

cd "$ROOT_DIR"

echo "== VPStudio SwiftPM coverage preflight =="
echo "root: $ROOT_DIR"
echo "scratch: $SCRATCH_DIR"
echo "developer_dir: $(xcode-select -p 2>/dev/null || echo unavailable)"
echo "swift: $(swift --version | head -n 1)"
echo

if xcodebuild -version >/dev/null 2>&1; then
  echo "xcodebuild: available"
else
  echo "xcodebuild: unavailable via current developer dir"
  echo "note: simulator-backed smoke/e2e/visual/perf flows stay blocked until full Xcode is selected."
fi

if xcrun --find simctl >/dev/null 2>&1; then
  echo "simctl: available"
else
  echo "simctl: unavailable via current developer dir"
fi

echo
echo "== Package describe =="
swift package describe --scratch-path "$SCRATCH_DIR" >/dev/null
echo "package: ok"

echo
echo "== Test discovery =="
swift test list --scratch-path "$SCRATCH_DIR"

echo
echo "== Coverage run =="
echo "command: swift test --scratch-path \"$SCRATCH_DIR\" --enable-code-coverage --show-code-coverage-path $*"
swift test --scratch-path "$SCRATCH_DIR" --enable-code-coverage --show-code-coverage-path "$@"
