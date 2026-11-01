---
name: release
description: Get a release of this mini app ready for the publisher to sign and publish — version bump, gates, a local package check with a throwaway key, then the owner's publish command. Use when asked to release, ship, publish or install a new build.
---

# Prepare a release

A protocol 1.0 release is a package: `plugin.json` with a signed `buwiz` block, the signed manifest and one binary
per platform, as GitHub release assets (`docs/guide.md` section 10).

1. **Raise the version** in `crates/<short>-mini-app/Cargo.toml`, semver, and both `version`s in
   `package/plugin.json` to match. Any change to the manifest or a screen since the last release needs it.
2. **Pass every gate:** `tools/check-all.sh`, conformance included, with no row failing beyond what `AGENTS.md`
   names as known.
3. **Check the package locally**, with a throwaway key under a test key id, never the release key: make the key
   with the Bot's `buwiz-plugin-test --keygen` in a fresh 0700 temp dir outside the repo, write a trust store
   for it (as `tools/bot/conformance.sh` does), then
   `KEY_ID=<short>-test-01 BUWIZ_BROKER_BIN=<buwiz-broker> tools/release/publish.sh --key-file <key> --trust <trust.json>`.
   Delete the temp dir after.
4. **Hand over.** Give the owner the command to run on a clean commit:
   `BUWIZ_BROKER_BIN=<buwiz-broker> tools/release/publish.sh --publish` (add `--prerelease` for a coordinated
   switch: the Bot's install skips pre-releases), once per platform, and the trust entry
   `{ "id": "<plugin id>", "publisher_key_id": "<release key id>" }` for the Bot's trust store. The owner signs
   (the release key is in the login Keychain) and publishes; an agent never signs with the release key, touches
   the Keychain or publishes.

Done when the gates pass, the local package check prints `checked:`, and the owner has the command.
