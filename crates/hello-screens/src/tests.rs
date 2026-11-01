use std::{
    sync::{Arc, Mutex, mpsc},
    time::{Duration, Instant},
};

use buwiz_app::{BuwizError, Done, Host, Listener};
use nsh_core::{ApproxTextEngine, MountBatch, MountItem};
use nsh_engine::{App, Engine, EngineConfig, MountSink};
use serde_json::{Map, Value};

use super::*;

struct FakeHost {
    props: Value,
    answer: Result<Value, BuwizError>,
    sent: Mutex<Vec<(String, Value)>>,
    failed: Mutex<Vec<String>>,
}

impl Host for FakeHost {
    fn params(&self) -> Map<String, Value> {
        json!({
            "props": self.props,
            "app": {"plugin": "app.buwiz.hello", "app": "home"},
            "granted": ["buwiz.call"],
            "viewport": {"width": 360, "height": 160, "placement": "inline"}
        })
        .as_object()
        .unwrap()
        .clone()
    }
    fn post(&self, method: &str, data: Value) {
        self.sent.lock().unwrap().push((method.to_owned(), data));
    }
    fn call(&self, method: &str, data: Value, done: Done) {
        self.sent.lock().unwrap().push((method.to_owned(), data));
        done(self.answer.clone());
    }
    fn listen(&self, _: Listener) {}
    fn fail(&self, message: &str) {
        self.failed.lock().unwrap().push(message.to_owned());
    }
}

struct Sink(mpsc::Sender<MountBatch>);

impl MountSink for Sink {
    fn submit(&self, batch: MountBatch) {
        let _ = self.0.send(batch);
    }
}

fn drive(props: Value, answer: Result<Value, BuwizError>, expected: &str, args: Value) {
    let host = Arc::new(FakeHost {
        props,
        answer,
        sent: Mutex::new(Vec::new()),
        failed: Mutex::new(Vec::new()),
    });
    let defs = screens();
    assert_eq!(defs.len(), 1);
    assert_eq!((defs[0].id, defs[0].abi), ("hello.home", 1));
    let (tx, rx) = mpsc::channel();
    let engine = Engine::start(
        EngineConfig::new(App::Rust((defs[0].build)(Bridge::new(host.clone())))),
        || ApproxTextEngine,
        Sink(tx),
    )
    .expect("engine starts");
    let deadline = Instant::now() + Duration::from_secs(10);
    let mut shown = Vec::new();
    while Instant::now() < deadline {
        if let Ok(batch) = rx.recv_timeout(Duration::from_millis(20)) {
            for item in batch.items {
                if let MountItem::Text { text, .. } = item {
                    shown.push(text.text.to_string());
                }
            }
        }
        if shown.iter().any(|s| s == expected)
            && host
                .sent
                .lock()
                .unwrap()
                .iter()
                .any(|(m, _)| m == "buwiz.ready")
        {
            break;
        }
    }
    drop(engine);
    assert!(shown.iter().any(|s| s == expected), "{shown:?}");
    assert_eq!(
        *host.sent.lock().unwrap(),
        [
            (
                "buwiz.call".into(),
                json!({"tool": "hello_greet", "args": args})
            ),
            ("buwiz.ready".into(), json!({})),
        ]
    );
    assert!(host.failed.lock().unwrap().is_empty());
}

#[test]
fn home_greets_everyone_with_empty_props() {
    drive(
        json!({}),
        Ok(json!({"greeting": "Hi, world"})),
        "Hi, world",
        json!({}),
    );
}

#[test]
fn home_forwards_only_the_ticket_prop() {
    drive(
        json!({"ticket": "tkt_synthetic", "ignored": "synthetic"}),
        Ok(json!({"greeting": "Hi, friend"})),
        "Hi, friend",
        json!({"ticket": "tkt_synthetic"}),
    );
}

#[test]
fn home_handles_missing_and_empty_greetings() {
    for answer in [
        Value::Null,
        json!({}),
        json!({"greeting": ""}),
        json!({"greeting": 42}),
    ] {
        drive(json!({}), Ok(answer), "Greeting unavailable.", json!({}));
    }
}

#[test]
fn home_handles_host_errors_without_showing_their_contents() {
    drive(
        json!({}),
        Err(BuwizError::new(
            "not_found",
            false,
            "synthetic private detail",
        )),
        "Greeting unavailable.",
        json!({}),
    );
}
