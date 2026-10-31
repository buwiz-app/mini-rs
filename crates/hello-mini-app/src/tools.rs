//! Hello's tools: `hello_greet`, and `hello_resolve` for the `/hello`
//! command and the `@hello:friend` scope.
//!
//! The SDK has already checked the caller against the manifest (an app's
//! grant, read-only resolves and routines). What is left is Hello's own
//! rule: a ticket Hello did not issue is refused, not guessed at (P1).

use buwiz_plugin::{Args, Caller, Tickets, Tool, fail, ok};
use serde_json::{Value, json};

use crate::manifest;

pub const GREET: &str = "hello_greet";
pub const RESOLVE: &str = "hello_resolve";

/// The subjects Hello knows. A real mini app looks them up in its store;
/// tickets stand for them everywhere outside this process.
const FRIENDS: [&str; 3] = ["Ada", "Grace", "Linus"];

/// Every tool, in `tools/list` order.
pub fn list() -> Vec<Tool> {
    vec![
        Tool {
            name: GREET,
            description: "Greet a friend by ticket, or everyone.",
            input_schema: json!({
                "type": "object",
                "properties": { "ticket": { "type": "string", "description": "A friend's ticket (tkt_…)" } }
            }),
            read_only: true,
        },
        Tool {
            name: RESOLVE,
            description: "Resolve /hello and @hello:friend tokens.",
            input_schema: json!({ "type": "object" }),
            read_only: true,
        },
    ]
}

/// Run one of [`list`].
pub fn call(tickets: &mut Tickets<String>, tool: &str, args: &Args, _caller: &Caller) -> Value {
    match tool {
        GREET => greet(tickets, args),
        RESOLVE => resolve(tickets, args),
        _ => fail("not_found", "No such tool."),
    }
}

fn greet(tickets: &Tickets<String>, args: &Args) -> Value {
    let Some(ticket) = args.get("ticket") else {
        return ok(json!({ "greeting": "Hi, world" }));
    };
    match ticket.as_str().and_then(|t| tickets.subject(t)) {
        Some(name) => ok(json!({ "greeting": format!("Hi, {name}") })),
        None => fail("not_found", "That friend is no longer available."),
    }
}

/// `{kind, name, value, complete}` in; one of `choices`, `open`, `token`,
/// `prompt` or `error` out.
fn resolve(tickets: &mut Tickets<String>, args: &Args) -> Value {
    let value = args
        .get("value")
        .and_then(Value::as_str)
        .unwrap_or("")
        .trim();
    let lower = value.to_lowercase();
    let matches: Vec<&str> = FRIENDS
        .into_iter()
        .filter(|f| f.to_lowercase().starts_with(&lower))
        .collect();

    if args.get("kind").and_then(Value::as_str) == Some("command") {
        let props = match matches.as_slice() {
            [one] if !value.is_empty() => json!({ "ticket": tickets.issue(&one.to_string()) }),
            _ => json!({}),
        };
        return ok(
            json!({ "result": "open", "app": "home", "props": props, "title": manifest::TITLE, "placement": "full" }),
        );
    }

    if args.get("complete") == Some(&Value::Bool(true)) {
        let choices: Vec<Value> = matches
            .iter()
            .take(20)
            .map(|f| json!({ "label": f, "detail": "A friend", "value": tickets.issue(&f.to_string()) }))
            .collect();
        return ok(json!({ "result": "choices", "choices": choices }));
    }

    // a value is a ticket already (a chosen completion) or typed text
    let subject = tickets.subject(value).cloned().or_else(|| {
        FRIENDS
            .iter()
            .find(|f| f.eq_ignore_ascii_case(value))
            .map(|f| f.to_string())
    });
    match subject {
        Some(name) => {
            ok(json!({ "result": "token", "ticket": tickets.issue(&name), "title": name }))
        }
        None => {
            let shown: String = value.chars().take(60).collect();
            ok(json!({ "result": "error", "message": format!("No friend called {shown}.") }))
        }
    }
}
