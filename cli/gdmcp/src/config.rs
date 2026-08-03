use std::{
    env, fs,
    path::{Path, PathBuf},
    time::Duration,
};

use directories::ProjectDirs;
use serde::Deserialize;

use crate::{cli::Cli, error::CliError};

#[derive(Debug, Clone)]
pub struct Config {
    pub base_url: String,
    pub token: Option<String>,
    pub timeout: Duration,
}

#[derive(Debug, Default, Deserialize)]
struct FileConfig {
    url: Option<String>,
    timeout_seconds: Option<u64>,
    token_env: Option<String>,
}

#[derive(Debug, Clone, Copy)]
struct GodotMcpSettings {
    transport_mode: Option<TransportMode>,
    http_port: Option<u16>,
}

impl Default for GodotMcpSettings {
    fn default() -> Self {
        Self {
            transport_mode: Some(TransportMode::Http),
            http_port: Some(9080),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum TransportMode {
    Http,
    Stdio,
}

impl Config {
    pub fn load(cli: &Cli) -> Result<Self, CliError> {
        let file = load_file_config()?;
        let godot_settings = load_godot_mcp_settings(cli)?;
        let base_url = cli
            .url
            .clone()
            .or_else(|| env::var("GODOT_MCP_URL").ok())
            .or(file.url)
            .or_else(|| godot_settings_base_url(godot_settings))
            .unwrap_or_else(|| "http://127.0.0.1:9080".to_string())
            .trim_end_matches('/')
            .to_string();
        if !base_url.starts_with("http://") && !base_url.starts_with("https://") {
            return Err(CliError::Configuration(
                "URL must start with http:// or https://".to_string(),
            ));
        }
        let token_env = cli
            .token_env
            .clone()
            .or(file.token_env)
            .unwrap_or_else(|| "GODOT_MCP_TOKEN".to_string());
        let token = env::var(token_env).ok().filter(|value| !value.is_empty());
        let timeout_seconds = cli
            .timeout
            .or_else(|| {
                env::var("GODOT_MCP_TIMEOUT")
                    .ok()
                    .and_then(|value| value.parse().ok())
            })
            .or(file.timeout_seconds)
            .unwrap_or(30);
        Ok(Self {
            base_url,
            token,
            timeout: Duration::from_secs(timeout_seconds.clamp(1, 300)),
        })
    }
}

fn godot_settings_base_url(settings: Option<GodotMcpSettings>) -> Option<String> {
    let settings = settings?;
    if settings.transport_mode != Some(TransportMode::Http) {
        return None;
    }
    settings
        .http_port
        .map(|port| format!("http://127.0.0.1:{port}"))
}

fn load_file_config() -> Result<FileConfig, CliError> {
    let Some(project_dirs) = ProjectDirs::from("dev", "GodotMCP", "gdmcp") else {
        return Ok(FileConfig::default());
    };
    let path: PathBuf = project_dirs.config_dir().join("config.toml");
    if !path.exists() {
        return Ok(FileConfig::default());
    }
    let content = fs::read_to_string(path)?;
    toml::from_str(&content).map_err(|error| CliError::Configuration(error.to_string()))
}

fn load_godot_mcp_settings(cli: &Cli) -> Result<Option<GodotMcpSettings>, CliError> {
    let project_path = cli
        .project_path
        .clone()
        .or_else(|| env::var_os("GODOT_MCP_PROJECT_PATH").map(PathBuf::from))
        .or_else(|| {
            let current = env::current_dir().ok()?;
            current.join("project.godot").is_file().then_some(current)
        });
    let Some(project_path) = project_path else {
        return Ok(None);
    };
    let project_name = read_project_name(&project_path)?;
    let Some(project_name) = project_name else {
        return Ok(None);
    };
    let user_data_dir = cli
        .godot_user_data_dir
        .clone()
        .or_else(|| env::var_os("GODOT_USER_DATA_DIR").map(PathBuf::from))
        .unwrap_or_else(default_godot_user_data_dir);
    let settings_path = user_data_dir
        .join("app_userdata")
        .join(project_name)
        .join("mcp_settings.cfg");
    if !settings_path.is_file() {
        return Ok(None);
    }
    parse_godot_mcp_settings(&settings_path).map(Some)
}

fn read_project_name(project_path: &Path) -> Result<Option<String>, CliError> {
    let project_file = if project_path.is_file() {
        project_path.to_path_buf()
    } else {
        project_path.join("project.godot")
    };
    if !project_file.is_file() {
        return Ok(None);
    }
    let content = fs::read_to_string(project_file)?;
    Ok(content.lines().find_map(|line| {
        let line = line.trim();
        let value = line.strip_prefix("config/name=")?.trim();
        Some(unquote_godot_value(value))
    }))
}

fn unquote_godot_value(value: &str) -> String {
    let value = value.trim();
    if value.len() >= 2 && value.starts_with('"') && value.ends_with('"') {
        value[1..value.len() - 1].replace("\\\"", "\"")
    } else {
        value.to_string()
    }
}

fn parse_godot_mcp_settings(path: &Path) -> Result<GodotMcpSettings, CliError> {
    let content = fs::read_to_string(path)?;
    let mut in_settings = false;
    let mut settings = GodotMcpSettings::default();
    for line in content.lines() {
        let line = line.trim();
        if line.starts_with('[') && line.ends_with(']') {
            in_settings = &line[1..line.len() - 1] == "settings";
            continue;
        }
        if !in_settings {
            continue;
        }
        let Some((key, raw_value)) = line.split_once('=') else {
            continue;
        };
        match key.trim() {
            "transport_mode" => {
                settings.transport_mode = match unquote_godot_value(raw_value).as_str() {
                    "http" => Some(TransportMode::Http),
                    "stdio" => Some(TransportMode::Stdio),
                    _ => None,
                };
            }
            "http_port" => {
                settings.http_port = raw_value
                    .trim()
                    .parse::<u16>()
                    .ok()
                    .filter(|port| (1024..=65535).contains(port));
            }
            _ => {}
        }
    }
    Ok(settings)
}

fn default_godot_user_data_dir() -> PathBuf {
    if cfg!(target_os = "windows") {
        return env::var_os("APPDATA")
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from("."))
            .join("Godot");
    }
    if cfg!(target_os = "macos") {
        return env::var_os("HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from("."))
            .join("Library")
            .join("Application Support")
            .join("Godot");
    }
    env::var_os("XDG_DATA_HOME")
        .map(PathBuf::from)
        .or_else(|| env::var_os("HOME").map(|home| PathBuf::from(home).join(".local/share")))
        .unwrap_or_else(|| PathBuf::from("."))
        .join("godot")
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use tempfile::NamedTempFile;

    #[test]
    fn godot_http_settings_override_the_builtin_port() {
        let settings = GodotMcpSettings {
            transport_mode: Some(TransportMode::Http),
            http_port: Some(19100),
        };
        assert_eq!(
            godot_settings_base_url(Some(settings)).as_deref(),
            Some("http://127.0.0.1:19100")
        );
    }

    #[test]
    fn stdio_settings_do_not_create_an_http_endpoint() {
        let settings = GodotMcpSettings {
            transport_mode: Some(TransportMode::Stdio),
            http_port: Some(19100),
        };
        assert_eq!(godot_settings_base_url(Some(settings)), None);
    }

    #[test]
    fn parses_the_godot_settings_section() {
        let mut file = NamedTempFile::new().unwrap();
        writeln!(file, "[settings]\ntransport_mode=\"http\"\nhttp_port=19101").unwrap();
        let settings = parse_godot_mcp_settings(file.path()).unwrap();
        assert_eq!(settings.transport_mode, Some(TransportMode::Http));
        assert_eq!(settings.http_port, Some(19101));
    }

    #[test]
    fn missing_godot_settings_keys_use_plugin_defaults() {
        let mut file = NamedTempFile::new().unwrap();
        writeln!(file, "[settings]\nhttp_port=19102").unwrap();
        let settings = parse_godot_mcp_settings(file.path()).unwrap();
        assert_eq!(settings.transport_mode, Some(TransportMode::Http));
        assert_eq!(settings.http_port, Some(19102));
    }

    #[test]
    fn reads_the_project_name_from_project_godot() {
        let mut file = NamedTempFile::new().unwrap();
        writeln!(file, "config/name=\"Example Project\"").unwrap();
        assert_eq!(
            read_project_name(file.path()).unwrap(),
            Some("Example Project".to_string())
        );
    }
}
