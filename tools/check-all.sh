#!/usr/bin/env bash
# tools/check-all.sh — every gate: fmt, clippy, tests, then the Bot's
# conformance runner (tools/bot/conformance.sh, which needs BUWIZ_BOT_DIR).
# SKIP_BOT=1 skips conformance, and the run then says it did not pass.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

step() { printf '\n== %s\n' "$*"; }

step "cargo fmt --check"
cargo fmt --all --check
step "cargo clippy"
cargo clippy --all-targets --quiet -- -D warnings
step "cargo test"
cargo test --quiet

if [ "${SKIP_BOT:-0}" = 1 ]; then
  printf '\nconformance SKIPPED: not every gate ran\n'
  exit 1
fi
step "conformance (the Bot's buwiz-plugin-test)"
tools/bot/conformance.sh

printf '\nall gates passed\n'
