extends "res://addons/gut/test.gd"

var _editor_tools: RefCounted = null

func before_each() -> void:
	_editor_tools = load("res://addons/godot_mcp/tools/editor_tools_native.gd").new()

func after_each() -> void:
	_editor_tools = null
	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")

# --- get_editor_errors (Batch 11) ---

func test_get_editor_errors_no_editor():
	var result: Dictionary = _editor_tools._tool_get_editor_errors({})
	assert_true(result.has("error"), "Without editor interface should error")

func test_get_output_log_no_editor():
	var result: Dictionary = _editor_tools._tool_get_output_log({})
	assert_true(result.has("error"), "Without editor interface should error")

func test_get_editor_camera_no_editor():
	var result: Dictionary = _editor_tools._tool_get_editor_camera({})
	assert_true(result.has("error"), "Without editor interface should error")

func test_set_editor_camera_no_editor():
	var result: Dictionary = _editor_tools._tool_set_editor_camera({})
	assert_true(result.has("error"), "Without editor interface should error")

func test_get_editor_selection_no_editor():
	var result: Dictionary = _editor_tools._tool_get_editor_selection({})
	assert_true(result.has("error"), "Without editor interface should error")

func test_clear_editor_selection_no_editor():
	var result: Dictionary = _editor_tools._tool_clear_editor_selection({})
	assert_true(result.has("error"), "Without editor interface should error")

func test_reload_plugin_no_editor():
	var result: Dictionary = _editor_tools._tool_reload_plugin({})
	assert_true(result.has("error"), "Without editor interface should error")

func test_select_nodes_requires_paths():
	var result: Dictionary = _editor_tools._tool_select_nodes({})
	assert_true(result.has("error"), "Missing node_paths should error")

func test_select_nodes_invalid_mode():
	var result: Dictionary = _editor_tools._tool_select_nodes({"node_paths": ["/root/Main"], "mode": "flip"})
	assert_true(result.has("error"), "Invalid mode should error")

func test_set_auto_dismiss_sets_plugin_meta():
	# Without GodotMCPPlugin meta, returns enabled state without error
	var result: Dictionary = _editor_tools._tool_set_auto_dismiss({"enabled": true})
	assert_eq(result.get("auto_dismiss", false), true, "Should report enabled=true")

func test_set_auto_dismiss_disabled():
	var result: Dictionary = _editor_tools._tool_set_auto_dismiss({"enabled": false})
	assert_eq(result.get("auto_dismiss", true), false, "Should report enabled=false")

func test_register_tools_includes_batch11():
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()
	var registered: Array = []
	server_core.register_tool = func(name: String, desc: String, schema: Dictionary, cb: Callable, out: Dictionary = {}, ann: Dictionary = {}, cat: String = "core", group: String = "") -> void:
		registered.append(name)
	_editor_tools.register_tools(server_core)
	for name in ["get_editor_errors", "get_output_log", "set_auto_dismiss", "get_editor_camera", "set_editor_camera",
			"get_editor_selection", "select_nodes", "clear_editor_selection", "reload_plugin"]:
		assert_true(name in registered, name + " should be registered")
