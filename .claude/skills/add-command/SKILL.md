---
name: add-command
description: Add or change a slash command (`/<short>`) or an `@` scope (`@<short>:<name>:<value>`) and the resolve tool behind it. Use for typed shortcuts, completions, chat tokens or starter prompts.
---

# Add a command or a scope

1. **Declare it** in `manifest.rs`: a `commands` entry `{name, description, args?, resolve}` or a `scopes` entry
   `{name, description, resolve, attach?}`. `resolve` names a read-only tool; reuse `hello_resolve` and branch on
   `name`, or add a resolve tool with the `add-tool` skill.
2. **Answer every input** in the resolve tool. It receives `{kind, name, value, complete, context}` and returns
   one `result`, shaped as `docs/guide.md` section 4 tables it:
   - `complete: true` → `choices`, whose `value`s are tickets;
   - a command → `open` one of your screens, or `prompt` with starter text;
   - a scope → `token` for a value it recognises (including every ticket it offered as a choice), else `error`.
3. **Keep it read-only and quick.** A resolve may issue tickets, never write data; it has 10 seconds.
4. **Test** each `result` through `Harness::resolve`, including `complete: true`, an unknown `value`, and (for an
   attachable scope) a chosen completion resolving to a `token`.

Done when `tools/check-all.sh` passes, with every `INV-04` (scopes) and `INV-05` (commands) row passing in
conformance.
