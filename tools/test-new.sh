#!/usr/bin/env bash
# tools/test-new.sh — check tools/new.sh on a temp copy of this repo, offline:
# no identity, a bad id, a bad publisher and Buwiz's own namespace without
# --first-party each exit 2 and change nothing; a valid identity renames the
# copy, and the copy then names no app.buwiz and no owner key id (tools/new.sh
# and this script name them, to refuse them, and are the only files that may)
# and builds (cargo check, offline).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
REPO="$PWD"

if [ ! -d crates/hello-mini-app ]; then
  echo "test-new: this is not the template any more (already renamed): nothing to test"
  exit 0
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/new-sh-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "test-new: $*" >&2; exit 1; }

fresh() { # a new copy of the tracked and untracked files, as a git repo
  rm -rf "$TMP/w" && mkdir "$TMP/w"
  git ls-files -z --cached --others --exclude-standard | tar --null -T - -cf - | tar -xf - -C "$TMP/w"
  (cd "$TMP/w" && git init -q && git add -A)
}
tree() { (cd "$TMP/w" && git add -A && git write-tree); }
refuses() { # <what> <new.sh args...>: exit 2, a line saying why, the tree unchanged
  local what="$1"; shift
  fresh
  local before after code=0
  before="$(tree)"
  (cd "$TMP/w" && tools/new.sh "$@" >"$TMP/out" 2>&1) || code=$?
  after="$(tree)"
  [ "$code" = 2 ] || fail "$what: exit $code, not 2"
  grep -q '^new.sh: ' "$TMP/out" || fail "$what: no explanation"
  [ "$before" = "$after" ] || fail "$what: the tree changed"
  echo "ok  $what"
}

refuses "no identity" widgets
refuses "no id" widgets --publisher com.example "Example"
refuses "no publisher" widgets --id com.example.widgets
refuses "bad id" widgets --id Widgets --publisher com.example "Example"
refuses "two-label id" widgets --id example.widgets --publisher com.example "Example"
refuses "the host's namespace" widgets --id com.buwiz.bot.widgets --publisher com.example "Example"
refuses "bad publisher" widgets --id com.example.widgets --publisher Example "Example"
refuses "bad short" w --id com.example.widgets --publisher com.example "Example"
refuses "app.buwiz id" widgets --id app.buwiz.widgets --publisher com.example "Example"
refuses "app.buwiz publisher" widgets --id com.example.widgets --publisher app.buwiz "Buwiz"
refuses "--first-party outside app.buwiz" widgets --first-party --id com.example.widgets --publisher com.example "Example"

# a valid identity
fresh
(cd "$TMP/w" && tools/new.sh widgets --id com.example.widgets --publisher com.example "Example" --no-build >"$TMP/out" 2>&1) ||
  { cat "$TMP/out" >&2; fail "a valid identity was refused"; }
grep -q 'created com.example.widgets' "$TMP/out" || fail "the valid run did not say it created com.example.widgets"
LEFT="$(cd "$TMP/w" && git grep -n -e 'app\.buwiz' -e 'gc-2026-01' -- . ':!tools/new.sh' ':!tools/test-new.sh' || true)"
[ -z "$LEFT" ] || { printf '%s\n' "$LEFT" >&2; fail "the generated copy still names app.buwiz or the owner's release key id"; }
grep -q 'RELEASE_KEY_ID: &str = "unassigned"' "$TMP/w/crates/widgets-mini-app/src/manifest.rs" || fail "the release key id is not unassigned"
grep -q 'PUBLISHER_ID: &str = "com.example"' "$TMP/w/crates/widgets-mini-app/src/manifest.rs" || fail "the publisher id was not set"
echo "ok  a valid identity: no app.buwiz, no owner key id"

# --first-party keeps the owner's namespace and release key id
fresh
(cd "$TMP/w" && tools/new.sh widgets --first-party --id app.buwiz.widgets --publisher app.buwiz "Buwiz" --no-build >/dev/null 2>&1) ||
  fail "--first-party with app.buwiz was refused"
grep -q 'RELEASE_KEY_ID: &str = "gc-2026-01"' "$TMP/w/crates/widgets-mini-app/src/manifest.rs" || fail "--first-party lost the release key id"
echo "ok  --first-party"

# the renamed copy builds, with its tests (offline, in this repo's target dir so
# the dependencies are not built again)
fresh
(cd "$TMP/w" && tools/new.sh widgets --id com.example.widgets --publisher com.example "Example" --no-build >/dev/null 2>&1)
(cd "$TMP/w" && CARGO_TARGET_DIR="$REPO/target" cargo check --offline --quiet --all-targets >"$TMP/out" 2>&1) ||
  { cat "$TMP/out" >&2; fail "the generated copy's cargo check failed"; }
echo "ok  the generated copy's cargo check"
