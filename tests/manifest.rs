//! The manifest against the tools Hello lists. The full check is the Bot's
//! conformance runner (`tools/bot/conformance.sh`); this is the quick one.

use buwiz_plugin::{Plugin, manifest};
use hello_mini_app::Hello;

#[test]
fn every_tool_the_manifest_names_exists_and_has_the_prefix() {
    let problems = manifest::problems(&Hello::manifest("test-key"), &Hello::default().tools());
    assert_eq!(problems, Vec::<String>::new());
}

#[test]
fn the_manifest_version_is_the_crate_version() {
    assert_eq!(
        Hello::manifest("test-key")["version"],
        env!("CARGO_PKG_VERSION")
    );
}

#[test]
fn a_release_manifest_names_the_release_key_and_a_test_one_its_own() {
    let release = Hello::manifest(Hello::RELEASE_KEY_ID);
    assert_eq!(release["publisher"]["key_id"], "gc-2026-01");
    assert_eq!(
        Hello::manifest("hello-test-01")["publisher"]["key_id"],
        "hello-test-01"
    );
}

#[test]
fn every_screen_is_native() {
    let manifest = Hello::manifest(Hello::RELEASE_KEY_ID);
    for app in manifest["apps"].as_array().unwrap() {
        assert_eq!(app["native"]["abi"], manifest::NATIVE_ABI, "{}", app["id"]);
        assert!(app.get("entry").is_none(), "{} is TSX", app["id"]);
    }
}

#[test]
fn the_package_template_matches_the_manifest() {
    // package/plugin.json, which `tools/release/publish.sh` fills and signs
    let plugin: serde_json::Value =
        serde_json::from_str(include_str!("../package/plugin.json")).unwrap();
    let manifest = Hello::manifest(Hello::RELEASE_KEY_ID);
    let block = &plugin["buwiz"];
    assert_eq!(block["protocol"], manifest::PROTOCOL);
    for key in ["id", "short", "version"] {
        assert_eq!(block[key], manifest[key], "buwiz.{key}");
    }
    assert_eq!(plugin["version"], manifest["version"]);
    assert_eq!(
        block["publisher"]["key_id"],
        manifest["publisher"]["key_id"]
    );
    assert!(plugin["mcpServers"][block["server"].as_str().unwrap()].is_object());
}
