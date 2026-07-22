import os
import shutil
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
TEMP_PROJECT = Path(__file__).resolve().parent / ".tmp_runtime_probe_clean_install"
ADDON_RELATIVE_PATH = Path("addons/godot_mcp")
PROBE_RELATIVE_PATH = Path("addons/godot_mcp/runtime/mcp_runtime_probe.gd")
TOOL_DESCRIPTIONS_RELATIVE_PATH = Path("addons/godot_mcp/translations/tool_descriptions.csv")
TOOL_DESCRIPTIONS_IMPORT_RELATIVE_PATH = Path(
    "addons/godot_mcp/translations/tool_descriptions.csv.import"
)


def resolve_godot_executable() -> Path:
    candidates = [
        Path(os.environ["GODOT_EXE"]) if os.environ.get("GODOT_EXE") else None,
        Path(r"F:\Godot\Godot_v4.6.1-stable_win64.exe"),
        Path(
            r"C:\SourceCode\Godot_v4.6.2-stable_mono_win64"
            r"\Godot_v4.6.2-stable_mono_win64_console.exe"
        ),
    ]
    for candidate in candidates:
        if candidate and candidate.is_file():
            return candidate
    raise FileNotFoundError("Godot 4.6 executable was not found")


def prepare_clean_project() -> None:
    if TEMP_PROJECT.exists():
        shutil.rmtree(TEMP_PROJECT)
    probe_target = TEMP_PROJECT / PROBE_RELATIVE_PATH
    probe_target.parent.mkdir(parents=True)
    shutil.copy2(REPO_ROOT / PROBE_RELATIVE_PATH, probe_target)
    translation_target = TEMP_PROJECT / TOOL_DESCRIPTIONS_RELATIVE_PATH
    translation_target.parent.mkdir(parents=True)
    shutil.copy2(REPO_ROOT / TOOL_DESCRIPTIONS_RELATIVE_PATH, translation_target)
    shutil.copy2(
        REPO_ROOT / TOOL_DESCRIPTIONS_IMPORT_RELATIVE_PATH,
        TEMP_PROJECT / TOOL_DESCRIPTIONS_IMPORT_RELATIVE_PATH,
    )
    (TEMP_PROJECT / "project.godot").write_text(
        '[application]\nconfig/name="Runtime Probe Clean Install Test"\n\n'
        '[rendering]\nrenderer/rendering_method="gl_compatibility"\n',
        encoding="utf-8",
    )


def run_clean_project_parse_check(godot_executable: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            str(godot_executable),
            "--headless",
            "--path",
            str(TEMP_PROJECT),
            "--check-only",
            "--script",
            "res://" + PROBE_RELATIVE_PATH.as_posix(),
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=30,
        check=False,
    )


def run_clean_project_import(godot_executable: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            str(godot_executable),
            "--headless",
            "--editor",
            "--path",
            str(TEMP_PROJECT),
            "--import",
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=60,
        check=False,
    )


def run_enabled_plugin_editor(godot_executable: Path) -> subprocess.CompletedProcess[str]:
    shutil.copytree(
        REPO_ROOT / ADDON_RELATIVE_PATH,
        TEMP_PROJECT / ADDON_RELATIVE_PATH,
        dirs_exist_ok=True,
    )
    project_file = TEMP_PROJECT / "project.godot"
    project_file.write_text(
        project_file.read_text(encoding="utf-8")
        + '\n[editor_plugins]\nenabled=PackedStringArray("res://addons/godot_mcp/plugin.cfg")\n',
        encoding="utf-8",
    )
    return subprocess.run(
        [
            str(godot_executable),
            "--headless",
            "--editor",
            "--path",
            str(TEMP_PROJECT),
            "--quit-after",
            "300",
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=60,
        check=False,
    )


def main() -> int:
    godot_executable = resolve_godot_executable()
    prepare_clean_project()
    try:
        result = run_clean_project_parse_check(godot_executable)
        output = result.stdout + result.stderr
        if "Could not find type \"MCPRuntimeProbe\"" in output:
            raise AssertionError("Runtime probe still depends on an Autoload type name\n" + output)
        if result.returncode != 0 or "Parse Error" in output:
            raise AssertionError("Runtime probe failed to parse in a clean project\n" + output)
        import_sidecar = REPO_ROOT / TOOL_DESCRIPTIONS_IMPORT_RELATIVE_PATH
        import_config = import_sidecar.read_text(encoding="utf-8")
        if 'importer="keep"' not in import_config:
            raise AssertionError("Tool description CSV must use the keep importer")
        import_result = run_clean_project_import(godot_executable)
        import_output = import_result.stdout + import_result.stderr
        if "Locale 'source' does not contain any translation" in import_output:
            raise AssertionError("Tool description CSV was imported as a translation\n" + import_output)
        if import_result.returncode != 0:
            raise AssertionError("Clean-project editor import failed\n" + import_output)
        plugin_result = run_enabled_plugin_editor(godot_executable)
        plugin_output = plugin_result.stdout + plugin_result.stderr
        if plugin_result.returncode != 0 or "Parse Error" in plugin_output:
            raise AssertionError("Plugin failed during first enabled editor session\n" + plugin_output)
        project_config = (TEMP_PROJECT / "project.godot").read_text(encoding="utf-8")
        probe_uid = (REPO_ROOT / (str(PROBE_RELATIVE_PATH) + ".uid")).read_text(
            encoding="utf-8"
        ).strip()
        expected_autoload_values = {
            'MCPRuntimeProbe="*res://addons/godot_mcp/runtime/mcp_runtime_probe.gd"',
            f'MCPRuntimeProbe="*{probe_uid}"',
        }
        if not any(value in project_config for value in expected_autoload_values):
            raise AssertionError(
                "Plugin did not register the runtime probe Autoload\n"
                + plugin_output
                + "\nFinal project.godot:\n"
                + project_config
            )
        print("runtime probe clean-install parse, CSV import, and first enable verified")
        return 0
    finally:
        if TEMP_PROJECT.exists():
            shutil.rmtree(TEMP_PROJECT)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"runtime probe clean-install test failed: {exc}", file=sys.stderr)
        raise
