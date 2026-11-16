#!/usr/bin/env bash
# tools/new.sh — make this template your mini app: rename Hello everywhere.
#
# Usage: tools/new.sh <short> --id <plugin id> --publisher <publisher id> "<publisher name>"
#                     [--title "<Title>"] [--first-party] [--no-build]
#   short        2 to 16 of a-z and 0-9, starting with a letter: the tool
#                prefix (<short>_…), the command (/<short>) and the crate
#                (<short>-mini-app)
#   --id         your plugin's id: reverse DNS under a domain you own
#   --publisher  your publisher id (reverse DNS, e.g. com.acme) and the
#                name users see next to your app
#   --title      the name users see for the app (default: the short, capitalised)
#   --first-party  Buwiz's own new plugins only (the app.buwiz namespace)
#   --no-build   rename only: skip the build, the formatting and the tests
#
# There is no default id or publisher. A new plugin has no release key id
# until Buwiz assigns one at submission: tools/release/publish.sh takes it
# from KEY_ID. It renames the crates, ids, tool names, screen ids and docs, writes a
# short README for your app, then builds, formats and tests. Run it once, on a
# fresh copy; commit the result.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

usage() {
  cat >&2 <<'USAGE'
  tools/new.sh invoices \
    --id com.acme.invoices \
    --publisher com.acme "Acme"

  <short>               2 to 16 of a-z and 0-9, starting with a letter
  --id <plugin id>      reverse DNS under a domain you own
  --publisher <id> "<name>"  your publisher id and the name users see
  --title "<Title>"     the app's name users see (default: the short, capitalised)
  --first-party         Buwiz's own new plugins only (the app.buwiz namespace)
  --no-build            rename only: skip the build, the formatting and the tests
USAGE
  exit 2
}
fail() { echo "new.sh: $*" >&2; usage; }

SHORT= ID= PUB_ID= PUB_NAME= TITLE= FIRST_PARTY=0 BUILD=1
POS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --id) [ $# -ge 2 ] || fail "--id needs a plugin id"; ID="$2"; shift 2 ;;
    --publisher)
      [ $# -ge 3 ] && [[ "$3" != -* ]] || fail "--publisher needs a publisher id and a name"
      PUB_ID="$2"; PUB_NAME="$3"; shift 3 ;;
    --title) [ $# -ge 2 ] || fail "--title needs a title"; TITLE="$2"; shift 2 ;;
    --first-party) FIRST_PARTY=1; shift ;;
    --no-build) BUILD=0; shift ;;
    -*) fail "unknown option $1" ;;
    *) POS+=("$1"); shift ;;
  esac
done
[ ${#POS[@]} -le 1 ] || fail "one short name, not ${#POS[@]}"
if [ -z "$ID" ] || [ -z "$PUB_ID" ]; then fail "give your plugin an id and a publisher:"; fi
[ ${#POS[@]} -eq 1 ] || fail "give your plugin a short name:"
SHORT="${POS[0]}"

[[ "$SHORT" =~ ^[a-z][a-z0-9]{1,15}$ ]] || fail "short must be 2 to 16 of a-z and 0-9, starting with a letter"
case "$SHORT" in buwiz | app | chat | mcp | nsh | all | office | skill | routine | bot | hello) fail "short $SHORT is reserved" ;; esac
TYPE="$(printf '%s' "${SHORT:0:1}" | tr a-z A-Z)${SHORT:1}"
TITLE="${TITLE:-$TYPE}"
[ "${#TITLE}" -ge 1 ] && [ "${#TITLE}" -le 60 ] || fail "the title must be 1 to 60 characters"
[[ "$TITLE$PUB_NAME" != *[\"\\]* ]] || fail "the title and the publisher name may not contain a quote or a backslash"
[ "${#PUB_NAME}" -ge 1 ] && [ "${#PUB_NAME}" -le 80 ] || fail "the publisher name must be 1 to 80 characters"
# the SDK's grammars (docs/manifest.md, protocol 1.0 section 4)
[ "${#ID}" -le 255 ] && [[ "$ID" =~ ^[a-z][a-z0-9-]{0,62}(\.[a-z][a-z0-9-]{0,62}){2,7}$ ]] ||
  fail "plugin id $ID is not reverse DNS with 3 to 8 labels (e.g. com.acme.$SHORT)"
case "$ID" in buwiz.* | com.buwiz.bot | com.buwiz.bot.*) fail "plugin id $ID is the host's own namespace" ;; esac
[[ "$PUB_ID" =~ ^[a-z][a-z0-9-]{1,62}(\.[a-z0-9-]{1,62})*$ ]] || fail "publisher id $PUB_ID is not reverse DNS (e.g. com.acme)"
# app.buwiz is Buwiz's own, and only Buwiz can sign for it
if [ "$FIRST_PARTY" = 1 ]; then
  [ "$PUB_ID" = app.buwiz ] && [[ "$ID" == app.buwiz.* ]] || fail "--first-party takes the id app.buwiz.<name> and the publisher app.buwiz"
  RELEASE_KEY_ID="gc-2026-01"
else
  if [[ "$ID" == app.buwiz.* || "$PUB_ID" == app.buwiz || "$PUB_ID" == app.buwiz.* ]]; then
    fail "app.buwiz is Buwiz's own namespace and only Buwiz can sign for it: use your own (--first-party is for Buwiz's own new plugins)"
  fi
  RELEASE_KEY_ID="unassigned"
fi
[ -d crates/hello-mini-app ] || fail "already renamed (no crates/hello-mini-app)"

git mv crates/hello-mini-app "crates/$SHORT-mini-app"
git mv crates/hello-screens "crates/$SHORT-screens"

# every tracked text file but these scripts and the lockfile
git ls-files -z | grep -zv -e '^tools/new.sh$' -e '^tools/test-new.sh$' -e '^Cargo.lock$' | while IFS= read -r -d '' f; do
  [ -f "$f" ] || continue
  TITLE="$TITLE" ID="$ID" PUB_ID="$PUB_ID" PUB_NAME="$PUB_NAME" RELEASE_KEY_ID="$RELEASE_KEY_ID" SHORT="$SHORT" TYPE="$TYPE" perl -pi -e '
    s/pub const TITLE: &str = "Hello";/pub const TITLE: &str = "$ENV{TITLE}";/g;
    s/pub const PUBLISHER_ID: &str = "app\.buwiz";/pub const PUBLISHER_ID: &str = "$ENV{PUB_ID}";/g;
    s/pub const PUBLISHER_NAME: &str = "Buwiz";/pub const PUBLISHER_NAME: &str = "$ENV{PUB_NAME}";/g;
    s/\bgc-2026-01\b/$ENV{RELEASE_KEY_ID}/g;
    s/app\.buwiz\.hello\b/$ENV{ID}/g;
    s/\bhello(?=[-_.](mini|screens|test|home)\b|_mini_app\b)/$ENV{SHORT}/g;
    s/\bhello_/$ENV{SHORT}_/g;
    s/([@\/"`])hello\b/$1$ENV{SHORT}/g;
    s/\bHello\b/$ENV{TYPE}/g;
  ' "$f"
done

cat >README.md <<README
# $TITLE

A mini app for the Buwiz Bot by $PUB_NAME: plugin \`$ID\`, made from
[buwiz-app/mini-rs](https://github.com/buwiz-app/mini-rs). [docs/guide.md](docs/guide.md) is the walkthrough;
\`tools/check-all.sh\` runs every gate.
README

if [ "$BUILD" = 1 ]; then
  cargo build --quiet
  cargo fmt --all # the new names change what fits on a line
  cargo test --quiet
fi
echo "new.sh: created $ID ($TITLE, by $PUB_NAME): $SHORT-mini-app, tools ${SHORT}_*, /$SHORT. Review the diff, then commit."
