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
