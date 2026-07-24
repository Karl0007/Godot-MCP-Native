# gdmcp Agent CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Rust `gdmcp` companion CLI and a localhost CLI API to Godot MCP Native so shell-capable agents can use progressive tool discovery without loading the complete MCP tool catalog.

**Architecture:** Introduce a protocol-neutral tool definition, registry, executor, execution policy, and result contract inside the Godot plugin. Keep the existing MCP protocol as one adapter and add `/cli/v1` as a second adapter over the existing HTTP server. Build a single-binary Rust CLI with stable JSON, bounded output, domain commands, raw tool discovery/call escape hatches, and a compact companion Skill.

**Tech Stack:** Godot 4.6.x, typed GDScript, GUT, Python 3 integration tests, Rust stable, Cargo, clap, reqwest, tokio, serde, serde_json, toml, thiserror, directories, GitHub Actions.

## Global Constraints

- All `.gd`, `.cs`, `.py`, `.rs`, `.toml`, and shell source files must contain English-only code, comments, identifiers, and runtime strings.
- Chinese is allowed only in `AGENTS.md`, `README.zh.md`, and `docs/`.
- Keep every existing MCP tool name and callable implementation intact.
- Do not remove an existing MCP endpoint or tool in this implementation.
- Godot 4.6.x remains the supported editor baseline.
- CLI API version is exactly `1` and CLI JSON schema version is exactly `1`.
- CLI API binds to loopback by default and reuses existing bearer-token authentication.
- Destructive operations require server-side `apply_confirmed=true`.
- Open-world operations require server-side `allow_open_world=true`.
- Supplementary tools are hidden from MCP by default but may be callable through CLI when policy permits.
- Every production change includes direct tests and impact-range tests.
- Use TDD: add a failing test, run it, implement the minimum change, rerun the focused test, then run the affected suite.
- Each task ends in one intentional commit; do not combine future tasks into an earlier commit.

---

## File Structure

### Godot protocol-neutral core

- Create `addons/godot_mcp/native_mcp/tool_policy.gd` — derives and stores independent availability, MCP visibility, CLI permission, and risk gates.
- Create `addons/godot_mcp/native_mcp/tool_definition.gd` — protocol-neutral tool metadata and serialization helpers.
- Create `addons/godot_mcp/native_mcp/tool_execution_context.gd` — caller and permission flags for one invocation.
- Create `addons/godot_mcp/native_mcp/tool_execution_result.gd` — normalized success and failure result.
- Create `addons/godot_mcp/native_mcp/tool_registry.gd` — registration, filtering, compact catalog, deterministic search, and hashes.
- Create `addons/godot_mcp/native_mcp/tool_executor.gd` — policy enforcement, callable invocation, signals, timing, and legacy-result normalization.
- Create `addons/godot_mcp/native_mcp/cli_api_handler.gd` — `/cli/v1` route parsing and JSON response mapping.
- Create `addons/godot_mcp/native_mcp/cli_result_limiter.gd` — list, tree, field, and byte limits for CLI responses.

### Existing Godot files to modify

- Modify `addons/godot_mcp/native_mcp/mcp_types.gd:58-110` — keep MCP wire types while removing ownership of the domain tool model.
- Modify `addons/godot_mcp/native_mcp/mcp_server_core.gd:60-68` — replace the private tool dictionary with registry and executor instances.
- Modify `addons/godot_mcp/native_mcp/mcp_server_core.gd:272-311` — keep MCP request routing unchanged externally.
- Modify `addons/godot_mcp/native_mcp/mcp_server_core.gd:365-494` — map `tools/list` and `tools/call` through registry and executor.
- Modify `addons/godot_mcp/native_mcp/mcp_server_core.gd:585-700` — preserve the existing `register_tool` API while constructing `ToolDefinition` and derived policy.
- Modify `addons/godot_mcp/native_mcp/mcp_http_server.gd` — dispatch `/cli/v1` requests to `CliApiHandler` before MCP request parsing.
- Modify `addons/godot_mcp/mcp_server_native.gd` — initialize and inject CLI API dependencies into the HTTP transport.
- Modify `addons/godot_mcp/native_mcp/tool_state_manager.gd` — persist `available` and `mcp_visible` without disabling CLI permission unintentionally.
- Modify `addons/godot_mcp/native_mcp/mcp_tool_classifier.gd` — expose classification lookup used by policy derivation; do not duplicate the catalog.

### Godot tests

- Create `test/unit/native_mcp/test_tool_policy.gd`.
- Create `test/unit/native_mcp/test_tool_registry.gd`.
- Create `test/unit/native_mcp/test_tool_executor.gd`.
- Create `test/unit/native_mcp/test_cli_result_limiter.gd`.
- Create `test/unit/native_mcp/test_cli_api_handler.gd`.
- Modify `test/unit/test_mcp_server_core.gd` or the repository's existing MCP core test file — verify unchanged MCP envelopes and new visibility semantics.
- Modify `test/unit/test_mcp_tool_classifier.gd` — verify all registered tools have a resolvable default policy.
- Create `test/integration/test_cli_api_flow.py`.
- Modify `test/integration/test_runtime_probe_flow.py` only when shared launch helpers are extracted.
- Create `test/integration/godot_test_server.py` — shared Godot process and HTTP readiness helper.

### Rust CLI

- Create `cli/gdmcp/Cargo.toml`.
- Create `cli/gdmcp/src/main.rs` — process boundary and exit-code handling.
- Create `cli/gdmcp/src/cli.rs` — clap command tree.
- Create `cli/gdmcp/src/config.rs` — URL, token, timeout, and config precedence.
- Create `cli/gdmcp/src/client.rs` — typed `/cli/v1` HTTP client.
- Create `cli/gdmcp/src/contracts.rs` — API and CLI JSON structs.
- Create `cli/gdmcp/src/error.rs` — classified errors and deterministic exit codes.
- Create `cli/gdmcp/src/output.rs` — human and JSON rendering with stdout/stderr separation.
- Create `cli/gdmcp/src/args.rs` — JSON/file input parsing and conflict validation.
- Create `cli/gdmcp/src/commands/doctor.rs`.
- Create `cli/gdmcp/src/commands/tools.rs`.
- Create `cli/gdmcp/src/commands/tool_call.rs`.
- Create `cli/gdmcp/src/commands/editor.rs`.
- Create `cli/gdmcp/src/commands/scenes.rs`.
- Create `cli/gdmcp/src/commands/nodes.rs`.
- Create `cli/gdmcp/src/commands/scripts.rs`.
- Create `cli/gdmcp/src/commands/resources.rs`.
- Create `cli/gdmcp/src/commands/project.rs`.
- Create `cli/gdmcp/src/commands/debug.rs`.
- Create `cli/gdmcp/src/commands/runtime.rs`.
- Create `cli/gdmcp/src/commands/batch.rs`.
- Create `cli/gdmcp/tests/cli_parser.rs`.
- Create `cli/gdmcp/tests/config_precedence.rs`.
- Create `cli/gdmcp/tests/http_commands.rs`.
- Create `cli/gdmcp/tests/json_contracts.rs`.
- Create `cli/gdmcp/tests/command_mappings.rs`.

### Documentation and packaging

- Create `skills/gdmcp/SKILL.md`.
- Create `skills/gdmcp/references/command-workflows.md`.
- Create `docs/current/gdmcp-cli-reference.md`.
- Create `cli/gdmcp/README.md`.
- Create `cli/gdmcp/scripts/install.ps1`.
- Create `cli/gdmcp/scripts/install.sh`.
- Modify `AGENTS.md` — add a compact CLI discovery section.
- Modify `.github/workflows/` by adding `gdmcp-cli.yml` or extending the repository's existing CI workflow.

---

### Task 1: Add Protocol-neutral Tool Models and Policy Derivation

**Files:**
- Create: `addons/godot_mcp/native_mcp/tool_policy.gd`
- Create: `addons/godot_mcp/native_mcp/tool_definition.gd`
- Create: `addons/godot_mcp/native_mcp/tool_execution_context.gd`
- Create: `addons/godot_mcp/native_mcp/tool_execution_result.gd`
- Test: `test/unit/native_mcp/test_tool_policy.gd`

**Interfaces:**
- Consumes: existing annotation dictionaries created by `MCPTypes.MCPTool.create_annotations()`.
- Produces: `ToolPolicy.from_metadata(category, annotations)`, `ToolDefinition.to_mcp_dict()`, `ToolDefinition.to_cli_summary()`, `ToolDefinition.to_cli_schema()`, `ToolExecutionContext`, and `ToolExecutionResult.to_cli_dict()`.

- [ ] **Step 1: Write failing policy tests**

```gdscript
extends "res://addons/gut/test.gd"

var ToolPolicyScript = load("res://addons/godot_mcp/native_mcp/tool_policy.gd")

func test_supplementary_read_tool_is_hidden_from_mcp_but_allowed_for_cli() -> void:
    var policy = ToolPolicyScript.from_metadata("supplementary", {
        "readOnlyHint": true,
        "destructiveHint": false,
        "openWorldHint": false,
    })
    assert_true(policy.available)
    assert_false(policy.mcp_visible)
    assert_true(policy.cli_allowed)
    assert_eq(policy.risk_level, "read")
    assert_false(policy.requires_apply)

func test_destructive_annotation_requires_apply() -> void:
    var policy = ToolPolicyScript.from_metadata("core", {
        "readOnlyHint": false,
        "destructiveHint": true,
        "openWorldHint": false,
    })
    assert_eq(policy.risk_level, "destructive")
    assert_true(policy.requires_apply)

func test_open_world_annotation_requires_permission() -> void:
    var policy = ToolPolicyScript.from_metadata("core", {
        "readOnlyHint": false,
        "destructiveHint": false,
        "openWorldHint": true,
    })
    assert_true(policy.requires_open_world_permission)
```

- [ ] **Step 2: Run the focused test and verify failure**

Run:

```powershell
& "F:\Godot\Godot_v4.6.1-stable_win64.exe" --headless --path "." -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/native_mcp/test_tool_policy.gd -gexit
```

Expected: test load failure because `tool_policy.gd` does not exist.

- [ ] **Step 3: Implement the four model files**

`tool_policy.gd` must provide this exact API:

```gdscript
class_name ToolPolicy
extends RefCounted

var available: bool = true
var mcp_visible: bool = true
var cli_allowed: bool = true
var risk_level: String = "read"
var requires_apply: bool = false
var requires_open_world_permission: bool = false

static func from_metadata(category: String, annotations: Dictionary) -> ToolPolicy:
    var policy := ToolPolicy.new()
    policy.mcp_visible = category == "core"
    policy.cli_allowed = true
    policy.requires_apply = bool(annotations.get("destructiveHint", false))
    policy.requires_open_world_permission = bool(annotations.get("openWorldHint", false))
    if policy.requires_apply:
        policy.risk_level = "destructive"
    elif bool(annotations.get("readOnlyHint", false)):
        policy.risk_level = "read"
    else:
        policy.risk_level = "write"
    return policy

func to_dict() -> Dictionary:
    return {
        "available": available,
        "mcp_visible": mcp_visible,
        "cli_allowed": cli_allowed,
        "risk_level": risk_level,
        "requires_apply": requires_apply,
        "requires_open_world_permission": requires_open_world_permission,
    }
```

Implement the remaining model classes with typed fields from the approved design. `ToolExecutionResult.to_cli_dict()` must omit empty `next_cursor` by returning `null` and must never include a callable.

- [ ] **Step 4: Run focused tests**

Expected: all tests in `test_tool_policy.gd` pass.

- [ ] **Step 5: Run the existing MCP type tests**

Run the repository's GUT suite for `native_mcp` and confirm no existing `MCPTypes` test regresses.

- [ ] **Step 6: Commit**

```bash
git add addons/godot_mcp/native_mcp/tool_policy.gd addons/godot_mcp/native_mcp/tool_definition.gd addons/godot_mcp/native_mcp/tool_execution_context.gd addons/godot_mcp/native_mcp/tool_execution_result.gd test/unit/native_mcp/test_tool_policy.gd
git commit -m "feat: add protocol-neutral tool models"
```

---

### Task 2: Implement ToolRegistry, Search Ranking, and Stable Hashes

**Files:**
- Create: `addons/godot_mcp/native_mcp/tool_registry.gd`
- Test: `test/unit/native_mcp/test_tool_registry.gd`

**Interfaces:**
- Consumes: `ToolDefinition` from Task 1.
- Produces: `register_tool`, `unregister_tool`, `get_tool`, `list_tools`, `search_tools`, `get_catalog_hash`, and `get_schema_hash`.

- [ ] **Step 1: Write failing registry tests**

Cover these exact cases:

```gdscript
func test_exact_name_ranks_before_description_match() -> void:
    var registry = ToolRegistry.new()
    registry.register_tool(_tool("runtime_tree", "Read something else"))
    registry.register_tool(_tool("other", "Read runtime tree"))
    var results: Array[Dictionary] = registry.search_tools("runtime tree", 5)
    assert_eq(results[0]["name"], "runtime_tree")

func test_cli_catalog_includes_hidden_supplementary_tool() -> void:
    var definition = _tool("advanced_read", "Advanced read", "supplementary")
    definition.policy.mcp_visible = false
    definition.policy.cli_allowed = true
    registry.register_tool(definition)
    assert_eq(registry.list_tools({"cli_allowed": true}).size(), 1)
    assert_eq(registry.list_tools({"mcp_visible": true}).size(), 0)

func test_catalog_hash_is_independent_of_registration_order() -> void:
    var left = ToolRegistry.new()
    var right = ToolRegistry.new()
    left.register_tool(_tool("a", "A"))
    left.register_tool(_tool("b", "B"))
    right.register_tool(_tool("b", "B"))
    right.register_tool(_tool("a", "A"))
    assert_eq(left.get_catalog_hash(), right.get_catalog_hash())
```

- [ ] **Step 2: Run focused tests and verify failure**

Expected: load failure because `tool_registry.gd` does not exist.

- [ ] **Step 3: Implement deterministic registry behavior**

Search score must use this exact order:

```text
500 exact normalized name
400 normalized name prefix
300 every query token appears in name
200 every query token appears in name plus description
100 any token appears in description
50  any token appears in group or category
```

Sort by descending score and then ascending tool name. Clamp search limit to `1..20`, with default `5`.

Catalog and schema hashes must serialize dictionaries with sorted keys and tools sorted by name, then use `sha256_text()` with the prefix `sha256:`.

- [ ] **Step 4: Run focused tests and the classifier tests**

Expected: registry tests and existing classifier tests pass.

- [ ] **Step 5: Commit**

```bash
git add addons/godot_mcp/native_mcp/tool_registry.gd test/unit/native_mcp/test_tool_registry.gd
git commit -m "feat: add tool registry and catalog search"
```

---

### Task 3: Implement Shared ToolExecutor and Policy Enforcement

**Files:**
- Create: `addons/godot_mcp/native_mcp/tool_executor.gd`
- Test: `test/unit/native_mcp/test_tool_executor.gd`

**Interfaces:**
- Consumes: `ToolRegistry`, `ToolExecutionContext`, and `ToolExecutionResult`.
- Produces: `execute(tool_name, arguments, context) -> ToolExecutionResult` and execution signals compatible with `MCPServerCore` logging.

- [ ] **Step 1: Write failing executor tests**

Tests must verify:

- missing tool returns `TOOL_NOT_FOUND`;
- unavailable tool returns `TOOL_UNAVAILABLE`;
- MCP caller cannot execute `mcp_visible=false` tool;
- CLI caller can execute `mcp_visible=false`, `cli_allowed=true` tool;
- destructive tool returns `APPLY_REQUIRED` before invoking the callable;
- open-world tool returns `OPEN_WORLD_PERMISSION_REQUIRED` before invoking the callable;
- a dictionary containing `error` normalizes to failure;
- ordinary values normalize to success;
- callable executes exactly once.

Use a fake callable counter:

```gdscript
var _call_count: int = 0

func _success_handler(arguments: Dictionary) -> Dictionary:
    _call_count += 1
    return {"echo": arguments}
```

- [ ] **Step 2: Run focused test and verify failure**

Expected: missing `tool_executor.gd`.

- [ ] **Step 3: Implement ToolExecutor**

The policy order must be exact:

```text
1. tool exists
2. policy.available
3. caller-specific permission
4. requires_apply
5. requires_open_world_permission
6. callable validity
7. invoke once
8. normalize result
```

Use these stable error codes:

```text
TOOL_NOT_FOUND
TOOL_UNAVAILABLE
MCP_TOOL_HIDDEN
CLI_TOOL_FORBIDDEN
APPLY_REQUIRED
OPEN_WORLD_PERMISSION_REQUIRED
INVALID_CALLABLE
TOOL_EXECUTION_FAILED
```

- [ ] **Step 4: Run focused tests**

Expected: all executor tests pass.

- [ ] **Step 5: Commit**

```bash
git add addons/godot_mcp/native_mcp/tool_executor.gd test/unit/native_mcp/test_tool_executor.gd
git commit -m "feat: add shared tool executor"
```

---

### Task 4: Migrate MCPServerCore to Registry and Executor Without Wire Changes

**Files:**
- Modify: `addons/godot_mcp/native_mcp/mcp_types.gd:58-110`
- Modify: `addons/godot_mcp/native_mcp/mcp_server_core.gd:60-68`
- Modify: `addons/godot_mcp/native_mcp/mcp_server_core.gd:365-494`
- Modify: `addons/godot_mcp/native_mcp/mcp_server_core.gd:585-700`
- Modify: `addons/godot_mcp/native_mcp/tool_state_manager.gd`
- Test: existing MCP server core tests
- Test: `test/unit/native_mcp/test_tool_executor.gd`

**Interfaces:**
- Consumes: registry and executor from Tasks 2 and 3.
- Produces: unchanged public `register_tool(...)`, `get_tool(...)`, `get_all_tools()`, `get_registered_tools()`, `set_tool_enabled(...)`, and MCP wire responses.

- [ ] **Step 1: Add failing MCP compatibility tests**

Capture exact legacy envelopes:

```gdscript
func test_tools_list_uses_input_schema_key_and_mcp_visibility() -> void:
    var response: Dictionary = core._handle_tools_list({"id": 1})
    var tools: Array = response["result"]["tools"]
    assert_true(tools[0].has("inputSchema"))
    assert_false(tools[0].has("callable"))

func test_tool_call_preserves_content_and_structured_content() -> void:
    var response: Dictionary = await core._handle_tool_call({
        "id": 2,
        "params": {"name": "sample", "arguments": {"value": 7}},
    })
    assert_false(response["result"]["isError"])
    assert_eq(response["result"]["structuredContent"]["value"], 7)
```

Add a visibility test where a supplementary tool is absent from `tools/list` but remains present in the registry.

- [ ] **Step 2: Run the focused MCP tests and record current passing baseline**

This is a characterization test step. Expected before migration: legacy tests pass; the new registry-specific assertion fails.

- [ ] **Step 3: Replace `_tools` ownership with registry and executor**

Keep `register_tool`'s eight-argument signature. Construct a `ToolDefinition`, derive policy from category and annotations, register it, and return without changing tool implementation files.

Map MCP calls using:

```gdscript
var context := ToolExecutionContext.new()
context.caller = "mcp"
context.request_id = str(id)
var execution: ToolExecutionResult = await _tool_executor.execute(tool_name, arguments, context)
```

The MCP mapper must continue returning text content containing JSON and `structuredContent` when an output schema exists.

- [ ] **Step 4: Preserve state-manager behavior with independent fields**

`set_tool_enabled(name, value)` remains a compatibility method and changes `policy.mcp_visible`. Add explicit methods:

```gdscript
func set_tool_available(tool_name: String, available: bool) -> void
func set_tool_mcp_visible(tool_name: String, visible: bool) -> void
func set_tool_cli_allowed(tool_name: String, allowed: bool) -> void
```

Persist only administrator-controlled availability and MCP visibility in the existing state file. Default `cli_allowed` continues to derive from metadata and policy overrides.

- [ ] **Step 5: Run MCP core, classifier, and tool-state tests**

Expected: existing MCP response tests pass unchanged; new visibility tests pass.

- [ ] **Step 6: Run the complete GUT suite**

```powershell
& "F:\Godot\Godot_v4.6.1-stable_win64.exe" --headless --path "." -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -ginclude_subdirs -gexit
```

Expected: zero failures.

- [ ] **Step 7: Commit**

```bash
git add addons/godot_mcp/native_mcp/mcp_types.gd addons/godot_mcp/native_mcp/mcp_server_core.gd addons/godot_mcp/native_mcp/tool_state_manager.gd test/unit
git commit -m "refactor: route MCP tools through shared executor"
```

---

### Task 5: Add CLI Result Limiting

**Files:**
- Create: `addons/godot_mcp/native_mcp/cli_result_limiter.gd`
- Test: `test/unit/native_mcp/test_cli_result_limiter.gd`

**Interfaces:**
- Consumes: a successful `ToolExecutionResult` and options dictionary.
- Produces: a limited result with `truncated`, `next_cursor`, and projected data.

- [ ] **Step 1: Write failing limiter tests**

Cover:

```gdscript
func test_list_limit_returns_cursor() -> void:
    var result = limiter.limit_data([1, 2, 3, 4], {"limit": 2, "cursor": ""})
    assert_eq(result.data, [1, 2])
    assert_true(result.truncated)
    assert_eq(result.next_cursor, "2")

func test_fields_projects_array_of_dictionaries() -> void:
    var result = limiter.limit_data([
        {"name": "A", "path": "a", "hidden": true},
    ], {"fields": ["name", "path"]})
    assert_eq(result.data, [{"name": "A", "path": "a"}])

func test_tree_depth_replaces_children_beyond_limit() -> void:
    var data = {"name": "root", "children": [{"name": "child", "children": [{"name": "leaf"}]}]}
    var result = limiter.limit_data(data, {"depth": 1})
    assert_true(result.truncated)
    assert_eq(result.data["children"][0]["children"], [])
```

- [ ] **Step 2: Run focused tests and verify failure**

- [ ] **Step 3: Implement deterministic limiting**

Rules:

- default list limit `50`, maximum `500`;
- default tree depth `4`, maximum `32`;
- cursor is a decimal array offset;
- invalid cursor returns `INVALID_CURSOR`;
- field projection applies only to dictionaries and arrays of dictionaries;
- generic byte guard uses UTF-8 size of compact JSON;
- byte overflow returns `OUTPUT_TOO_LARGE` with a narrowing hint rather than emitting invalid truncated JSON.

- [ ] **Step 4: Run focused tests**

- [ ] **Step 5: Commit**

```bash
git add addons/godot_mcp/native_mcp/cli_result_limiter.gd test/unit/native_mcp/test_cli_result_limiter.gd
git commit -m "feat: add bounded CLI result handling"
```

---

### Task 6: Add `/cli/v1` API Handler and HTTP Routing

**Files:**
- Create: `addons/godot_mcp/native_mcp/cli_api_handler.gd`
- Modify: `addons/godot_mcp/native_mcp/mcp_http_server.gd`
- Modify: `addons/godot_mcp/mcp_server_native.gd`
- Test: `test/unit/native_mcp/test_cli_api_handler.gd`

**Interfaces:**
- Consumes: `ToolRegistry`, `ToolExecutor`, `CliResultLimiter`, server/plugin version information, and existing auth manager.
- Produces: HTTP status, headers, and JSON body for `/cli/v1/doctor`, `/catalog`, `/tools/search`, `/tools/<name>`, and `/tools/<name>/execute`.

- [ ] **Step 1: Write handler-level failing tests**

Test with plain dictionaries instead of sockets:

```gdscript
var response: Dictionary = await handler.handle({
    "method": "GET",
    "path": "/cli/v1/tools/search",
    "query": {"q": "runtime tree", "limit": "5"},
    "headers": {"x-gdmcp-api-version": "1"},
    "body": "",
    "remote_address": "127.0.0.1",
})
assert_eq(response["status"], 200)
assert_eq(response["body"]["api_version"], 1)
```

Required cases:

- doctor success;
- catalog contains compact summaries without schemas;
- search limit clamp;
- one-tool schema success and 404;
- read execute success;
- destructive execute returns HTTP 409 and `APPLY_REQUIRED`;
- API version mismatch returns HTTP 409 and `API_VERSION_MISMATCH`;
- non-loopback request returns HTTP 403 when remote CLI API is disabled.

- [ ] **Step 2: Run focused tests and verify failure**

- [ ] **Step 3: Implement `CliApiHandler`**

Use exact route matching. URL-decode path segments and query values. Every JSON response includes `api_version: 1`. Error bodies use:

```json
{
  "api_version": 1,
  "ok": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable message",
    "retryable": false,
    "hint": null
  }
}
```

- [ ] **Step 4: Route CLI requests in `mcp_http_server.gd`**

Before JSON-RPC parsing:

```gdscript
if request.path.begins_with("/cli/v1"):
    var cli_response: Dictionary = await _cli_api_handler.handle(request.to_dictionary())
    _send_http_json(peer, cli_response["status"], cli_response["body"], cli_response.get("headers", {}))
    return
```

Expose `set_cli_api_handler(handler)` on the HTTP transport. The plugin entry constructs the handler only after registry and executor initialization and injects it when HTTP transport is selected.

- [ ] **Step 5: Run handler tests and existing HTTP transport tests**

- [ ] **Step 6: Run complete GUT suite**

Expected: zero failures.

- [ ] **Step 7: Commit**

```bash
git add addons/godot_mcp/native_mcp/cli_api_handler.gd addons/godot_mcp/native_mcp/mcp_http_server.gd addons/godot_mcp/mcp_server_native.gd test/unit/native_mcp/test_cli_api_handler.gd
git commit -m "feat: expose localhost CLI API"
```

---

### Task 7: Add Python CLI API Integration Tests

**Files:**
- Create: `test/integration/godot_test_server.py`
- Create: `test/integration/test_cli_api_flow.py`
- Modify: `test/integration/test_runtime_probe_flow.py`

**Interfaces:**
- Consumes: headless Godot launch command and HTTP port `9080`.
- Produces: reusable `GodotTestServer` context manager and end-to-end API assertions.

- [ ] **Step 1: Extract the Godot process helper with characterization tests**

Implement:

```python
class GodotTestServer:
    def __init__(self, project_path: Path, godot_path: Path, port: int = 9080) -> None:
        self.project_path = project_path
        self.godot_path = godot_path
        self.port = port
        self.process: subprocess.Popen[str] | None = None

    def __enter__(self) -> "GodotTestServer":
        self.start()
        self.wait_until_ready()
        return self

    def __exit__(self, exc_type, exc, traceback) -> None:
        self.stop()
```

Use the repository's current executable resolution and process-cleanup rules.

- [ ] **Step 2: Add failing end-to-end tests**

The test must verify:

1. `GET /cli/v1/doctor` returns API version 1.
2. catalog contains `get_scene_tree`.
3. search finds `get_runtime_scene_tree` with limit 5.
4. schema returns only that tool.
5. a CLI read execution succeeds.
6. a supplementary CLI-allowed tool does not appear in MCP `tools/list`.
7. the same supplementary tool executes through `/cli/v1`.
8. a destructive fake/integration-safe operation is rejected without apply.
9. existing MCP initialize/list/call still work.

- [ ] **Step 3: Run the new integration test and verify the first failing assertion**

```powershell
python test/integration/test_cli_api_flow.py
```

- [ ] **Step 4: Fix only integration defects found by the test**

Do not add Rust code in this task.

- [ ] **Step 5: Run both integration flows**

```powershell
python test/integration/test_cli_api_flow.py
python test/integration/test_runtime_probe_flow.py
```

Expected: both exit with code 0.

- [ ] **Step 6: Commit**

```bash
git add test/integration/godot_test_server.py test/integration/test_cli_api_flow.py test/integration/test_runtime_probe_flow.py
git commit -m "test: cover CLI API integration flow"
```

---

### Task 8: Scaffold Rust CLI, Configuration, Contracts, and Doctor

**Files:**
- Create: `cli/gdmcp/Cargo.toml`
- Create: `cli/gdmcp/src/main.rs`
- Create: `cli/gdmcp/src/cli.rs`
- Create: `cli/gdmcp/src/config.rs`
- Create: `cli/gdmcp/src/client.rs`
- Create: `cli/gdmcp/src/contracts.rs`
- Create: `cli/gdmcp/src/error.rs`
- Create: `cli/gdmcp/src/output.rs`
- Create: `cli/gdmcp/src/commands/mod.rs`
- Create: `cli/gdmcp/src/commands/doctor.rs`
- Test: `cli/gdmcp/tests/cli_parser.rs`
- Test: `cli/gdmcp/tests/config_precedence.rs`
- Test: `cli/gdmcp/tests/json_contracts.rs`

**Interfaces:**
- Consumes: `/cli/v1/doctor`.
- Produces: `gdmcp --json doctor`, global options, stable envelope, and exit codes.

- [ ] **Step 1: Create Cargo manifest and failing parser tests**

Use:

```toml
[package]
name = "gdmcp"
version = "0.1.0"
edition = "2021"
rust-version = "1.80"

[dependencies]
anyhow = "1"
clap = { version = "4", features = ["derive"] }
directories = "6"
reqwest = { version = "0.12", default-features = false, features = ["json", "rustls-tls"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
thiserror = "2"
tokio = { version = "1", features = ["macros", "rt-multi-thread"] }
toml = "0.8"

[dev-dependencies]
assert_cmd = "2"
predicates = "3"
serde_json = "1"
tempfile = "3"
wiremock = "0.6"
```

Parser tests must assert `doctor`, `--json`, `--url`, and `--timeout` parse and that unknown commands exit with code 2.

- [ ] **Step 2: Run Cargo tests and verify failure**

```powershell
cargo test --manifest-path cli/gdmcp/Cargo.toml
```

Expected: compile failure because source files do not exist.

- [ ] **Step 3: Implement configuration precedence**

Exact precedence:

```text
CLI --url / --timeout
GODOT_MCP_URL / GODOT_MCP_TIMEOUT / GODOT_MCP_TOKEN
config.toml
http://127.0.0.1:9080 and 30 seconds
```

Do not accept token through a command-line flag. Redact token in `Debug` output.

- [ ] **Step 4: Implement typed doctor client and output envelope**

`main.rs` maps errors to exit codes and calls `std::process::exit(code)` only at the outer boundary. JSON stdout must serialize exactly one `CliEnvelope`.

- [ ] **Step 5: Run Cargo fmt, clippy, and tests**

```powershell
cargo fmt --manifest-path cli/gdmcp/Cargo.toml --check
cargo clippy --manifest-path cli/gdmcp/Cargo.toml --all-targets -- -D warnings
cargo test --manifest-path cli/gdmcp/Cargo.toml
```

Expected: all exit 0.

- [ ] **Step 6: Commit**

```bash
git add cli/gdmcp
git commit -m "feat: scaffold gdmcp CLI and doctor command"
```

---

### Task 9: Add Progressive Discovery and Raw Tool Calls

**Files:**
- Create: `cli/gdmcp/src/args.rs`
- Create: `cli/gdmcp/src/commands/tools.rs`
- Create: `cli/gdmcp/src/commands/tool_call.rs`
- Modify: `cli/gdmcp/src/cli.rs`
- Modify: `cli/gdmcp/src/client.rs`
- Test: `cli/gdmcp/tests/http_commands.rs`

**Interfaces:**
- Consumes: search, schema, and execute CLI API routes.
- Produces: `tools search`, `tools schema`, and `tool-call` commands.

- [ ] **Step 1: Write failing mocked HTTP tests**

Verify exact requests:

```text
GET /cli/v1/tools/search?q=runtime%20tree&limit=5
GET /cli/v1/tools/get_runtime_scene_tree
POST /cli/v1/tools/get_runtime_scene_tree/execute
```

Verify `--args-json` and `--args-file` are mutually exclusive and conflicts return code 2 before HTTP is called.

- [ ] **Step 2: Run focused Cargo test and verify failure**

- [ ] **Step 3: Implement argument loading**

```rust
pub fn load_json_argument(
    inline: Option<&str>,
    file: Option<&Path>,
) -> Result<serde_json::Value, CliError>
```

Rules:

- neither means `{}`;
- both means `InvalidArguments`;
- file is UTF-8 JSON;
- root must be a JSON object for `tool-call`.

- [ ] **Step 4: Implement commands and stable errors**

`tools search` defaults to 5 and rejects values above 20 locally. `tools schema` requires an exact tool name. `tool-call` forwards `--apply`, `--allow-open-world`, and `--max-bytes`.

- [ ] **Step 5: Run fmt, clippy, and Cargo tests**

- [ ] **Step 6: Run against the integration Godot server**

```powershell
cargo run --manifest-path cli/gdmcp/Cargo.toml -- --json doctor
cargo run --manifest-path cli/gdmcp/Cargo.toml -- --json tools search "scene tree" --limit 5
cargo run --manifest-path cli/gdmcp/Cargo.toml -- --json tools schema get_scene_tree
cargo run --manifest-path cli/gdmcp/Cargo.toml -- --json tool-call get_scene_tree --args-json "{}"
```

Expected: each command exits 0 and stdout is valid JSON.

- [ ] **Step 7: Commit**

```bash
git add cli/gdmcp/src cli/gdmcp/tests
git commit -m "feat: add progressive CLI tool discovery"
```

---

### Task 10: Add High-level Read Commands and Stable Resolve Operations

**Files:**
- Create: `cli/gdmcp/src/commands/editor.rs`
- Create: `cli/gdmcp/src/commands/scenes.rs`
- Create: `cli/gdmcp/src/commands/nodes.rs`
- Create: `cli/gdmcp/src/commands/scripts.rs`
- Create: `cli/gdmcp/src/commands/resources.rs`
- Create: `cli/gdmcp/src/commands/project.rs`
- Create: `cli/gdmcp/src/commands/debug.rs`
- Create: `cli/gdmcp/src/commands/runtime.rs`
- Modify: `cli/gdmcp/src/cli.rs`
- Test: `cli/gdmcp/tests/command_mappings.rs`

**Interfaces:**
- Consumes: raw execute client from Task 9.
- Produces: typed mappings for the approved high-level read commands and local resolve logic.

- [ ] **Step 1: Write failing mapping tests**

Create table-driven tests asserting command-to-tool and JSON arguments:

```rust
#[test]
fn scenes_tree_maps_to_get_scene_tree() {
    let call = map_command(Command::Scenes(ScenesCommand::Tree {
        scene: None,
        depth: 4,
        fields: vec!["path".into(), "type".into()],
    }))
    .unwrap();
    assert_eq!(call.tool, "get_scene_tree");
    assert_eq!(call.limit.depth, Some(4));
}
```

Cover:

- `editor state`;
- `scenes list`, `current`, `tree`;
- `nodes get`;
- `scripts list`, `read`, `validate`;
- `resources list`;
- `project info`;
- `debug logs`;
- `runtime info`, `tree`, `nodes get`.

- [ ] **Step 2: Run focused test and verify failure**

- [ ] **Step 3: Implement read mappings**

Mappings use the exact table in the design specification. Keep one `ToolInvocation` structure:

```rust
pub struct ToolInvocation {
    pub command_name: &'static str,
    pub tool: &'static str,
    pub arguments: serde_json::Value,
    pub apply_confirmed: bool,
    pub allow_open_world: bool,
    pub limit: LimitOptions,
}
```

- [ ] **Step 4: Implement resolve commands**

Resolve uses the corresponding list command, then applies these rules:

1. exact path match;
2. exact case-sensitive name match;
3. exact case-insensitive name match;
4. unique suffix match;
5. otherwise return `AMBIGUOUS_MATCH` with at most 10 candidates.

Resolve output includes `kind`, `id`, and the domain-specific stable path field.

- [ ] **Step 5: Run Cargo tests and CLI integration smoke commands**

- [ ] **Step 6: Commit**

```bash
git add cli/gdmcp/src/commands cli/gdmcp/src/cli.rs cli/gdmcp/tests/command_mappings.rs
git commit -m "feat: add high-level Godot read commands"
```

---

### Task 11: Add Explicit Write Commands and Server-side Permission Flags

**Files:**
- Modify: `cli/gdmcp/src/commands/scenes.rs`
- Modify: `cli/gdmcp/src/commands/nodes.rs`
- Modify: `cli/gdmcp/src/commands/scripts.rs`
- Modify: `cli/gdmcp/src/commands/resources.rs`
- Modify: `cli/gdmcp/src/commands/project.rs`
- Modify: `cli/gdmcp/src/commands/debug.rs`
- Modify: `cli/gdmcp/src/commands/runtime.rs`
- Modify: `cli/gdmcp/src/cli.rs`
- Test: `cli/gdmcp/tests/command_mappings.rs`
- Test: `cli/gdmcp/tests/http_commands.rs`

**Interfaces:**
- Consumes: `ToolInvocation` and raw execute client.
- Produces: explicit create/set/replace/delete/run/stop commands with permission propagation.

- [ ] **Step 1: Write failing write-mapping tests**

Cover exact mappings:

```text
scenes open          -> open_scene
scenes save          -> save_scene
nodes create         -> create_node
nodes delete         -> delete_node
nodes move           -> move_node
nodes rename         -> rename_node
nodes properties set -> update_node_property
scripts create       -> create_script
scripts replace      -> modify_script
resources create     -> create_resource
project run          -> run_project
project stop         -> stop_project
debug clear          -> clear_output
runtime nodes set    -> update_runtime_node_property
runtime nodes call   -> call_runtime_node_method
```

Verify `nodes delete` cannot run unless `--apply` is present. Verify `runtime nodes call` forwards `--allow-open-world` when supplied.

- [ ] **Step 2: Run focused tests and verify failure**

- [ ] **Step 3: Implement JSON value and content-file parsing**

`--value-json` parses any JSON value. `--content-file` reads UTF-8 without changing line endings. Empty files are valid script content.

- [ ] **Step 4: Implement write command mappings**

Each command maps to exactly one tool invocation. Do not implement automatic multi-step fixes.

- [ ] **Step 5: Verify server enforcement with mocked and real tests**

A client-side missing flag may fail early, but the integration test must also send a direct request without the flag and verify the server returns `APPLY_REQUIRED`.

- [ ] **Step 6: Run fmt, clippy, and Cargo tests**

- [ ] **Step 7: Commit**

```bash
git add cli/gdmcp/src cli/gdmcp/tests
git commit -m "feat: add explicit Godot write commands"
```

---

### Task 12: Add Local Output Files and Batch Preview/Apply

**Files:**
- Create: `cli/gdmcp/src/commands/batch.rs`
- Modify: `cli/gdmcp/src/output.rs`
- Modify: `cli/gdmcp/src/cli.rs`
- Test: `cli/gdmcp/tests/json_contracts.rs`
- Test: `cli/gdmcp/tests/command_mappings.rs`

**Interfaces:**
- Consumes: high-level command mapper and execute client.
- Produces: `--out`, `batch preview`, and `batch apply`.

- [ ] **Step 1: Write failing output-file tests**

Verify:

- parent directories are created;
- output is UTF-8 JSON or JSONL according to command mode;
- stdout contains only metadata after a successful `--out` write;
- file errors return configuration/output error code 3;
- secrets are not included in file metadata.

- [ ] **Step 2: Write failing batch tests**

Input format is exactly:

```json
{
  "operations": [
    {
      "command": "nodes.properties.set",
      "target": "/root/Main/Player",
      "property": "speed",
      "value": 300
    }
  ]
}
```

Preview returns mapped tools and arguments without HTTP execution. Apply requires `--apply`, executes sequentially, stops at the first failure, and reports:

```json
{
  "atomic": false,
  "completed": 1,
  "failed_index": null,
  "results": []
}
```

- [ ] **Step 3: Run focused tests and verify failure**

- [ ] **Step 4: Implement atomic mapping for supported native batches**

Use `batch_update_node_properties` only when every operation is `nodes.properties.set`. Use `batch_scene_node_edits` only when every operation belongs to its supported create/delete/move subset. Otherwise execute sequentially and return `atomic: false`.

- [ ] **Step 5: Run Cargo tests and a real preview/apply smoke flow against a disposable test scene**

- [ ] **Step 6: Commit**

```bash
git add cli/gdmcp/src cli/gdmcp/tests
git commit -m "feat: add CLI output files and batch operations"
```

---

### Task 13: Add Skill, Documentation, Installers, CI, and Final Verification

**Files:**
- Create: `skills/gdmcp/SKILL.md`
- Create: `skills/gdmcp/references/command-workflows.md`
- Create: `docs/current/gdmcp-cli-reference.md`
- Create: `cli/gdmcp/README.md`
- Create: `cli/gdmcp/scripts/install.ps1`
- Create: `cli/gdmcp/scripts/install.sh`
- Modify: `AGENTS.md`
- Create or modify: `.github/workflows/gdmcp-cli.yml`
- Modify: root `README.md`
- Modify: root `README.zh.md`

**Interfaces:**
- Consumes: completed Godot API and Rust CLI.
- Produces: agent usage guidance, human installation guidance, cross-platform builds, and release artifacts.

- [ ] **Step 1: Add the compact Skill**

`skills/gdmcp/SKILL.md` must contain this workflow and no complete tool catalog:

```markdown
---
name: gdmcp
description: Use the installed gdmcp CLI to inspect, edit, run, and debug the current Godot project without loading the full Godot MCP tool catalog.
---

# gdmcp

Run `gdmcp --json doctor` when connection state is unknown.

Use high-level commands for common work. For uncommon work, run:

1. `gdmcp --json tools search "<intent>" --limit 5`
2. `gdmcp --json tools schema <tool-name>`
3. `gdmcp --json tool-call <tool-name> --args-file <path>`

Use `--limit`, `--depth`, `--fields`, `--max-bytes`, and `--out` to bound output.
Use file arguments for complex JSON on Windows.
Do not perform destructive or open-world operations unless the user requested them.
Preview batches before applying them.
```

- [ ] **Step 2: Add reference documentation**

Document installation, configuration precedence, authentication, command taxonomy, JSON envelope, exit codes, progressive discovery, Windows quoting, batch behavior, and troubleshooting.

- [ ] **Step 3: Add installers**

`install.ps1` accepts `-InstallDir`, defaults to `$env:LOCALAPPDATA\Programs\gdmcp`, copies `gdmcp.exe`, and prints the exact PATH entry when the directory is absent from PATH.

`install.sh` accepts an optional destination, defaults to `$HOME/.local/bin`, installs mode `0755`, and prints the exact PATH export when needed.

Neither installer downloads code or modifies shell profiles automatically.

- [ ] **Step 4: Add CI**

The workflow runs:

```text
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
cargo build --release
```

Matrix:

```text
windows-latest / x86_64-pc-windows-msvc
ubuntu-latest  / x86_64-unknown-linux-gnu
macos-latest   / aarch64-apple-darwin
```

Upload the single executable with platform-specific archive names. Keep Godot GUT and Python integration verification in the repository's existing compatible runner.

- [ ] **Step 5: Update project guidance**

Add a short `AGENTS.md` section that points agents to `skills/gdmcp/SKILL.md` and gives only `doctor`, `tools search`, and `tools schema` examples.

Update README files with:

- what `gdmcp` solves;
- supported platforms;
- one installation example;
- one progressive discovery example;
- a link to `docs/current/gdmcp-cli-reference.md`.

- [ ] **Step 6: Run documentation consistency checks**

Search for conflicting API versions, schema versions, tool totals, and command spellings:

```powershell
rg -n "api_version|schema_version|gdmcp|tool-call|tools schema|tools search" docs skills cli AGENTS.md README.md README.zh.md
```

Confirm API and schema versions are `1` everywhere and the docs do not contain a hand-maintained full tool catalog.

- [ ] **Step 7: Run complete verification**

Godot unit tests:

```powershell
& "F:\Godot\Godot_v4.6.1-stable_win64.exe" --headless --path "." -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -ginclude_subdirs -gexit
```

Python integration tests:

```powershell
python test/integration/test_cli_api_flow.py
python test/integration/test_runtime_probe_flow.py
```

Rust verification:

```powershell
cargo fmt --manifest-path cli/gdmcp/Cargo.toml --check
cargo clippy --manifest-path cli/gdmcp/Cargo.toml --all-targets -- -D warnings
cargo test --manifest-path cli/gdmcp/Cargo.toml
cargo build --manifest-path cli/gdmcp/Cargo.toml --release
```

CLI smoke test with a running disposable Godot test project:

```powershell
cli\gdmcp\target\release\gdmcp.exe --json doctor
cli\gdmcp\target\release\gdmcp.exe --json tools search "scene tree" --limit 5
cli\gdmcp\target\release\gdmcp.exe --json tools schema get_scene_tree
cli\gdmcp\target\release\gdmcp.exe --json scenes tree --depth 2 --fields path,type
```

Expected: every command exits 0, every JSON stdout value parses, GUT reports zero failures, both Python scripts exit 0, and the Rust release executable is produced.

- [ ] **Step 8: Commit**

```bash
git add skills/gdmcp docs/current/gdmcp-cli-reference.md cli/gdmcp/README.md cli/gdmcp/scripts AGENTS.md .github/workflows README.md README.zh.md
git commit -m "docs: publish gdmcp agent workflow and release pipeline"
```

---

## Plan Self-review Record

### Spec coverage

- Progressive disclosure: Tasks 6, 9, 10, and 13.
- One source of truth: Tasks 1 through 4.
- Independent availability/MCP/CLI policy: Tasks 1, 3, 4, and 6.
- Stable CLI API and versioning: Task 6.
- Rust single-binary CLI: Tasks 8 through 13.
- High-level commands plus raw escape hatch: Tasks 9 through 11.
- Bounded output and local files: Tasks 5 and 12.
- Destructive/open-world safety: Tasks 1, 3, 6, 9, and 11.
- Batch preview/apply: Task 12.
- Companion Skill and AGENTS guidance: Task 13.
- Existing MCP compatibility: Tasks 4, 6, 7, and 13.
- Unit, integration, Rust, and cross-platform verification: Tasks 1 through 13.

### Type consistency

- `ToolPolicy`, `ToolDefinition`, `ToolExecutionContext`, and `ToolExecutionResult` originate in Task 1.
- `ToolRegistry` originates in Task 2 and is consumed by Tasks 3, 4, and 6.
- `ToolExecutor.execute(tool_name, arguments, context)` originates in Task 3 and is consumed by MCP and CLI adapters.
- `CliResultLimiter` originates in Task 5 and is consumed by Task 6.
- Rust `ToolInvocation` originates in Task 10 and is consumed by Tasks 11 and 12.
- API version and CLI schema version remain exactly `1` throughout.

### Scope decision

The plan remains one sequential implementation plan because the Godot core, CLI API, and Rust CLI are dependency-linked deliverables. Each task still yields an independently testable commit and may be reviewed or paused before the next task.
