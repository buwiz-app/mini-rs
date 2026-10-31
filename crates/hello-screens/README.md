# hello-screens

Hello's native screens: Rust, built into the Buwiz Bot, in place of TSX. The manifest's `home` app names one:
`"native": { "screen": "hello.home", "abi": 1 }`.

This crate waits for the native-screen SDK, `buwiz-mini-app`. The Bot's team is writing it (see
[buwiz-sdk `crates/buwiz-mini-app`](https://github.com/buwiz-app/buwiz-sdk/tree/main/crates/buwiz-mini-app)), and
the Bot's native loader ships with it. Until then a native app verifies at install, and opening it shows "this
screen needs a newer Buwiz Bot". When the SDK lands, this folder becomes a crate in the workspace:

```rust
// crates/hello-screens/src/lib.rs (the shape as sketched; final names land with the SDK)
use buwiz_mini_app::{Bridge, ScreenDef};

pub fn screens() -> &'static [ScreenDef] {
    &[ScreenDef { id: "hello.home", abi: 1, build: home }]
}

fn home(bridge: Bridge) -> Root {
    // read bridge.props()["ticket"], call bridge.call("hello_greet", …), size from bridge.viewport()
}
```

Native screens are for first-party publishers (`app.buwiz`, key `gc-2026-01`). The Bot compiles each first-party
screens crate in, pinned by git rev, so a change to a screen ships with a Bot build. A plugin from another
publisher serves TSX screens instead: see [buwiz-app/mini-tsx](https://github.com/buwiz-app/mini-tsx).
