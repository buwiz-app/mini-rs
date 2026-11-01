# hello-screens

Hello's native screens: Rust, built into the Buwiz Bot, in place of TSX. The manifest's `home` app names one:
`"native": { "screen": "hello.home", "abi": 1 }`.

This crate uses [buwiz-sdk `crates/app`](https://github.com/buwiz-app/buwiz-sdk/tree/2120c725112e2072b22f6630079fc938b6c9b1e9/crates/app).
It exports the screen for the Bot to register under `app.buwiz.hello`:

```rust
use hello_screens::screens;

assert_eq!(screens()[0].id, "hello.home");
assert_eq!(screens()[0].abi, 1);
```

Native screens are for first-party publishers (`app.buwiz`, key `gc-2026-01`). The Bot compiles each first-party
screens crate in, pinned by git rev, so a change to a screen ships with a Bot build. A plugin from another
publisher serves TSX screens instead: see [buwiz-app/mini-tsx](https://github.com/buwiz-app/mini-tsx).
