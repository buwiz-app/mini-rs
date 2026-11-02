# AGENTS.md

A Buwiz Bot mini app in Rust (Buwiz Mini App Protocol 1.0), made from the `buwiz-app/mini-rs` template. The SDK
(`buwiz-plugin`, from `buwiz-app/buwiz-sdk`, pinned by rev in the root `Cargo.toml`) does the protocol; this repo
holds the manifest (`src/manifest.rs`), the tools (`src/tools.rs`), the screens and the package template
(`package/plugin.json`). `docs/guide.md` is the reference for every part.

Skills, by task: `add-tool`, `add-command` (commands and scopes), `add-screen`, `release`.

## Invariants

1. **The manifest declares everything.** A tool a screen calls is in that app's `permissions.tools`; a resolve or
   routine query names a read-only tool; a routine's write is in its `writes`. `tests/manifest.rs` runs the SDK's
   quick check; conformance runs the Bot's full one.
2. **Tools start with the manifest's `short` and `_`**, and say `read_only: true` unless they change data.
3. **Tickets, not identifiers.** A subject leaves the process only as a ticket. A tool refuses a ticket it did not
   issue (P1); a ticket's title never reveals its subject.
4. **Text without secrets.** No subject data and never a key in a message, title or log (P4, P9). Side effects sit
   behind explicit arguments, so a call with `{}` changes nothing (P5).
5. **One version, one signature.** Any change to the manifest or a screen raises `version` in the crate's
   `Cargo.toml`, the one place: `package` fills `package/plugin.json`'s version, ids and publisher from the
   signed manifest. Tests sign with a throwaway test key id (`hello-test-01`); only the owner signs a release
   with the release key, from the Keychain. Agents never touch the Keychain.
6. **One protocol version.** Protocol 1.0 (`1.0.0`) only. No shims for older protocol names or versions.

## Gates

`tools/check-all.sh` passes before every commit: `cargo fmt --check`, `cargo clippy --all-targets -D warnings`,
`cargo test`, and `tools/bot/conformance.sh`, which needs a buwiz-bot checkout in `BUWIZ_BOT_DIR` (`docs/guide.md`
section 7). `SKIP_BOT=1` skips conformance and fails the run, so a skip never reads as a pass.
