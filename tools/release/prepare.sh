#!/usr/bin/env bash
# tools/release/prepare.sh — everything a release needs except the
# signature. It builds the release binary and writes, to dist/release/
# (or $1):
#   <binary>        the binary the Bot spawns
#   manifest.json   unsigned, under the release key id
#   app-<id>.tsx    each TSX app's source, exactly as the binary serves it
# then prints the publisher's steps: the trust entry, the signature, the
# install. This script never reads a key or the Keychain.
set -euo pipefail

BIN_NAME="hello-mini-app"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${1:-$REPO/dist/release}"
BOT="${BUWIZ_BOT_DIR:-<buwiz-bot checkout>}"

cargo build --release --quiet --bin "$BIN_NAME" --manifest-path "$REPO/Cargo.toml"
mkdir -p "$OUT"
cp "$REPO/target/release/$BIN_NAME" "$OUT/$BIN_NAME"
BIN="$OUT/$BIN_NAME"
"$BIN" manifest >"$OUT/manifest.json"

read -r PLUGIN_ID VERSION KEY_ID < <(node -e 'const m = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")); console.log(m.id, m.version, m.publisher.key_id)' "$OUT/manifest.json")
APPS=()
for id in $(node -e 'for (const a of JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).apps ?? []) if (a.entry) console.log(a.id)' "$OUT/manifest.json"); do
  "$BIN" app-source "$id" >"$OUT/app-$id.tsx"
  APPS+=(--app "$id=$OUT/app-$id.tsx")
done

cat <<STEPS
Prepared $PLUGIN_ID $VERSION in $OUT (publisher.key_id $KEY_ID).

1. The Bot's owner: approve the plugin under that key, in the Bot's
   server/src/v1/trust.json approved_plugins:
     { "id": "$PLUGIN_ID", "publisher_key_id": "$KEY_ID" }

2. The publisher: sign with the release key from the login Keychain
     cd $BOT/server && node src/v1/sign-manifest.mjs $OUT/manifest.json \\
       --keychain $KEY_ID ${APPS[*]+${APPS[*]}} \\
       --out $OUT/$PLUGIN_ID.manifest.json
   The signed file ships next to the binary, which serves it.

3. Install in the Buwiz Bot (Connect apps), as a local plugin:
     command  $BIN
     args     mcp
STEPS
