---
name: add-screen
description: Add or change a screen of this mini app (an app in the manifest) — a full-screen view or an inline chat card, native Rust. Use for anything the user sees.
---

# Add a screen

1. **Declare the app** in `manifest.rs` `apps`: `id`, `title`, `description`,
   `"native": {"screen": "<short>.<id>", "abi": NATIVE_ABI}`, a `props` schema (tickets as strings of at most 30
   characters), `placement` (`full`, `inline` or both), `inline` size when inline, and `permissions` granting
   exactly what it uses: the tools it calls, plus `open`, `attach`, `pick_file`, `storage`, `copy` or `preview`.
2. **Write the screen** in `crates/hello-screens` against the native-screen SDK (`buwiz-mini-app`), registering
   the screen id from step 1 in `screens()`. Until that SDK ships the crate holds only its README: stop after step
   1 and say the screen code waits for it (`crates/hello-screens/README.md`).
3. **Grant before you call.** Every tool the screen calls is in its `permissions.tools`, and nothing else.
4. **Test** that the screen's tools answer as that app: `h.app(<id>, <tool>, …)` in `tests/tools.rs`.

Done when `tools/check-all.sh` passes.
