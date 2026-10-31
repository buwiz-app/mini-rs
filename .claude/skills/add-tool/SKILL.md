---
name: add-tool
description: Add or change a tool in this mini app — anything the model, a screen or a routine calls (`<short>_*`). Use for a new capability, a new data read or write, or a changed tool's arguments or result.
---

# Add a tool

1. **Name it.** `<short>_<verb>` (the manifest's `short`, today `hello`), unique in `tools.rs`.
2. **List it** in `tools::list()`: a description written for the model choosing among tools, an `input_schema`
   that names every argument, and `read_only: true` unless it changes data.
3. **Run it** in `tools::call()`: answer `ok(json!({…}))`, or `fail(code, message)` with a protocol code
   (`not_found`, `invalid_args`, `permission_denied`…) and a user-readable message first.
   - Every ticket argument: look it up in your own tickets or store, and `fail("not_found", …)` when you did not
     issue it.
   - A write happens only when an explicit argument asks for it, so a call with `{}` changes nothing.
   - Results carry tickets, never raw identifiers; messages carry no subject data.
4. **Grant it** where it is used: a screen that calls it lists it in its app's `permissions.tools` in
   `manifest.rs`; a routine that writes with it lists it in `writes`.
5. **Test it** in `tests/tools.rs` through `Harness`: the answer as the model, a refusal for a ticket you did not
   issue, and, if a screen calls it, `h.app(<app>, <tool>, …)`.

Done when `tools/check-all.sh` passes, with `MAN-10` and the tool's `BRG-03` call rows passing in conformance.
Reference: `docs/guide.md` sections 3 and 8.
