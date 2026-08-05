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

# --- Batch 16: export/android ---

func test_export_project_no_editor():
	var result: Dictionary = _editor_tools._tool_export_project({})
	# Without export_presets.cfg it errors; with presets it returns a command
	if result.has("error"):
		pass_test("No preset configured: expected error")
	else:
		assert_true(result.has("command"), "Should generate export command")

func test_get_export_info():
	var result: Dictionary = _editor_tools._tool_get_export_info({})
	assert_true(result.has("has_export_presets"), "Should report preset presence")
	assert_true(result.has("godot_executable"), "Should report Godot path")
	assert_true(result.has("templates_installed"), "Should report templates status")

func test_list_android_devices_requires_adb():
	# adb may not exist; tool should return error dict or devices
	var result: Dictionary = _editor_tools._tool_list_android_devices({})
	if result.has("error"):
		assert_true(result["error"].contains("adb"), "Error should mention adb")
	else:
		assert_true(result.has("devices"), "Should return devices array")

func test_get_android_preset_info_no_preset():
	var result: Dictionary = _editor_tools._tool_get_android_preset_info({})
	assert_true(result.has("error"), "No preset configured should error")

func test_deploy_to_android_no_preset():
	var result: Dictionary = _editor_tools._tool_deploy_to_android({})
	assert_true(result.has("error"), "No preset configured should error")

func test_find_export_preset_missing_file():
	var preset: Dictionary = _editor_tools._find_export_preset("", 0)
	assert_true(preset.is_empty(), "Missing export_presets.cfg should return empty")
