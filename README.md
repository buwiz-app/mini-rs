# mini-rs

A template for a Buwiz Bot mini app in Rust, with native Rust screens. Fork it, run one command to name it, and
build: the protocol comes from [buwiz-sdk](https://github.com/buwiz-app/buwiz-sdk), so the template holds only
what is yours.

```sh
tools/new.sh notes "Notes"     # name it: app.buwiz.notes, notes_* tools, /notes
cargo test                     # your tests, through the SDK's harness
tools/check-all.sh             # every gate, the Bot's conformance runner included
```

The example app, Hello, has one tool (`hello_greet`), a `/hello` command and an `@hello:friend` scope (one resolve
tool, `hello_resolve`), and one native screen (`hello.home`).

| Path | What |
|---|---|
| `crates/hello-mini-app/` | The mini app: `manifest.rs`, `tools.rs`, and the `Plugin` impl in `lib.rs` |
| `crates/hello-screens/` | Native screens, once the native-screen SDK ships |
| `tests/` | Integration tests |
| `tools/` | `new.sh`, `check-all.sh`, `bot/conformance.sh`, `release/prepare.sh` |
| `docs/guide.md` | The walkthrough: tools, commands and scopes, screens, routines, tests, release |
| `.claude/skills/` | Skills for coding agents: add a tool, a command or scope, a screen; release |

Want TSX screens, or TypeScript throughout? Use [buwiz-app/mini-tsx](https://github.com/buwiz-app/mini-tsx).
Native screens are for first-party (`app.buwiz`) mini apps; any publisher can ship TSX.
