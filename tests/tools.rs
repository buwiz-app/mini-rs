//! Hello's tools through the SDK's harness: a provisioned server, and calls
//! as the model, a resolve and the home screen, the way the Bot makes them.

use buwiz_plugin::is_ticket;
use buwiz_plugin::testing::Harness;
use hello_mini_app::Hello;
use serde_json::json;

#[test]
fn greets_everyone_without_a_ticket() {
    let mut h = Harness::new(Hello::default());
    assert_eq!(
        h.agent("hello_greet", json!({})),
        Ok(json!({ "greeting": "Hi, world" }))
    );
}

#[test]
fn a_friend_resolves_to_a_ticket_that_greets_them() {
    let mut h = Harness::new(Hello::default());
    let token = h
        .resolve(
            "hello_resolve",
            json!({ "kind": "scope", "name": "friend", "value": "ada" }),
        )
        .unwrap();
    assert_eq!(token["result"], "token");
    assert_eq!(token["title"], "Ada");
    let ticket = token["ticket"].as_str().unwrap();
    assert!(is_ticket(ticket));

    // the home screen calls hello_greet; its open grants it
    let greeting = h.app("home", "hello_greet", json!({ "ticket": ticket }));
    assert_eq!(greeting, Ok(json!({ "greeting": "Hi, Ada" })));
}

#[test]
fn a_ticket_hello_did_not_issue_is_refused() {
    let mut h = Harness::new(Hello::default());
    let refused = h.agent(
        "hello_greet",
        json!({ "ticket": "tkt_0000000000000000000000000A" }),
    );
    assert_eq!(refused.unwrap_err()["code"], "not_found");
}

#[test]
fn completion_offers_choices_as_tickets() {
    let mut h = Harness::new(Hello::default());
    let choices = h
        .resolve(
            "hello_resolve",
            json!({ "kind": "scope", "name": "friend", "value": "", "complete": true }),
        )
        .unwrap();
    let labels: Vec<&str> = choices["choices"]
        .as_array()
        .unwrap()
        .iter()
        .map(|c| c["label"].as_str().unwrap())
        .collect();
    assert_eq!(labels, ["Ada", "Grace", "Linus"]);
    assert!(
        choices["choices"]
            .as_array()
            .unwrap()
            .iter()
            .all(|c| is_ticket(c["value"].as_str().unwrap()))
    );
}

#[test]
fn the_command_opens_home_for_one_friend_or_none() {
    let mut h = Harness::new(Hello::default());
    let open = h
        .resolve(
            "hello_resolve",
            json!({ "kind": "command", "name": "hello", "value": "grace" }),
        )
        .unwrap();
    assert_eq!(open["result"], "open");
    assert_eq!(open["app"], "home");
    assert!(is_ticket(open["props"]["ticket"].as_str().unwrap()));
    let bare = h
        .resolve(
            "hello_resolve",
            json!({ "kind": "command", "name": "hello", "value": "" }),
        )
        .unwrap();
    assert_eq!(bare["props"], json!({}));
}

#[test]
fn uninstall_forgets_every_ticket() {
    let mut h = Harness::new(Hello::default());
    let token = h
        .resolve(
            "hello_resolve",
            json!({ "kind": "scope", "value": "Linus" }),
        )
        .unwrap();
    let ticket = token["ticket"].clone();
    h.call("buwiz.uninstall", json!({}), serde_json::Value::Null)
        .unwrap();
    assert_eq!(
        h.call(
            "buwiz.ticket.resolve",
            json!({ "ticket": ticket }),
            serde_json::Value::Null
        ),
        Ok(json!({ "valid": false }))
    );
}
