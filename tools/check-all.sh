#!/usr/bin/env bash
# tools/check-all.sh — every gate: fmt, clippy, tests,
# tools/new.sh on a temp copy,
# then the SDK's conformance runner (tools/conformance.sh, which needs
# BUWIZ_SDK_DIR).
# SKIP_CONFORMANCE=1 skips conformance, and the run then says it did not pass.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

step() { printf '\n== %s\n' "$*"; }

# the prerequisite first, so a run does not spend minutes before it fails
if [ "${SKIP_CONFORMANCE:-0}" != 1 ] && { [ -z "${BUWIZ_SDK_DIR:-}" ] || [ ! -d "$BUWIZ_SDK_DIR" ]; }; then
  echo "check-all: set BUWIZ_SDK_DIR to a buwiz-sdk checkout (git clone https://github.com/buwiz-app/buwiz-sdk; cd buwiz-sdk; bun install)" >&2
  exit 2
fi

step "the SDK pin (Cargo.toml, crates and Cargo.lock name one revision)"
tools/sdk-pin.sh

step "cargo fmt --check"
cargo fmt --all --check
step "cargo clippy"
cargo clippy --all-targets --quiet -- -D warnings
step "cargo test"
cargo test --quiet
step "tools/new.sh (a temp copy, offline)"
tools/test-new.sh

step "SDK doc links follow the pin"
PIN="$(tools/sdk-pin.sh)"
STALE="$(grep -rhoE 'buwiz-sdk/(blob|tree)/[^/)]+|checkout [0-9a-f]{40}' docs README.md crates/*/README.md | grep -vE "(blob|tree)/$PIN\$|checkout $PIN\$" || true)"
[ -z "$STALE" ] || { printf 'SDK links name a revision other than the pinned %s:\n%s\n' "$PIN" "$STALE" >&2; exit 1; }

if [ "${SKIP_CONFORMANCE:-0}" = 1 ]; then
  printf '\nconformance SKIPPED: not every gate ran\n'
  exit 1
fi
step "conformance (the SDK's buwiz-plugin-test)"
tools/conformance.sh

printf '\nall gates passed\n'
