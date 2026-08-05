# media_tools_native.gd - Media Tools (Animation editing, Batch 5)
# Ported from godot-mcp-pro animation_commands.gd, adapted to native MCP
# registration pattern. Future batches (audio/theme/shader/tilemap) also
# live in this module per AGENTS.md.

@tool
class_name MediaToolsNative
extends RefCounted

var _editor_interface: EditorInterface = null

func initialize(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface

func _get_editor_interface() -> EditorInterface:
	if _editor_interface:
		return _editor_interface
	if Engine.has_meta("GodotMCPPlugin"):
		var plugin = Engine.get_meta("GodotMCPPlugin")
		if plugin and plugin.has_method("get_editor_interface"):
			return plugin.get_editor_interface()
	return null

func _get_user_scene_root() -> Node:
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return null
	return editor_interface.get_edited_scene_root()

func _resolve_node_path(node_path: String) -> Node:
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return null
	if node_path == "/root" or node_path.is_empty() or node_path == ".":
		return scene_root
	var relative: String = node_path.trim_prefix("/root/")
	if relative == scene_root.name:
		return scene_root
	if relative.begins_with(scene_root.name + "/"):
		relative = relative.substr(scene_root.name.length() + 1)
	return scene_root.get_node_or_null(relative)

func _find_animation_player(node_path: String) -> AnimationPlayer:
	var node: Node = _resolve_node_path(node_path)
	if node is AnimationPlayer:
		return node as AnimationPlayer
	return null

func _mark_scene_unsaved() -> void:
	var editor_interface: EditorInterface = _get_editor_interface()
	if editor_interface and editor_interface.has_method("mark_scene_as_unsaved"):
		editor_interface.mark_scene_as_unsaved()

func _set_node_property_with_undo(target: Node, property: String, new_value: Variant, action_name: String) -> void:
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		target.set(property, new_value)
		return
	var undo_redo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()
	var old_value: Variant = target.get(property)
	undo_redo.create_action(action_name)
	undo_redo.add_do_property(target, property, new_value)
	if new_value is Resource:
		undo_redo.add_do_reference(new_value)
	undo_redo.add_undo_property(target, property, old_value)
	if old_value is Resource:
		undo_redo.add_undo_reference(old_value)
	undo_redo.commit_action()
	editor_interface.mark_scene_as_unsaved()

# ============================================================================
# Tool registration
# ============================================================================

func register_tools(server_core: RefCounted) -> void:
	_register_list_animations(server_core)
	_register_create_animation(server_core)
	_register_add_animation_track(server_core)
	_register_set_animation_keyframe(server_core)
	_register_get_animation_info(server_core)
	_register_remove_animation(server_core)
	_register_create_animation_tree(server_core)
	_register_get_animation_tree_structure(server_core)
	_register_add_state_machine_state(server_core)
	_register_remove_state_machine_state(server_core)
	_register_add_state_machine_transition(server_core)
	_register_remove_state_machine_transition(server_core)
	_register_set_blend_tree_node(server_core)
	_register_set_tree_parameter(server_core)
	_register_get_audio_bus_layout(server_core)
	_register_add_audio_bus(server_core)
	_register_set_audio_bus(server_core)
	_register_add_audio_bus_effect(server_core)
	_register_add_audio_player(server_core)
	_register_get_audio_info(server_core)
	_register_create_theme(server_core)
	_register_set_theme_color(server_core)
	_register_set_theme_constant(server_core)
	_register_set_theme_font_size(server_core)
	_register_set_theme_stylebox(server_core)
	_register_setup_control(server_core)
	_register_get_theme_info(server_core)

# ============================================================================
# list_animations
# ============================================================================

func _register_list_animations(server_core: RefCounted) -> void:
	server_core.register_tool(
		"list_animations",
		"List all animations on an AnimationPlayer node with length, loop mode, and track count.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string", "description": "Path to the AnimationPlayer node."}
			},
			"required": ["node_path"],
			"additionalProperties": false
		},
		Callable(self, "_tool_list_animations"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"animations": {"type": "array"},
				"count": {"type": "integer"}
			}
		},
		{"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "Media-Animation"
	)

func _tool_list_animations(params: Dictionary) -> Dictionary:
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var player: AnimationPlayer = _find_animation_player(node_path)
	if not player:
		return {"error": "AnimationPlayer at '" + node_path + "' not found"}

	var animations: Array = []
	for anim_name in player.get_animation_list():
		var anim := player.get_animation(anim_name)
		animations.append({
			"name": anim_name,
			"length": anim.length,
			"loop_mode": anim.loop_mode,
			"track_count": anim.get_track_count(),
		})
	return {"node_path": node_path, "animations": animations, "count": animations.size()}

# ============================================================================
# create_animation
# ============================================================================

func _register_create_animation(server_core: RefCounted) -> void:
	server_core.register_tool(
		"create_animation",
		"Create a new animation on an AnimationPlayer node with length and loop mode.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string", "description": "Path to the AnimationPlayer node."},
				"name": {"type": "string", "description": "Animation name."},
				"length": {"type": "number", "description": "Animation length in seconds. Default 1.0."},
				"loop_mode": {"type": "integer", "description": "0=none, 1=linear, 2=pingpong. Default 0."}
			},
			"required": ["node_path", "name"],
			"additionalProperties": false
		},
		Callable(self, "_tool_create_animation"),
		{
			"type": "object",
			"properties": {
				"name": {"type": "string"},
				"length": {"type": "number"},
				"created": {"type": "boolean"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "Media-Animation"
	)

func _tool_create_animation(params: Dictionary) -> Dictionary:
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var anim_name: String = String(params.get("name", ""))
	if anim_name.is_empty():
		return {"error": "Missing required parameter: name"}
	var player: AnimationPlayer = _find_animation_player(node_path)
	if not player:
		return {"error": "AnimationPlayer at '" + node_path + "' not found"}

	var length: float = float(params.get("length", 1.0))
	var loop_mode: int = int(params.get("loop_mode", 0))
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = loop_mode as Animation.LoopMode

	var lib := player.get_animation_library("")
	var created_library := false
	if lib == null:
		lib = AnimationLibrary.new()
		created_library = true

	if lib.has_animation(anim_name):
		return {"error": "Animation '" + anim_name + "' already exists"}

	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	var undo_redo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("MCP: Create animation " + anim_name)
	if created_library:
		undo_redo.add_do_method(player, "add_animation_library", "", lib)
		undo_redo.add_do_reference(lib)
		undo_redo.add_undo_method(player, "remove_animation_library", "")
	undo_redo.add_do_method(lib, "add_animation", anim_name, anim)
	undo_redo.add_do_reference(anim)
	undo_redo.add_undo_method(lib, "remove_animation", anim_name)
	undo_redo.commit_action()
	editor_interface.mark_scene_as_unsaved()

	return {"name": anim_name, "length": length, "created": true}

# ============================================================================
# add_animation_track
# ============================================================================

func _register_add_animation_track(server_core: RefCounted) -> void:
	server_core.register_tool(
		"add_animation_track",
		"Add a track to an animation. Track types: value, position_2d, rotation_2d, scale_2d, method, bezier, blend_shape.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"animation": {"type": "string", "description": "Animation name."},
				"track_path": {"type": "string", "description": "Node path for the track, e.g. 'Sprite2D:position'."},
				"track_type": {"type": "string", "description": "value, position_2d, rotation_2d, scale_2d, method, bezier, or blend_shape. Default 'value'."},
				"update_mode": {"type": "string", "description": "For value tracks: continuous, discrete, or capture."}
			},
			"required": ["node_path", "animation", "track_path"],
			"additionalProperties": false
		},
		Callable(self, "_tool_add_animation_track"),
		{
			"type": "object",
			"properties": {
				"track_index": {"type": "integer"},
				"track_path": {"type": "string"},
				"track_type": {"type": "string"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "Media-Animation"
	)

func _tool_add_animation_track(params: Dictionary) -> Dictionary:
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var anim_name: String = String(params.get("animation", ""))
	if anim_name.is_empty():
		return {"error": "Missing required parameter: animation"}
	var track_path: String = String(params.get("track_path", ""))
	if track_path.is_empty():
		return {"error": "Missing required parameter: track_path"}
	var player: AnimationPlayer = _find_animation_player(node_path)
	if not player:
		return {"error": "AnimationPlayer at '" + node_path + "' not found"}
	var anim := player.get_animation(anim_name)
	if anim == null:
		return {"error": "Animation '" + anim_name + "' not found"}

	var track_type_str: String = String(params.get("track_type", "value"))
	var track_type: int
	match track_type_str:
		"value": track_type = Animation.TYPE_VALUE
		"position_2d": track_type = Animation.TYPE_POSITION_3D
		"rotation_2d": track_type = Animation.TYPE_ROTATION_3D
		"scale_2d": track_type = Animation.TYPE_SCALE_3D
		"method": track_type = Animation.TYPE_METHOD
		"bezier": track_type = Animation.TYPE_BEZIER
		"blend_shape": track_type = Animation.TYPE_BLEND_SHAPE
		_:
			return {"error": "Unknown track_type: '" + track_type_str + "'. Available: value, position_2d, rotation_2d, scale_2d, method, bezier, blend_shape"}

	var track_idx: int = anim.get_track_count()
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	var undo_redo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("MCP: Add animation track")
	undo_redo.add_do_method(anim, "add_track", track_type, track_idx)
	undo_redo.add_do_method(anim, "track_set_path", track_idx, NodePath(track_path))

	var update_mode_str: String = String(params.get("update_mode", ""))
	if not update_mode_str.is_empty() and track_type == Animation.TYPE_VALUE:
		match update_mode_str:
			"continuous":
				undo_redo.add_do_method(anim, "value_track_set_update_mode", track_idx, Animation.UPDATE_CONTINUOUS)
			"discrete":
				undo_redo.add_do_method(anim, "value_track_set_update_mode", track_idx, Animation.UPDATE_DISCRETE)
			"capture":
				undo_redo.add_do_method(anim, "value_track_set_update_mode", track_idx, Animation.UPDATE_CAPTURE)
	undo_redo.add_undo_method(anim, "remove_track", track_idx)
	undo_redo.commit_action()
	editor_interface.mark_scene_as_unsaved()

	return {"track_index": track_idx, "track_path": track_path, "track_type": track_type_str}

# ============================================================================
# set_animation_keyframe
# ============================================================================

func _register_set_animation_keyframe(server_core: RefCounted) -> void:
	server_core.register_tool(
		"set_animation_keyframe",
		"Insert or update a keyframe at a given time on an animation track.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"animation": {"type": "string"},
				"track_index": {"type": "integer", "description": "Track index. Default 0."},
				"time": {"type": "number", "description": "Keyframe time in seconds. Default 0."},
				"value": {"type": "object", "description": "Keyframe value (auto-parsed from strings like 'Vector2(100, 0)')."},
				"easing": {"type": "number", "description": "Easing value. Default 1.0."}
			},
			"required": ["node_path", "animation", "track_index", "time", "value"],
			"additionalProperties": false
		},
		Callable(self, "_tool_set_animation_keyframe"),
		{
			"type": "object",
			"properties": {
				"track_index": {"type": "integer"},
				"time": {"type": "number"},
				"key_index": {"type": "integer"},
				"easing": {"type": "number"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "Media-Animation"
	)

func _find_animation_key_at_time(anim: Animation, track_index: int, time: float) -> int:
	for key_index: int in anim.track_get_key_count(track_index):
		if is_equal_approx(anim.track_get_key_time(track_index, key_index), time):
			return key_index
	return -1

func _upsert_animation_key(anim: Animation, track_index: int, time: float, value: Variant, easing: float) -> void:
	var key_idx: int = _find_animation_key_at_time(anim, track_index, time)
	if key_idx < 0:
		key_idx = anim.track_insert_key(track_index, time, value)
	else:
		anim.track_set_key_value(track_index, key_idx, value)
	if easing != 1.0:
		anim.track_set_key_transition(track_index, key_idx, easing)

func _restore_animation_key(anim: Animation, track_index: int, time: float, had_old_key: bool, old_value: Variant, old_easing: float) -> void:
	var key_idx: int = _find_animation_key_at_time(anim, track_index, time)
	if had_old_key:
		if key_idx < 0:
			key_idx = anim.track_insert_key(track_index, time, old_value)
		else:
			anim.track_set_key_value(track_index, key_idx, old_value)
		anim.track_set_key_transition(track_index, key_idx, old_easing)
	elif key_idx >= 0:
		anim.track_remove_key(track_index, key_idx)

func _tool_set_animation_keyframe(params: Dictionary) -> Dictionary:
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var anim_name: String = String(params.get("animation", ""))
	if anim_name.is_empty():
		return {"error": "Missing required parameter: animation"}
	var player: AnimationPlayer = _find_animation_player(node_path)
	if not player:
		return {"error": "AnimationPlayer at '" + node_path + "' not found"}
	var anim := player.get_animation(anim_name)
	if anim == null:
		return {"error": "Animation '" + anim_name + "' not found"}

	var track_index: int = int(params.get("track_index", 0))
	if track_index < 0 or track_index >= anim.get_track_count():
		return {"error": "Invalid track_index: " + str(track_index)}

	var time: float = float(params.get("time", 0.0))
	var value: Variant = params.get("value", null)
	if value is String:
		var expr := Expression.new()
		if expr.parse(String(value)) == OK:
			var parsed: Variant = expr.execute()
			if parsed != null:
				value = parsed

	# Position/rotation/scale tracks map to Animation.TYPE_*_3D and require
	# Vector3 values; coerce Vector2 inputs to Vector3 (z=0) so 2D tweens
	# written as Vector2 still work on those tracks.
	if value is Vector2 and anim.get_track_count() > track_index:
		var track_type: int = anim.track_get_type(track_index)
		if track_type in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			var v2: Vector2 = value
			value = Vector3(v2.x, v2.y, 0.0)

	var easing: float = float(params.get("easing", 1.0))
	var old_key_idx: int = _find_animation_key_at_time(anim, track_index, time)
	var had_old_key: bool = old_key_idx >= 0
	var old_value: Variant = anim.track_get_key_value(track_index, old_key_idx) if had_old_key else null
	var old_easing: float = anim.track_get_key_transition(track_index, old_key_idx) if had_old_key else 1.0

	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	var undo_redo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("MCP: Set animation keyframe")
	# Execute do action synchronously so the key is present immediately;
	# add_do_method defers to commit but the animation may not be re-queried.
	_upsert_animation_key(anim, track_index, time, value, easing)
	undo_redo.add_do_method(self, "_upsert_animation_key", anim, track_index, time, value, easing)
	undo_redo.add_undo_method(self, "_restore_animation_key", anim, track_index, time, had_old_key, old_value, old_easing)
	undo_redo.commit_action()
	editor_interface.mark_scene_as_unsaved()

	var key_idx: int = _find_animation_key_at_time(anim, track_index, time)
	return {"track_index": track_index, "time": time, "key_index": key_idx, "easing": anim.track_get_key_transition(track_index, key_idx)}

# ============================================================================
# get_animation_info
# ============================================================================

func _register_get_animation_info(server_core: RefCounted) -> void:
	server_core.register_tool(
		"get_animation_info",
		"Read animation details: length, loop mode, step, and per-track keyframes.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"animation": {"type": "string"}
			},
			"required": ["node_path", "animation"],
			"additionalProperties": false
		},
		Callable(self, "_tool_get_animation_info"),
		{
			"type": "object",
			"properties": {
				"name": {"type": "string"},
				"length": {"type": "number"},
				"loop_mode": {"type": "integer"},
				"tracks": {"type": "array"}
			}
		},
		{"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "Media-Animation"
	)

func _tool_get_animation_info(params: Dictionary) -> Dictionary:
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var anim_name: String = String(params.get("animation", ""))
	if anim_name.is_empty():
		return {"error": "Missing required parameter: animation"}
	var player: AnimationPlayer = _find_animation_player(node_path)
	if not player:
		return {"error": "AnimationPlayer at '" + node_path + "' not found"}
	var anim := player.get_animation(anim_name)
	if anim == null:
		return {"error": "Animation '" + anim_name + "' not found"}

	var tracks: Array = []
	for i in anim.get_track_count():
		var track_info: Dictionary = {
			"index": i,
			"path": str(anim.track_get_path(i)),
			"type": anim.track_get_type(i),
			"key_count": anim.track_get_key_count(i),
		}
		var keys: Array = []
		for k in anim.track_get_key_count(i):
			keys.append({
				"time": anim.track_get_key_time(i, k),
				"value": str(anim.track_get_key_value(i, k)),
				"easing": anim.track_get_key_transition(i, k),
			})
		track_info["keys"] = keys
		tracks.append(track_info)

	return {
		"name": anim_name,
		"length": anim.length,
		"loop_mode": anim.loop_mode,
		"step": anim.step,
		"tracks": tracks,
	}

# ============================================================================
# remove_animation
# ============================================================================

func _register_remove_animation(server_core: RefCounted) -> void:
	server_core.register_tool(
		"remove_animation",
		"Remove an animation from an AnimationPlayer node (undoable).",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"name": {"type": "string", "description": "Animation name to remove."}
			},
			"required": ["node_path", "name"],
			"additionalProperties": false
		},
		Callable(self, "_tool_remove_animation"),
		{
			"type": "object",
			"properties": {
				"name": {"type": "string"},
				"removed": {"type": "boolean"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": true, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "Media-Animation"
	)

func _tool_remove_animation(params: Dictionary) -> Dictionary:
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var anim_name: String = String(params.get("name", ""))
	if anim_name.is_empty():
		return {"error": "Missing required parameter: name"}
	var player: AnimationPlayer = _find_animation_player(node_path)
	if not player:
		return {"error": "AnimationPlayer at '" + node_path + "' not found"}

	var lib := player.get_animation_library("")
	if lib == null or not lib.has_animation(anim_name):
		return {"error": "Animation '" + anim_name + "' not found"}

	var anim := lib.get_animation(anim_name)
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	var undo_redo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("MCP: Remove animation " + anim_name)
	undo_redo.add_do_method(lib, "remove_animation", anim_name)
	undo_redo.add_undo_method(lib, "add_animation", anim_name, anim)
	undo_redo.add_undo_reference(anim)
	undo_redo.commit_action()
	editor_interface.mark_scene_as_unsaved()
	return {"name": anim_name, "removed": true}

# ============================================================================
# AnimationTree tools (Batch 6)
# ============================================================================

func _find_animation_tree(node_path: String) -> AnimationTree:
	var node: Node = _resolve_node_path(node_path)
	if node is AnimationTree:
		return node as AnimationTree
	return null

func _resolve_state_machine(tree: AnimationTree, sm_path: String) -> Array:
	var root := tree.tree_root
	if not root is AnimationNodeStateMachine:
		return [null, {"error": "AnimationTree root is not an AnimationNodeStateMachine"}]
	if sm_path.is_empty() or sm_path == ".":
		return [root as AnimationNodeStateMachine, null]
	var current: AnimationNodeStateMachine = root as AnimationNodeStateMachine
	var parts: PackedStringArray = sm_path.split("/")
	for part in parts:
		if not current.has_node(StringName(part)):
			return [null, {"error": "State machine node '" + part + "' in path '" + sm_path + "' not found"}]
		var child: Variant = current.get_node(StringName(part))
		if not child is AnimationNodeStateMachine:
			return [null, {"error": "Node '" + part + "' is not a StateMachine"}]
		current = child as AnimationNodeStateMachine
	return [current, null]

func _resolve_blend_tree(tree: AnimationTree, sm_path: String, bt_name: String) -> Array:
	var result: Array = _resolve_state_machine(tree, sm_path)
	if result[1] != null:
		return result
	var sm: AnimationNodeStateMachine = result[0]
	if not sm.has_node(StringName(bt_name)):
		return [null, {"error": "BlendTree node '" + bt_name + "' not found"}]
	var node: Variant = sm.get_node(StringName(bt_name))
	if not node is AnimationNodeBlendTree:
		return [null, {"error": "Node '" + bt_name + "' is not an AnimationNodeBlendTree"}]
	return [node as AnimationNodeBlendTree, null]

func _get_sm_node_names(sm: AnimationNodeStateMachine) -> Array:
	var names: Array = []
	var prop_list: Array = sm.get_property_list()
	for prop: Dictionary in prop_list:
		var pname: String = prop["name"]
		if pname.begins_with("states/") and pname.ends_with("/node"):
			var state_name: String = pname.get_slice("/", 1)
			if state_name != "Start" and state_name != "End":
				names.append(state_name)
	return names

func _read_anim_node_structure(node: AnimationNode) -> Dictionary:
	if node is AnimationNodeStateMachine:
		return _read_state_machine_structure(node as AnimationNodeStateMachine)
	elif node is AnimationNodeBlendTree:
		return _read_blend_tree_structure(node as AnimationNodeBlendTree)
	elif node is AnimationNodeAnimation:
		return {"type": "AnimationNodeAnimation", "animation": str((node as AnimationNodeAnimation).animation)}
	return {"type": node.get_class()}

func _read_state_machine_structure(sm: AnimationNodeStateMachine) -> Dictionary:
	var states: Array = []
	var node_list: Array = _get_sm_node_names(sm)
	for state_name in node_list:
		var child: Variant = sm.get_node(StringName(state_name))
		var state_info: Dictionary = {
			"name": state_name,
			"position": {"x": sm.get_node_position(StringName(state_name)).x, "y": sm.get_node_position(StringName(state_name)).y},
		}
		state_info.merge(_read_anim_node_structure(child))
		states.append(state_info)
	var transitions: Array = []
	for i in sm.get_transition_count():
		var from_node: StringName = sm.get_transition_from(i)
		var to_node: StringName = sm.get_transition_to(i)
		var trans: AnimationNodeStateMachineTransition = sm.get_transition(i)
		var trans_info: Dictionary = {
			"from": str(from_node),
			"to": str(to_node),
			"switch_mode": trans.switch_mode,
			"advance_mode": trans.advance_mode,
		}
		if not trans.advance_expression.is_empty():
			trans_info["advance_expression"] = trans.advance_expression
		transitions.append(trans_info)
	return {
		"type": "AnimationNodeStateMachine",
		"states": states,
		"transitions": transitions,
	}

func _read_blend_tree_structure(bt: AnimationNodeBlendTree) -> Dictionary:
	var nodes_info: Array = []
	var prop_list: Array = bt.get_property_list()
	var node_names: Array = []
	for prop: Dictionary in prop_list:
		var pname: String = prop["name"]
		if pname.begins_with("nodes/") and pname.ends_with("/node"):
			var n: String = pname.get_slice("/", 1)
			if n != "output":
				node_names.append(n)
	for n_name in node_names:
		var child: Variant = bt.get_node(StringName(n_name))
		var node_info: Dictionary = {
			"name": n_name,
			"type": child.get_class(),
			"position": {"x": bt.get_node_position(StringName(n_name)).x, "y": bt.get_node_position(StringName(n_name)).y},
		}
		if child is AnimationNodeAnimation:
			node_info["animation"] = str((child as AnimationNodeAnimation).animation)
		nodes_info.append(node_info)
	return {"type": "AnimationNodeBlendTree", "nodes": nodes_info}

func _tool_create_animation_tree(params: Dictionary) -> Dictionary:
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var parent: Node = _resolve_node_path(node_path)
	if not parent:
		return {"error": "Node at '" + node_path + "' not found"}

	var anim_player_path: String = String(params.get("anim_player", ""))
	var tree_name: String = String(params.get("name", "AnimationTree"))
	var tree := AnimationTree.new()
	tree.name = tree_name
	var state_machine := AnimationNodeStateMachine.new()
	tree.tree_root = state_machine
	if not anim_player_path.is_empty():
		tree.anim_player = NodePath(anim_player_path)

	var error: Dictionary = _add_child_with_undo(parent, tree, scene_root, "MCP: Create AnimationTree")
	if not error.is_empty():
		return error

	return {
		"name": tree.name,
		"node_path": str(tree.get_path()),
		"root_type": "AnimationNodeStateMachine",
		"anim_player": anim_player_path,
		"created": true,
	}

func _add_child_with_undo(parent: Node, child: Node, root: Node, action_name: String) -> Dictionary:
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	var undo_redo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()
	undo_redo.create_action(action_name)
	undo_redo.add_do_method(parent, "add_child", child)
	undo_redo.add_do_method(child, "set_owner", root)
	undo_redo.add_do_reference(child)
	undo_redo.add_undo_method(parent, "remove_child", child)
	undo_redo.commit_action()
	editor_interface.mark_scene_as_unsaved()
	return {}

func _tool_get_animation_tree_structure(params: Dictionary) -> Dictionary:
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var tree: AnimationTree = _find_animation_tree(node_path)
	if tree == null:
		return {"error": "AnimationTree at '" + node_path + "' not found"}
	var root: Variant = tree.tree_root
	if root == null:
		return {"node_path": node_path, "root": null}
	var structure: Dictionary = _read_anim_node_structure(root)
	structure["active"] = tree.active
	structure["anim_player"] = str(tree.anim_player)
	structure["node_path"] = node_path
	return structure

func _tool_add_state_machine_state(params: Dictionary) -> Dictionary:
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var state_name: String = String(params.get("state_name", ""))
	if state_name.is_empty():
		return {"error": "Missing required parameter: state_name"}
	var tree: AnimationTree = _find_animation_tree(node_path)
	if tree == null:
		return {"error": "AnimationTree at '" + node_path + "' not found"}

	var sm_path: String = String(params.get("state_machine_path", ""))
	var sm_result: Array = _resolve_state_machine(tree, sm_path)
	if sm_result[1] != null:
		return sm_result[1]
	var sm: AnimationNodeStateMachine = sm_result[0]
	if sm.has_node(StringName(state_name)):
		return {"error": "State '" + state_name + "' already exists"}

	var state_type: String = String(params.get("state_type", "animation"))
	var position_x: float = float(params.get("position_x", 0.0))
	var position_y: float = float(params.get("position_y", 0.0))
	var position := Vector2(position_x, position_y)

	var node: AnimationNode
	match state_type:
		"animation":
			var anim_node := AnimationNodeAnimation.new()
			var anim_name: String = String(params.get("animation", ""))
			if not anim_name.is_empty():
				anim_node.animation = StringName(anim_name)
			node = anim_node
		"blend_tree":
			node = AnimationNodeBlendTree.new()
		"state_machine":
			node = AnimationNodeStateMachine.new()
		_:
			return {"error": "Unknown state_type: '" + state_type + "'. Use 'animation', 'blend_tree', or 'state_machine'"}

	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	var undo_redo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("MCP: Add state machine state")
	undo_redo.add_do_method(sm, "add_node", StringName(state_name), node, position)
	undo_redo.add_do_reference(node)
	undo_redo.add_undo_method(sm, "remove_node", StringName(state_name))
	undo_redo.commit_action()
	editor_interface.mark_scene_as_unsaved()

	return {"state_name": state_name, "state_type": state_type, "position": {"x": position_x, "y": position_y}, "added": true}

func _tool_remove_state_machine_state(params: Dictionary) -> Dictionary:
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var state_name: String = String(params.get("state_name", ""))
	if state_name.is_empty():
		return {"error": "Missing required parameter: state_name"}
	var tree: AnimationTree = _find_animation_tree(node_path)
	if tree == null:
		return {"error": "AnimationTree at '" + node_path + "' not found"}

	var sm_path: String = String(params.get("state_machine_path", ""))
	var sm_result: Array = _resolve_state_machine(tree, sm_path)
	if sm_result[1] != null:
		return sm_result[1]
	var sm: AnimationNodeStateMachine = sm_result[0]
	if not sm.has_node(StringName(state_name)):
		return {"error": "State '" + state_name + "' not found"}

	var old_node: Variant = sm.get_node(StringName(state_name))
	var old_position: Vector2 = sm.get_node_position(StringName(state_name))
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	var undo_redo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("MCP: Remove state machine state")
	undo_redo.add_do_method(sm, "remove_node", StringName(state_name))
	undo_redo.add_undo_method(sm, "add_node", StringName(state_name), old_node, old_position)
	undo_redo.add_undo_reference(old_node)
	undo_redo.commit_action()
	editor_interface.mark_scene_as_unsaved()

	return {"state_name": state_name, "removed": true}

func _tool_add_state_machine_transition(params: Dictionary) -> Dictionary:
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var from_state: String = String(params.get("from_state", ""))
	if from_state.is_empty():
		return {"error": "Missing required parameter: from_state"}
	var to_state: String = String(params.get("to_state", ""))
	if to_state.is_empty():
		return {"error": "Missing required parameter: to_state"}
	var tree: AnimationTree = _find_animation_tree(node_path)
	if tree == null:
		return {"error": "AnimationTree at '" + node_path + "' not found"}

	var sm_path: String = String(params.get("state_machine_path", ""))
	var sm_result: Array = _resolve_state_machine(tree, sm_path)
	if sm_result[1] != null:
		return sm_result[1]
	var sm: AnimationNodeStateMachine = sm_result[0]

	if from_state != "Start" and from_state != "End" and not sm.has_node(StringName(from_state)):
		return {"error": "State '" + from_state + "' not found"}
	if to_state != "Start" and to_state != "End" and not sm.has_node(StringName(to_state)):
		return {"error": "State '" + to_state + "' not found"}

	var transition := AnimationNodeStateMachineTransition.new()
	var switch_mode_str: String = String(params.get("switch_mode", "immediate"))
	match switch_mode_str:
		"at_end":
			transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
		"immediate":
			transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
		"sync":
			transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
		_:
			transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	var advance_mode_str: String = String(params.get("advance_mode", "enabled"))
	match advance_mode_str:
		"disabled":
			transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_DISABLED
		"enabled":
			transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
		"auto":
			transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
		_:
			transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
	var expression: String = String(params.get("advance_expression", ""))
	if not expression.is_empty():
		transition.advance_expression = expression
	if params.has("xfade_time"):
		transition.xfade_time = float(params["xfade_time"])

	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	var undo_redo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("MCP: Add state machine transition")
	undo_redo.add_do_method(sm, "add_transition", StringName(from_state), StringName(to_state), transition)
	undo_redo.add_do_reference(transition)
	undo_redo.add_undo_method(sm, "remove_transition", StringName(from_state), StringName(to_state))
	undo_redo.commit_action()
	editor_interface.mark_scene_as_unsaved()

	return {
		"from": from_state,
		"to": to_state,
		"switch_mode": switch_mode_str,
		"advance_mode": advance_mode_str,
		"advance_expression": expression,
		"added": true,
	}

func _tool_remove_state_machine_transition(params: Dictionary) -> Dictionary:
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var from_state: String = String(params.get("from_state", ""))
	if from_state.is_empty():
		return {"error": "Missing required parameter: from_state"}
	var to_state: String = String(params.get("to_state", ""))
	if to_state.is_empty():
		return {"error": "Missing required parameter: to_state"}
	var tree: AnimationTree = _find_animation_tree(node_path)
	if tree == null:
		return {"error": "AnimationTree at '" + node_path + "' not found"}

	var sm_path: String = String(params.get("state_machine_path", ""))
	var sm_result: Array = _resolve_state_machine(tree, sm_path)
	if sm_result[1] != null:
		return sm_result[1]
	var sm: AnimationNodeStateMachine = sm_result[0]

	var found := false
	var transition: AnimationNodeStateMachineTransition = null
	for i in sm.get_transition_count():
		if str(sm.get_transition_from(i)) == from_state and str(sm.get_transition_to(i)) == to_state:
			found = true
			transition = sm.get_transition(i)
			break
	if not found:
		return {"error": "Transition from '" + from_state + "' to '" + to_state + "' not found"}

	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	var undo_redo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("MCP: Remove state machine transition")
	undo_redo.add_do_method(sm, "remove_transition", StringName(from_state), StringName(to_state))
	undo_redo.add_undo_method(sm, "add_transition", StringName(from_state), StringName(to_state), transition)
	undo_redo.add_undo_reference(transition)
	undo_redo.commit_action()
	editor_interface.mark_scene_as_unsaved()

	return {"from": from_state, "to": to_state, "removed": true}

func _tool_set_blend_tree_node(params: Dictionary) -> Dictionary:
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var bt_state: String = String(params.get("blend_tree_state", ""))
	if bt_state.is_empty():
		return {"error": "Missing required parameter: blend_tree_state"}
	var bt_node_name: String = String(params.get("bt_node_name", ""))
	if bt_node_name.is_empty():
		return {"error": "Missing required parameter: bt_node_name"}
	var bt_node_type: String = String(params.get("bt_node_type", ""))
	if bt_node_type.is_empty():
		return {"error": "Missing required parameter: bt_node_type"}
	var tree: AnimationTree = _find_animation_tree(node_path)
	if tree == null:
		return {"error": "AnimationTree at '" + node_path + "' not found"}

	var sm_path: String = String(params.get("state_machine_path", ""))
	var bt_result: Array = _resolve_blend_tree(tree, sm_path, bt_state)
	if bt_result[1] != null:
		return bt_result[1]
	var bt: AnimationNodeBlendTree = bt_result[0]

	var position_x: float = float(params.get("position_x", 0.0))
	var position_y: float = float(params.get("position_y", 0.0))
	var position := Vector2(position_x, position_y)
	var had_old_node: bool = bt.has_node(StringName(bt_node_name))
	var old_node: AnimationNode = bt.get_node(StringName(bt_node_name)) if had_old_node else null
	var old_position: Vector2 = bt.get_node_position(StringName(bt_node_name)) if had_old_node else Vector2.ZERO

	var node: AnimationNode
	match bt_node_type:
		"Animation":
			var anim_node := AnimationNodeAnimation.new()
			var anim_name: String = String(params.get("animation", ""))
			if not anim_name.is_empty():
				anim_node.animation = StringName(anim_name)
			node = anim_node
		"Add2":
			node = AnimationNodeAdd2.new()
		"Blend2":
			node = AnimationNodeBlend2.new()
		"Add3":
			node = AnimationNodeAdd3.new()
		"Blend3":
			node = AnimationNodeBlend3.new()
		"TimeScale":
			node = AnimationNodeTimeScale.new()
		"TimeSeek":
			node = AnimationNodeTimeSeek.new()
		"Transition":
			node = AnimationNodeTransition.new()
		"OneShot":
			node = AnimationNodeOneShot.new()
		"Sub2":
			node = AnimationNodeSub2.new()
		_:
			return {"error": "Unknown bt_node_type: '" + bt_node_type + "'. Use: Animation, Add2, Blend2, Add3, Blend3, TimeScale, TimeSeek, Transition, OneShot, Sub2"}

	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	var undo_redo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("MCP: Set blend tree node")
	if had_old_node:
		undo_redo.add_do_method(bt, "remove_node", StringName(bt_node_name))
		undo_redo.add_undo_method(bt, "add_node", StringName(bt_node_name), old_node, old_position)
		undo_redo.add_undo_reference(old_node)
	undo_redo.add_do_method(bt, "add_node", StringName(bt_node_name), node, position)
	undo_redo.add_do_reference(node)
	undo_redo.add_undo_method(bt, "remove_node", StringName(bt_node_name))
	var connect_to: String = String(params.get("connect_to", ""))
	var connect_port: int = int(params.get("connect_port", 0))
	if not connect_to.is_empty():
		undo_redo.add_do_method(bt, "connect_node", StringName(connect_to), connect_port, StringName(bt_node_name))
	undo_redo.commit_action()
	editor_interface.mark_scene_as_unsaved()

	var connected_to_value: Variant = connect_to if not connect_to.is_empty() else null
	return {
		"blend_tree_state": bt_state,
		"bt_node_name": bt_node_name,
		"bt_node_type": bt_node_type,
		"position": {"x": position_x, "y": position_y},
		"connected_to": connected_to_value,
		"added": true,
	}

func _tool_set_tree_parameter(params: Dictionary) -> Dictionary:
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var parameter: String = String(params.get("parameter", ""))
	if parameter.is_empty():
		return {"error": "Missing required parameter: parameter"}
	var tree: AnimationTree = _find_animation_tree(node_path)
	if tree == null:
		return {"error": "AnimationTree at '" + node_path + "' not found"}
	if not params.has("value"):
		return {"error": "Missing required parameter: value"}
	var value: Variant = params["value"]
	if not parameter.begins_with("parameters/"):
		parameter = "parameters/" + parameter
	if value is String:
		var expr := Expression.new()
		if expr.parse(String(value)) == OK:
			var parsed: Variant = expr.execute()
			if parsed != null:
				value = parsed
	_set_node_property_with_undo(tree, parameter, value, "MCP: Set AnimationTree parameter")
	var actual: Variant = tree.get(parameter)
	return {"parameter": parameter, "value": str(actual), "set": true}

# ============================================================================
# Registration helpers (Batch 6 animation tree)
# ============================================================================

func _register_create_animation_tree(server_core: RefCounted) -> void:
	server_core.register_tool(
		"create_animation_tree",
		"Create an AnimationTree node with an AnimationNodeStateMachine root, optionally linked to an AnimationPlayer.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string", "description": "Parent node path."},
				"name": {"type": "string", "description": "AnimationTree node name. Default 'AnimationTree'."},
				"anim_player": {"type": "string", "description": "AnimationPlayer node path to link."}
			},
			"required": ["node_path"],
			"additionalProperties": false
		},
		Callable(self, "_tool_create_animation_tree"),
		{
			"type": "object",
			"properties": {
				"name": {"type": "string"},
				"node_path": {"type": "string"},
				"root_type": {"type": "string"},
				"created": {"type": "boolean"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "Media-Animation"
	)

func _register_get_animation_tree_structure(server_core: RefCounted) -> void:
	server_core.register_tool(
		"get_animation_tree_structure",
		"Read an AnimationTree structure: root node type, state machine states/transitions, or blend tree nodes.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"}
			},
			"required": ["node_path"],
			"additionalProperties": false
		},
		Callable(self, "_tool_get_animation_tree_structure"),
		{
			"type": "object",
			"properties": {
				"type": {"type": "string"},
				"states": {"type": "array"},
				"transitions": {"type": "array"},
				"active": {"type": "boolean"}
			}
		},
		{"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "Media-Animation"
	)

func _register_add_state_machine_state(server_core: RefCounted) -> void:
	server_core.register_tool(
		"add_state_machine_state",
		"Add a state to an AnimationNodeStateMachine. State types: animation, blend_tree, or state_machine.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"state_name": {"type": "string"},
				"state_machine_path": {"type": "string", "description": "Nested state machine path (slash-separated)."},
				"state_type": {"type": "string", "description": "animation, blend_tree, or state_machine. Default 'animation'."},
				"animation": {"type": "string", "description": "Animation name for animation states."},
				"position_x": {"type": "number"},
				"position_y": {"type": "number"}
			},
			"required": ["node_path", "state_name"],
			"additionalProperties": false
		},
		Callable(self, "_tool_add_state_machine_state"),
		{
			"type": "object",
			"properties": {
				"state_name": {"type": "string"},
				"state_type": {"type": "string"},
				"added": {"type": "boolean"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "Media-Animation"
	)

func _register_remove_state_machine_state(server_core: RefCounted) -> void:
	server_core.register_tool(
		"remove_state_machine_state",
		"Remove a state from an AnimationNodeStateMachine (undoable).",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"state_name": {"type": "string"},
				"state_machine_path": {"type": "string"}
			},
			"required": ["node_path", "state_name"],
			"additionalProperties": false
		},
		Callable(self, "_tool_remove_state_machine_state"),
		{
			"type": "object",
			"properties": {
				"state_name": {"type": "string"},
				"removed": {"type": "boolean"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": true, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "Media-Animation"
	)

func _register_add_state_machine_transition(server_core: RefCounted) -> void:
	server_core.register_tool(
		"add_state_machine_transition",
		"Add a transition between two states in an AnimationNodeStateMachine.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"from_state": {"type": "string"},
				"to_state": {"type": "string"},
				"state_machine_path": {"type": "string"},
				"switch_mode": {"type": "string", "description": "at_end, immediate, or sync. Default 'immediate'."},
				"advance_mode": {"type": "string", "description": "disabled, enabled, or auto. Default 'enabled'."},
				"advance_expression": {"type": "string"},
				"xfade_time": {"type": "number"}
			},
			"required": ["node_path", "from_state", "to_state"],
			"additionalProperties": false
		},
		Callable(self, "_tool_add_state_machine_transition"),
		{
			"type": "object",
			"properties": {
				"from": {"type": "string"},
				"to": {"type": "string"},
				"added": {"type": "boolean"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "Media-Animation"
	)

func _register_remove_state_machine_transition(server_core: RefCounted) -> void:
	server_core.register_tool(
		"remove_state_machine_transition",
		"Remove a transition between two states in an AnimationNodeStateMachine (undoable).",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"from_state": {"type": "string"},
				"to_state": {"type": "string"},
				"state_machine_path": {"type": "string"}
			},
			"required": ["node_path", "from_state", "to_state"],
			"additionalProperties": false
		},
		Callable(self, "_tool_remove_state_machine_transition"),
		{
			"type": "object",
			"properties": {
				"from": {"type": "string"},
				"to": {"type": "string"},
				"removed": {"type": "boolean"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": true, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "Media-Animation"
	)

func _register_set_blend_tree_node(server_core: RefCounted) -> void:
	server_core.register_tool(
		"set_blend_tree_node",
		"Add or replace a node inside an AnimationNodeBlendTree. Types: Animation, Add2, Blend2, Add3, Blend3, TimeScale, TimeSeek, Transition, OneShot, Sub2.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"blend_tree_state": {"type": "string", "description": "BlendTree node name inside the state machine."},
				"bt_node_name": {"type": "string"},
				"bt_node_type": {"type": "string"},
				"state_machine_path": {"type": "string"},
				"animation": {"type": "string", "description": "Animation name for Animation node type."},
				"position_x": {"type": "number"},
				"position_y": {"type": "number"},
				"connect_to": {"type": "string", "description": "Existing node to connect this node to."},
				"connect_port": {"type": "integer", "description": "Input port on connect_to. Default 0."}
			},
			"required": ["node_path", "blend_tree_state", "bt_node_name", "bt_node_type"],
			"additionalProperties": false
		},
		Callable(self, "_tool_set_blend_tree_node"),
		{
			"type": "object",
			"properties": {
				"bt_node_name": {"type": "string"},
				"bt_node_type": {"type": "string"},
				"added": {"type": "boolean"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "Media-Animation"
	)

func _register_set_tree_parameter(server_core: RefCounted) -> void:
	server_core.register_tool(
		"set_tree_parameter",
		"Set an AnimationTree parameter (auto-prefixed with 'parameters/').",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"parameter": {"type": "string", "description": "Parameter name, e.g. 'blend_amount'."},
				"value": {"type": "object", "description": "Parameter value (auto-parsed from strings)."}
			},
			"required": ["node_path", "parameter", "value"],
			"additionalProperties": false
		},
		Callable(self, "_tool_set_tree_parameter"),
		{
			"type": "object",
			"properties": {
				"parameter": {"type": "string"},
				"value": {"type": "string"},
				"set": {"type": "boolean"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "Media-Animation"
	)

# ============================================================================
# Audio tools (Batch 7)
# ============================================================================

func _get_effect_params(effect: AudioEffect) -> Dictionary:
	var params: Dictionary = {}
	if effect is AudioEffectReverb:
		var rev := effect as AudioEffectReverb
		params = {"room_size": rev.room_size, "damping": rev.damping, "wet": rev.wet, "dry": rev.dry, "spread": rev.spread}
	elif effect is AudioEffectDelay:
		var d := effect as AudioEffectDelay
		params = {"tap1_active": d.tap1_active, "tap1_delay_ms": d.tap1_delay_ms, "tap1_level_db": d.tap1_level_db, "tap2_active": d.tap2_active, "tap2_delay_ms": d.tap2_delay_ms, "tap2_level_db": d.tap2_level_db}
	elif effect is AudioEffectCompressor:
		var c := effect as AudioEffectCompressor
		params = {"threshold": c.threshold, "ratio": c.ratio, "attack_us": c.attack_us, "release_ms": c.release_ms, "gain": c.gain, "mix": c.mix, "sidechain": c.sidechain}
	elif effect is AudioEffectLimiter:
		var l := effect as AudioEffectLimiter
		params = {"ceiling_db": l.ceiling_db, "threshold_db": l.threshold_db, "soft_clip_db": l.soft_clip_db, "soft_clip_ratio": l.soft_clip_ratio}
	elif effect is AudioEffectDistortion:
		var dist := effect as AudioEffectDistortion
		params = {"mode": dist.mode, "pre_gain": dist.pre_gain, "post_gain": dist.post_gain, "keep_hf_hz": dist.keep_hf_hz, "drive": dist.drive}
	elif effect is AudioEffectChorus:
		var ch := effect as AudioEffectChorus
		params = {"voice_count": ch.voice_count, "dry": ch.dry, "wet": ch.wet}
	elif effect is AudioEffectPhaser:
		var ph := effect as AudioEffectPhaser
		params = {"range_min_hz": ph.range_min_hz, "range_max_hz": ph.range_max_hz, "rate_hz": ph.rate_hz, "feedback": ph.feedback, "depth": ph.depth}
	elif effect is AudioEffectFilter:
		var f := effect as AudioEffectFilter
		params = {"cutoff_hz": f.cutoff_hz, "resonance": f.resonance, "gain": f.gain, "db": f.db}
	elif effect is AudioEffectAmplify:
		var a := effect as AudioEffectAmplify
		params = {"volume_db": a.volume_db}
	return params

func _tool_get_audio_bus_layout(params: Dictionary) -> Dictionary:
	var buses: Array = []
	for i in range(AudioServer.bus_count):
		var bus_data: Dictionary = {
			"index": i,
			"name": AudioServer.get_bus_name(i),
			"volume_db": AudioServer.get_bus_volume_db(i),
			"solo": AudioServer.is_bus_solo(i),
			"mute": AudioServer.is_bus_mute(i),
			"bypass_effects": AudioServer.is_bus_bypassing_effects(i),
			"send": AudioServer.get_bus_send(i),
			"effects": [],
		}
		var effects: Array = []
		for j in range(AudioServer.get_bus_effect_count(i)):
			var effect: AudioEffect = AudioServer.get_bus_effect(i, j)
			var effect_data: Dictionary = {
				"index": j,
				"type": effect.get_class(),
				"enabled": AudioServer.is_bus_effect_enabled(i, j),
			}
			effect_data["params"] = _get_effect_params(effect)
			effects.append(effect_data)
		bus_data["effects"] = effects
		buses.append(bus_data)
	return {"bus_count": AudioServer.bus_count, "buses": buses}

func _tool_add_audio_bus(params: Dictionary) -> Dictionary:
	var bus_name: String = String(params.get("name", ""))
	if bus_name.is_empty():
		return {"error": "Missing required parameter: name"}
	for i in range(AudioServer.bus_count):
		if AudioServer.get_bus_name(i) == bus_name:
			return {"error": "Audio bus '" + bus_name + "' already exists at index " + str(i)}

	var at_position: int = int(params.get("at_position", -1))
	AudioServer.add_bus(at_position)
	var idx: int = AudioServer.bus_count - 1 if at_position < 0 else at_position
	AudioServer.set_bus_name(idx, bus_name)
	if params.has("volume_db"):
		AudioServer.set_bus_volume_db(idx, float(params["volume_db"]))
	var send: String = String(params.get("send", ""))
	if not send.is_empty():
		AudioServer.set_bus_send(idx, send)
	if params.has("solo"):
		AudioServer.set_bus_solo(idx, bool(params["solo"]))
	if params.has("mute"):
		AudioServer.set_bus_mute(idx, bool(params["mute"]))
	return {"name": bus_name, "index": idx, "bus_count": AudioServer.bus_count}

func _tool_set_audio_bus(params: Dictionary) -> Dictionary:
	var bus_name: String = String(params.get("name", ""))
	if bus_name.is_empty():
		return {"error": "Missing required parameter: name"}
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return {"error": "Audio bus '" + bus_name + "' not found"}

	var changes := 0
	if params.has("volume_db"):
		AudioServer.set_bus_volume_db(idx, float(params["volume_db"]))
		changes += 1
	if params.has("solo"):
		AudioServer.set_bus_solo(idx, bool(params["solo"]))
		changes += 1
	if params.has("mute"):
		AudioServer.set_bus_mute(idx, bool(params["mute"]))
		changes += 1
	if params.has("bypass_effects"):
		AudioServer.set_bus_bypass_effects(idx, bool(params["bypass_effects"]))
		changes += 1
	var send: String = String(params.get("send", ""))
	if not send.is_empty():
		AudioServer.set_bus_send(idx, send)
		changes += 1
	if params.has("rename"):
		var new_name: String = str(params["rename"])
		AudioServer.set_bus_name(idx, new_name)
		bus_name = new_name
		changes += 1
	return {"name": bus_name, "index": idx, "changes": changes}

func _tool_add_audio_bus_effect(params: Dictionary) -> Dictionary:
	var bus_name: String = String(params.get("bus", ""))
	if bus_name.is_empty():
		return {"error": "Missing required parameter: bus"}
	var effect_type: String = String(params.get("effect_type", ""))
	if effect_type.is_empty():
		return {"error": "Missing required parameter: effect_type"}
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return {"error": "Audio bus '" + bus_name + "' not found"}

	var effect: AudioEffect = null
	var effect_params: Dictionary = params.get("params", {}) if params.has("params") else {}

	match effect_type.to_lower():
		"reverb":
			var e := AudioEffectReverb.new()
			if effect_params.has("room_size"):
				e.room_size = float(effect_params["room_size"])
			if effect_params.has("damping"):
				e.damping = float(effect_params["damping"])
			if effect_params.has("wet"):
				e.wet = float(effect_params["wet"])
			if effect_params.has("dry"):
				e.dry = float(effect_params["dry"])
			if effect_params.has("spread"):
				e.spread = float(effect_params["spread"])
			effect = e
		"chorus":
			var e := AudioEffectChorus.new()
			if effect_params.has("voice_count"):
				e.voice_count = int(effect_params["voice_count"])
			if effect_params.has("dry"):
				e.dry = float(effect_params["dry"])
			if effect_params.has("wet"):
				e.wet = float(effect_params["wet"])
			effect = e
		"delay":
			var e := AudioEffectDelay.new()
			if effect_params.has("tap1_active"):
				e.tap1_active = bool(effect_params["tap1_active"])
			if effect_params.has("tap1_delay_ms"):
				e.tap1_delay_ms = float(effect_params["tap1_delay_ms"])
			if effect_params.has("tap1_level_db"):
				e.tap1_level_db = float(effect_params["tap1_level_db"])
			if effect_params.has("tap2_active"):
				e.tap2_active = bool(effect_params["tap2_active"])
			if effect_params.has("tap2_delay_ms"):
				e.tap2_delay_ms = float(effect_params["tap2_delay_ms"])
			if effect_params.has("tap2_level_db"):
				e.tap2_level_db = float(effect_params["tap2_level_db"])
			effect = e
		"compressor":
			var e := AudioEffectCompressor.new()
			if effect_params.has("threshold"):
				e.threshold = float(effect_params["threshold"])
			if effect_params.has("ratio"):
				e.ratio = float(effect_params["ratio"])
			if effect_params.has("attack_us"):
				e.attack_us = float(effect_params["attack_us"])
			if effect_params.has("release_ms"):
				e.release_ms = float(effect_params["release_ms"])
			if effect_params.has("gain"):
				e.gain = float(effect_params["gain"])
			if effect_params.has("mix"):
				e.mix = float(effect_params["mix"])
			effect = e
		"limiter":
			var e := AudioEffectLimiter.new()
			if effect_params.has("ceiling_db"):
				e.ceiling_db = float(effect_params["ceiling_db"])
			if effect_params.has("threshold_db"):
				e.threshold_db = float(effect_params["threshold_db"])
			if effect_params.has("soft_clip_db"):
				e.soft_clip_db = float(effect_params["soft_clip_db"])
			if effect_params.has("soft_clip_ratio"):
				e.soft_clip_ratio = float(effect_params["soft_clip_ratio"])
			effect = e
		"phaser":
			var e := AudioEffectPhaser.new()
			if effect_params.has("range_min_hz"):
				e.range_min_hz = float(effect_params["range_min_hz"])
			if effect_params.has("range_max_hz"):
				e.range_max_hz = float(effect_params["range_max_hz"])
			if effect_params.has("rate_hz"):
				e.rate_hz = float(effect_params["rate_hz"])
			if effect_params.has("feedback"):
				e.feedback = float(effect_params["feedback"])
			if effect_params.has("depth"):
				e.depth = float(effect_params["depth"])
			effect = e
		"distortion":
			var e := AudioEffectDistortion.new()
			if effect_params.has("mode"):
				e.mode = int(effect_params["mode"]) as AudioEffectDistortion.Mode
			if effect_params.has("pre_gain"):
				e.pre_gain = float(effect_params["pre_gain"])
			if effect_params.has("post_gain"):
				e.post_gain = float(effect_params["post_gain"])
			if effect_params.has("keep_hf_hz"):
				e.keep_hf_hz = float(effect_params["keep_hf_hz"])
			if effect_params.has("drive"):
				e.drive = float(effect_params["drive"])
			effect = e
		"lowpassfilter", "lowpass":
			var e := AudioEffectLowPassFilter.new()
			if effect_params.has("cutoff_hz"):
				e.cutoff_hz = float(effect_params["cutoff_hz"])
			if effect_params.has("resonance"):
				e.resonance = float(effect_params["resonance"])
			effect = e
		"highpassfilter", "highpass":
			var e := AudioEffectHighPassFilter.new()
			if effect_params.has("cutoff_hz"):
				e.cutoff_hz = float(effect_params["cutoff_hz"])
			if effect_params.has("resonance"):
				e.resonance = float(effect_params["resonance"])
			effect = e
		"bandpassfilter", "bandpass":
			var e := AudioEffectBandPassFilter.new()
			if effect_params.has("cutoff_hz"):
				e.cutoff_hz = float(effect_params["cutoff_hz"])
			if effect_params.has("resonance"):
				e.resonance = float(effect_params["resonance"])
			effect = e
		"amplify":
			var e := AudioEffectAmplify.new()
			if effect_params.has("volume_db"):
				e.volume_db = float(effect_params["volume_db"])
			effect = e
		"eq":
			effect = AudioEffectEQ.new()
		_:
			return {"error": "Unknown effect type: '" + effect_type + "'. Valid types: reverb, chorus, delay, compressor, limiter, phaser, distortion, lowpassfilter, highpassfilter, bandpassfilter, amplify, eq"}

	var at_position: int = int(params.get("at_position", -1))
	AudioServer.add_bus_effect(bus_idx, effect, at_position)
	var effect_idx: int = AudioServer.get_bus_effect_count(bus_idx) - 1 if at_position < 0 else at_position
	return {"bus": bus_name, "bus_index": bus_idx, "effect_type": effect.get_class(), "effect_index": effect_idx}

func _tool_add_audio_player(params: Dictionary) -> Dictionary:
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var player_name: String = String(params.get("name", ""))
	if player_name.is_empty():
		return {"error": "Missing required parameter: name"}
	var parent: Node = _resolve_node_path(node_path)
	if not parent:
		return {"error": "Node at '" + node_path + "' not found"}

	var player_type: String = String(params.get("type", "AudioStreamPlayer"))
	var valid_types: Array = ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]
	if player_type not in valid_types:
		return {"error": "Invalid player type '" + player_type + "'. Valid: " + ", ".join(valid_types)}

	var player: Node = null
	match player_type:
		"AudioStreamPlayer":
			player = AudioStreamPlayer.new()
		"AudioStreamPlayer2D":
			player = AudioStreamPlayer2D.new()
		"AudioStreamPlayer3D":
			player = AudioStreamPlayer3D.new()
	player.name = player_name

	var stream_path: String = String(params.get("stream", ""))
	if not stream_path.is_empty():
		if ResourceLoader.exists(stream_path):
			var stream: Resource = load(stream_path)
			if stream is AudioStream:
				player.set("stream", stream)
			else:
				player.free()
				return {"error": "Resource at '" + stream_path + "' is not an AudioStream"}
		else:
			player.free()
			return {"error": "Audio stream at '" + stream_path + "' not found"}

	if params.has("volume_db"):
		player.set("volume_db", float(params["volume_db"]))
	var bus: String = String(params.get("bus", ""))
	if not bus.is_empty():
		player.set("bus", bus)
	if params.has("autoplay"):
		player.set("autoplay", bool(params["autoplay"]))
	if player is AudioStreamPlayer2D:
		if params.has("max_distance"):
			(player as AudioStreamPlayer2D).max_distance = float(params["max_distance"])
		if params.has("attenuation"):
			(player as AudioStreamPlayer2D).attenuation = float(params["attenuation"])
	if player is AudioStreamPlayer3D:
		if params.has("max_distance"):
			(player as AudioStreamPlayer3D).max_distance = float(params["max_distance"])
		if params.has("attenuation_model"):
			(player as AudioStreamPlayer3D).attenuation_model = int(params["attenuation_model"]) as AudioStreamPlayer3D.AttenuationModel
		if params.has("unit_size"):
			(player as AudioStreamPlayer3D).unit_size = float(params["unit_size"])

	var error: Dictionary = _add_child_with_undo(parent, player, scene_root, "MCP: Add audio player")
	if not error.is_empty():
		return error

	return {
		"name": player_name,
		"type": player_type,
		"parent": node_path,
		"stream": stream_path,
		"bus": player.get("bus"),
		"volume_db": player.get("volume_db"),
		"autoplay": player.get("autoplay"),
	}

func _collect_audio_players(node: Node, result: Array) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		var info: Dictionary = {
			"name": node.name,
			"path": str(node.get_path()),
			"type": node.get_class(),
			"volume_db": node.get("volume_db"),
			"bus": node.get("bus"),
			"autoplay": node.get("autoplay"),
			"playing": node.get("playing"),
			"stream": "",
		}
		var stream: Variant = node.get("stream")
		if stream is AudioStream:
			info["stream"] = (stream as AudioStream).resource_path
		if node is AudioStreamPlayer2D:
			info["max_distance"] = (node as AudioStreamPlayer2D).max_distance
			info["attenuation"] = (node as AudioStreamPlayer2D).attenuation
		elif node is AudioStreamPlayer3D:
			info["max_distance"] = (node as AudioStreamPlayer3D).max_distance
			info["attenuation_model"] = (node as AudioStreamPlayer3D).attenuation_model
			info["unit_size"] = (node as AudioStreamPlayer3D).unit_size
		result.append(info)
	for child in node.get_children():
		_collect_audio_players(child, result)

func _tool_get_audio_info(params: Dictionary) -> Dictionary:
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var node: Node = _resolve_node_path(node_path)
	if not node:
		return {"error": "Node at '" + node_path + "' not found"}
	var players: Array = []
	_collect_audio_players(node, players)
	return {"node_path": node_path, "audio_player_count": players.size(), "players": players}

# ============================================================================
# Registration helpers (Batch 7 audio)
# ============================================================================

func _register_get_audio_bus_layout(server_core: RefCounted) -> void:
	server_core.register_tool(
		"get_audio_bus_layout",
		"Read the full AudioServer bus layout: names, volume, solo/mute, send, and per-bus effects with parameters.",
		{
			"type": "object",
			"properties": {},
			"additionalProperties": false
		},
		Callable(self, "_tool_get_audio_bus_layout"),
		{
			"type": "object",
			"properties": {
				"bus_count": {"type": "integer"},
				"buses": {"type": "array"}
			}
		},
		{"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "Media-Audio"
	)

func _register_add_audio_bus(server_core: RefCounted) -> void:
	server_core.register_tool(
		"add_audio_bus",
		"Add a new audio bus to the AudioServer with volume, send, solo, and mute settings.",
		{
			"type": "object",
			"properties": {
				"name": {"type": "string"},
				"at_position": {"type": "integer", "description": "Insert position. Default -1 (append)."},
				"volume_db": {"type": "number"},
				"send": {"type": "string"},
				"solo": {"type": "boolean"},
				"mute": {"type": "boolean"}
			},
			"required": ["name"],
			"additionalProperties": false
		},
		Callable(self, "_tool_add_audio_bus"),
		{
			"type": "object",
			"properties": {
				"name": {"type": "string"},
				"index": {"type": "integer"},
				"bus_count": {"type": "integer"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "Media-Audio"
	)

func _register_set_audio_bus(server_core: RefCounted) -> void:
	server_core.register_tool(
		"set_audio_bus",
		"Update audio bus properties: volume_db, solo, mute, bypass_effects, send, or rename.",
		{
			"type": "object",
			"properties": {
				"name": {"type": "string"},
				"volume_db": {"type": "number"},
				"solo": {"type": "boolean"},
				"mute": {"type": "boolean"},
				"bypass_effects": {"type": "boolean"},
				"send": {"type": "string"},
				"rename": {"type": "string"}
			},
			"required": ["name"],
			"additionalProperties": false
		},
		Callable(self, "_tool_set_audio_bus"),
		{
			"type": "object",
			"properties": {
				"name": {"type": "string"},
				"index": {"type": "integer"},
				"changes": {"type": "integer"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "Media-Audio"
	)

func _register_add_audio_bus_effect(server_core: RefCounted) -> void:
	server_core.register_tool(
		"add_audio_bus_effect",
		"Add an audio effect to a bus. Types: reverb, chorus, delay, compressor, limiter, phaser, distortion, lowpassfilter, highpassfilter, bandpassfilter, amplify, eq.",
		{
			"type": "object",
			"properties": {
				"bus": {"type": "string"},
				"effect_type": {"type": "string"},
				"params": {"type": "object", "description": "Effect-specific parameters."},
				"at_position": {"type": "integer"}
			},
			"required": ["bus", "effect_type"],
			"additionalProperties": false
		},
		Callable(self, "_tool_add_audio_bus_effect"),
		{
			"type": "object",
			"properties": {
				"bus": {"type": "string"},
				"effect_type": {"type": "string"},
				"effect_index": {"type": "integer"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "Media-Audio"
	)

func _register_add_audio_player(server_core: RefCounted) -> void:
	server_core.register_tool(
		"add_audio_player",
		"Add an AudioStreamPlayer, AudioStreamPlayer2D, or AudioStreamPlayer3D with stream, volume, bus, and spatial settings.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string", "description": "Parent node path."},
				"name": {"type": "string"},
				"type": {"type": "string", "description": "AudioStreamPlayer, AudioStreamPlayer2D, or AudioStreamPlayer3D."},
				"stream": {"type": "string", "description": "Audio stream resource path."},
				"volume_db": {"type": "number"},
				"bus": {"type": "string"},
				"autoplay": {"type": "boolean"},
				"max_distance": {"type": "number"},
				"attenuation": {"type": "number"},
				"unit_size": {"type": "number"}
			},
			"required": ["node_path", "name"],
			"additionalProperties": false
		},
		Callable(self, "_tool_add_audio_player"),
		{
			"type": "object",
			"properties": {
				"name": {"type": "string"},
				"type": {"type": "string"},
				"stream": {"type": "string"},
				"bus": {"type": "string"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "Media-Audio"
	)

func _register_get_audio_info(server_core: RefCounted) -> void:
	server_core.register_tool(
		"get_audio_info",
		"List audio players under a node with stream, volume, bus, autoplay, and spatial properties.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"}
			},
			"required": ["node_path"],
			"additionalProperties": false
		},
		Callable(self, "_tool_get_audio_info"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"audio_player_count": {"type": "integer"},
				"players": {"type": "array"}
			}
		},
		{"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "Media-Audio"
	)

# ============================================================================
# Theme/UI tools (Batch 8)
# ============================================================================

func _tool_create_theme(params: Dictionary) -> Dictionary:
	var path: String = String(params.get("path", ""))
	if path.is_empty():
		return {"error": "Missing required parameter: path"}
	var validation: Dictionary = _validate_theme_path(path)
	if not validation.is_empty():
		return validation

	var theme := Theme.new()
	var font_size: int = int(params.get("default_font_size", 0))
	if font_size > 0:
		theme.default_font_size = font_size

	var dir_path: String = path.get_base_dir()
	if not dir_path.is_empty() and not DirAccess.dir_exists_absolute(dir_path):
		var derr: Error = DirAccess.make_dir_recursive_absolute(dir_path)
		if derr != OK:
			return {"error": "Cannot create directory '" + dir_path + "': " + error_string(derr)}

	var err: Error = ResourceSaver.save(theme, path)
	if err != OK:
		return {"error": "Failed to save theme: " + error_string(err)}

	var editor_interface: EditorInterface = _get_editor_interface()
	if editor_interface:
		editor_interface.get_resource_filesystem().scan()
	return {"path": path, "created": true}

func _validate_theme_path(path: String) -> Dictionary:
	if not path.begins_with("res://"):
		return {"error": "Invalid theme path (must be res://): " + path}
	if path.get_extension().to_lower() != "tres":
		return {"error": "Theme path must end with .tres"}
	return {}

func _resolve_control_node(node_path: String) -> Control:
	var node: Node = _resolve_node_path(node_path)
	if node is Control:
		return node as Control
	return null

func _restore_theme_override(control: Control, kind: String, override_name: String, had_old: bool, old_value: Variant) -> void:
	match kind:
		"color":
			if had_old:
				control.add_theme_color_override(override_name, old_value)
			else:
				control.remove_theme_color_override(override_name)
		"constant":
			if had_old:
				control.add_theme_constant_override(override_name, old_value)
			else:
				control.remove_theme_constant_override(override_name)
		"font_size":
			if had_old:
				control.add_theme_font_size_override(override_name, old_value)
			else:
				control.remove_theme_font_size_override(override_name)
		"stylebox":
			if had_old:
				control.add_theme_stylebox_override(override_name, old_value)
			else:
				control.remove_theme_stylebox_override(override_name)

func _tool_set_theme_color(params: Dictionary) -> Dictionary:
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var color_name: String = String(params.get("name", ""))
	if color_name.is_empty():
		return {"error": "Missing required parameter: name"}
	var color_str: String = String(params.get("color", ""))
	if color_str.is_empty():
		return {"error": "Missing required parameter: color"}
	var control: Control = _resolve_control_node(node_path)
	if not control:
		return {"error": "Control node at '" + node_path + "' not found"}
	var color := Color(color_str)

	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	var had_old: bool = control.has_theme_color_override(color_name)
	var old_value: Variant = control.get("theme_override_colors/" + color_name) if had_old else null
	var undo_redo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("MCP: Set theme color override")
	undo_redo.add_do_method(control, "add_theme_color_override", color_name, color)
	undo_redo.add_undo_method(self, "_restore_theme_override", control, "color", color_name, had_old, old_value)
	undo_redo.commit_action()
	editor_interface.mark_scene_as_unsaved()
	return {"node_path": node_path, "name": color_name, "color": color_str}

func _tool_set_theme_constant(params: Dictionary) -> Dictionary:
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var const_name: String = String(params.get("name", ""))
	if const_name.is_empty():
		return {"error": "Missing required parameter: name"}
	var control: Control = _resolve_control_node(node_path)
	if not control:
		return {"error": "Control node at '" + node_path + "' not found"}
	var value: int = int(params.get("value", 0))

	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	var had_old: bool = control.has_theme_constant_override(const_name)
	var old_value: Variant = control.get("theme_override_constants/" + const_name) if had_old else null
	var undo_redo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("MCP: Set theme constant override")
	undo_redo.add_do_method(control, "add_theme_constant_override", const_name, value)
	undo_redo.add_undo_method(self, "_restore_theme_override", control, "constant", const_name, had_old, old_value)
	undo_redo.commit_action()
	editor_interface.mark_scene_as_unsaved()
	return {"node_path": node_path, "name": const_name, "value": value}

func _tool_set_theme_font_size(params: Dictionary) -> Dictionary:
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var font_name: String = String(params.get("name", ""))
	if font_name.is_empty():
		return {"error": "Missing required parameter: name"}
	var control: Control = _resolve_control_node(node_path)
	if not control:
		return {"error": "Control node at '" + node_path + "' not found"}
	var size: int = int(params.get("size", 16))

	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	var had_old: bool = control.has_theme_font_size_override(font_name)
	var old_value: Variant = control.get("theme_override_font_sizes/" + font_name) if had_old else null
	var undo_redo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("MCP: Set theme font size override")
	undo_redo.add_do_method(control, "add_theme_font_size_override", font_name, size)
	undo_redo.add_undo_method(self, "_restore_theme_override", control, "font_size", font_name, had_old, old_value)
	undo_redo.commit_action()
	editor_interface.mark_scene_as_unsaved()
	return {"node_path": node_path, "name": font_name, "size": size}

func _tool_set_theme_stylebox(params: Dictionary) -> Dictionary:
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var style_name: String = String(params.get("name", ""))
	if style_name.is_empty():
		return {"error": "Missing required parameter: name"}
	var control: Control = _resolve_control_node(node_path)
	if not control:
		return {"error": "Control node at '" + node_path + "' not found"}

	var stylebox := StyleBoxFlat.new()
	var bg_color: String = String(params.get("bg_color", ""))
	if not bg_color.is_empty():
		stylebox.bg_color = Color(bg_color)
	var border_color: String = String(params.get("border_color", ""))
	if not border_color.is_empty():
		stylebox.border_color = Color(border_color)
	var border_width: int = int(params.get("border_width", 0))
	if border_width > 0:
		stylebox.border_width_left = border_width
		stylebox.border_width_top = border_width
		stylebox.border_width_right = border_width
		stylebox.border_width_bottom = border_width
	var corner_radius: int = int(params.get("corner_radius", 0))
	if corner_radius > 0:
		stylebox.corner_radius_top_left = corner_radius
		stylebox.corner_radius_top_right = corner_radius
		stylebox.corner_radius_bottom_left = corner_radius
		stylebox.corner_radius_bottom_right = corner_radius
	var padding: int = int(params.get("padding", 0))
	if padding > 0:
		stylebox.content_margin_left = padding
		stylebox.content_margin_top = padding
		stylebox.content_margin_right = padding
		stylebox.content_margin_bottom = padding

	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	var had_old: bool = control.has_theme_stylebox_override(style_name)
	var old_value: Variant = control.get("theme_override_styles/" + style_name) if had_old else null
	var undo_redo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("MCP: Set theme stylebox override")
	undo_redo.add_do_method(control, "add_theme_stylebox_override", style_name, stylebox)
	undo_redo.add_do_reference(stylebox)
	undo_redo.add_undo_method(self, "_restore_theme_override", control, "stylebox", style_name, had_old, old_value)
	if old_value is Resource:
		undo_redo.add_undo_reference(old_value)
	undo_redo.commit_action()
	editor_interface.mark_scene_as_unsaved()
	return {"node_path": node_path, "name": style_name, "type": "StyleBoxFlat"}

func _capture_control_setup_state(control: Control) -> Dictionary:
	var state: Dictionary = {"properties": {}, "theme_constants": {}}
	for property: String in [
		"anchor_left", "anchor_top", "anchor_right", "anchor_bottom",
		"offset_left", "offset_top", "offset_right", "offset_bottom",
		"custom_minimum_size", "size_flags_horizontal", "size_flags_vertical",
		"grow_horizontal", "grow_vertical",
	]:
		state["properties"][property] = control.get(property)
	for constant_name: String in ["margin_left", "margin_top", "margin_right", "margin_bottom", "separation"]:
		var had_override: bool = control.has_theme_constant_override(constant_name)
		state["theme_constants"][constant_name] = {
			"had": had_override,
			"value": control.get("theme_override_constants/" + constant_name) if had_override else null,
		}
	return state

func _register_control_setup_undo(control: Control, old_state: Dictionary, new_state: Dictionary) -> void:
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return
	var undo_redo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("MCP: Setup Control")
	for property: String in new_state["properties"]:
		undo_redo.add_do_property(control, property, new_state["properties"][property])
		undo_redo.add_undo_property(control, property, old_state["properties"][property])
	for constant_name: String in new_state["theme_constants"]:
		var new_constant: Dictionary = new_state["theme_constants"][constant_name]
		var old_constant: Dictionary = old_state["theme_constants"][constant_name]
		undo_redo.add_do_method(self, "_restore_theme_override", control, "constant", constant_name, new_constant["had"], new_constant["value"])
		undo_redo.add_undo_method(self, "_restore_theme_override", control, "constant", constant_name, old_constant["had"], old_constant["value"])
	undo_redo.commit_action()
	editor_interface.mark_scene_as_unsaved()

func _tool_setup_control(params: Dictionary) -> Dictionary:
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var control: Control = _resolve_control_node(node_path)
	if not control:
		return {"error": "Control node at '" + node_path + "' not found"}

	var applied: Array = []
	var old_state: Dictionary = _capture_control_setup_state(control)
	var target: Control = control.duplicate() as Control

	var anchor_preset: String = String(params.get("anchor_preset", ""))
	if not anchor_preset.is_empty():
		var preset_map: Dictionary = {
			"top_left": Control.PRESET_TOP_LEFT,
			"top_right": Control.PRESET_TOP_RIGHT,
			"bottom_left": Control.PRESET_BOTTOM_LEFT,
			"bottom_right": Control.PRESET_BOTTOM_RIGHT,
			"center_left": Control.PRESET_CENTER_LEFT,
			"center_top": Control.PRESET_CENTER_TOP,
			"center_right": Control.PRESET_CENTER_RIGHT,
			"center_bottom": Control.PRESET_CENTER_BOTTOM,
			"center": Control.PRESET_CENTER,
			"left_wide": Control.PRESET_LEFT_WIDE,
			"top_wide": Control.PRESET_TOP_WIDE,
			"right_wide": Control.PRESET_RIGHT_WIDE,
			"bottom_wide": Control.PRESET_BOTTOM_WIDE,
			"vcenter_wide": Control.PRESET_VCENTER_WIDE,
			"hcenter_wide": Control.PRESET_HCENTER_WIDE,
			"full_rect": Control.PRESET_FULL_RECT,
		}
		if preset_map.has(anchor_preset):
			target.set_anchors_and_offsets_preset(preset_map[anchor_preset])
			applied.append("anchor_preset=" + anchor_preset)

	var min_size_str: String = String(params.get("min_size", ""))
	if not min_size_str.is_empty():
		var expr := Expression.new()
		if expr.parse(min_size_str) == OK:
			var val: Variant = expr.execute()
			if val is Vector2:
				target.custom_minimum_size = val
				applied.append("min_size=" + min_size_str)

	var flags_map: Dictionary = {
		"fill": Control.SIZE_FILL,
		"expand": Control.SIZE_EXPAND,
		"fill_expand": Control.SIZE_EXPAND_FILL,
		"shrink_center": Control.SIZE_SHRINK_CENTER,
		"shrink_end": Control.SIZE_SHRINK_END,
	}
	var sf_h: String = String(params.get("size_flags_h", ""))
	if not sf_h.is_empty() and flags_map.has(sf_h):
		target.size_flags_horizontal = flags_map[sf_h]
		applied.append("size_flags_h=" + sf_h)
	var sf_v: String = String(params.get("size_flags_v", ""))
	if not sf_v.is_empty() and flags_map.has(sf_v):
		target.size_flags_vertical = flags_map[sf_v]
		applied.append("size_flags_v=" + sf_v)

	if params.has("margins") and params["margins"] is Dictionary:
		var margins: Dictionary = params["margins"]
		if target is MarginContainer:
			if margins.has("left"):
				target.add_theme_constant_override("margin_left", int(margins["left"]))
			if margins.has("top"):
				target.add_theme_constant_override("margin_top", int(margins["top"]))
			if margins.has("right"):
				target.add_theme_constant_override("margin_right", int(margins["right"]))
			if margins.has("bottom"):
				target.add_theme_constant_override("margin_bottom", int(margins["bottom"]))
			applied.append("margins=" + str(margins))

	if params.has("separation"):
		var sep: int = int(params["separation"])
		if target is BoxContainer:
			target.add_theme_constant_override("separation", sep)
			applied.append("separation=" + str(sep))

	var grow_map: Dictionary = {
		"begin": Control.GROW_DIRECTION_BEGIN,
		"end": Control.GROW_DIRECTION_END,
		"both": Control.GROW_DIRECTION_BOTH,
	}
	var grow_h: String = String(params.get("grow_h", ""))
	if not grow_h.is_empty() and grow_map.has(grow_h):
		target.grow_horizontal = grow_map[grow_h]
		applied.append("grow_h=" + grow_h)
	var grow_v: String = String(params.get("grow_v", ""))
	if not grow_v.is_empty() and grow_map.has(grow_v):
		target.grow_vertical = grow_map[grow_v]
		applied.append("grow_v=" + grow_v)

	if not applied.is_empty():
		var new_state: Dictionary = _capture_control_setup_state(target)
		_register_control_setup_undo(control, old_state, new_state)
	target.free()
	return {"node_path": node_path, "applied": applied, "count": applied.size()}

func _tool_get_theme_info(params: Dictionary) -> Dictionary:
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var control: Control = _resolve_control_node(node_path)
	if not control:
		return {"error": "Control node at '" + node_path + "' not found"}

	var info: Dictionary = {"node_path": node_path, "class": control.get_class()}
	var theme: Theme = control.theme
	if theme:
		info["theme_path"] = theme.resource_path
		info["type_list"] = Array(theme.get_type_list())

	var overrides: Dictionary = {"colors": {}, "constants": {}, "font_sizes": {}, "styleboxes": {}}
	for prop: Dictionary in control.get_property_list():
		var pname: String = prop["name"]
		if pname.begins_with("theme_override_colors/"):
			var key: String = pname.substr(22)
			var color_val: Variant = control.get(pname)
			overrides["colors"][key] = "#" + (color_val as Color).to_html() if color_val is Color else str(color_val)
		elif pname.begins_with("theme_override_constants/"):
			var key: String = pname.substr(25)
			overrides["constants"][key] = control.get(pname)
		elif pname.begins_with("theme_override_font_sizes/"):
			var key: String = pname.substr(26)
			overrides["font_sizes"][key] = control.get(pname)
		elif pname.begins_with("theme_override_styles/"):
			var key: String = pname.substr(22)
			var style: Variant = control.get(pname)
			overrides["styleboxes"][key] = style.get_class() if style else null

	info["overrides"] = overrides
	return info

# ============================================================================
# Registration helpers (Batch 8 theme)
# ============================================================================

func _register_create_theme(server_core: RefCounted) -> void:
	server_core.register_tool(
		"create_theme",
		"Create a new Theme resource (.tres) with an optional default font size.",
		{
			"type": "object",
			"properties": {
				"path": {"type": "string", "description": "Theme resource path (res://..., .tres)."},
				"default_font_size": {"type": "integer", "description": "Default font size. Default 0 (unset)."}
			},
			"required": ["path"],
			"additionalProperties": false
		},
		Callable(self, "_tool_create_theme"),
		{
			"type": "object",
			"properties": {
				"path": {"type": "string"},
				"created": {"type": "boolean"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "Media-Theme"
	)

func _register_set_theme_color(server_core: RefCounted) -> void:
	server_core.register_tool(
		"set_theme_color",
		"Set a theme color override on a Control node (undoable).",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"name": {"type": "string", "description": "Color override name, e.g. 'font_color'."},
				"color": {"type": "string", "description": "Color value, e.g. '#ff0000' or 'Color(1,0,0)'."}
			},
			"required": ["node_path", "name", "color"],
			"additionalProperties": false
		},
		Callable(self, "_tool_set_theme_color"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"name": {"type": "string"},
				"color": {"type": "string"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "Media-Theme"
	)

func _register_set_theme_constant(server_core: RefCounted) -> void:
	server_core.register_tool(
		"set_theme_constant",
		"Set a theme constant override on a Control node (undoable).",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"name": {"type": "string"},
				"value": {"type": "integer"}
			},
			"required": ["node_path", "name", "value"],
			"additionalProperties": false
		},
		Callable(self, "_tool_set_theme_constant"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"name": {"type": "string"},
				"value": {"type": "integer"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "Media-Theme"
	)

func _register_set_theme_font_size(server_core: RefCounted) -> void:
	server_core.register_tool(
		"set_theme_font_size",
		"Set a theme font size override on a Control node (undoable).",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"name": {"type": "string", "description": "Font size override name, e.g. 'font_size'."},
				"size": {"type": "integer", "description": "Font size in pixels. Default 16."}
			},
			"required": ["node_path", "name"],
			"additionalProperties": false
		},
		Callable(self, "_tool_set_theme_font_size"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"name": {"type": "string"},
				"size": {"type": "integer"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "Media-Theme"
	)

func _register_set_theme_stylebox(server_core: RefCounted) -> void:
	server_core.register_tool(
		"set_theme_stylebox",
		"Set a StyleBoxFlat theme override on a Control node with background, border, corner radius, and padding (undoable).",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"name": {"type": "string", "description": "Stylebox override name, e.g. 'panel'."},
				"bg_color": {"type": "string"},
				"border_color": {"type": "string"},
				"border_width": {"type": "integer"},
				"corner_radius": {"type": "integer"},
				"padding": {"type": "integer"}
			},
			"required": ["node_path", "name"],
			"additionalProperties": false
		},
		Callable(self, "_tool_set_theme_stylebox"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"name": {"type": "string"},
				"type": {"type": "string"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "Media-Theme"
	)

func _register_setup_control(server_core: RefCounted) -> void:
	server_core.register_tool(
		"setup_control",
		"Configure a Control node layout: anchor preset, min size, size flags, margins, separation, and grow direction (undoable).",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"anchor_preset": {"type": "string", "description": "top_left, top_right, bottom_left, bottom_right, center_left, center_top, center_right, center_bottom, center, left_wide, top_wide, right_wide, bottom_wide, vcenter_wide, hcenter_wide, full_rect."},
				"min_size": {"type": "string", "description": "Minimum size as 'Vector2(w, h)'."},
				"size_flags_h": {"type": "string", "description": "fill, expand, fill_expand, shrink_center, shrink_end."},
				"size_flags_v": {"type": "string"},
				"margins": {"type": "object", "description": "MarginContainer margins {left, top, right, bottom}."},
				"separation": {"type": "integer", "description": "BoxContainer separation."},
				"grow_h": {"type": "string", "description": "begin, end, or both."},
				"grow_v": {"type": "string"}
			},
			"required": ["node_path"],
			"additionalProperties": false
		},
		Callable(self, "_tool_setup_control"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"applied": {"type": "array"},
				"count": {"type": "integer"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "Media-Theme"
	)

func _register_get_theme_info(server_core: RefCounted) -> void:
	server_core.register_tool(
		"get_theme_info",
		"Read a Control node's theme path, type list, and all theme overrides (colors, constants, font sizes, styleboxes).",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"}
			},
			"required": ["node_path"],
			"additionalProperties": false
		},
		Callable(self, "_tool_get_theme_info"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"class": {"type": "string"},
				"overrides": {"type": "object"}
			}
		},
		{"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "Media-Theme"
	)
