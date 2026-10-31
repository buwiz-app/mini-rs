//! `hello-mini-app mcp | manifest [--key-id <id>] | app-source <id>`: the
//! SDK's command line (`--help` says more).

use std::process::ExitCode;

fn main() -> ExitCode {
    buwiz_plugin::cli::main(|| Ok(hello_mini_app::Hello::default()))
}
