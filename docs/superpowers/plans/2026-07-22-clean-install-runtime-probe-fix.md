# Clean-Install Runtime Probe Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:test-driven-development` while executing each code task. Git write operations are intentionally omitted because this repository forbids them without explicit user authorization.

**Goal:** Make the addon parse and import cleanly before it is enabled, and make runtime-probe Autoload cleanup safe.

**Architecture:** Remove the runtime script's compile-time dependency on an Autoload identifier by protecting the active probe through instance identity. Keep Autoload registration during plugin startup, but remove it only on explicit plugin disable and only when the existing entry points to this addon's probe script. Preserve custom CSV files as raw files so Godot's translation importer does not interpret the `source` column as a locale.

**Tech Stack:** Godot 4.6.1, typed GDScript, GUT, Python integration tests.

## Global Constraints

- Do not perform git add, commit, push, pull, stash, reset, or branch operations.
- All new code and comments must use English only.
- Every production-code change must include direct and impact-range tests.
- Clean `.codeartsdoer/temp/`, root `.tmp_*`, and `test/integration/.tmp_*` artifacts after verification.

---

### Task 1: Clean-project parser regression

**Files:**
- Create: `test/integration/test_runtime_probe_clean_install.py`
- Modify: `addons/godot_mcp/runtime/mcp_runtime_probe.gd:324`
- Modify: `test/unit/test_mcp_runtime_probe.gd`

- [x] Add an integration test that copies the probe script into a temporary project with no Autoload settings and runs Godot `--check-only`.
- [x] Run the integration test and verify it fails with `Could not find type "MCPRuntimeProbe"`.
- [x] Replace the Autoload-dependent type check with active-instance identity.
- [x] Add direct GUT coverage for protected probe identity and an ordinary node.
- [x] Run the focused integration and GUT tests and verify they pass.

### Task 2: Safe Autoload lifecycle

**Files:**
- Modify: `addons/godot_mcp/mcp_server_native.gd:197-237,518-533`
- Modify: `test/unit/test_mcp_server_native.gd:112-137`

- [x] Add failing tests requiring cleanup from `_disable_plugin()`, no cleanup from `_exit_tree()`, and exact-path matching with optional singleton prefix.
- [x] Run the focused GUT test and verify the new assertions fail for the expected missing lifecycle behavior.
- [x] Add named Autoload constants and a pure path-matching helper, including Godot-normalized UID paths.
- [x] Register with `add_autoload_singleton()` when absent, report collisions without overwriting, and remove only an exact matching entry.
- [x] Move cleanup from `_exit_tree()` to `_disable_plugin()`.
- [x] Run focused tests and verify they pass.

### Task 3: CSV raw-import packaging

**Files:**
- Include: `addons/godot_mcp/translations/tool_descriptions.csv.import`
- Test: `test/integration/test_runtime_probe_clean_install.py`

- [x] Verify the sidecar contains `importer="keep"` and is part of the working-tree deliverables.
- [x] Extend the clean-install test to run a focused editor import and reject the `Locale 'source'` warning.
- [x] Verify the focused import test passes.

### Task 4: Full verification and cleanup

**Files:**
- Verify all files changed by Tasks 1-3.

- [x] Run the exact clean-install reproduction and confirm exit code 0.
- [x] Run the complete GUT suite and record the existing baseline result: 609 passing, 28 failing, 18 risky/pending.
- [x] Run the isolated first-install, CSV-import, and first-enable integration flow in a temporary project.
- [x] Scan added code lines for Chinese characters.
- [x] Clean mandated temporary directories and inspect the final read-only diff/status.
