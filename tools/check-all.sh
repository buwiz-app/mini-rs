#!/usr/bin/env bash
# tools/check-all.sh — every gate: fmt, clippy, tests, then the SDK's
# conformance runner (tools/conformance.sh, which needs BUWIZ_SDK_DIR).
# SKIP_CONFORMANCE=1 skips conformance, and the run then says it did not pass.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

step() { printf '\n== %s\n' "$*"; }

step "cargo fmt --check"
cargo fmt --all --check
step "cargo clippy"
cargo clippy --all-targets --quiet -- -D warnings
step "cargo test"
cargo test --quiet

step "SDK doc links follow the pin"
PIN="$(sed -n 's/^buwiz-plugin = .*rev = "\([0-9a-f]\{40\}\)".*/\1/p' Cargo.toml)"
STALE="$(grep -rhoE 'buwiz-sdk/blob/[^/)]+|checkout [0-9a-f]{40}' docs README.md | grep -vE "blob/$PIN\$|checkout $PIN\$" || true)"
[ -z "$STALE" ] || { printf 'SDK links name a revision other than the pinned %s:\n%s\n' "$PIN" "$STALE" >&2; exit 1; }

if [ "${SKIP_CONFORMANCE:-0}" = 1 ]; then
  printf '\nconformance SKIPPED: not every gate ran\n'
  exit 1
fi
step "conformance (the SDK's buwiz-plugin-test)"
tools/conformance.sh

printf '\nall gates passed\n'
