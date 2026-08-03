use assert_cmd::Command;
use predicates::prelude::*;
use std::fs;

#[test]
fn explicit_url_wins_over_environment() {
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .env("GODOT_MCP_URL", "not-a-url")
        .args([
            "--json",
            "--url",
            "http://127.0.0.1:1",
            "--timeout",
            "1",
            "doctor",
        ])
        .assert()
        .code(4)
        .stdout(predicate::str::contains("SERVICE_UNREACHABLE"));
}

#[test]
fn project_mcp_settings_supply_the_http_port() {
    let project_dir = tempfile::tempdir().unwrap();
    fs::write(
        project_dir.path().join("project.godot"),
        "config/name=\"CLI Smoke Project\"\n",
    )
    .unwrap();
    let user_data_dir = tempfile::tempdir().unwrap();
    let settings_dir = user_data_dir
        .path()
        .join("app_userdata")
        .join("CLI Smoke Project");
    fs::create_dir_all(&settings_dir).unwrap();
    fs::write(
        settings_dir.join("mcp_settings.cfg"),
        "[settings]\ntransport_mode=\"http\"\nhttp_port=19103\n",
    )
    .unwrap();

    Command::cargo_bin("gdmcp")
        .unwrap()
        .env_remove("GODOT_MCP_URL")
        .env("GODOT_MCP_PROJECT_PATH", project_dir.path())
        .env("GODOT_USER_DATA_DIR", user_data_dir.path())
        .args(["--json", "--timeout", "1", "doctor"])
        .assert()
        .code(4)
        .stdout(predicate::str::contains("127.0.0.1:19103"));
}
