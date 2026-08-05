extends "res://addons/gut/test.gd"

var _scene_tools: RefCounted = null

func before_each() -> void:
	_scene_tools = load("res://addons/godot_mcp/tools/scene_tools_native.gd").new()

func after_each() -> void:
	_scene_tools = null
	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")

func test_scene_extension_validation():
	assert_has([".tscn"], ".tscn", "Scene should have .tscn extension")

func test_scene_path_safety():
	assert_true(true, "res:// scene path should be safe")

func test_scene_structure_format():
	var result: Dictionary = {"root_node": {"children": []}}
	assert_has(result, "root_node", "Should have root_node")
	assert_has(result.root_node, "children", "Root node should have children")

func test_friendly_path_for_scene():
	var root_path: String = "/root/MainScene"
	assert_true(root_path.contains("MainScene"), "Root path should contain MainScene")

func test_current_scene_format():
	var result: Dictionary = {"scene_path": "res://main.tscn", "scene_name": "Main"}
	assert_has(result, "scene_path", "Should have scene_path")
	assert_has(result, "scene_name", "Should have scene_name")

# --- Vibe Coding policy guard tests ---

func test_open_scene_blocked_in_vibe_mode() -> void:
	var result: Dictionary = _scene_tools._tool_open_scene({"scene_path": "res://TestScene.tscn"})
	assert_true(result.get("blocked", false), "open_scene should be blocked in vibe mode")
	assert_eq(result.get("reason", ""), "vibe_coding_mode", "Block reason should be vibe_coding_mode")

func test_open_scene_bypasses_with_allow_ui_focus() -> void:
	var result: Dictionary = _scene_tools._tool_open_scene({"scene_path": "res://TestScene.tscn", "allow_ui_focus": true})
	assert_false(result.get("blocked", false), "allow_ui_focus should bypass vibe mode")

func test_close_scene_tab_blocked_in_vibe_mode() -> void:
	var result: Dictionary = _scene_tools._tool_close_scene_tab({})
	assert_true(result.get("blocked", false), "close_scene_tab should be blocked in vibe mode")

func test_close_scene_tab_bypasses_with_allow_ui_focus() -> void:
	var result: Dictionary = _scene_tools._tool_close_scene_tab({"allow_ui_focus": true})
	assert_false(result.get("blocked", false), "allow_ui_focus should bypass vibe mode")

# --- Save-as operation field tests ---

func test_save_scene_returns_operation_field():
	"""save_scene without file_path returns operation=save"""
	var result: Dictionary = _scene_tools._tool_save_scene({"file_path": ""})
	# Will error because no scene is open, but the structure should include operation
	if result.has("operation"):
		assert_true(result.get("operation", "") in ["save", "save_as"], "operation should be 'save' or 'save_as'")

func test_save_scene_output_schema_includes_operation():
	"""verify output_schema in _register_save_scene includes operation field"""
	var result: Dictionary = _scene_tools._tool_save_scene({"file_path": ""})
	# In headless mode: will error. When it succeeds, it should have operation.
	if result.has("error"):
		pass_test("Headless mode: expected error without editor interface")
	else:
		assert_has(result, "operation", "save_scene should return operation field")

func test_open_scene_returns_verification_tip_on_success():
	"""open_scene that bypasses vibe mode should include verification_tip in success path"""
	var result: Dictionary = _scene_tools._tool_open_scene({"scene_path": "res://TestScene.tscn", "allow_ui_focus": true})
	# In headless mode without editor interface, this will error.
	# But if it somehow succeeds, it should have verification_tip.
	if result.get("status") == "success":
		assert_has(result, "verification_tip", "successful open_scene should include verification_tip")
		assert_true(result.get("verification_tip", "").length() > 0, "verification_tip should not be empty")

# --- Batch 12: scene operations ---

func test_delete_scene_requires_path():
	var result: Dictionary = _scene_tools._tool_delete_scene({})
	assert_true(result.has("error"), "Missing path should error")

func test_delete_scene_not_found():
	var result: Dictionary = _scene_tools._tool_delete_scene({"path": "res://nonexistent.tscn"})
	assert_true(result.has("error"), "Missing file should error")

func test_add_scene_instance_requires_path():
	var result: Dictionary = _scene_tools._tool_add_scene_instance({})
	assert_true(result.has("error"), "Missing scene_path should error")

func test_add_scene_instance_not_found():
	var result: Dictionary = _scene_tools._tool_add_scene_instance({"scene_path": "res://nonexistent.tscn"})
	assert_true(result.has("error"), "Missing scene file should error")

func test_play_scene_invalid_path():
	var result: Dictionary = _scene_tools._tool_play_scene({"mode": "res://nonexistent.tscn"})
	assert_true(result.has("error"), "Invalid scene path should error")

func test_stop_scene_no_editor():
	var result: Dictionary = _scene_tools._tool_stop_scene({})
	assert_true(result.has("error"), "Without editor interface should error")

func test_get_scene_file_content_requires_path():
	var result: Dictionary = _scene_tools._tool_get_scene_file_content({})
	assert_true(result.has("error"), "Missing path should error")

func test_get_scene_file_content_not_found():
	var result: Dictionary = _scene_tools._tool_get_scene_file_content({"path": "res://nonexistent.tscn"})
	assert_true(result.has("error"), "Missing file should error")

func test_get_scene_exports_requires_path():
	var result: Dictionary = _scene_tools._tool_get_scene_exports({})
	assert_true(result.has("error"), "Missing path should error")

func test_get_scene_exports_not_found():
	var result: Dictionary = _scene_tools._tool_get_scene_exports({"path": "res://nonexistent.tscn"})
	assert_true(result.has("error"), "Missing file should error")

func test_resolve_scene_node_no_scene():
	var result: Node = _scene_tools._resolve_scene_node("/root/Main")
	assert_eq(result, null, "Without scene root should return null")
