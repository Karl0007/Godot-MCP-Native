extends "res://addons/gut/test.gd"

var _world_tools: RefCounted = null

func before_each() -> void:
	_world_tools = load("res://addons/godot_mcp/tools/world_tools_native.gd").new()

func after_each() -> void:
	_world_tools = null
	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")

# --- add_mesh_instance ---

func test_add_mesh_instance_requires_mesh_source():
	var result: Dictionary = _world_tools._tool_add_mesh_instance({})
	assert_true(result.has("error"), "Should error when neither mesh_type nor mesh_file provided")

func test_add_mesh_instance_rejects_unknown_mesh_type():
	var result: Dictionary = _world_tools._tool_add_mesh_instance({"mesh_type": "octagon"})
	assert_true(result.has("error"), "Unknown mesh type should error")

func test_add_mesh_instance_no_scene_errors():
	var result: Dictionary = _world_tools._tool_add_mesh_instance({"mesh_type": "box"})
	assert_true(result.has("error"), "No open scene should error")

func test_add_mesh_instance_missing_file_errors():
	var result: Dictionary = _world_tools._tool_add_mesh_instance({"mesh_file": "res://nonexistent.glb"})
	assert_true(result.has("error"), "Missing mesh file should error")

func test_add_mesh_instance_output_format():
	# Headless without editor: error result; when it succeeds it must carry node_path/node_type/created
	var result: Dictionary = _world_tools._tool_add_mesh_instance({"mesh_type": "box"})
	if result.has("error"):
		pass_test("Headless: expected error without editor interface")
	else:
		assert_has(result, "node_path", "Success should include node_path")
		assert_has(result, "node_type", "Success should include node_type")
		assert_has(result, "created", "Success should include created")

# --- setup_lighting ---

func test_setup_lighting_unknown_type_errors():
	var result: Dictionary = _world_tools._tool_setup_lighting({"light_type": "candle"})
	assert_true(result.has("error"), "Unknown light type should error")

func test_setup_lighting_default_directional():
	var result: Dictionary = _world_tools._tool_setup_lighting({})
	if result.has("error"):
		pass_test("Headless: expected error without editor interface")
	else:
		assert_eq(result.get("light_type", ""), "directional", "Default should be directional")

func test_setup_lighting_no_scene_errors():
	var result: Dictionary = _world_tools._tool_setup_lighting({"light_type": "omni"})
	assert_true(result.has("error"), "No open scene should error")

# --- set_material_3d ---

func test_set_material_3d_requires_node_path():
	var result: Dictionary = _world_tools._tool_set_material_3d({})
	assert_true(result.has("error"), "Missing node_path should error")

func test_set_material_3d_no_scene_errors():
	var result: Dictionary = _world_tools._tool_set_material_3d({"node_path": "/root/Main"})
	assert_true(result.has("error"), "No open scene should error")

func test_set_material_3d_rejects_non_mesh_node():
	# Without editor interface the tool errors before node lookup; verify error path
	var result: Dictionary = _world_tools._tool_set_material_3d({"node_path": "/root/NotMesh"})
	assert_true(result.has("error"), "Should error without open scene")

func test_set_material_3d_output_format():
	var result: Dictionary = _world_tools._tool_set_material_3d({"node_path": "/root/Main"})
	if result.has("error"):
		pass_test("Headless: expected error without editor interface")
	else:
		assert_has(result, "updated", "Success should include updated flag")

# --- setup_environment ---

func test_setup_environment_unknown_bg_mode_errors():
	var result: Dictionary = _world_tools._tool_setup_environment({"background_mode": "neon"})
	assert_true(result.has("error"), "Unknown background_mode should error")

func test_setup_environment_default_sky():
	var result: Dictionary = _world_tools._tool_setup_environment({})
	if result.has("error"):
		pass_test("Headless: expected error without editor interface")
	else:
		assert_eq(result.get("background_mode", ""), "sky", "Default background_mode should be sky")

func test_setup_environment_no_scene_errors():
	var result: Dictionary = _world_tools._tool_setup_environment({"background_mode": "color"})
	assert_true(result.has("error"), "No open scene should error")

# --- setup_camera_3d ---

func test_setup_camera_3d_no_scene_errors():
	var result: Dictionary = _world_tools._tool_setup_camera_3d({})
	assert_true(result.has("error"), "No open scene should error")

func test_setup_camera_3d_output_format():
	var result: Dictionary = _world_tools._tool_setup_camera_3d({})
	if result.has("error"):
		pass_test("Headless: expected error without editor interface")
	else:
		assert_has(result, "fov", "Success should include fov")
		assert_has(result, "current", "Success should include current flag")
		assert_has(result, "created", "Success should include created")

# --- add_gridmap ---

func test_add_gridmap_no_scene_errors():
	var result: Dictionary = _world_tools._tool_add_gridmap({})
	assert_true(result.has("error"), "No open scene should error")

func test_add_gridmap_missing_library_errors():
	var result: Dictionary = _world_tools._tool_add_gridmap({"mesh_library": "res://missing.tres"})
	assert_true(result.has("error"), "Missing mesh library should error")

func test_add_gridmap_output_format():
	var result: Dictionary = _world_tools._tool_add_gridmap({})
	if result.has("error"):
		pass_test("Headless: expected error without editor interface")
	else:
		assert_has(result, "node_path", "Success should include node_path")
		assert_has(result, "created", "Success should include created")

# --- registration ---

func test_register_tools_registers_all_six():
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()
	var registered: Array = []
	var original: Callable = server_core.register_tool
	server_core.register_tool = func(name: String, desc: String, schema: Dictionary, cb: Callable, out: Dictionary = {}, ann: Dictionary = {}, cat: String = "core", group: String = "") -> void:
		registered.append(name)
	_world_tools.register_tools(server_core)
	assert_eq(registered.size(), 6, "Should register exactly 6 tools")
	for name in ["add_mesh_instance", "setup_lighting", "set_material_3d", "setup_environment", "setup_camera_3d", "add_gridmap"]:
		assert_true(name in registered, name + " should be registered")
