#!/usr/bin/env bash
# tools/test-new.sh — check tools/new.sh on temp copies of this repo, offline:
#
#   - no --first-party (this repo has a native screen, which Buwiz Bot runs only
#     for Buwiz's own plugins), a missing or bad identity, a title, name or
#     description with a quote, backtick, $ or control character: each exits 2,
#     says why and changes nothing;
#   - the shell's id checks agree with the SDK's own grammar (BUWIZ_SDK_DIR),
#     on a table of valid and invalid short names, plugin ids and publisher ids;
#   - a title, publisher name and description that use the template's own
#     words (Hello, hello_, gc-2026-01, ...) come out exactly as given;
#   - a generated plugin (always --first-party: app.buwiz, the owner's release
#     key id) has no Hello, no template and no new.sh anywhere, has neither
#     tools/new.sh nor tools/test-new.sh, and publish.sh --publish refuses it
#     under another key id, a test key or a test-key pattern, before it builds
#     or looks for the broker (also with the release key id set to unassigned);
#   - what the rename can break still passes in the copy: the formatter and
#     cargo check (offline, in this repo's target directory) and the manifest
#     test (not the whole suite again).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
REPO="$PWD"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/new-sh-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "test-new: $*" >&2; exit 1; }

# a pristine copy of the tracked and untracked files (those that exist: a
# tracked file deleted in the working tree is skipped), as a git repo
mkdir "$TMP/pristine"
git ls-files -z --cached --others --exclude-standard |
  while IFS= read -r -d '' f; do if [ -e "$f" ] || [ -L "$f" ]; then printf '%s\0' "$f"; fi; done |
  tar --null -T - -cf - | tar -xf - -C "$TMP/pristine"
(cd "$TMP/pristine" && git init -q && git add -A)
fresh() { rm -rf "$TMP/w" && cp -R "$TMP/pristine" "$TMP/w"; }
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
generate() { # new.sh args...: a new copy, renamed (no install, format or tests)
  fresh
  (cd "$TMP/w" && tools/new.sh "$@" --no-build >"$TMP/out" 2>&1) || { cat "$TMP/out" >&2; fail "refused: new.sh $*"; }
}
has() { grep -qF -- "$2" "$TMP/w/$1" || fail "$1 lacks: $2"; }
leftovers() { # <extended regex> [-i]: matches in any file of the copy, tracked or not
  local found
  found="$(cd "$TMP/w" && git grep -n ${2:+"$2"} -E "$1" -- . || true)"
  found="$found$(grep -rIn ${2:+"$2"} -E --exclude-dir=.git --exclude-dir=target "$1" "$TMP/w" || true)"
  [ -z "$found" ] || { printf '%s\n' "$found" >&2; fail "the generated copy still has: $1"; }
}

# --- refusals ---
OK=(--first-party --id app.buwiz.widgets --publisher app.buwiz "Buwiz")
refuses "no --first-party" widgets --id app.buwiz.widgets --publisher app.buwiz "Buwiz"
refuses "a third-party identity without --first-party" widgets --id com.example.widgets --publisher com.example "Example"
refuses "no identity" widgets --first-party
refuses "no id" widgets --first-party --publisher app.buwiz "Buwiz"
refuses "no publisher" widgets --first-party --id app.buwiz.widgets
refuses "bad id" widgets --first-party --id Widgets --publisher app.buwiz "Buwiz"
refuses "two-label id" widgets --first-party --id app.widgets --publisher app.buwiz "Buwiz"
refuses "the host's namespace" widgets --first-party --id com.buwiz.bot.widgets --publisher app.buwiz "Buwiz"
refuses "bad publisher" widgets --first-party --id app.buwiz.widgets --publisher Buwiz "Buwiz"
refuses "bad short" w "${OK[@]}"
refuses "--first-party outside app.buwiz" widgets --first-party --id com.example.widgets --publisher com.example "Example"
refuses "--first-party with another publisher" widgets --first-party --id app.buwiz.widgets --publisher com.example "Example"
refuses "a quote in the title" widgets "${OK[@]}" --title 'A "quoted" title'
refuses "a backslash in the publisher name" widgets --first-party --id app.buwiz.widgets --publisher app.buwiz 'A\B'
refuses "a backtick in the title" widgets "${OK[@]}" --title 'A `touch PWNED` title'
refuses "a command substitution in the publisher name" widgets --first-party --id app.buwiz.widgets --publisher app.buwiz '$(touch PWNED)'
refuses "a \$ in the title" widgets "${OK[@]}" --title 'Costs $5'
refuses "a backtick in the description" widgets "${OK[@]}" --description 'Does `date`'
refuses "a \$ in the description" widgets "${OK[@]}" --description 'Does ${HOME}'
refuses "a newline in the title" widgets "${OK[@]}" --title $'two\nlines'
refuses "a title over 60 characters" widgets "${OK[@]}" --title "$(printf 'x%.0s' $(seq 61))"
refuses "a publisher name over 80 characters" widgets --first-party --id app.buwiz.widgets --publisher app.buwiz "$(printf 'x%.0s' $(seq 81))"
refuses "a description over 300 characters" widgets "${OK[@]}" --description "$(printf 'x%.0s' $(seq 301))"

# --- the shell's id checks and the SDK's grammar agree ---
SDK="${BUWIZ_SDK_DIR:-}"
if [ -z "$SDK" ] && [ "${SKIP_CONFORMANCE:-0}" = 1 ]; then
  echo "SKIPPED  the shell's id checks against the SDK's grammar (BUWIZ_SDK_DIR is not set)"
else
  [ -f "$SDK/packages/conformance/src/grammar.mjs" ] ||
    fail "set BUWIZ_SDK_DIR to the buwiz-sdk checkout at the pinned revision (no packages/conformance/src/grammar.mjs in '$SDK')"
  rep() { printf "%$2s" '' | tr ' ' "$1"; } # <char> <count>
  ROWS=(
    "plugin com.example.widgets"
    "plugin example.widgets"
    "plugin a.b.c"
    "plugin a.b.c.d.e.f.g.h"
    "plugin a.b.c.d.e.f.g.h.i"
    "plugin com..widgets"
    "plugin com.example.1widgets"
    "plugin com.example.-widgets"
    "plugin com.example.widgets-"
    "plugin com.example.wid-gets"
    "plugin com.Example.widgets"
    "plugin com.example.wid_gets"
    "plugin com.example.a$(rep b 62)"
    "plugin com.example.a$(rep b 63)"
    "plugin a$(rep b 62).a$(rep b 62).a$(rep b 62).a$(rep b 30).a$(rep b 30)"
    "plugin a$(rep b 62).a$(rep b 62).a$(rep b 62).a$(rep b 31).a$(rep b 31)"
    "plugin buwiz.example.widgets"
    "plugin com.buwiz.bot"
    "plugin com.buwiz.bot.widgets"
    "plugin com.buwiz.botany.widgets"
    "plugin com.buwiz.widgets"
    "plugin app.buwiz.widgets"
    "publisher com.example"
    "publisher acme"
    "publisher a"
    "publisher ab"
    "publisher 9acme"
    "publisher Acme"
    "publisher acme_x"
    "publisher com.9example"
    "publisher com.-x"
    "publisher com.e"
    "publisher com..example"
    "publisher com.example."
    "publisher a$(rep b 62)"
    "publisher a$(rep b 63)"
    "publisher com.$(rep b 62)"
    "publisher com.$(rep b 63)"
    "publisher app.buwiz"
    "short ab"
    "short a"
    "short 9ab"
    "short Ab"
    "short ab-c"
    "short abc123"
    "short a$(rep b 15)"
    "short a$(rep b 16)"
    "short buwiz"
    "short bot"
    "short office"
  )
  : >"$TMP/rows"
  for row in "${ROWS[@]}"; do printf '%s\n' "$row" >>"$TMP/rows"; done
  cat >"$TMP/grammar.mjs" <<'JS'
// each "<kind> <value>" line of stdin: valid or invalid by the SDK's own grammar and reserved names
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
const g = await import(pathToFileURL(`${process.argv[2]}/packages/conformance/src/grammar.mjs`).href);
for (const line of readFileSync(0, "utf8").split("\n")) {
  if (!line) continue;
  const at = line.indexOf(" ");
  const [kind, v] = [line.slice(0, at), line.slice(at + 1)];
  const ok =
    kind === "plugin" ? g.isV1("pluginId", v) && !g.V1_RESERVED.idPrefixes.some((p) => v.startsWith(p))
    : kind === "publisher" ? g.isV1("publisherId", v)
    : g.isV1("short", v) && !g.V1_RESERVED.shorts.includes(v);
  console.log(ok ? "valid" : "invalid");
}
JS
  node "$TMP/grammar.mjs" "$SDK" <"$TMP/rows" >"$TMP/sdk-verdicts"
  [ "$(wc -l <"$TMP/sdk-verdicts" | tr -d ' ')" = "${#ROWS[@]}" ] || fail "the SDK's grammar check answered the wrong number of rows"
  n=0
  for row in "${ROWS[@]}"; do
    n=$((n + 1))
    kind="${row%% *}" value="${row#* }"
    case "$kind" in
      plugin) args=(widgets --first-party --id "$value" --publisher app.buwiz Buwiz) ;;
      publisher) args=(widgets --first-party --id app.buwiz.widgets --publisher "$value" Buwiz) ;;
      short) args=("$value" --first-party --id app.buwiz.widgets --publisher app.buwiz Buwiz) ;;
    esac
    fresh
    code=0
    (cd "$TMP/w" && tools/new.sh "${args[@]}" --no-build >"$TMP/out" 2>&1) || code=$?
    if grep -qE '^new\.sh: (plugin id|publisher id|short) ' "$TMP/out"; then
      shell=invalid
    else
      # valid by the grammar: it went on to generate, or to the --first-party rule
      [ "$code" = 0 ] || grep -q '^new\.sh: --first-party takes' "$TMP/out" || { cat "$TMP/out" >&2; fail "$kind $value: refused for another reason"; }
      shell=valid
    fi
    sdk="$(sed -n "${n}p" "$TMP/sdk-verdicts")"
    [ "$shell" = "$sdk" ] || fail "$kind '$value': new.sh says $shell, the SDK's grammar says $sdk"
  done
  echo "ok  the shell's id checks and the SDK's grammar agree on ${#ROWS[@]} names"
fi

# --- the template's own words in what the developer wrote ---
SRC=crates/widgets-mini-app/src/manifest.rs
HELLO_PUB='Hello hello_x @hello hello-mini-app gc-2026-01'
HELLO_TITLE='Hello Buwiz hello-test-01 app.buwiz.hello'
HELLO_DESC='Hello, hello_greet and @hello:friend by hello-mini-app, gc-2026-01'
generate widgets --first-party --id app.buwiz.widgets --publisher app.buwiz "$HELLO_PUB" --title "$HELLO_TITLE" --description "$HELLO_DESC"
has "$SRC" "pub const TITLE: &str = \"$HELLO_TITLE\";"
has "$SRC" "pub const PUBLISHER_NAME: &str = \"$HELLO_PUB\";"
has "$SRC" "\"description\": \"$HELLO_DESC\","
has package/plugin.json "\"author\": { \"name\": \"$HELLO_PUB\" }"
has package/plugin.json "\"description\": \"$HELLO_DESC\","
has README.md "# $HELLO_TITLE"
has README.md "by $HELLO_PUB:"
has NOTICE "$HELLO_TITLE"
has NOTICE "$HELLO_PUB"
echo "ok  a title, publisher name and description with Hello, hello_, @hello, gc-2026-01 come out as given"

# --- a generated plugin ---
generate widgets "${OK[@]}"
[ ! -e "$TMP/w/tools/new.sh" ] && [ ! -e "$TMP/w/tools/test-new.sh" ] || fail "tools/new.sh or tools/test-new.sh is still in the generated plugin"
[ -z "$(cd "$TMP/w" && git ls-files tools/new.sh tools/test-new.sh)" ] || fail "tools/new.sh or tools/test-new.sh is still tracked"
grep -q 'created app.buwiz.widgets' "$TMP/out" || fail "the run did not say it created app.buwiz.widgets"
(cd "$TMP/w" && bash -n tools/check-all.sh) || fail "the generated tools/check-all.sh does not parse"
leftovers 'hello|template|new\.sh' -i
has "$SRC" 'RELEASE_KEY_ID: &str = "gc-2026-01"'
has "$SRC" 'PUBLISHER_ID: &str = "app.buwiz"'
has "$SRC" 'PUBLISHER_NAME: &str = "Buwiz"'
has "$SRC" 'TITLE: &str = "Widgets"'
has "$SRC" '"description": "Widgets",'
has package/plugin.json '"author": { "name": "Buwiz" }'
has package/plugin.json '"description": "Widgets",'
echo "ok  a generated plugin: no Hello, template or new.sh; the owner's namespace and release key id kept"

# publish.sh refuses these before it builds or looks for the broker
publish_refused() { # <what> <message> [VAR=value]: exit 2, the message, no signing, no output folder
  local what="$1" want="$2"; shift 2
  local code=0
  (cd "$TMP/w" && env -u BUWIZ_BROKER_BIN "$@" tools/release/publish.sh --publish >"$TMP/out" 2>&1) || code=$?
  [ "$code" = 2 ] || { cat "$TMP/out" >&2; fail "$what: exit $code, not 2"; }
  grep -qF -- "$want" "$TMP/out" || { cat "$TMP/out" >&2; fail "$what: no '$want'"; }
  ! grep -q '^signing' "$TMP/out" || fail "$what: it reached a signing step"
  [ ! -e "$TMP/w/dist/release" ] || fail "$what: it made dist/release"
  echo "ok  publish.sh --publish: $what"
}
publish_refused "the plugin's test key id" "test key id (widgets-test-01)" KEY_ID=widgets-test-01
publish_refused "another test key id" "test key id (other-test-07)" KEY_ID=other-test-07
publish_refused "another key id than the release key id" "release key id gc-2026-01 only" KEY_ID=acme-2026-01
publish_refused "the release key id goes on to the broker" "BUWIZ_BROKER_BIN"
# a plugin whose release key id is not assigned yet
perl -pi -e 's/RELEASE_KEY_ID: &str = "gc-2026-01"/RELEASE_KEY_ID: &str = "unassigned"/' "$TMP/w/$SRC"
publish_refused "no KEY_ID, no release key id yet" "no release key id yet"
publish_refused "KEY_ID=unassigned" "no release key id yet" KEY_ID=unassigned
publish_refused "unassigned: the plugin's test key id" "test key id (widgets-test-01)" KEY_ID=widgets-test-01
publish_refused "unassigned: another test key id" "test key id (other-test-07)" KEY_ID=other-test-07
publish_refused "unassigned: a real key id goes on to the broker" "BUWIZ_BROKER_BIN" KEY_ID=acme-2026-01

# --- what the rename can break still passes (offline, in this repo's target directory) ---
generate widgets "${OK[@]}"
(cd "$TMP/w" && cargo fmt --all && cargo fmt --all -- --check &&
  CARGO_TARGET_DIR="$REPO/target" cargo check --offline --quiet --all-targets &&
  CARGO_TARGET_DIR="$REPO/target" cargo test --offline --quiet -p widgets-mini-app --test manifest) >"$TMP/out" 2>&1 ||
  { cat "$TMP/out" >&2; fail "the generated copy is not format-clean, does not check, or its manifest test fails"; }
echo "ok  the generated copy: formatter, cargo check and manifest test"
