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
	assert_eq(registered.size(), 14, "Should register exactly 14 tools")
	for name in ["list_animations", "create_animation", "add_animation_track", "set_animation_keyframe", "get_animation_info", "remove_animation",
			"create_animation_tree", "get_animation_tree_structure", "add_state_machine_state", "remove_state_machine_state",
			"add_state_machine_transition", "remove_state_machine_transition", "set_blend_tree_node", "set_tree_parameter"]:
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
