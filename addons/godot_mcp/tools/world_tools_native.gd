# world_tools_native.gd - 3D Scene Construction Tools (Batch 1)
# Ported from godot-mcp-pro scene_3d_commands.gd, adapted to native MCP
# registration pattern (register_tool with 8 args).

@tool
class_name WorldToolsNative
extends RefCounted

const VIBE_CODING_POLICY = preload("res://addons/godot_mcp/utils/vibe_coding_policy.gd")
const PathValidator = preload("res://addons/godot_mcp/utils/path_validator.gd")

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

func _is_vibe_coding_mode() -> bool:
	if Engine.has_meta("GodotMCPPlugin"):
		var plugin = Engine.get_meta("GodotMCPPlugin")
		if plugin and plugin.get("vibe_coding_mode") != null:
			return bool(plugin.vibe_coding_mode)
	return true

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

func _add_child_with_undo(parent: Node, child: Node, root: Node, action_name: String) -> Dictionary:
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	var undo_redo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()
	if undo_redo:
		undo_redo.create_action(action_name)
		undo_redo.add_do_method(parent, "add_child", child)
		undo_redo.add_do_method(child, "set_owner", root)
		undo_redo.add_do_reference(child)
		undo_redo.add_undo_method(parent, "remove_child", child)
		undo_redo.commit_action()
	else:
		parent.add_child(child)
		child.owner = root
	editor_interface.mark_scene_as_unsaved()
	return {}

func _optional_float(params: Dictionary, key: String, default_value: float) -> float:
	if params.has(key):
		return float(params[key])
	return default_value

func _parse_color(params: Dictionary, key: String, default_color: Color) -> Color:
	if not params.has(key):
		return default_color
	var value: Variant = params[key]
	if value is String:
		var color_str: String = String(value)
		if color_str.begins_with("#"):
			return Color.html(color_str)
		if color_str.begins_with("Color("):
			var expr := Expression.new()
			if expr.parse(color_str) == OK:
				var parsed: Variant = expr.execute()
				if parsed is Color:
					return parsed
		return default_color
	if value is Dictionary:
		var dict: Dictionary = value
		return Color(
			float(dict.get("r", default_color.r)),
			float(dict.get("g", default_color.g)),
			float(dict.get("b", default_color.b)),
			float(dict.get("a", default_color.a))
		)
	return default_color

func _parse_vector3(params: Dictionary, key: String, default_vector: Vector3) -> Vector3:
	if not params.has(key):
		return default_vector
	var value: Variant = params[key]
	if value is String:
		var expr := Expression.new()
		if expr.parse(String(value)) == OK:
			var parsed: Variant = expr.execute()
			if parsed is Vector3:
				return parsed
		return default_vector
	if value is Dictionary:
		var dict: Dictionary = value
		return Vector3(
			float(dict.get("x", default_vector.x)),
			float(dict.get("y", default_vector.y)),
			float(dict.get("z", default_vector.z))
		)
	if value is Array and (value as Array).size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return default_vector

func _serialize_vector3(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}

func _serialize_color(value: Color) -> Dictionary:
	return {"r": value.r, "g": value.g, "b": value.b, "a": value.a, "html": "#" + value.to_html()}

# ============================================================================
# Tool registration
# ============================================================================

func register_tools(server_core: RefCounted) -> void:
	_register_add_mesh_instance(server_core)
	_register_setup_lighting(server_core)
	_register_set_material_3d(server_core)
	_register_setup_environment(server_core)
	_register_setup_camera_3d(server_core)
	_register_add_gridmap(server_core)

# ============================================================================
# add_mesh_instance - Create MeshInstance3D
# ============================================================================

func _register_add_mesh_instance(server_core: RefCounted) -> void:
	server_core.register_tool(
		"add_mesh_instance",
		"Create a MeshInstance3D node with a primitive mesh (box, sphere, cylinder, capsule, plane, quad) or load a mesh from a .glb/.gltf/.obj/.tres file.",
		{
			"type": "object",
			"properties": {
				"parent_path": {"type": "string", "description": "Path of the parent node. Default '.' for scene root."},
				"name": {"type": "string", "description": "Name of the new node. Default 'MeshInstance3D'."},
				"mesh_type": {"type": "string", "description": "Primitive mesh type: box, sphere, cylinder, capsule, plane, quad, prism, torus."},
				"mesh_file": {"type": "string", "description": "Path to a mesh file (.glb/.gltf/.obj/.tres) to load."},
				"material": {"type": "object", "description": "Optional material dict: {albedo_color, metallic, roughness} applied to a new StandardMaterial3D."},
				"position": {"type": "object", "description": "Position as {x,y,z} or 'Vector3(x,y,z)'."},
				"rotation_degrees": {"type": "object", "description": "Rotation in degrees as {x,y,z} or 'Vector3(x,y,z)'."},
				"scale": {"type": "object", "description": "Scale as {x,y,z} or 'Vector3(x,y,z)'."}
			},
			"required": [],
			"additionalProperties": false
		},
		Callable(self, "_tool_add_mesh_instance"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"node_type": {"type": "string"},
				"mesh_source": {"type": "string"},
				"created": {"type": "boolean"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "World"
	)

func _tool_add_mesh_instance(params: Dictionary) -> Dictionary:
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}

	var parent_path: String = String(params.get("parent_path", "."))
	var parent: Node = _resolve_node_path(parent_path)
	if not parent:
		return {"error": "Parent node not found: " + parent_path}

	var mesh_type: String = String(params.get("mesh_type", ""))
	var mesh_file: String = String(params.get("mesh_file", ""))
	if mesh_type.is_empty() and mesh_file.is_empty():
		return {"error": "Either mesh_type or mesh_file is required"}

	var mesh: Mesh = null
	var mesh_source: String = mesh_type if not mesh_type.is_empty() else mesh_file

	if not mesh_file.is_empty():
		var validation: Dictionary = PathValidator.validate_file_path(mesh_file, [".glb", ".gltf", ".obj", ".tres"])
		if not validation["valid"]:
			return {"error": "Invalid mesh file path: " + validation["error"]}
		mesh_file = validation["sanitized"]
		if not ResourceLoader.exists(mesh_file):
			return {"error": "Mesh file not found: " + mesh_file}
		var loaded: Resource = load(mesh_file)
		if loaded is Mesh:
			mesh = loaded
		elif loaded is PackedScene:
			return {"error": "File is a scene, not a mesh: " + mesh_file}
		else:
			return {"error": "File is not a mesh: " + mesh_file}
	else:
		var mesh_name: String = mesh_type.to_lower()
		match mesh_name:
			"box", "cube":
				mesh = BoxMesh.new()
			"sphere":
				mesh = SphereMesh.new()
			"cylinder":
				mesh = CylinderMesh.new()
			"capsule":
				mesh = CapsuleMesh.new()
			"plane":
				mesh = PlaneMesh.new()
			"quad":
				mesh = QuadMesh.new()
			"prism":
				mesh = PrismMesh.new()
			"torus":
				mesh = TorusMesh.new()
			_:
				return {"error": "Unknown mesh type: '" + mesh_type + "'. Available: box, sphere, cylinder, capsule, plane, quad, prism, torus"}

	var node_name: String = String(params.get("name", "MeshInstance3D"))
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = mesh

	if params.has("material"):
		var material_dict: Dictionary = params["material"]
		var material := StandardMaterial3D.new()
		material.albedo_color = _parse_color(material_dict, "albedo_color", Color.WHITE)
		material.metallic = _optional_float(material_dict, "metallic", 0.0)
		material.roughness = _optional_float(material_dict, "roughness", 1.0)
		mesh_instance.material_override = material

	if params.has("position"):
		mesh_instance.position = _parse_vector3(params, "position", Vector3.ZERO)
	if params.has("rotation_degrees"):
		mesh_instance.rotation_degrees = _parse_vector3(params, "rotation_degrees", Vector3.ZERO)
	if params.has("scale"):
		mesh_instance.scale = _parse_vector3(params, "scale", Vector3.ONE)

	var error: Dictionary = _add_child_with_undo(parent, mesh_instance, scene_root, "MCP: Add MeshInstance3D")
	if not error.is_empty():
		return error

	return {
		"node_path": str(mesh_instance.get_path()),
		"node_type": "MeshInstance3D",
		"mesh_source": mesh_source,
		"created": true
	}

# ============================================================================
# setup_lighting - Create 3D light
# ============================================================================

func _register_setup_lighting(server_core: RefCounted) -> void:
	server_core.register_tool(
		"setup_lighting",
		"Add a DirectionalLight3D, OmniLight3D, or SpotLight3D to the scene with configurable color, energy, and shadow settings.",
		{
			"type": "object",
			"properties": {
				"parent_path": {"type": "string", "description": "Parent node path. Default '.' for scene root."},
				"name": {"type": "string", "description": "Light node name. Default 'DirectionalLight3D'/'OmniLight3D'/'SpotLight3D'."},
				"light_type": {"type": "string", "description": "Type: directional, omni, or spot. Default 'directional'."},
				"color": {"type": "string", "description": "Light color as '#RRGGBB' or 'Color(r,g,b,a)'."},
				"energy": {"type": "number", "description": "Light energy multiplier. Default 1.0."},
				"position": {"type": "object", "description": "Position as {x,y,z} or 'Vector3(x,y,z)'."},
				"rotation_degrees": {"type": "object", "description": "Rotation in degrees as {x,y,z}."},
				"shadow_enabled": {"type": "boolean", "description": "Enable shadows. Default true for directional."},
				"range": {"type": "number", "description": "Range for omni/spot lights (units)."}
			},
			"required": [],
			"additionalProperties": false
		},
		Callable(self, "_tool_setup_lighting"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"light_type": {"type": "string"},
				"created": {"type": "boolean"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "World"
	)

func _tool_setup_lighting(params: Dictionary) -> Dictionary:
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}

	var parent_path: String = String(params.get("parent_path", "."))
	var parent: Node = _resolve_node_path(parent_path)
	if not parent:
		return {"error": "Parent node not found: " + parent_path}

	var light_type: String = String(params.get("light_type", "directional")).to_lower()
	var light: Light3D = null
	var node_name: String = String(params.get("name", ""))

	match light_type:
		"directional":
			if node_name.is_empty():
				node_name = "DirectionalLight3D"
			light = DirectionalLight3D.new()
		"omni":
			if node_name.is_empty():
				node_name = "OmniLight3D"
			light = OmniLight3D.new()
		"spot":
			if node_name.is_empty():
				node_name = "SpotLight3D"
			light = SpotLight3D.new()
		_:
			return {"error": "Unknown light type: '" + light_type + "'. Available: directional, omni, spot"}

	light.name = node_name
	light.light_color = _parse_color(params, "color", Color(1, 1, 1))
	light.light_energy = _optional_float(params, "energy", 1.0)

	var shadow_enabled: bool = bool(params.get("shadow_enabled", light_type == "directional"))
	light.shadow_enabled = shadow_enabled

	if params.has("range") and (light is OmniLight3D or light is SpotLight3D):
		var range_value: float = float(params["range"])
		if light is OmniLight3D:
			(light as OmniLight3D).omni_range = range_value
		elif light is SpotLight3D:
			(light as SpotLight3D).spot_range = range_value

	if params.has("position"):
		light.position = _parse_vector3(params, "position", Vector3.ZERO)
	if params.has("rotation_degrees"):
		light.rotation_degrees = _parse_vector3(params, "rotation_degrees", Vector3.ZERO)

	var error: Dictionary = _add_child_with_undo(parent, light, scene_root, "MCP: Add " + light_type + " light")
	if not error.is_empty():
		return error

	return {
		"node_path": str(light.get_path()),
		"light_type": light_type,
		"created": true
	}

# ============================================================================
# set_material_3d - Configure StandardMaterial3D
# ============================================================================

func _register_set_material_3d(server_core: RefCounted) -> void:
	server_core.register_tool(
		"set_material_3d",
		"Create or update a StandardMaterial3D on a MeshInstance3D surface with PBR parameters: albedo, metallic, roughness, emission, transparency, cull mode.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string", "description": "Path to the MeshInstance3D node."},
				"surface_index": {"type": "integer", "description": "Surface index. Default 0."},
				"albedo_color": {"type": "string", "description": "Albedo color as '#RRGGBB' or 'Color(r,g,b,a)'."},
				"albedo_texture": {"type": "string", "description": "Albedo texture path (res://)."},
				"metallic": {"type": "number", "description": "Metallic value 0-1."},
				"roughness": {"type": "number", "description": "Roughness value 0-1."},
				"emission_color": {"type": "string", "description": "Emission color."},
				"emission_energy": {"type": "number", "description": "Emission energy multiplier."},
				"transparency": {"type": "string", "description": "disabled, alpha, alpha_scissor, alpha_hash, or alpha_depth_pre_pass."},
				"cull_mode": {"type": "string", "description": "back, front, or disabled."},
				"normal_texture": {"type": "string", "description": "Normal map texture path."},
				"metallic_texture": {"type": "string", "description": "Metallic map texture path."},
				"roughness_texture": {"type": "string", "description": "Roughness map texture path."}
			},
			"required": ["node_path"],
			"additionalProperties": false
		},
		Callable(self, "_tool_set_material_3d"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"surface_index": {"type": "integer"},
				"albedo_color": {"type": "string"},
				"metallic": {"type": "number"},
				"roughness": {"type": "number"},
				"updated": {"type": "boolean"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "World"
	)

func _tool_set_material_3d(params: Dictionary) -> Dictionary:
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}

	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var node: Node = _resolve_node_path(node_path)
	if not node:
		return {"error": "Node not found: " + node_path}
	if not (node is MeshInstance3D):
		return {"error": "Node '" + node_path + "' is not a MeshInstance3D (is " + node.get_class() + ")"}

	var mesh_inst: MeshInstance3D = node as MeshInstance3D
	var surface_index: int = int(params.get("surface_index", 0))

	var material := StandardMaterial3D.new()
	material.albedo_color = _parse_color(params, "albedo_color", Color.WHITE)
	if params.has("albedo_texture"):
		var tex_path: String = String(params["albedo_texture"])
		if ResourceLoader.exists(tex_path):
			material.albedo_texture = load(tex_path) as Texture2D

	material.metallic = _optional_float(params, "metallic", 0.0)
	material.roughness = _optional_float(params, "roughness", 1.0)

	if params.has("metallic_texture") and ResourceLoader.exists(String(params["metallic_texture"])):
		material.metallic_texture = load(String(params["metallic_texture"])) as Texture2D
	if params.has("roughness_texture") and ResourceLoader.exists(String(params["roughness_texture"])):
		material.roughness_texture = load(String(params["roughness_texture"])) as Texture2D
	if params.has("normal_texture") and ResourceLoader.exists(String(params["normal_texture"])):
		material.normal_enabled = true
		material.normal_texture = load(String(params["normal_texture"])) as Texture2D

	if params.has("emission_color") or params.has("emission_energy"):
		material.emission_enabled = true
		material.emission = _parse_color(params, "emission_color", Color.BLACK)
		material.emission_energy_multiplier = _optional_float(params, "emission_energy", 1.0)

	if params.has("transparency"):
		var transparency: String = String(params["transparency"]).to_upper()
		match transparency:
			"DISABLED", "0":
				material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			"ALPHA", "1":
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			"ALPHA_SCISSOR", "2":
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			"ALPHA_HASH", "3":
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
			"ALPHA_DEPTH_PRE_PASS", "4":
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS

	if params.has("cull_mode"):
		var cull: String = String(params["cull_mode"]).to_upper()
		match cull:
			"BACK", "0":
				material.cull_mode = BaseMaterial3D.CULL_BACK
			"FRONT", "1":
				material.cull_mode = BaseMaterial3D.CULL_FRONT
			"DISABLED", "2":
				material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var old_material: Material = mesh_inst.get_surface_override_material(surface_index)
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	var undo_redo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()
	if undo_redo:
		undo_redo.create_action("MCP: Set material on " + str(mesh_inst.name))
		undo_redo.add_do_method(mesh_inst, "set_surface_override_material", surface_index, material)
		undo_redo.add_do_reference(material)
		undo_redo.add_undo_method(mesh_inst, "set_surface_override_material", surface_index, old_material)
		undo_redo.commit_action()
	else:
		mesh_inst.set_surface_override_material(surface_index, material)
	editor_interface.mark_scene_as_unsaved()

	return {
		"node_path": node_path,
		"surface_index": surface_index,
		"albedo_color": material.albedo_color.to_html(),
		"metallic": material.metallic,
		"roughness": material.roughness,
		"updated": true
	}

# ============================================================================
# setup_environment - Configure WorldEnvironment
# ============================================================================

func _register_setup_environment(server_core: RefCounted) -> void:
	server_core.register_tool(
		"setup_environment",
		"Create or update a WorldEnvironment with background mode (sky, color, canvas, clear_color), procedural sky, ambient light, and tonemap settings.",
		{
			"type": "object",
			"properties": {
				"parent_path": {"type": "string", "description": "Parent node path. Default '.' for scene root."},
				"name": {"type": "string", "description": "WorldEnvironment node name."},
				"background_mode": {"type": "string", "description": "sky, color, canvas, or clear_color. Default 'sky'."},
				"background_color": {"type": "string", "description": "Background color for 'color' mode."},
				"sky": {"type": "object", "description": "Procedural sky dict: {sky_top_color, sky_horizon_color, ground_bottom_color, ground_horizon_color, sun_angle_max, sky_curve}."},
				"ambient_light_color": {"type": "string", "description": "Ambient light color."},
				"ambient_light_energy": {"type": "number", "description": "Ambient light energy."},
				"ambient_light_source": {"type": "string", "description": "background, disabled, color, or sky."},
				"tonemap_mode": {"type": "string", "description": "linear, reinhard, filmic, aces, or agx."},
				"exposure": {"type": "number", "description": "Exposure value."}
			},
			"required": [],
			"additionalProperties": false
		},
		Callable(self, "_tool_setup_environment"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"background_mode": {"type": "string"},
				"created": {"type": "boolean"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "World"
	)

func _tool_setup_environment(params: Dictionary) -> Dictionary:
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}

	var parent_path: String = String(params.get("parent_path", "."))
	var parent: Node = _resolve_node_path(parent_path)
	if not parent:
		return {"error": "Parent node not found: " + parent_path}

	var node_name: String = String(params.get("name", "WorldEnvironment"))
	var world_env: WorldEnvironment = null

	# Reuse an existing WorldEnvironment under the parent if present
	for child in parent.get_children():
		if child is WorldEnvironment:
			world_env = child as WorldEnvironment
			break

	var created: bool = false
	if world_env == null:
		world_env = WorldEnvironment.new()
		world_env.name = node_name
		created = true

	var env: Environment = world_env.environment
	if env == null:
		env = Environment.new()
		world_env.environment = env

	var bg_mode: String = String(params.get("background_mode", "sky")).to_lower()
	match bg_mode:
		"sky":
			env.background_mode = Environment.BG_SKY
		"color":
			env.background_mode = Environment.BG_COLOR
			env.background_color = _parse_color(params, "background_color", Color(0.3, 0.3, 0.3))
		"canvas":
			env.background_mode = Environment.BG_CANVAS
		"clear_color":
			env.background_mode = Environment.BG_CLEAR_COLOR
		_:
			return {"error": "Unknown background_mode: '" + bg_mode + "'. Available: sky, color, canvas, clear_color"}

	if params.has("sky") and params["sky"] is Dictionary:
		var sky_dict: Dictionary = params["sky"]
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = _parse_color(sky_dict, "sky_top_color", Color(0.385, 0.454, 0.55))
		sky_mat.sky_horizon_color = _parse_color(sky_dict, "sky_horizon_color", Color(0.646, 0.654, 0.67))
		sky_mat.ground_bottom_color = _parse_color(sky_dict, "ground_bottom_color", Color(0.2, 0.169, 0.133))
		sky_mat.ground_horizon_color = _parse_color(sky_dict, "ground_horizon_color", Color(0.646, 0.654, 0.67))
		if sky_dict.has("sun_angle_max"):
			sky_mat.sun_angle_max = _optional_float(sky_dict, "sun_angle_max", 30.0)
		if sky_dict.has("sky_curve"):
			sky_mat.sky_curve = _optional_float(sky_dict, "sky_curve", 0.15)
		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.sky = sky
		env.background_mode = Environment.BG_SKY

	if params.has("ambient_light_color"):
		env.ambient_light_color = _parse_color(params, "ambient_light_color", Color.WHITE)
	if params.has("ambient_light_energy"):
		env.ambient_light_energy = _optional_float(params, "ambient_light_energy", 1.0)
	if params.has("ambient_light_source"):
		var src: String = String(params["ambient_light_source"]).to_upper()
		match src:
			"BACKGROUND", "0":
				env.ambient_light_source = Environment.AMBIENT_SOURCE_BG
			"DISABLED", "1":
				env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
			"COLOR", "2":
				env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			"SKY", "3":
				env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY

	if params.has("tonemap_mode"):
		var tm: String = String(params["tonemap_mode"]).to_upper()
		match tm:
			"LINEAR", "0":
				env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			"REINHARD", "REINHARDT", "1":
				env.tonemap_mode = Environment.TONE_MAPPER_REINHARDT
			"FILMIC", "2":
				env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			"ACES", "3":
				env.tonemap_mode = Environment.TONE_MAPPER_ACES
			"AGX", "4":
				env.tonemap_mode = Environment.TONE_MAPPER_AGX

	if params.has("exposure"):
		env.exposure = _optional_float(params, "exposure", 1.0)

	if created:
		var error: Dictionary = _add_child_with_undo(parent, world_env, scene_root, "MCP: Add WorldEnvironment")
		if not error.is_empty():
			return error
	else:
		var editor_interface: EditorInterface = _get_editor_interface()
		if editor_interface:
			editor_interface.mark_scene_as_unsaved()

	return {
		"node_path": str(world_env.get_path()),
		"background_mode": bg_mode,
		"created": created
	}

# ============================================================================
# setup_camera_3d - Configure 3D camera
# ============================================================================

func _register_setup_camera_3d(server_core: RefCounted) -> void:
	server_core.register_tool(
		"setup_camera_3d",
		"Create or configure a Camera3D node with position, rotation, FOV, near/far planes, and current camera flag.",
		{
			"type": "object",
			"properties": {
				"parent_path": {"type": "string", "description": "Parent node path. Default '.' for scene root."},
				"name": {"type": "string", "description": "Camera node name. Default 'Camera3D'."},
				"position": {"type": "object", "description": "Position as {x,y,z} or 'Vector3(x,y,z)'."},
				"rotation_degrees": {"type": "object", "description": "Rotation in degrees."},
				"fov": {"type": "number", "description": "Field of view in degrees. Default 75."},
				"near": {"type": "number", "description": "Near plane. Default 0.05."},
				"far": {"type": "number", "description": "Far plane. Default 4000."},
				"current": {"type": "boolean", "description": "Make this the current camera. Default true."},
				"make_current": {"type": "boolean", "description": "Alias of current."}
			},
			"required": [],
			"additionalProperties": false
		},
		Callable(self, "_tool_setup_camera_3d"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"fov": {"type": "number"},
				"current": {"type": "boolean"},
				"created": {"type": "boolean"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "World"
	)

func _tool_setup_camera_3d(params: Dictionary) -> Dictionary:
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}

	var parent_path: String = String(params.get("parent_path", "."))
	var parent: Node = _resolve_node_path(parent_path)
	if not parent:
		return {"error": "Parent node not found: " + parent_path}

	var node_name: String = String(params.get("name", "Camera3D"))
	var camera := Camera3D.new()
	camera.name = node_name

	if params.has("position"):
		camera.position = _parse_vector3(params, "position", Vector3.ZERO)
	if params.has("rotation_degrees"):
		camera.rotation_degrees = _parse_vector3(params, "rotation_degrees", Vector3.ZERO)
	camera.fov = _optional_float(params, "fov", 75.0)
	camera.near = _optional_float(params, "near", 0.05)
	camera.far = _optional_float(params, "far", 4000.0)

	var make_current: bool = bool(params.get("current", params.get("make_current", true)))
	if make_current:
		camera.current = true

	var error: Dictionary = _add_child_with_undo(parent, camera, scene_root, "MCP: Add Camera3D")
	if not error.is_empty():
		return error

	return {
		"node_path": str(camera.get_path()),
		"fov": camera.fov,
		"current": camera.current,
		"created": true
	}

# ============================================================================
# add_gridmap - Create GridMap
# ============================================================================

func _register_add_gridmap(server_core: RefCounted) -> void:
	server_core.register_tool(
		"add_gridmap",
		"Create a GridMap node, optionally assign a mesh library (from .tres resource) and set cell size.",
		{
			"type": "object",
			"properties": {
				"parent_path": {"type": "string", "description": "Parent node path. Default '.' for scene root."},
				"name": {"type": "string", "description": "GridMap node name. Default 'GridMap'."},
				"mesh_library": {"type": "string", "description": "Path to a MeshLibrary .tres resource."},
				"cell_size": {"type": "object", "description": "Cell size as {x,y,z} or 'Vector3(x,y,z)'. Default (1,1,1)."},
				"cell_scale": {"type": "number", "description": "Cell scale. Default 1.0."}
			},
			"required": [],
			"additionalProperties": false
		},
		Callable(self, "_tool_add_gridmap"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"mesh_library": {"type": "string"},
				"created": {"type": "boolean"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "World"
	)

func _tool_add_gridmap(params: Dictionary) -> Dictionary:
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}

	var parent_path: String = String(params.get("parent_path", "."))
	var parent: Node = _resolve_node_path(parent_path)
	if not parent:
		return {"error": "Parent node not found: " + parent_path}

	var node_name: String = String(params.get("name", "GridMap"))
	var gridmap := GridMap.new()
	gridmap.name = node_name

	if params.has("mesh_library"):
		var library_path: String = String(params["mesh_library"])
		var validation: Dictionary = PathValidator.validate_file_path(library_path, [".tres"])
		if not validation["valid"]:
			return {"error": "Invalid mesh library path: " + validation["error"]}
		library_path = validation["sanitized"]
		if not ResourceLoader.exists(library_path):
			return {"error": "Mesh library not found: " + library_path}
		var library: Resource = load(library_path)
		if not (library is MeshLibrary):
			return {"error": "File is not a MeshLibrary: " + library_path}
		gridmap.mesh_library = library

	if params.has("cell_size"):
		gridmap.cell_size = _parse_vector3(params, "cell_size", Vector3.ONE)
	if params.has("cell_scale"):
		gridmap.cell_scale = _optional_float(params, "cell_scale", 1.0)

	var error: Dictionary = _add_child_with_undo(parent, gridmap, scene_root, "MCP: Add GridMap")
	if not error.is_empty():
		return error

	return {
		"node_path": str(gridmap.get_path()),
		"mesh_library": str(gridmap.mesh_library.resource_path) if gridmap.mesh_library else "",
		"created": true
	}
