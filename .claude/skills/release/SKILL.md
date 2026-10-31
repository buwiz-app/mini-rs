---
name: release
description: Prepare a release of this mini app for the publisher to sign — version bump, gates, the unsigned manifest and binary in dist/release. Use when asked to release, ship, publish or install a new build.
---

# Prepare a release

1. **Raise the version** in `crates/<short>-mini-app/Cargo.toml`, semver: the manifest takes it from there. Any
   change to the manifest or a screen since the last release needs it.
2. **Pass every gate:** `tools/check-all.sh`, conformance included, with no row failing beyond what `AGENTS.md`
   names as known.
3. **Prepare:** `tools/release/prepare.sh` builds the binary and the unsigned manifest into `dist/release/` and
   prints the publisher's three steps.
4. **Hand over.** Give the owner the printed steps verbatim: the trust entry, the signing command (release key from
   the login Keychain) and the install. The owner runs them; an agent never signs with the release key or touches
   the Keychain.

Done when `dist/release/` holds the binary and `manifest.json` at the new version, and the owner has the steps.
