extends "res://addons/gut/test.gd"

var _media_tools: RefCounted = null

func before_each() -> void:
	_media_tools = load("res://addons/godot_mcp/tools/media_tools_native.gd").new()

func after_each() -> void:
	_media_tools = null
	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")

# --- list_animations ---

func test_list_animations_requires_node_path():
	var result: Dictionary = _media_tools._tool_list_animations({})
	assert_true(result.has("error"), "Missing node_path should error")

func test_list_animations_no_player():
	var result: Dictionary = _media_tools._tool_list_animations({"node_path": "/root/Main"})
	assert_true(result.has("error"), "No AnimationPlayer should error")

# --- create_animation ---

func test_create_animation_requires_node_path():
	var result: Dictionary = _media_tools._tool_create_animation({})
	assert_true(result.has("error"), "Missing node_path should error")

func test_create_animation_requires_name():
	var result: Dictionary = _media_tools._tool_create_animation({"node_path": "/root/Main"})
	assert_true(result.has("error"), "Missing name should error")

func test_create_animation_no_player():
	var result: Dictionary = _media_tools._tool_create_animation({"node_path": "/root/Main", "name": "walk"})
	assert_true(result.has("error"), "No AnimationPlayer should error")

# --- add_animation_track ---

func test_add_animation_track_requires_params():
	var result: Dictionary = _media_tools._tool_add_animation_track({})
	assert_true(result.has("error"), "Missing params should error")

func test_add_animation_track_requires_track_path():
	var result: Dictionary = _media_tools._tool_add_animation_track({"node_path": "/root/Main", "animation": "walk"})
	assert_true(result.has("error"), "Missing track_path should error")

func test_add_animation_track_unknown_type():
	var result: Dictionary = _media_tools._tool_add_animation_track({"node_path": "/root/Main", "animation": "walk", "track_path": "Sprite2D:position", "track_type": "spline"})
	assert_true(result.has("error"), "Unknown track_type should error")

# --- set_animation_keyframe ---

func test_set_animation_keyframe_requires_params():
	var result: Dictionary = _media_tools._tool_set_animation_keyframe({})
	assert_true(result.has("error"), "Missing params should error")

func test_set_animation_keyframe_no_player():
	var result: Dictionary = _media_tools._tool_set_animation_keyframe({"node_path": "/root/Main", "animation": "walk", "track_index": 0, "time": 0.0, "value": 1.0})
	assert_true(result.has("error"), "No AnimationPlayer should error")

# --- get_animation_info ---

func test_get_animation_info_requires_params():
	var result: Dictionary = _media_tools._tool_get_animation_info({})
	assert_true(result.has("error"), "Missing params should error")

func test_get_animation_info_no_player():
	var result: Dictionary = _media_tools._tool_get_animation_info({"node_path": "/root/Main", "animation": "walk"})
	assert_true(result.has("error"), "No AnimationPlayer should error")

# --- remove_animation ---

func test_remove_animation_requires_params():
	var result: Dictionary = _media_tools._tool_remove_animation({})
	assert_true(result.has("error"), "Missing params should error")

func test_remove_animation_no_player():
	var result: Dictionary = _media_tools._tool_remove_animation({"node_path": "/root/Main", "name": "walk"})
	assert_true(result.has("error"), "No AnimationPlayer should error")

# --- key helpers ---

func test_find_animation_key_at_time_empty():
	var anim := Animation.new()
	assert_eq(_media_tools._find_animation_key_at_time(anim, 0, 0.0), -1, "Empty track should have no key")

func test_upsert_animation_key_inserts():
	var anim := Animation.new()
	anim.add_track(Animation.TYPE_VALUE, 0)
	_media_tools._upsert_animation_key(anim, 0, 0.5, 10.0, 1.0)
	assert_eq(anim.track_get_key_count(0), 1, "Should insert one key")
	assert_eq(anim.track_get_key_value(0, 0), 10.0, "Key value should be 10")

func test_upsert_animation_key_updates():
	var anim := Animation.new()
	anim.add_track(Animation.TYPE_VALUE, 0)
	anim.track_insert_key(0, 0.5, 1.0)
	_media_tools._upsert_animation_key(anim, 0, 0.5, 99.0, 1.0)
	assert_eq(anim.track_get_key_count(0), 1, "Should not add duplicate key")
	assert_eq(anim.track_get_key_value(0, 0), 99.0, "Should update value in place")

func test_restore_animation_key_removes_new():
	var anim := Animation.new()
	anim.add_track(Animation.TYPE_VALUE, 0)
	_media_tools._upsert_animation_key(anim, 0, 0.5, 10.0, 1.0)
	_media_tools._restore_animation_key(anim, 0, 0.5, false, null, 1.0)
	assert_eq(anim.track_get_key_count(0), 0, "Should remove key that did not exist before")

# --- registration ---

func test_register_tools_registers_all_six():
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()
	var registered: Array = []
	server_core.register_tool = func(name: String, desc: String, schema: Dictionary, cb: Callable, out: Dictionary = {}, ann: Dictionary = {}, cat: String = "core", group: String = "") -> void:
		registered.append(name)
	_media_tools.register_tools(server_core)
	assert_eq(registered.size(), 33, "Should register exactly 33 tools")
	for name in ["list_animations", "create_animation", "add_animation_track", "set_animation_keyframe", "get_animation_info", "remove_animation",
			"create_animation_tree", "get_animation_tree_structure", "add_state_machine_state", "remove_state_machine_state",
			"add_state_machine_transition", "remove_state_machine_transition", "set_blend_tree_node", "set_tree_parameter",
			"get_audio_bus_layout", "add_audio_bus", "set_audio_bus", "add_audio_bus_effect", "add_audio_player", "get_audio_info",
			"create_theme", "set_theme_color", "set_theme_constant", "set_theme_font_size", "set_theme_stylebox", "setup_control", "get_theme_info",
			"create_shader", "read_shader", "edit_shader", "assign_shader_material", "set_shader_param", "get_shader_params"]:
		assert_true(name in registered, name + " should be registered")

# --- AnimationTree (Batch 6) ---

func test_create_animation_tree_no_scene():
	var result: Dictionary = _media_tools._tool_create_animation_tree({})
	assert_true(result.has("error"), "No open scene should error")

func test_create_animation_tree_requires_node_path():
	var result: Dictionary = _media_tools._tool_create_animation_tree({})
	assert_true(result.has("error"), "Missing node_path should error")

func test_get_animation_tree_structure_requires_node_path():
	var result: Dictionary = _media_tools._tool_get_animation_tree_structure({})
	assert_true(result.has("error"), "Missing node_path should error")

func test_get_animation_tree_structure_no_tree():
	var result: Dictionary = _media_tools._tool_get_animation_tree_structure({"node_path": "/root/Main"})
	assert_true(result.has("error"), "No AnimationTree should error")

func test_add_state_machine_state_requires_params():
	var result: Dictionary = _media_tools._tool_add_state_machine_state({})
	assert_true(result.has("error"), "Missing params should error")

func test_add_state_machine_state_requires_name():
	var result: Dictionary = _media_tools._tool_add_state_machine_state({"node_path": "/root/Main"})
	assert_true(result.has("error"), "Missing state_name should error")

func test_add_state_machine_state_no_tree():
	var result: Dictionary = _media_tools._tool_add_state_machine_state({"node_path": "/root/Main", "state_name": "idle"})
	assert_true(result.has("error"), "No AnimationTree should error")

func test_add_state_machine_state_unknown_type():
	var result: Dictionary = _media_tools._tool_add_state_machine_state({"node_path": "/root/Main", "state_name": "idle", "state_type": "bezier"})
	assert_true(result.has("error"), "Unknown state_type should error")

func test_remove_state_machine_state_requires_params():
	var result: Dictionary = _media_tools._tool_remove_state_machine_state({})
	assert_true(result.has("error"), "Missing params should error")

func test_add_state_machine_transition_requires_params():
	var result: Dictionary = _media_tools._tool_add_state_machine_transition({})
	assert_true(result.has("error"), "Missing params should error")

func test_add_state_machine_transition_missing_from():
	var result: Dictionary = _media_tools._tool_add_state_machine_transition({"node_path": "/root/Main", "to_state": "walk"})
	assert_true(result.has("error"), "Missing from_state should error")

func test_remove_state_machine_transition_requires_params():
	var result: Dictionary = _media_tools._tool_remove_state_machine_transition({})
	assert_true(result.has("error"), "Missing params should error")

func test_set_blend_tree_node_requires_params():
	var result: Dictionary = _media_tools._tool_set_blend_tree_node({})
	assert_true(result.has("error"), "Missing params should error")

func test_set_blend_tree_node_unknown_type():
	var result: Dictionary = _media_tools._tool_set_blend_tree_node({"node_path": "/root/Main", "blend_tree_state": "bt", "bt_node_name": "n", "bt_node_type": "Warp"})
	assert_true(result.has("error"), "Unknown bt_node_type should error")

func test_set_tree_parameter_requires_params():
	var result: Dictionary = _media_tools._tool_set_tree_parameter({})
	assert_true(result.has("error"), "Missing params should error")

func test_set_tree_parameter_missing_value():
	var result: Dictionary = _media_tools._tool_set_tree_parameter({"node_path": "/root/Main", "parameter": "blend"})
	assert_true(result.has("error"), "Missing value should error")

func test_resolve_state_machine_wrong_root():
	var tree := AnimationTree.new()
	var blend := AnimationNodeBlendTree.new()
	tree.tree_root = blend
	var result: Array = _media_tools._resolve_state_machine(tree, "")
	assert_true(result[1] != null, "Non-state-machine root should error")
	tree.free()

# --- Audio (Batch 7) ---

func test_get_audio_bus_layout():
	var result: Dictionary = _media_tools._tool_get_audio_bus_layout({})
	assert_true(result.has("bus_count"), "Should return bus_count")
	assert_true(result.has("buses"), "Should return buses")
	assert_true(result["bus_count"] >= 1, "Default Master bus should exist")

func test_add_audio_bus_requires_name():
	var result: Dictionary = _media_tools._tool_add_audio_bus({})
	assert_true(result.has("error"), "Missing name should error")

func test_add_audio_bus_duplicate():
	# Adding same name twice should error on second call
	var first: Dictionary = _media_tools._tool_add_audio_bus({"name": "Music_Test"})
	if first.has("error"):
		pass_test("Bus may already exist from previous run")
	else:
		var second: Dictionary = _media_tools._tool_add_audio_bus({"name": "Music_Test"})
		assert_true(second.has("error"), "Duplicate bus name should error")
		# Cleanup: rename back to Master? AudioServer has no remove_bus; skip cleanup.

func test_set_audio_bus_requires_name():
	var result: Dictionary = _media_tools._tool_set_audio_bus({})
	assert_true(result.has("error"), "Missing name should error")

func test_set_audio_bus_unknown():
	var result: Dictionary = _media_tools._tool_set_audio_bus({"name": "NonExistent_XYZ"})
	assert_true(result.has("error"), "Unknown bus should error")

func test_set_audio_bus_master_volume():
	var result: Dictionary = _media_tools._tool_set_audio_bus({"name": "Master", "volume_db": -6.0})
	assert_false(result.has("error"), "Master bus should be settable")
	assert_eq(result.get("changes", 0), 1, "One change should be applied")

func test_add_audio_bus_effect_requires_params():
	var result: Dictionary = _media_tools._tool_add_audio_bus_effect({})
	assert_true(result.has("error"), "Missing params should error")

func test_add_audio_bus_effect_unknown_type():
	var result: Dictionary = _media_tools._tool_add_audio_bus_effect({"bus": "Master", "effect_type": "flanger"})
	assert_true(result.has("error"), "Unknown effect type should error")

func test_add_audio_bus_effect_unknown_bus():
	var result: Dictionary = _media_tools._tool_add_audio_bus_effect({"bus": "NonExistent_XYZ", "effect_type": "reverb"})
	assert_true(result.has("error"), "Unknown bus should error")

func test_add_audio_player_requires_params():
	var result: Dictionary = _media_tools._tool_add_audio_player({})
	assert_true(result.has("error"), "Missing params should error")

func test_add_audio_player_invalid_type():
	var result: Dictionary = _media_tools._tool_add_audio_player({"node_path": "/root/Main", "name": "P", "type": "AudioStreamPlayer4D"})
	assert_true(result.has("error"), "Invalid player type should error")

func test_get_audio_info_requires_node_path():
	var result: Dictionary = _media_tools._tool_get_audio_info({})
	assert_true(result.has("error"), "Missing node_path should error")

func test_get_effect_params_reverb():
	var effect := AudioEffectReverb.new()
	effect.room_size = 0.5
	var params: Dictionary = _media_tools._get_effect_params(effect)
	assert_true(params.has("room_size"), "Reverb params should include room_size")
	assert_eq(params["room_size"], 0.5, "room_size should round-trip")

# --- Theme/UI (Batch 8) ---

func test_create_theme_requires_path():
	var result: Dictionary = _media_tools._tool_create_theme({})
	assert_true(result.has("error"), "Missing path should error")

func test_create_theme_invalid_path():
	var result: Dictionary = _media_tools._tool_create_theme({"path": "C:/tmp/theme.tres"})
	assert_true(result.has("error"), "Non-res:// path should error")

func test_create_theme_wrong_extension():
	var result: Dictionary = _media_tools._tool_create_theme({"path": "res://theme.json"})
	assert_true(result.has("error"), "Non-.tres path should error")

func test_set_theme_color_requires_params():
	var result: Dictionary = _media_tools._tool_set_theme_color({})
	assert_true(result.has("error"), "Missing params should error")

func test_set_theme_color_requires_color():
	var result: Dictionary = _media_tools._tool_set_theme_color({"node_path": "/root/Main", "name": "font_color"})
	assert_true(result.has("error"), "Missing color should error")

func test_set_theme_color_not_control():
	var result: Dictionary = _media_tools._tool_set_theme_color({"node_path": "/root/Main", "name": "font_color", "color": "#ff0000"})
	assert_true(result.has("error"), "Non-Control node should error")

func test_set_theme_constant_requires_params():
	var result: Dictionary = _media_tools._tool_set_theme_constant({})
	assert_true(result.has("error"), "Missing params should error")

func test_set_theme_constant_requires_value():
	var result: Dictionary = _media_tools._tool_set_theme_constant({"node_path": "/root/Main", "name": "outline_size"})
	assert_true(result.has("error"), "Missing value should error")

func test_set_theme_font_size_requires_params():
	var result: Dictionary = _media_tools._tool_set_theme_font_size({})
	assert_true(result.has("error"), "Missing params should error")

func test_set_theme_font_size_not_control():
	var result: Dictionary = _media_tools._tool_set_theme_font_size({"node_path": "/root/Main", "name": "font_size"})
	assert_true(result.has("error"), "Non-Control node should error")

func test_set_theme_stylebox_requires_params():
	var result: Dictionary = _media_tools._tool_set_theme_stylebox({})
	assert_true(result.has("error"), "Missing params should error")

func test_set_theme_stylebox_not_control():
	var result: Dictionary = _media_tools._tool_set_theme_stylebox({"node_path": "/root/Main", "name": "panel"})
	assert_true(result.has("error"), "Non-Control node should error")

func test_setup_control_requires_node_path():
	var result: Dictionary = _media_tools._tool_setup_control({})
	assert_true(result.has("error"), "Missing node_path should error")

func test_setup_control_not_control():
	var result: Dictionary = _media_tools._tool_setup_control({"node_path": "/root/Main"})
	assert_true(result.has("error"), "Non-Control node should error")

func test_get_theme_info_requires_node_path():
	var result: Dictionary = _media_tools._tool_get_theme_info({})
	assert_true(result.has("error"), "Missing node_path should error")

func test_get_theme_info_not_control():
	var result: Dictionary = _media_tools._tool_get_theme_info({"node_path": "/root/Main"})
	assert_true(result.has("error"), "Non-Control node should error")

func test_validate_theme_path_valid():
	var validation: Dictionary = _media_tools._validate_theme_path("res://themes/my.tres")
	assert_true(validation.is_empty(), "Valid theme path should pass")

func test_validate_theme_path_invalid_extension():
	var validation: Dictionary = _media_tools._validate_theme_path("res://themes/my.json")
	assert_true(not validation.is_empty(), "Wrong extension should fail")

# --- Shader (Batch 9) ---

func test_create_shader_requires_path():
	var result: Dictionary = _media_tools._tool_create_shader({})
	assert_true(result.has("error"), "Missing path should error")

func test_create_shader_invalid_extension():
	var result: Dictionary = _media_tools._tool_create_shader({"path": "res://shader.txt"})
	assert_true(result.has("error"), "Non-.gdshader path should error")

func test_create_shader_unknown_type():
	var result: Dictionary = _media_tools._tool_create_shader({"path": "res://s.gdshader", "shader_type": "compute"})
	assert_true(result.has("error"), "Unknown shader_type should error")

func test_read_shader_requires_path():
	var result: Dictionary = _media_tools._tool_read_shader({})
	assert_true(result.has("error"), "Missing path should error")

func test_read_shader_invalid_extension():
	var result: Dictionary = _media_tools._tool_read_shader({"path": "res://s.txt"})
	assert_true(result.has("error"), "Non-.gdshader path should error")

func test_read_shader_not_found():
	var result: Dictionary = _media_tools._tool_read_shader({"path": "res://nonexistent.gdshader"})
	assert_true(result.has("error"), "Missing file should error")

func test_edit_shader_requires_path():
	var result: Dictionary = _media_tools._tool_edit_shader({})
	assert_true(result.has("error"), "Missing path should error")

func test_edit_shader_not_found():
	var result: Dictionary = _media_tools._tool_edit_shader({"path": "res://nonexistent.gdshader"})
	assert_true(result.has("error"), "Missing file should error")

func test_assign_shader_material_requires_params():
	var result: Dictionary = _media_tools._tool_assign_shader_material({})
	assert_true(result.has("error"), "Missing params should error")

func test_assign_shader_material_missing_shader():
	var result: Dictionary = _media_tools._tool_assign_shader_material({"node_path": "/root/Main"})
	assert_true(result.has("error"), "Missing shader_path should error")

func test_assign_shader_material_missing_file():
	var result: Dictionary = _media_tools._tool_assign_shader_material({"node_path": "/root/Main", "shader_path": "res://nonexistent.gdshader"})
	assert_true(result.has("error"), "Missing shader file should error")

func test_set_shader_param_requires_params():
	var result: Dictionary = _media_tools._tool_set_shader_param({})
	assert_true(result.has("error"), "Missing params should error")

func test_set_shader_param_missing_param():
	var result: Dictionary = _media_tools._tool_set_shader_param({"node_path": "/root/Main", "value": 1.0})
	assert_true(result.has("error"), "Missing param should error")

func test_get_shader_params_requires_node_path():
	var result: Dictionary = _media_tools._tool_get_shader_params({})
	assert_true(result.has("error"), "Missing node_path should error")

func test_is_shader_resource_path():
	assert_true(_media_tools._is_shader_resource_path("res://s.gdshader"), ".gdshader should be shader")
	assert_true(_media_tools._is_shader_resource_path("res://s.gdshaderinc"), ".gdshaderinc should be shader")
	assert_false(_media_tools._is_shader_resource_path("res://s.gd"), ".gd should not be shader")

func test_guard_shader_path_rejects_non_shader():
	var guard: Dictionary = _media_tools._guard_shader_path("res://s.gd", "create_shader")
	assert_true(not guard.is_empty(), "Non-shader path should be guarded")
