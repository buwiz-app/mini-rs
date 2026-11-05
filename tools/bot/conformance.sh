#!/usr/bin/env bash
# tools/bot/conformance.sh — run the Buwiz Bot's conformance runner
# (buwiz-plugin-test) against this mini app's release build:
#
#   1. build the release binary;
#   2. make a fresh 0700 temp dir outside the repo;
#   3. make a throwaway ed25519 test key (buwiz-plugin-test --keygen);
#   4. write a per-run trust store (BUWIZ_TRUST_FILE): that key under a TEST
#      key id, marked first_party (native screens are for first-party keys
#      only), with this plugin approved under it;
#   5. print the manifest under the test key id and sign it with the test
#      key (sign-manifest.mjs --key-file);
#   6. run the runner, which spawns the binary the way the broker does.
#
# The release manifest keeps the release key id; only Buwiz signs it
# (tools/release/publish.sh). Nothing here touches the Keychain or a Bot's
# data folder.
#
# Usage: tools/bot/conformance.sh [runner args, e.g. --json]
# Env:   BUWIZ_BOT_DIR  a buwiz-bot checkout (https://github.com/buwiz-bot/buwiz-bot)
#                       with its server/node_modules installed (cd server && npm ci)
#        TEST_KEY_ID    the test key id (default <short>-test-01)
#        KEEP_TMP=1     keep the temp dir (it holds a test key: delete it after)
set -euo pipefail

BIN_NAME="hello-mini-app"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BOT="${BUWIZ_BOT_DIR:-}"
RUNNER="$BOT/server/sdk/mini-app/bin/buwiz-plugin-test.mjs"
SIGNER="$BOT/server/src/v1/sign-manifest.mjs"

die() { echo "conformance: $*" >&2; exit 2; }
[ -n "$BOT" ] || die "set BUWIZ_BOT_DIR to a buwiz-bot checkout (git clone https://github.com/buwiz-bot/buwiz-bot; cd buwiz-bot/server; npm ci)"
for f in "$RUNNER" "$SIGNER"; do [ -f "$f" ] || die "$f not found: is BUWIZ_BOT_DIR a buwiz-bot checkout on protocol 1.0?"; done
[ -d "$BOT/server/node_modules/@modelcontextprotocol/sdk" ] || die "the Bot's server/node_modules is missing: cd $BOT/server && npm ci"
command -v node >/dev/null || die "node is needed to run the Bot's tools"

# 1. the release binary
cargo build --release --quiet --bin "$BIN_NAME" --manifest-path "$REPO/Cargo.toml"
BIN="$REPO/target/release/$BIN_NAME"

# 2. a fresh temp dir outside the repo, removed on exit
TMP="$(mktemp -d "${TMPDIR:-/tmp}/$BIN_NAME-conformance.XXXXXX")"
chmod 700 "$TMP"
case "$TMP" in "$REPO"/*) die "the temp dir is inside the repo" ;; esac
cleanup() { if [ "${KEEP_TMP:-0}" = 1 ]; then echo "kept $TMP (it holds a test key)" >&2; else rm -rf "$TMP"; fi; }
trap cleanup EXIT

# the plugin's id and short, from the manifest this build prints
"$BIN" manifest >"$TMP/release.json"
read -r PLUGIN_ID SHORT RELEASE_KEY_ID < <(node -e 'const m = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")); console.log(m.id, m.short, m.publisher.key_id)' "$TMP/release.json")
KEY_ID="${TEST_KEY_ID:-$SHORT-test-01}"
[ "$KEY_ID" != "$RELEASE_KEY_ID" ] || die "the test key id must not be the release key id $RELEASE_KEY_ID"

# 3. a throwaway test key (0600); the runner prints only its public key
node "$RUNNER" --keygen "$TMP/test.key" >"$TMP/keygen.txt"
PUB="$(sed -n 's/.*Public key: \([A-Za-z0-9_-]*\).*/\1/p' "$TMP/keygen.txt")"
[ -n "$PUB" ] || die "keygen printed no public key"

# 4. the per-run trust store: the test key id only
cat >"$TMP/trust.json" <<JSON
{
  "v": 1,
  "about": "Per-run trust store for $PLUGIN_ID conformance: a throwaway test key, never a release key.",
  "publishers": { "$KEY_ID": { "publisher": "app.buwiz", "first_party": true, "alg": "ed25519", "public_key": "$PUB" } },
  "approved_plugins": [ { "id": "$PLUGIN_ID", "publisher_key_id": "$KEY_ID" } ]
}
JSON
export BUWIZ_TRUST_FILE="$TMP/trust.json"

# 5. the manifest under the test key id, signed with the test key; every
# TSX app's source as the binary serves it
"$BIN" manifest --key-id "$KEY_ID" >"$TMP/manifest.json"
APP_ARGS=()
for id in $(node -e 'for (const a of JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).apps ?? []) if (a.entry) console.log(a.id)' "$TMP/manifest.json"); do
  "$BIN" app-source "$id" >"$TMP/app-$id.tsx"
  APP_ARGS+=(--app "$id=$TMP/app-$id.tsx")
done
(cd "$BOT/server" && node "$SIGNER" "$TMP/manifest.json" --key-file "$TMP/test.key" ${APP_ARGS[@]+"${APP_ARGS[@]}"} --out "$TMP/signed.json")

# 6. the runner: it serves the signed manifest through BUWIZ_PLUGIN_MANIFEST
cd "$BOT/server"
node --disable-warning=ExperimentalWarning "$RUNNER" \
  --command "$BIN" --args mcp \
  --manifest "$TMP/signed.json" --key-file "$TMP/test.key" "$@"
