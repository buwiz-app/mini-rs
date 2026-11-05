# Building a mini app in Rust

A mini app is a plugin for the Buwiz Bot: a small binary the Bot spawns, speaking MCP on stdin and stdout. It
brings **tools** (the model, screens and routines call them), **commands** (`/hello`) and **scopes**
(`@hello:friend:Ada`), **routines** (timed agent runs) and **screens** (full screen, or inline cards in the chat).
A signed **manifest** declares all of it, and the Bot trusts nothing the manifest does not declare.

You write what is yours: the manifest, the tools, the screens. The SDK
([buwiz-app/buwiz-sdk](https://github.com/buwiz-app/buwiz-sdk), crate `buwiz-plugin`) does the protocol: MCP, the
reserved `buwiz.*` tools, session certificates, tickets, pushed account tokens, the caller checks and the release
package. The protocol is Buwiz Mini App Protocol 1.0
([the spec](https://github.com/buwiz-app/buwiz-sdk/blob/main/docs/protocol-1.0.md)); the manifest declares `1.0.0`.

You can build and test a mini app freely. Before it installs in the Bot, Buwiz reviews it and signs it, so you need no
signing key of your own (section 10).

## 1. Make it yours

Click **Use this template** on GitHub (or clone it), then name your app:

```sh
tools/new.sh notes "Notes"            # plugin id app.buwiz.notes
tools/new.sh notes "Notes" com.example.notes
```

It renames the crate, the plugin id, every `hello_*` tool, the `/hello` command and the screen id, writes a short
README, then builds and tests. The rest of this guide calls the app Hello.

## 2. What is where

| Path | What |
|---|---|
| `crates/hello-mini-app/src/manifest.rs` | The manifest, built in code; its version is the crate's |
| `crates/hello-mini-app/src/tools.rs` | The tools: `list()` (what the model sees) and `call()` (what runs) |
| `crates/hello-mini-app/src/lib.rs` | `Hello`: the state (tickets, your store) and the `Plugin` impl that ties it together |
| `crates/hello-mini-app/src/main.rs` | One line: the SDK's command line |
| `crates/hello-screens/` | Native screens, on the SDK's `buwiz-app` crate ([its README](../crates/hello-screens/README.md)) |
| `package/plugin.json` | The package template a release fills and signs (section 10) |
| `tests/` | Integration tests, through the SDK's harness |
| `tools/` | `check-all.sh` (every gate), `bot/conformance.sh`, `release/publish.sh`, `new.sh` |

The binary's command line comes from the SDK:

```
hello-mini-app mcp                       what the Bot runs
hello-mini-app manifest [--key-id <id>]  the unsigned manifest, for signing
hello-mini-app app-source <id>           a TSX app's source (none here: Hello's screens are native)
hello-mini-app package <plugin.json> <out> <platform> [--published <plugin.json>]
                                         fill a release's plugin.json to sign (section 10)
```

## 3. Add a tool

1. In `tools.rs`, name it `hello_<verb>` (every tool starts with the manifest's `short` and `_`), and add it to
   `list()`: a description the model reads to choose it, a JSON Schema for its arguments, and
   `read_only: true` unless it changes data.
2. Add its arm to `call()`. Answer `ok(json!({…}))`, or `fail(code, message)` with a code such as `not_found` or
   `invalid_args` and a message the user can read.
3. A screen that calls it lists it in its app's `permissions.tools` in `manifest.rs`; the model can call any tool.
4. Test it in `tests/` through the harness (section 7).

The SDK refuses a call before it reaches you when the caller may not make it (section 8). What it cannot know is
your data: check every ticket an argument carries against your own subjects, and refuse one you did not issue.

## 4. Add a command or a scope

A command (`/hello ada`) and a scope (`@hello:friend:ada`) each name a **resolve tool**, a read-only tool the Bot
calls with `{kind: "command" | "scope", name, value, complete, context}`. It answers one `result`:

| `result` | Fields | Means |
|---|---|---|
| `choices` | `choices: [{label, detail?, value}]` (20 at most; `value` a ticket) | completions while the user types (`complete: true`) |
| `open` | `app`, `props?`, `title`, `placement?` | open one of your screens |
| `token` | `ticket`, `title` | the scope token, standing for a subject |
| `prompt` | `text` | commands only: starter text for the message field |
| `error` | `message` | nothing matched |

Add the entry to `commands` or `scopes` in `manifest.rs`, and handle its `kind` and `name` in the resolve tool.
A scope with `attach: true` must answer `token` for every `value` it offered as a choice.

## 5. Add a screen

Hello's screens are **native**: Rust, compiled into the Bot. An app entry in the manifest names its screen:

```rust
{ "id": "home", "title": TITLE, "description": "…",
  "native": { "screen": "hello.home", "abi": NATIVE_ABI },
  "props": { "type": "object", "properties": { "ticket": { "type": "string", "maxLength": 30 } } },
  "placement": ["full", "inline"],
  "inline": { "width": 360, "height": 160 },
  "permissions": { "tools": ["hello_greet"] } }
```

`permissions` grants exactly what the screen uses: the tools it calls, and `open`, `attach`, `pick_file`,
`storage`, `copy` or `preview` if it needs them. The screen's code goes in `crates/hello-screens`, on the SDK's
`buwiz-app` crate, and the Bot compiles it in.

Native screens are for first-party publishers. Outside `app.buwiz`, ship TSX screens: see
[buwiz-app/mini-tsx](https://github.com/buwiz-app/mini-tsx).

## 6. Add a routine

A routine is a timed agent run: every `every_s` seconds the Bot calls your read-only `query` tool, and when its
`field` has text, the model runs `prompt` with your read-only tools. A tool that changes data runs in that turn
only if the routine lists it in `writes`, and the user approves those writes at install. Add it to `routines` in
`manifest.rs`; the harness's `routine()` calls a tool as that routine's turn.

## 7. Test

```sh
cargo test                     # your tests
tools/check-all.sh             # every gate: fmt, clippy, tests, conformance
```

`buwiz_plugin::testing::Harness` is a provisioned server: call your tools the way the Bot does.

```rust
let mut h = Harness::new(Hello::default());
h.agent("hello_greet", json!({}));                       // as the model
h.resolve("hello_resolve", json!({ "kind": "scope", "value": "ada" }));
h.app("home", "hello_greet", json!({ "ticket": t }));    // as the home screen, from a certified open
h.routine("tidy", "hello_tidy", json!({}));              // in a routine's turn
```

Each returns `Ok(structuredContent)` or `Err({code, message})`.

**Conformance** runs the Bot's own checker against your release build: the manifest's grammar and limits, the
signature, the reserved tools, sessions, signed calls, resolves. It needs a checkout of the Bot:

```sh
git clone https://github.com/buwiz-bot/buwiz-bot && (cd buwiz-bot/server && npm ci)
BUWIZ_BOT_DIR=$PWD/buwiz-bot tools/bot/conformance.sh
```

It signs with a throwaway key under a test key id, never the release key. Every row must pass.

## 8. What the SDK checks, and what is yours

Before your tool runs, the SDK has made sure that:

- nothing runs before the Bot provisions the plugin's key;
- a screen's call comes from an open the plugin certified, and names a tool in that screen's `permissions.tools`;
- a resolve and a routine's query only read;
- a routine's turn only reads, or calls a write the routine declares.

Yours:

- **Tickets, not identifiers.** Outside your process a subject is a ticket (`tkt_…`): in tool results, props,
  tokens and titles. `buwiz.ticket.resolve` answers a title, never the subject.
- **Check what you are handed.** Every ticket, every id: refuse what you did not issue (P1).
- **Side effects behind explicit arguments** (P5), so a probe with `{}` changes nothing.
- **Text without secrets.** A message, title or log carries no subject data and never the key (P4, P9).

The full rules: the Bot's [security checklist](https://github.com/buwiz-bot/buwiz-bot/blob/main/server/sdk/mini-app/docs/security.md),
[manifest reference](https://github.com/buwiz-bot/buwiz-bot/blob/main/server/sdk/mini-app/docs/manifest.md) and
[bridge](https://github.com/buwiz-bot/buwiz-bot/blob/main/server/sdk/mini-app/docs/bridge.md).

## 9. Accounts

A package may declare accounts in `package/plugin.json` (`buwiz.accounts`, protocol 1.0 section 20), such as
`{ "id": "google", "provider": "google", "label": "Google account", "scopes": […] }`. The Bot signs the person in
and pushes the token; the SDK keeps it in memory. A tool reads it from its caller, and without one asks for a
sign-in:

```rust
use buwiz_plugin::account_required;

let Some(google) = caller.account("google") else {
    return account_required("google"); // the Bot asks the person to sign in
};
let header = google.authorization(); // "Bearer …": never log it or put it in an answer
```

In tests, the harness signs in and out as the Bot does. Use a synthetic token, never a real one:

```rust
let mut h = Harness::new(Hello::default());
h.sign_in("google", "synthetic-token"); // the `default` sign-in: provider google, no expiry
h.agent("hello_events", json!({}));      // a tool of yours: caller.account("google") is that sign-in
h.sign_out("google");
h.agent("hello_events", json!({}));      // now it answers account_required("google")
```

`h.sign_in_with(json!({ "account": "google", "label": "work", "access_token": "synthetic-token", "scopes": […] }))`
pushes another label, scopes or an expiry (`expires_at`); `h.sign_out_label("google", "work")` clears that one.

## 10. Release

Only Buwiz signs a release, and the Bot installs only mini apps Buwiz has signed. You build and check your mini app,
then submit it to Buwiz, which reviews it and signs it. The way to submit isn't open yet.

A release is a package (protocol 1.0 section 7): `plugin.json` with a signed `buwiz` block, the signed manifest
and one binary per platform, as flat GitHub release assets.

1. Raise `version` in `crates/hello-mini-app/Cargo.toml`: any change to the manifest or a screen needs a new
   version and a new signature. That is the one place: the manifest takes the crate's version, and `package`
   takes `plugin.json`'s version, ids and publisher from the signed manifest.
2. `tools/check-all.sh`.
3. Submit the mini app to Buwiz for review. The way to submit isn't open yet.
4. After review, Buwiz (the release key `gc-2026-01` for `app.buwiz` is in the Keychain) runs
   `tools/release/publish.sh` with `BUWIZ_BROKER_BIN` set to a `buwiz-broker` build. It builds the binary, signs
   the manifest as `<plugin id>.manifest.json`, has the binary's `package` command fill `package/plugin.json`
   (the version, ids and publisher from the signed manifest; the manifest at `bin/<plugin id>.manifest.json`
   and the binary at `bin/hello-mini-app`, each with its SHA-256),
   and signs its `buwiz` block with `buwiz-broker sign-manifest --block buwiz`, all into `dist/release/`.
   `--publish` creates the GitHub release `v<version>` (on a second platform it adds that binary to the
   release's `plugin.json`); `--publish --prerelease` makes it a pre-release, which the Bot's install from the
   repo URL skips, for a coordinated switch.
5. Buwiz approves the plugin id under the release key in the Bot's trust store.

For a local check without the Keychain, sign under a test key id with a throwaway key and check the result as
the Bot does: `KEY_ID=hello-test-01 tools/release/publish.sh --key-file <test key> --trust <trust store>`.
A package signed this way is only a check: the Bot installs what Buwiz has signed.
