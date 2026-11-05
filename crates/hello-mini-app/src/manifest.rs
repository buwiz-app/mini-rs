//! Hello's manifest, built in code. The version is the crate's, so a
//! release bumps one number.
//!
//! The field rules and limits are the Bot's
//! (`server/sdk/mini-app/docs/manifest.md`); `tools/bot/conformance.sh`
//! checks them all.

use buwiz_plugin::manifest::{NATIVE_ABI, PROTOCOL};
use serde_json::{Value, json};

use crate::tools;

/// The plugin id. Buwiz's own mini apps are `app.buwiz.<name>`.
pub const ID: &str = "app.buwiz.hello";
/// Every tool starts with `hello_`.
pub const SHORT: &str = "hello";
/// The name the user sees.
pub const TITLE: &str = "Hello";
/// The publisher key a release is signed with. Only Buwiz signs.
pub const RELEASE_KEY_ID: &str = "gc-2026-01";

/// The manifest without its signature, under publisher key id `key_id`.
pub fn unsigned(key_id: &str) -> Value {
    json!({
        "protocol": PROTOCOL,
        "id": ID,
        "short": SHORT,
        "version": env!("CARGO_PKG_VERSION"),
        "title": TITLE,
        "description": "The mini-rs template: one tool, one command, one scope and one native screen.",
        "publisher": { "id": "app.buwiz", "key_id": key_id, "name": "Buwiz" },
        "commands": [
            { "name": SHORT, "args": "[name]", "description": format!("Open {TITLE}, optionally for a friend"), "resolve": tools::RESOLVE }
        ],
        "scopes": [
            { "name": "friend", "description": "Friend by name", "resolve": tools::RESOLVE, "attach": true }
        ],
        "apps": [
            {
                "id": "home",
                "title": TITLE,
                "description": "Greets a friend.",
                // a native screen, built into the Bot from crates/hello-screens
                "native": { "screen": "hello.home", "abi": NATIVE_ABI },
                "props": { "type": "object", "properties": { "ticket": { "type": "string", "maxLength": 30 } } },
                "placement": ["full", "inline"],
                "inline": { "width": 360, "height": 160, "resizable": false },
                // exactly the tools the screen calls
                "permissions": { "tools": [tools::GREET] }
            }
        ]
    })
}
