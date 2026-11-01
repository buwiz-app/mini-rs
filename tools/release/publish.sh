#!/usr/bin/env bash
# tools/release/publish.sh — build this machine's release and write a
# protocol 1.0 package's GitHub release assets to dist/release/ (flat
# names, as GitHub's are):
#   <binary>-<os>-<arch>     the binary (os, arch as Rust names them),
#                            installed at bin/<binary>
#   <plugin id>.manifest.json the signed manifest it serves, installed at
#                            bin/<plugin id>.manifest.json beside it
#   plugin.json              package/plugin.json with buwiz.files and
#                            buwiz.binaries filled in by the binary's
#                            `package` command, its buwiz block signed
# Both are signed with the publisher key from the login Keychain: macOS
# asks twice (the manifest, then plugin.json). Only the owner runs that.
#
# With --publish it then creates the release v<version> on GitHub (gh), or,
# when it exists (another platform's run), adds this platform's binary to
# its plugin.json, re-signs that and uploads both.
#
# Usage: tools/release/publish.sh [--publish [--prerelease]] [--key-file <seed file>] [--trust <trust.json>]
#   --prerelease       mark a new release as a pre-release: the Bot's install
#                      from the repo URL reads the latest release, which
#                      skips pre-releases (for a coordinated switch)
#   --key-file <path>  sign with a seed file instead (a throwaway key for
#                      local checks; never with --publish)
#   --trust <file>     check the result as the Bot does (`buwiz-broker
#                      manifest verify` and `manifest package`) against
#                      this trust store
# Env:
#   BUWIZ_BROKER_BIN   buwiz-broker from buwiz-bot/buwiz-bot (broker/): its
#                      sign-manifest and manifest checks
#   KEY_ID             the publisher key id to sign under (default: the
#                      release key id); another id, such as a test key's,
#                      goes into the manifest and plugin.json for a local
#                      check, never with --publish
#   GH_REPO            default: this checkout's GitHub repo (gh repo view)
set -euo pipefail

BIN_NAME="hello-mini-app"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$REPO/dist/release"
PUBLISH=0
PRERELEASE=()
KEY_FILE=
TRUST=
die() { echo "publish: $*" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --publish) PUBLISH=1 ;;
    --prerelease) PRERELEASE=(--prerelease) ;;
    --key-file) KEY_FILE="${2:?--key-file needs a path}"; shift ;;
    --trust) TRUST="${2:?--trust needs a file}"; shift ;;
    *) die "usage: publish.sh [--publish [--prerelease]] [--key-file <seed file>] [--trust <trust.json>]" ;;
  esac
  shift
done
BROKER="${BUWIZ_BROKER_BIN:-}"
[ -x "$BROKER" ] || die "set BUWIZ_BROKER_BIN to a buwiz-broker build (buwiz-bot/buwiz-bot broker/)"
[ "$PUBLISH" = 1 ] || [ ${#PRERELEASE[@]} = 0 ] || die "--prerelease needs --publish"
[ "$PUBLISH" = 0 ] || [ -z "$KEY_FILE" ] || die "--publish signs with the Keychain key only"
command -v node >/dev/null || die "node is needed to read the manifest"

case "$(uname -s)" in Darwin) OS=macos ;; Linux) OS=linux ;; *) die "unsupported OS $(uname -s)" ;; esac
case "$(uname -m)" in arm64 | aarch64) ARCH=aarch64 ;; x86_64) ARCH=x86_64 ;; *) die "unsupported arch $(uname -m)" ;; esac
PLATFORM="$OS-$ARCH"
BIN_ASSET="$BIN_NAME-$PLATFORM"

cd "$REPO"
# a release is a commit; a local check with a throwaway key may run on changes
if [ -z "$KEY_FILE" ] && [ -n "$(git status --porcelain)" ]; then die "the tree has changes: release a commit"; fi
COMMIT="$(git rev-parse HEAD)"
cargo build --release --locked --quiet --bin "$BIN_NAME"
rm -rf "$OUT" && mkdir -p "$OUT"
cp "target/release/$BIN_NAME" "$OUT/$BIN_ASSET"
BIN="$OUT/$BIN_ASSET"
"$BIN" manifest >"$OUT/manifest.json"

json() { node -e 'const m = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")); console.log(eval(process.argv[2]))' "$OUT/manifest.json" "$1"; }
PLUGIN_ID="$(json m.id)"
VERSION="$(json m.version)"
RELEASE_KEY_ID="$(json m.publisher.key_id)"
KEY_ID="${KEY_ID:-$RELEASE_KEY_ID}"
TAG="v$VERSION"
TEMPLATE=package/plugin.json
if [ "$KEY_ID" != "$RELEASE_KEY_ID" ]; then
  # a local check under another key id: the manifest and plugin.json name it
  [ "$PUBLISH" = 0 ] || die "--publish signs under the release key id $RELEASE_KEY_ID only"
  "$BIN" manifest --key-id "$KEY_ID" >"$OUT/manifest.json"
  TEMPLATE="$OUT/plugin.template.json"
  node -e 'const fs = require("fs"); const p = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); p.buwiz.publisher.key_id = process.argv[3]; fs.writeFileSync(process.argv[2], JSON.stringify(p, null, 2) + "\n")' \
    package/plugin.json "$TEMPLATE" "$KEY_ID"
fi
if [ -n "$KEY_FILE" ]; then SIGN=(--key-file "$KEY_FILE"); HOW="(a key file)"; else SIGN=(--keychain "$KEY_ID"); HOW="(approve the Keychain prompt)"; fi

# each TSX app's source as the binary serves it, for its fingerprint
APPS=()
for id in $(json '(m.apps ?? []).filter((a) => a.entry).map((a) => a.id).join("\n")'); do
  "$BIN" app-source "$id" >"$OUT/app-$id.tsx"
  APPS+=(--app "$id=$OUT/app-$id.tsx")
done

echo "signing the manifest with $KEY_ID $HOW" >&2
"$BROKER" sign-manifest "$OUT/manifest.json" "${SIGN[@]}" ${APPS[@]+"${APPS[@]}"} --out "$OUT/$PLUGIN_ID.manifest.json"
rm -f "$OUT/manifest.json" "$OUT"/app-*.tsx

PUBLISHED=()
EXISTS=0
if [ "$PUBLISH" = 1 ]; then
  GH_REPO="${GH_REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
  if gh release view "$TAG" -R "$GH_REPO" >/dev/null 2>&1; then
    # another platform's run: keep the platforms the release already has
    EXISTS=1
    gh release download "$TAG" -R "$GH_REPO" -p plugin.json -O "$OUT/published.plugin.json" --clobber
    PUBLISHED=(--published "$OUT/published.plugin.json")
    echo "$TAG exists: adding $PLATFORM to its plugin.json" >&2
  fi
fi
# fills buwiz.files and buwiz.binaries; writes plugin.unsigned.json
"$BIN" package "$TEMPLATE" "$OUT" "$PLATFORM" ${PUBLISHED[@]+"${PUBLISHED[@]}"}
rm -f "$OUT/published.plugin.json" "$OUT/plugin.template.json"

echo "signing plugin.json's buwiz block with $KEY_ID $HOW" >&2
"$BROKER" sign-manifest "$OUT/plugin.unsigned.json" --block buwiz "${SIGN[@]}" --out "$OUT/plugin.json"
rm "$OUT/plugin.unsigned.json"

if [ -n "$TRUST" ]; then
  # as the Bot's install checks them: the served manifest's signature, then
  # plugin.json's block for this platform
  node - "$OUT" "$TRUST" "$PLATFORM" "$BROKER" "$PLUGIN_ID" <<'JS'
const { execFileSync } = require("child_process");
const fs = require("fs");
const [out, trustFile, platform, broker, id] = process.argv.slice(2);
const trust = JSON.parse(fs.readFileSync(trustFile, "utf8"));
const op = (name, req) => {
  let text;
  try {
    text = execFileSync(broker, ["manifest", name], { input: JSON.stringify(req), encoding: "utf8" });
  } catch (e) {
    text = e.stdout || "";
  }
  const a = JSON.parse(text || "{}");
  if (!a.ok) throw new Error(`buwiz-broker manifest ${name}: ${text.trim()}`);
  return a.value;
};
const served = op("verify", { text: fs.readFileSync(`${out}/${id}.manifest.json`, "utf8"), trust }).manifest;
const p = op("package", { text: fs.readFileSync(`${out}/plugin.json`, "utf8"), trust, platform });
for (const k of ["id", "short", "version"]) {
  if (served[k] !== p[k]) throw new Error(`the served manifest's ${k} is ${served[k]}; plugin.json's is ${p[k]}`);
}
console.error(`checked: ${p.id} ${p.version} for ${platform}, binary ${p.binary.asset}`);
JS
fi
echo "dist/release: $PLUGIN_ID $TAG for $PLATFORM at $COMMIT" >&2

if [ "$PUBLISH" = 0 ]; then
  cat >&2 <<STEPS
dry run: --publish creates the release. Before the Bot installs it, its owner
approves the plugin under that key (trust store approved_plugins):
  { "id": "$PLUGIN_ID", "publisher_key_id": "$KEY_ID" }
STEPS
  exit 0
fi
if [ "$EXISTS" = 1 ]; then
  gh release upload "$TAG" -R "$GH_REPO" --clobber "$OUT/$BIN_ASSET" "$OUT/plugin.json"
else
  gh release create "$TAG" -R "$GH_REPO" --target "$COMMIT" ${PRERELEASE[@]+"${PRERELEASE[@]}"} \
    --title "$BIN_NAME $VERSION" \
    --notes "$PLUGIN_ID $VERSION, Buwiz mini app protocol 1.0. Install it by asking Buwiz Bot's agent to install https://github.com/$GH_REPO" \
    "$OUT/$BIN_ASSET" "$OUT/$PLUGIN_ID.manifest.json" "$OUT/plugin.json"
fi
echo "published $TAG${PRERELEASE[*]:+ (pre-release)}" >&2
