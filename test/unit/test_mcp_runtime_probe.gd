extends "res://addons/gut/test.gd"

var _probe: Node = null

func before_each():
	_probe = load("res://addons/godot_mcp/runtime/mcp_runtime_probe.gd").new()
	add_child_autofree(_probe)

func after_each():
	_probe = null

func test_runtime_node_protection_accepts_active_probe():
	assert_true(_probe._is_protected_runtime_node(_probe), "The active runtime probe must be protected")

func test_runtime_node_protection_rejects_regular_node():
	var regular_node: Node = Node.new()
	add_child_autofree(regular_node)
	assert_false(_probe._is_protected_runtime_node(regular_node), "An ordinary runtime node must remain deletable")

func test_serialize_animation_tree_state_basic():
	var anim_tree := AnimationTree.new()
	add_child(anim_tree)
	anim_tree.active = false
	var result: Dictionary = _probe._serialize_animation_tree_state(anim_tree)
	assert_has(result, "node_path", "Result should have node_path")
	assert_has(result, "active", "Result should have active")
	assert_eq(result["active"], false, "active should be false")
	assert_has(result, "tree_root_type", "Result should have tree_root_type")
	assert_has(result, "has_playback", "Result should have has_playback")
	assert_has(result, "current_length", "Result should have current_length")
	assert_has(result, "current_position", "Result should have current_position")
	assert_has(result, "current_delta", "Result should have current_delta")
	remove_child(anim_tree)
	anim_tree.queue_free()

func test_serialize_animation_tree_state_float_values_are_float_type():
	var anim_tree := AnimationTree.new()
	add_child(anim_tree)
	anim_tree.active = false
	var result: Dictionary = _probe._serialize_animation_tree_state(anim_tree)
	assert_eq(typeof(result["current_length"]), TYPE_FLOAT, "current_length should be float type")
	assert_eq(typeof(result["current_position"]), TYPE_FLOAT, "current_position should be float type")
	assert_eq(typeof(result["current_delta"]), TYPE_FLOAT, "current_delta should be float type")
	remove_child(anim_tree)
	anim_tree.queue_free()

func test_serialize_animation_tree_state_with_active_tree():
	var anim_player := AnimationPlayer.new()
	var anim_library := AnimationLibrary.new()
	var anim := Animation.new()
	anim.length = 2.0
	anim_library.add_animation("test_anim", anim)
	anim_player.add_animation_library("", anim_library)
	add_child(anim_player)
	var anim_tree := AnimationTree.new()
	anim_tree.anim_player = anim_player.get_path()
	add_child(anim_tree)
	anim_tree.active = true
	await get_tree().process_frame
	var result: Dictionary = _probe._serialize_animation_tree_state(anim_tree)
	assert_has(result, "node_path", "Result should have node_path")
	assert_eq(result["active"], true, "active should be true")
	assert_eq(typeof(result["current_length"]), TYPE_FLOAT, "current_length should be float type")
	assert_eq(typeof(result["current_position"]), TYPE_FLOAT, "current_position should be float type")
	assert_eq(typeof(result["current_delta"]), TYPE_FLOAT, "current_delta should be float type")
	anim_tree.active = false
	remove_child(anim_tree)
	anim_tree.queue_free()
	remove_child(anim_player)
	anim_player.queue_free()

func test_serialize_animation_tree_state_no_tree_root():
	var anim_tree := AnimationTree.new()
	add_child(anim_tree)
	anim_tree.active = false
	var result: Dictionary = _probe._serialize_animation_tree_state(anim_tree)
	assert_eq(result["tree_root_type"], "", "tree_root_type should be empty string when no tree_root")
	remove_child(anim_tree)
	anim_tree.queue_free()

func test_serialize_animation_state_basic():
	var anim_player := AnimationPlayer.new()
	var anim_library := AnimationLibrary.new()
	var anim := Animation.new()
	anim.length = 1.5
	anim_library.add_animation("idle", anim)
	anim_player.add_animation_library("", anim_library)
	add_child(anim_player)
	anim_player.current_animation = "idle"
	anim_player.play()
	await get_tree().process_frame
	var result: Dictionary = _probe._serialize_animation_state(anim_player)
	assert_has(result, "node_path", "Result should have node_path")
	assert_eq(result["current_animation"], "idle", "current_animation should be idle")
	assert_eq(result["is_playing"], true, "is_playing should be true")
	assert_has(result, "current_position", "Result should have current_position")
	assert_has(result, "current_length", "Result should have current_length")
	anim_player.stop()
	remove_child(anim_player)
	anim_player.queue_free()

func test_serialize_animation_tree_state_with_state_machine():
	var anim_player := AnimationPlayer.new()
	var anim_library := AnimationLibrary.new()
	var anim := Animation.new()
	anim.length = 1.0
	anim_library.add_animation("idle", anim)
	anim_player.add_animation_library("", anim_library)
	add_child(anim_player)
	var anim_tree := AnimationTree.new()
	anim_tree.anim_player = anim_player.get_path()
	var sm := AnimationNodeStateMachine.new()
	var idle_node := AnimationNodeAnimation.new()
	idle_node.animation = "idle"
	sm.add_node("idle", idle_node)
	anim_tree.tree_root = sm
	anim_tree.active = true
	add_child(anim_tree)
	await get_tree().process_frame
	var result: Dictionary = _probe._serialize_animation_tree_state(anim_tree)
	assert_has(result, "node_path", "Result should have node_path")
	assert_eq(result["active"], true, "active should be true")
	assert_eq(result["tree_root_type"], "AnimationNodeStateMachine", "tree_root_type should be AnimationNodeStateMachine")
	assert_has(result, "has_playback", "Result should have has_playback")
	assert_eq(typeof(result["current_length"]), TYPE_FLOAT, "current_length should be float type")
	assert_eq(typeof(result["current_position"]), TYPE_FLOAT, "current_position should be float type")
	anim_tree.active = false
	remove_child(anim_tree)
	anim_tree.queue_free()
	remove_child(anim_player)
	anim_player.queue_free()

func test_serialize_animation_state_not_playing():
	var anim_player := AnimationPlayer.new()
	add_child(anim_player)
	var result: Dictionary = _probe._serialize_animation_state(anim_player)
	assert_eq(result["is_playing"], false, "is_playing should be false when not playing")
	assert_eq(result["current_animation"], "", "current_animation should be empty")
	remove_child(anim_player)
	anim_player.queue_free()
