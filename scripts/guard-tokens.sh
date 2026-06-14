#!/usr/bin/env bash
# Fails if feature code bypasses the design system.
set -euo pipefail
TARGET="${1:-Haven/Sources}"
status=0

scan() { # pattern, message
  if grep -REn --include='*.swift' "$1" "$TARGET" >/tmp/guard.out 2>/dev/null; then
    echo "✗ $2"; cat /tmp/guard.out; status=1
  fi
}

scan 'Color\(\s*(\.sRGB|red:|white:|hue:|#)' 'Raw Color(...) — use a Theme token'
scan 'Color\.(red|orange|yellow|green|mint|teal|cyan|blue|indigo|purple|pink|brown|white|black|gray|primary|secondary)\b' 'System named Color — use a Theme token (Color.clear is allowed)'
scan '\.font\(\s*\.system' '.font(.system ...) — use .havenText(...)'
scan '#[0-9A-Fa-f]{6}' 'Hex literal — primitives live only in HavenDesignSystem'

if [ "$status" -eq 0 ]; then echo "✓ token guard passed"; fi
exit $status
