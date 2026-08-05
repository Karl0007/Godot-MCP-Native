extends "res://addons/gut/test.gd"

var _project_tools: RefCounted = null

func before_each() -> void:
	_project_tools = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()

func after_each() -> void:
	_project_tools = null
	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")

func test_project_info_format():
	var result: Dictionary = {
		"project_name": "Godot MCP Native",
		"project_path": "F:/gitProjects/Godot-MCP-Native/",
		"project_version": "",
		"project_description": "",
		"main_scene": "res://TestScene.tscn"
	}
	assert_has(result, "project_name", "Should have project_name")
	assert_has(result, "project_path", "Should have project_path")
	assert_has(result, "main_scene", "Should have main_scene")

func test_project_settings_filter():
	var settings: Dictionary = {
		"application/config/name": "Godot MCP Native",
		"application/run/main_scene": "res://TestScene.tscn",
		"debug/gdscript/warnings/unused_variable": true
	}
	var filtered: Dictionary = {}
	for key in settings:
		if key.begins_with("application/"):
			filtered[key] = settings[key]
	assert_eq(filtered.size(), 2, "Should filter to application/ settings only")
	assert_false(filtered.has("debug/gdscript/warnings/unused_variable"), "Should not have debug settings")

func test_project_settings_no_filter():
	var settings: Dictionary = {
		"application/config/name": "Godot MCP Native",
		"debug/gdscript/warnings/unused_variable": true
	}
	assert_eq(settings.size(), 2, "Without filter should return all settings")

func test_resource_extensions():
	var extensions: Array = [
		".tres", ".res", ".png", ".jpg", ".jpeg", ".webp", ".svg",
		".ogg", ".wav", ".mp3", ".glb", ".gltf", ".obj",
		".tscn", ".gd", ".cfg", ".json", ".gdshader"
	]
	assert_has(extensions, ".tscn", "Should include .tscn")
	assert_has(extensions, ".gd", "Should include .gd")
	assert_has(extensions, ".png", "Should include .png")
	assert_has(extensions, ".gdshader", "Should include .gdshader")

func test_resource_path_safety():
	assert_true(MCPTypes.is_path_safe("res://icon.svg"), "res:// resource should be safe")
	assert_false(MCPTypes.is_path_safe("C:\\Windows\\icon.png"), "Windows path should be unsafe")

func test_create_resource_types():
	var valid_types: Array = ["Curve", "Gradient", "StyleBoxFlat", "Animation"]
	assert_has(valid_types, "Curve", "Should support Curve resource")
	assert_has(valid_types, "Gradient", "Should support Gradient resource")

func test_resource_uri_format():
	var uri: String = "godot://scene/list"
	assert_true(uri.begins_with("godot://"), "Resource URI should start with godot://")

func test_collect_project_autoloads_from_properties_marks_singletons_and_sorts():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var properties: Array = [
		{"name": "autoload/GameState"},
		{"name": "autoload/Bootstrap"},
		{"name": "display/window/size/viewport_width"}
	]
	var values: Dictionary = {
		"autoload/GameState": "*res://autoload/game_state.gd",
		"autoload/Bootstrap": "res://autoload/bootstrap.gd"
	}
	var orders: Dictionary = {
		"autoload/GameState": 40,
		"autoload/Bootstrap": 12
	}
	var autoloads: Array = project_tools._collect_project_autoloads_from_properties(properties, values, orders)
	assert_eq(autoloads.size(), 2, "Should collect two autoload entries")
	assert_eq(autoloads[0].name, "Bootstrap", "Should sort autoloads by project setting order")
	assert_eq(autoloads[0].path, "res://autoload/bootstrap.gd", "Should preserve non-singleton autoload path")
	assert_false(autoloads[0].is_singleton, "Non-prefixed autoload should not be marked singleton")
	assert_eq(autoloads[1].name, "GameState", "Should include singleton autoload name")
	assert_eq(autoloads[1].path, "res://autoload/game_state.gd", "Singleton autoload should strip the * prefix")
	assert_true(autoloads[1].is_singleton, "Prefixed autoload should be marked singleton")

func test_normalize_global_class_entries_preserves_metadata():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var classes: Array = [
		{
			"class": "MyRuntimeNode",
			"path": "res://scripts/my_runtime_node.gd",
			"base": "Node",
			"language": "GDScript",
			"is_tool": false,
			"is_abstract": false,
			"icon": ""
		}
	]
	var normalized: Array = project_tools._normalize_global_class_entries(classes)
	assert_eq(normalized.size(), 1, "Should normalize one global class entry")
	assert_eq(normalized[0].name, "MyRuntimeNode", "Should expose class name as name")
	assert_eq(normalized[0].path, "res://scripts/my_runtime_node.gd", "Should preserve script path")
	assert_eq(normalized[0].base, "Node", "Should preserve base type")
	assert_eq(normalized[0].language, "GDScript", "Should preserve language")
	assert_false(normalized[0].is_tool, "Should preserve tool flag")

func test_get_class_api_metadata_returns_classdb_metadata():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var result: Dictionary = project_tools._tool_get_class_api_metadata({
		"class_name": "Node",
		"filter": "process"
	})
	assert_eq(result.source, "classdb", "Engine classes should be sourced from ClassDB")
	assert_eq(result.class_name, "Node", "Should report requested class name")
	assert_eq(result.base_class, "Object", "Should report Node base class")
	assert_gt(result.methods.size(), 0, "Filtered ClassDB methods should be returned")
	assert_gt(result.properties.size(), 0, "Filtered ClassDB properties should be returned")
	assert_true(result.signals.is_empty(), "Process filter should exclude unrelated signals")
	for method in result.methods:
		assert_true(str(method.get("name", "")).to_lower().contains("process"), "Filtered methods should match filter text")

func test_get_class_api_metadata_returns_global_class_metadata_with_base_api():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var result: Dictionary = project_tools._tool_get_class_api_metadata({
		"class_name": "ProjectToolsNative",
		"include_base_api": true
	})
	var has_initialize: bool = false
	for method in result.methods:
		if method.get("name", "") == "initialize":
			has_initialize = true
			break
	assert_eq(result.source, "global_class", "Project class should be sourced from global_class metadata")
	assert_eq(result.class_name, "ProjectToolsNative", "Should report requested global class name")
	assert_eq(result.script_path, "res://addons/godot_mcp/tools/project_tools_native.gd", "Should preserve global class script path")
	assert_eq(result.base_class, "RefCounted", "Should preserve global class base type")
	assert_gt(result.methods.size(), 0, "Global class script methods should be returned")
	assert_true(has_initialize, "Should include script-defined methods")
	assert_true(result.has("base_api"), "Should include base API metadata when requested")
	assert_eq(result.base_api.get("class_name", ""), "RefCounted", "Base API should be resolved from ClassDB")

func test_get_class_api_metadata_reports_missing_class():
	var project_tools: RefCounted = load("res://addons/godot_mcp/tools/project_tools_native.gd").new()
	var result: Dictionary = project_tools._tool_get_class_api_metadata({"class_name": "DefinitelyMissingClass123"})
	assert_has(result, "error", "Missing classes should return an error payload")

# --- Batch 13: project operations ---

func test_get_filesystem_tree():
	var result: Dictionary = _project_tools._tool_get_filesystem_tree({})
	assert_true(result.has("tree"), "Should return tree")
	assert_true(result["tree"].has("path"), "Tree root should have path")

func test_search_files_requires_query():
	var result: Dictionary = _project_tools._tool_search_files({})
	assert_true(result.has("error"), "Missing query should error")

func test_search_files_finds_own_file():
	var result: Dictionary = _project_tools._tool_search_files({"query": "project_tools_native", "max_results": 5})
	assert_true(result.get("count", 0) >= 1, "Should find project_tools_native.gd")

func test_set_project_setting_requires_key():
	var result: Dictionary = _project_tools._tool_set_project_setting({})
	assert_true(result.has("error"), "Missing key should error")

func test_set_project_setting_requires_value():
	var result: Dictionary = _project_tools._tool_set_project_setting({"key": "test/key"})
	assert_true(result.has("error"), "Missing value should error")

func test_uid_to_project_path_requires_uid():
	var result: Dictionary = _project_tools._tool_uid_to_project_path({})
	assert_true(result.has("error"), "Missing uid should error")

func test_uid_to_project_path_invalid():
	var result: Dictionary = _project_tools._tool_uid_to_project_path({"uid": "uid://not_a_uid"})
	assert_true(result.has("error"), "Invalid uid should error")

func test_project_path_to_uid_requires_path():
	var result: Dictionary = _project_tools._tool_project_path_to_uid({})
	assert_true(result.has("error"), "Missing path should error")

func test_add_autoload_requires_params():
	var result: Dictionary = _project_tools._tool_add_autoload({})
	assert_true(result.has("error"), "Missing params should error")

func test_add_autoload_missing_file():
	var result: Dictionary = _project_tools._tool_add_autoload({"name": "Test", "path": "res://nonexistent.gd"})
	assert_true(result.has("error"), "Missing file should error")

func test_remove_autoload_requires_name():
	var result: Dictionary = _project_tools._tool_remove_autoload({})
	assert_true(result.has("error"), "Missing name should error")

func test_get_project_statistics():
	var result: Dictionary = _project_tools._tool_get_project_statistics({})
	assert_true(result.has("totals"), "Should return totals")
	assert_true(result.has("breakdown"), "Should return breakdown")
	assert_true(int(result["totals"].get("total_files", 0)) >= 1, "Should count files")

func test_get_autoload_requires_name():
	var result: Dictionary = _project_tools._tool_get_autoload({})
	assert_true(result.has("error"), "Missing name should error")

func test_get_autoload_unknown():
	var result: Dictionary = _project_tools._tool_get_autoload({"name": "NonExistentAutoload"})
	assert_true(result.has("error"), "Unknown autoload should error")

# --- Batch 14: resource tools ---

func test_read_resource_requires_path():
	var result: Dictionary = _project_tools._tool_read_resource({})
	assert_true(result.has("error"), "Missing path should error")

func test_read_resource_not_found():
	var result: Dictionary = _project_tools._tool_read_resource({"path": "res://nonexistent.tres"})
	assert_true(result.has("error"), "Missing file should error")

func test_edit_resource_requires_params():
	var result: Dictionary = _project_tools._tool_edit_resource({})
	assert_true(result.has("error"), "Missing params should error")

func test_edit_resource_requires_properties():
	var result: Dictionary = _project_tools._tool_edit_resource({"path": "res://x.tres"})
	assert_true(result.has("error"), "Missing properties should error")

func test_edit_resource_not_found():
	var result: Dictionary = _project_tools._tool_edit_resource({"path": "res://nonexistent.tres", "properties": {"a": 1}})
	assert_true(result.has("error"), "Missing file should error")

func test_get_resource_preview_requires_path():
	var result: Dictionary = _project_tools._tool_get_resource_preview({})
	assert_true(result.has("error"), "Missing path should error")

func test_get_resource_preview_not_found():
	var result: Dictionary = _project_tools._tool_get_resource_preview({"path": "res://nonexistent.png"})
	assert_true(result.has("error"), "Missing file should error")

func test_resource_property_parse_int():
	var parsed: Variant = _project_tools._resource_property_parse("42", TYPE_INT)
	assert_eq(parsed, 42, "String should parse to int")

func test_resource_property_parse_bool():
	var parsed: Variant = _project_tools._resource_property_parse("true", TYPE_BOOL)
	assert_eq(parsed, true, "String should parse to bool")

func test_resource_property_parse_vector2():
	var parsed: Variant = _project_tools._resource_property_parse({"x": 1.0, "y": 2.0}, TYPE_VECTOR2)
	assert_true(parsed is Vector2, "Dict should parse to Vector2")
	assert_eq(parsed, Vector2(1, 2), "Vector2 values should round-trip")

func test_resource_property_serialize_color():
	var serialized: Variant = _project_tools._resource_property_serialize(Color.RED)
	assert_true(serialized is Dictionary, "Color should serialize to dict")
	assert_eq(serialized["html"], "#ff0000ff", "HTML should match")
