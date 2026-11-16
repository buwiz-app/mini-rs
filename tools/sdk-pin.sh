#!/usr/bin/env bash
# tools/sdk-pin.sh — print the buwiz-sdk revision this repo pins: the one
# place it is read from (tools/conformance.sh and the SDK link check in
# tools/check-all.sh call it). The revision is named in the root Cargo.toml
# (buwiz-plugin), in crates/*/Cargo.toml (buwiz-app) and in Cargo.lock; if
# they do not all name one revision it lists each place and fails.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# every buwiz-sdk git revision, as <file>:<line>:<revision>
REFS="$(awk 'index($0, "buwiz-sdk") && match($0, /rev *= *"?[0-9a-f]+/) { r = substr($0, RSTART, RLENGTH); sub(/^rev *= *"?/, "", r); print FILENAME ":" FNR ":" r }' Cargo.toml crates/*/Cargo.toml Cargo.lock)"
[ -n "$REFS" ] || { echo "sdk-pin: no buwiz-sdk revision in Cargo.toml" >&2; exit 1; }
grep -q 'buwiz-sdk?rev=' Cargo.lock || { echo "sdk-pin: Cargo.lock names no buwiz-sdk revision" >&2; exit 1; }
PINS="$(printf '%s\n' "$REFS" | sed 's/.*://' | sort -u)"
if [ "$(printf '%s\n' "$PINS" | wc -l | tr -d ' ')" != 1 ] || [ "${#PINS}" != 40 ]; then
  { echo "sdk-pin: the buwiz-sdk revision is not one 40-digit commit; it is named:"; printf '%s\n' "$REFS" | sed 's/^/  /'; } >&2
  exit 1
fi
printf '%s\n' "$PINS"
