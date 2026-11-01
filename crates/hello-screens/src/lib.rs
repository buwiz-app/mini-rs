use buwiz_app::{ABI, Bridge, ScreenDef};
use nsh_core::element::{Root, signal, text};
use serde_json::json;

pub fn screens() -> &'static [ScreenDef] {
    &[ScreenDef {
        id: "hello.home",
        abi: ABI,
        build: home,
    }]
}

fn home(bridge: Bridge) -> Root {
    buwiz_app::root(bridge, |b| {
        let greeting = signal(String::from("Loading…"));
        let props = b.props();
        let args = match props.get("ticket") {
            Some(ticket) => json!({ "ticket": ticket }),
            None => json!({}),
        };
        let bridge = b.clone();
        b.spawn(async move {
            let result = bridge.call("hello_greet", args).await;
            greeting.set(match result {
                Ok(value) => value
                    .get("greeting")
                    .and_then(|v| v.as_str())
                    .filter(|s| !s.is_empty())
                    .unwrap_or("Greeting unavailable.")
                    .to_owned(),
                Err(_) => "Greeting unavailable.".to_owned(),
            });
            bridge.ready();
        });
        text(move || greeting.get())
    })
}

#[cfg(test)]
mod tests;
