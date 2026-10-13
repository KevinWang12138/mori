#!/bin/bash
set -euo pipefail
MORI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$MORI_ROOT"
(cd Web && npm ci --no-fund --no-audit && npm run check && npm test && npm run build)
swift test
swift build -c release
git diff --check
