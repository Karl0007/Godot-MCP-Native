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
