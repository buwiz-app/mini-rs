//! Hello, the mini-rs template's mini app (`app.buwiz.hello`).
//!
//! The SDK (`buwiz-plugin`) serves MCP, answers the reserved `buwiz.*`
//! tools and checks every caller; this crate holds only what is Hello's:
//!
//! - [`manifest`]: the manifest, built in code;
//! - [`tools`]: the `hello_*` tools.

pub mod manifest;
pub mod tools;

use buwiz_plugin::{Args, Caller, Plugin, Tickets, Tool};
use serde_json::Value;

/// The mini app's state: its subjects' tickets. A real mini app opens its
/// own store here too.
#[derive(Default)]
pub struct Hello {
    tickets: Tickets<String>,
}

impl Plugin for Hello {
    const ID: &'static str = manifest::ID;
    const NAME: &'static str = env!("CARGO_PKG_NAME");
    const VERSION: &'static str = env!("CARGO_PKG_VERSION");
    const RELEASE_KEY_ID: &'static str = manifest::RELEASE_KEY_ID;
    const INSTRUCTIONS: &'static str = "Hello greets the user's friends. Use hello_greet with a \
        friend's ticket from an @hello:friend token, or without one to greet everyone.";

    fn manifest(key_id: &str) -> Value {
        manifest::unsigned(key_id)
    }

    fn tools(&self) -> Vec<Tool> {
        tools::list()
    }

    fn call(&mut self, tool: &str, args: &Args, caller: &Caller) -> Value {
        tools::call(&mut self.tickets, tool, args, caller)
    }

    fn ticket_title(&mut self, ticket: &str) -> Option<String> {
        // a friend's name is the title the user sees; a real subject's
        // title must not reveal what the ticket hides
        self.tickets.subject(ticket).cloned()
    }

    fn uninstall(&mut self) {
        self.tickets.clear();
    }
}
