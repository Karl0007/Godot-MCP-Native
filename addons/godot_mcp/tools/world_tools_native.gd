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
	_register_setup_collision(server_core)
	_register_set_physics_layers(server_core)
	_register_get_physics_layers(server_core)
	_register_add_raycast(server_core)
	_register_setup_physics_body(server_core)
	_register_get_collision_info(server_core)
	_register_setup_navigation_region(server_core)
	_register_bake_navigation_mesh(server_core)
	_register_setup_navigation_agent(server_core)
	_register_set_navigation_layers(server_core)
	_register_get_navigation_info(server_core)

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

# ============================================================================
# Physics tools (Batch 2)
# ============================================================================

func _detect_dimension(node: Node) -> String:
	if node is Node2D or node is Control:
		return "2d"
	if node is Node3D:
		return "3d"
	var parent := node.get_parent()
	while parent != null:
		if parent is Node2D or parent is Control:
			return "2d"
		if parent is Node3D:
			return "3d"
		parent = parent.get_parent()
	return ""

func _get_layer_name(dim: String, layer_index: int) -> String:
	var setting_key: String = "layer_names/%s_physics/layer_%d" % [dim, layer_index]
	if ProjectSettings.has_setting(setting_key):
		var name_val: Variant = ProjectSettings.get_setting(setting_key)
		if name_val is String and not String(name_val).is_empty():
			return String(name_val)
	return ""

func _layer_bitmask_to_info(bitmask: int, dim: String) -> Array:
	var layers: Array = []
	for i in range(1, 33):
		if bitmask & (1 << (i - 1)):
			var layer_name: String = _get_layer_name(dim, i)
			var entry: Dictionary = {"layer": i}
			if not layer_name.is_empty():
				entry["name"] = layer_name
			layers.append(entry)
	return layers

func _parse_layer_value(value: Variant) -> int:
	if value is int or value is float:
		return int(value)
	if value is Array:
		var bitmask: int = 0
		for layer_num: Variant in value:
			var n: int = int(layer_num)
			if n >= 1 and n <= 32:
				bitmask |= (1 << (n - 1))
		return bitmask
	return int(value)

func _tool_setup_collision(params: Dictionary) -> Dictionary:
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}

	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var shape_name: String = String(params.get("shape", ""))
	if shape_name.is_empty():
		return {"error": "Missing required parameter: shape"}

	var node: Node = _resolve_node_path(node_path)
	if not node:
		return {"error": "Node not found: " + node_path}

	var dim: String = _detect_dimension(node)
	if dim.is_empty():
		dim = String(params.get("dimension", "2d")).to_lower()

	var valid_parents_2d: Array = ["PhysicsBody2D", "Area2D", "StaticBody2D", "CharacterBody2D", "RigidBody2D", "AnimatableBody2D"]
	var valid_parents_3d: Array = ["PhysicsBody3D", "Area3D", "StaticBody3D", "CharacterBody3D", "RigidBody3D", "AnimatableBody3D"]
	var is_valid_parent: bool = false
	var parents: Array = valid_parents_2d if dim == "2d" else valid_parents_3d
	for vp: String in parents:
		if node.is_class(vp):
			is_valid_parent = true
			break
	if not is_valid_parent:
		return {"error": "Node '" + node_path + "' (" + node.get_class() + ") is not a physics body or area. CollisionShape should be added to a PhysicsBody or Area node."}

	var shape: Resource = null
	var child_name: String = "CollisionShape"

	if dim == "2d":
		match shape_name:
			"rectangle", "rect":
				shape = RectangleShape2D.new()
				(shape as RectangleShape2D).size = Vector2(float(params.get("width", 32.0)), float(params.get("height", 32.0)))
			"circle":
				shape = CircleShape2D.new()
				(shape as CircleShape2D).radius = float(params.get("radius", 16.0))
			"capsule":
				shape = CapsuleShape2D.new()
				(shape as CapsuleShape2D).radius = float(params.get("radius", 16.0))
				(shape as CapsuleShape2D).height = float(params.get("height", 40.0))
			"segment":
				shape = SegmentShape2D.new()
				(shape as SegmentShape2D).a = Vector2(float(params.get("ax", 0.0)), float(params.get("ay", 0.0)))
				(shape as SegmentShape2D).b = Vector2(float(params.get("bx", 32.0)), float(params.get("by", 0.0)))
			"custom":
				shape = ConvexPolygonShape2D.new()
				var points_data: Array = params.get("points", [])
				var pool := PackedVector2Array()
				for p: Variant in points_data:
					if p is Array and (p as Array).size() >= 2:
						pool.append(Vector2(float(p[0]), float(p[1])))
				if pool.size() >= 3:
					(shape as ConvexPolygonShape2D).points = pool
			_:
				return {"error": "Unknown 2D shape: '" + shape_name + "'. Available: rectangle, circle, capsule, segment, custom"}

		var collision_node := CollisionShape2D.new()
		collision_node.shape = shape
		collision_node.name = child_name
		collision_node.disabled = bool(params.get("disabled", false))
		collision_node.one_way_collision = bool(params.get("one_way_collision", false))
		var error: Dictionary = _add_child_with_undo(node, collision_node, scene_root, "MCP: Add CollisionShape2D to " + str(node.name))
		if not error.is_empty():
			return error
		return {
			"node_path": str(collision_node.get_path()),
			"shape_type": shape.get_class(),
			"dimension": "2D"
		}
	else:
		match shape_name:
			"box", "rectangle", "rect":
				shape = BoxShape3D.new()
				(shape as BoxShape3D).size = Vector3(float(params.get("width", 1.0)), float(params.get("height", 1.0)), float(params.get("depth", 1.0)))
			"sphere", "circle":
				shape = SphereShape3D.new()
				(shape as SphereShape3D).radius = float(params.get("radius", 0.5))
			"capsule":
				shape = CapsuleShape3D.new()
				(shape as CapsuleShape3D).radius = float(params.get("radius", 0.5))
				(shape as CapsuleShape3D).height = float(params.get("height", 2.0))
			"cylinder":
				shape = CylinderShape3D.new()
				(shape as CylinderShape3D).radius = float(params.get("radius", 0.5))
				(shape as CylinderShape3D).height = float(params.get("height", 2.0))
			"convex", "custom":
				shape = ConvexPolygonShape3D.new()
				var points_data: Array = params.get("points", [])
				var pool := PackedVector3Array()
				for p: Variant in points_data:
					if p is Array and (p as Array).size() >= 3:
						pool.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
				if pool.size() >= 4:
					(shape as ConvexPolygonShape3D).points = pool
			_:
				return {"error": "Unknown 3D shape: '" + shape_name + "'. Available: box, sphere, capsule, cylinder, convex"}

		var collision_node := CollisionShape3D.new()
		collision_node.shape = shape
		collision_node.name = child_name
		collision_node.disabled = bool(params.get("disabled", false))
		var error: Dictionary = _add_child_with_undo(node, collision_node, scene_root, "MCP: Add CollisionShape3D to " + str(node.name))
		if not error.is_empty():
			return error
		return {
			"node_path": str(collision_node.get_path()),
			"shape_type": shape.get_class(),
			"dimension": "3D"
		}

func _tool_set_physics_layers(params: Dictionary) -> Dictionary:
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}

	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var node: Node = _resolve_node_path(node_path)
	if not node:
		return {"error": "Node not found: " + node_path}
	if not "collision_layer" in node:
		return {"error": "Node '" + node_path + "' (" + node.get_class() + ") does not have collision_layer property"}

	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	var undo_redo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("MCP: Set physics layers on " + str(node.name))

	var changes: Dictionary = {}
	if params.has("collision_layer"):
		var old_layer: Variant = node.get("collision_layer")
		var new_layer: int = _parse_layer_value(params["collision_layer"])
		undo_redo.add_do_property(node, "collision_layer", new_layer)
		undo_redo.add_undo_property(node, "collision_layer", old_layer)
		changes["collision_layer"] = new_layer
	if params.has("collision_mask"):
		var old_mask: Variant = node.get("collision_mask")
		var new_mask: int = _parse_layer_value(params["collision_mask"])
		undo_redo.add_do_property(node, "collision_mask", new_mask)
		undo_redo.add_undo_property(node, "collision_mask", old_mask)
		changes["collision_mask"] = new_mask
	if changes.is_empty():
		undo_redo.commit_action()
		return {"error": "Must provide collision_layer and/or collision_mask"}
	undo_redo.commit_action()
	editor_interface.mark_scene_as_unsaved()

	var dim: String = _detect_dimension(node)
	if dim.is_empty():
		dim = "2d"
	var result: Dictionary = {"node_path": node_path}
	if changes.has("collision_layer"):
		result["collision_layer"] = changes["collision_layer"]
		result["collision_layer_info"] = _layer_bitmask_to_info(changes["collision_layer"], dim)
	if changes.has("collision_mask"):
		result["collision_mask"] = changes["collision_mask"]
		result["collision_mask_info"] = _layer_bitmask_to_info(changes["collision_mask"], dim)
	return result

func _tool_get_physics_layers(params: Dictionary) -> Dictionary:
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var node: Node = _resolve_node_path(node_path)
	if not node:
		return {"error": "Node not found: " + node_path}
	if not "collision_layer" in node:
		return {"error": "Node '" + node_path + "' (" + node.get_class() + ") does not have collision_layer property"}
	var layer: int = int(node.get("collision_layer"))
	var mask: int = int(node.get("collision_mask"))
	var dim: String = _detect_dimension(node)
	if dim.is_empty():
		dim = "2d"
	return {
		"node_path": node_path,
		"type": node.get_class(),
		"collision_layer": layer,
		"collision_layer_info": _layer_bitmask_to_info(layer, dim),
		"collision_mask": mask,
		"collision_mask_info": _layer_bitmask_to_info(mask, dim),
	}

func _tool_add_raycast(params: Dictionary) -> Dictionary:
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var node: Node = _resolve_node_path(node_path)
	if not node:
		return {"error": "Node not found: " + node_path}

	var dim: String = _detect_dimension(node)
	if dim.is_empty():
		dim = String(params.get("dimension", "2d")).to_lower()
	var ray_name: String = String(params.get("name", "RayCast"))
	var enabled: bool = bool(params.get("enabled", true))
	var collision_mask: int = int(params.get("collision_mask", 1))
	var collide_with_areas: bool = bool(params.get("collide_with_areas", false))
	var collide_with_bodies: bool = bool(params.get("collide_with_bodies", true))
	var hit_from_inside: bool = bool(params.get("hit_from_inside", false))

	if dim == "2d":
		var ray := RayCast2D.new()
		ray.name = ray_name
		ray.enabled = enabled
		ray.collision_mask = collision_mask
		ray.collide_with_areas = collide_with_areas
		ray.collide_with_bodies = collide_with_bodies
		ray.hit_from_inside = hit_from_inside
		ray.target_position = Vector2(float(params.get("target_x", 0.0)), float(params.get("target_y", 50.0)))
		var error: Dictionary = _add_child_with_undo(node, ray, scene_root, "MCP: Add RayCast2D to " + str(node.name))
		if not error.is_empty():
			return error
		return {
			"node_path": str(ray.get_path()),
			"type": "RayCast2D",
			"target_position": "Vector2(%s, %s)" % [ray.target_position.x, ray.target_position.y],
			"collision_mask": collision_mask,
		}
	else:
		var ray := RayCast3D.new()
		ray.name = ray_name
		ray.enabled = enabled
		ray.collision_mask = collision_mask
		ray.collide_with_areas = collide_with_areas
		ray.collide_with_bodies = collide_with_bodies
		ray.hit_from_inside = hit_from_inside
		ray.target_position = Vector3(float(params.get("target_x", 0.0)), float(params.get("target_y", -1.0)), float(params.get("target_z", 0.0)))
		var error: Dictionary = _add_child_with_undo(node, ray, scene_root, "MCP: Add RayCast3D to " + str(node.name))
		if not error.is_empty():
			return error
		return {
			"node_path": str(ray.get_path()),
			"type": "RayCast3D",
			"target_position": "Vector3(%s, %s, %s)" % [ray.target_position.x, ray.target_position.y, ray.target_position.z],
			"collision_mask": collision_mask,
		}

func _tool_setup_physics_body(params: Dictionary) -> Dictionary:
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var node: Node = _resolve_node_path(node_path)
	if not node:
		return {"error": "Node not found: " + node_path}

	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	var undo_redo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("MCP: Setup physics body " + str(node.name))

	var applied: Dictionary = {}

	if node is CharacterBody2D or node is CharacterBody3D:
		if params.has("floor_stop_on_slope"):
			var old_b: Variant = node.floor_stop_on_slope
			var new_b: bool = bool(params["floor_stop_on_slope"])
			undo_redo.add_do_property(node, "floor_stop_on_slope", new_b)
			undo_redo.add_undo_property(node, "floor_stop_on_slope", old_b)
			applied["floor_stop_on_slope"] = new_b
		if params.has("floor_max_angle"):
			var old_f: Variant = node.floor_max_angle
			var new_f: float = float(params["floor_max_angle"])
			undo_redo.add_do_property(node, "floor_max_angle", new_f)
			undo_redo.add_undo_property(node, "floor_max_angle", old_f)
			applied["floor_max_angle"] = new_f
		if params.has("floor_snap_length"):
			var old_s: Variant = node.floor_snap_length
			var new_s: float = float(params["floor_snap_length"])
			undo_redo.add_do_property(node, "floor_snap_length", new_s)
			undo_redo.add_undo_property(node, "floor_snap_length", old_s)
			applied["floor_snap_length"] = new_s
		if params.has("wall_min_slide_angle"):
			var old_w: Variant = node.wall_min_slide_angle
			var new_w: float = float(params["wall_min_slide_angle"])
			undo_redo.add_do_property(node, "wall_min_slide_angle", new_w)
			undo_redo.add_undo_property(node, "wall_min_slide_angle", old_w)
			applied["wall_min_slide_angle"] = new_w
		if params.has("motion_mode"):
			var mode_str: String = str(params["motion_mode"])
			var mode_val: int = 0
			if node is CharacterBody2D:
				match mode_str.to_lower():
					"grounded":
						mode_val = CharacterBody2D.MOTION_MODE_GROUNDED
					"floating":
						mode_val = CharacterBody2D.MOTION_MODE_FLOATING
					_:
						mode_val = int(params["motion_mode"])
			else:
				match mode_str.to_lower():
					"grounded":
						mode_val = CharacterBody3D.MOTION_MODE_GROUNDED
					"floating":
						mode_val = CharacterBody3D.MOTION_MODE_FLOATING
					_:
						mode_val = int(params["motion_mode"])
			var old_m: Variant = node.motion_mode
			undo_redo.add_do_property(node, "motion_mode", mode_val)
			undo_redo.add_undo_property(node, "motion_mode", old_m)
			applied["motion_mode"] = mode_str
		if params.has("max_slides"):
			var old_x: Variant = node.max_slides
			var new_x: int = int(params["max_slides"])
			undo_redo.add_do_property(node, "max_slides", new_x)
			undo_redo.add_undo_property(node, "max_slides", old_x)
			applied["max_slides"] = new_x
		if params.has("slide_on_ceiling"):
			var old_c: Variant = node.slide_on_ceiling
			var new_c: bool = bool(params["slide_on_ceiling"])
			undo_redo.add_do_property(node, "slide_on_ceiling", new_c)
			undo_redo.add_undo_property(node, "slide_on_ceiling", old_c)
			applied["slide_on_ceiling"] = new_c

	elif node is RigidBody2D or node is RigidBody3D:
		if params.has("mass"):
			var old_ma: Variant = node.mass
			var new_ma: float = float(params["mass"])
			undo_redo.add_do_property(node, "mass", new_ma)
			undo_redo.add_undo_property(node, "mass", old_ma)
			applied["mass"] = new_ma
		if params.has("gravity_scale"):
			var old_g: Variant = node.gravity_scale
			var new_g: float = float(params["gravity_scale"])
			undo_redo.add_do_property(node, "gravity_scale", new_g)
			undo_redo.add_undo_property(node, "gravity_scale", old_g)
			applied["gravity_scale"] = new_g
		if params.has("linear_damp"):
			var old_l: Variant = node.linear_damp
			var new_l: float = float(params["linear_damp"])
			undo_redo.add_do_property(node, "linear_damp", new_l)
			undo_redo.add_undo_property(node, "linear_damp", old_l)
			applied["linear_damp"] = new_l
		if params.has("angular_damp"):
			var old_a: Variant = node.angular_damp
			var new_a: float = float(params["angular_damp"])
			undo_redo.add_do_property(node, "angular_damp", new_a)
			undo_redo.add_undo_property(node, "angular_damp", old_a)
			applied["angular_damp"] = new_a
		if params.has("freeze"):
			var old_z: Variant = node.freeze
			var new_z: bool = bool(params["freeze"])
			undo_redo.add_do_property(node, "freeze", new_z)
			undo_redo.add_undo_property(node, "freeze", old_z)
			applied["freeze"] = new_z
		if params.has("freeze_mode"):
			var fm_str: String = str(params["freeze_mode"])
			var fm_val: int = 0
			if node is RigidBody2D:
				match fm_str.to_lower():
					"static":
						fm_val = RigidBody2D.FREEZE_MODE_STATIC
					"kinematic":
						fm_val = RigidBody2D.FREEZE_MODE_KINEMATIC
					_:
						fm_val = int(params["freeze_mode"])
			else:
				match fm_str.to_lower():
					"static":
						fm_val = RigidBody3D.FREEZE_MODE_STATIC
					"kinematic":
						fm_val = RigidBody3D.FREEZE_MODE_KINEMATIC
					_:
						fm_val = int(params["freeze_mode"])
			var old_fm: Variant = node.freeze_mode
			undo_redo.add_do_property(node, "freeze_mode", fm_val)
			undo_redo.add_undo_property(node, "freeze_mode", old_fm)
			applied["freeze_mode"] = fm_str
		if params.has("contact_monitor"):
			var old_cm: Variant = node.contact_monitor
			var new_cm: bool = bool(params["contact_monitor"])
			undo_redo.add_do_property(node, "contact_monitor", new_cm)
			undo_redo.add_undo_property(node, "contact_monitor", old_cm)
			applied["contact_monitor"] = new_cm
		if params.has("max_contacts_reported"):
			var old_mc: Variant = node.max_contacts_reported
			var new_mc: int = int(params["max_contacts_reported"])
			undo_redo.add_do_property(node, "max_contacts_reported", new_mc)
			undo_redo.add_undo_property(node, "max_contacts_reported", old_mc)
			applied["max_contacts_reported"] = new_mc
	else:
		undo_redo.commit_action()
		return {"error": "Node '" + node_path + "' (" + node.get_class() + ") is not a recognized physics body type. Supported: CharacterBody2D/3D, RigidBody2D/3D, StaticBody2D/3D, AnimatableBody2D/3D"}

	if applied.is_empty():
		undo_redo.commit_action()
		return {"error": "No valid properties provided for " + node.get_class()}

	undo_redo.commit_action()
	editor_interface.mark_scene_as_unsaved()

	return {
		"node_path": node_path,
		"type": node.get_class(),
		"applied": applied,
	}

func _tool_get_collision_info(params: Dictionary) -> Dictionary:
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var node: Node = _resolve_node_path(node_path)
	if not node:
		return {"error": "Node not found: " + node_path}

	var include_children: bool = bool(params.get("include_children", true))
	var info: Dictionary = {
		"node_path": node_path,
		"type": node.get_class(),
	}

	if "collision_layer" in node:
		var dim: String = _detect_dimension(node)
		if dim.is_empty():
			dim = "2d"
		var layer_val: int = int(node.get("collision_layer"))
		var mask_val: int = int(node.get("collision_mask"))
		info["collision_layer"] = layer_val
		info["collision_layer_info"] = _layer_bitmask_to_info(layer_val, dim)
		info["collision_mask"] = mask_val
		info["collision_mask_info"] = _layer_bitmask_to_info(mask_val, dim)

	if node is CharacterBody2D or node is CharacterBody3D:
		info["body_settings"] = {
			"motion_mode": node.motion_mode,
			"floor_stop_on_slope": node.floor_stop_on_slope,
			"floor_max_angle": node.floor_max_angle,
			"floor_snap_length": node.floor_snap_length,
			"wall_min_slide_angle": node.wall_min_slide_angle,
			"max_slides": node.max_slides,
			"slide_on_ceiling": node.slide_on_ceiling,
		}
	elif node is RigidBody2D or node is RigidBody3D:
		info["body_settings"] = {
			"mass": node.mass,
			"gravity_scale": node.gravity_scale,
			"linear_damp": node.linear_damp,
			"angular_damp": node.angular_damp,
			"freeze": node.freeze,
			"freeze_mode": node.freeze_mode,
			"contact_monitor": node.contact_monitor,
			"max_contacts_reported": node.max_contacts_reported,
		}

	var shapes: Array = []
	var raycasts: Array = []
	var nodes_to_check: Array = [node]
	if include_children:
		var queue: Array = [node]
		while queue.size() > 0:
			var current: Node = queue.pop_front()
			for child_idx in current.get_child_count():
				var child: Node = current.get_child(child_idx)
				nodes_to_check.append(child)
				queue.append(child)

	for check_node: Node in nodes_to_check:
		if check_node is CollisionShape2D:
			var shape_info: Dictionary = {
				"node_path": node_path,
				"disabled": check_node.disabled,
				"one_way_collision": check_node.one_way_collision,
			}
			if check_node.shape != null:
				shape_info["shape_type"] = check_node.shape.get_class()
				if check_node.shape is RectangleShape2D:
					shape_info["size"] = "Vector2(%s, %s)" % [(check_node.shape as RectangleShape2D).size.x, (check_node.shape as RectangleShape2D).size.y]
				elif check_node.shape is CircleShape2D:
					shape_info["radius"] = (check_node.shape as CircleShape2D).radius
				elif check_node.shape is CapsuleShape2D:
					shape_info["radius"] = (check_node.shape as CapsuleShape2D).radius
					shape_info["height"] = (check_node.shape as CapsuleShape2D).height
			shapes.append(shape_info)
		elif check_node is CollisionShape3D:
			var shape_info: Dictionary = {
				"node_path": node_path,
				"disabled": check_node.disabled,
			}
			if check_node.shape != null:
				shape_info["shape_type"] = check_node.shape.get_class()
				if check_node.shape is BoxShape3D:
					shape_info["size"] = "Vector3(%s, %s, %s)" % [(check_node.shape as BoxShape3D).size.x, (check_node.shape as BoxShape3D).size.y, (check_node.shape as BoxShape3D).size.z]
				elif check_node.shape is SphereShape3D:
					shape_info["radius"] = (check_node.shape as SphereShape3D).radius
				elif check_node.shape is CapsuleShape3D:
					shape_info["radius"] = (check_node.shape as CapsuleShape3D).radius
					shape_info["height"] = (check_node.shape as CapsuleShape3D).height
				elif check_node.shape is CylinderShape3D:
					shape_info["radius"] = (check_node.shape as CylinderShape3D).radius
					shape_info["height"] = (check_node.shape as CylinderShape3D).height
			shapes.append(shape_info)
		elif check_node is RayCast2D:
			raycasts.append({
				"node_path": node_path,
				"type": "RayCast2D",
				"enabled": check_node.enabled,
				"target_position": "Vector2(%s, %s)" % [check_node.target_position.x, check_node.target_position.y],
				"collision_mask": check_node.collision_mask,
			})
		elif check_node is RayCast3D:
			raycasts.append({
				"node_path": node_path,
				"type": "RayCast3D",
				"enabled": check_node.enabled,
				"target_position": "Vector3(%s, %s, %s)" % [check_node.target_position.x, check_node.target_position.y, check_node.target_position.z],
				"collision_mask": check_node.collision_mask,
			})

	info["collision_shapes"] = shapes
	info["raycasts"] = raycasts
	return info

# ============================================================================
# Registration helpers (Batch 2 physics)
# ============================================================================

func _register_setup_collision(server_core: RefCounted) -> void:
	server_core.register_tool(
		"setup_collision",
		"Add a CollisionShape2D or CollisionShape3D to a physics body or area node. Supports rectangle, circle, capsule, segment, convex (2D) and box, sphere, capsule, cylinder, convex (3D).",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string", "description": "Physics body or area node path."},
				"shape": {"type": "string", "description": "Shape name: rectangle/circle/capsule/segment/custom (2D) or box/sphere/capsule/cylinder/convex (3D)."},
				"dimension": {"type": "string", "description": "2d or 3d. Auto-detected from node context when omitted."},
				"width": {"type": "number", "description": "Width for rectangle/box."},
				"height": {"type": "number", "description": "Height for rectangle/box/capsule/cylinder."},
				"depth": {"type": "number", "description": "Depth for 3D box."},
				"radius": {"type": "number", "description": "Radius for circle/sphere/capsule/cylinder."},
				"points": {"type": "array", "description": "Array of [x,y] (2D) or [x,y,z] (3D) points for convex/custom shapes."},
				"disabled": {"type": "boolean", "description": "Start disabled. Default false."},
				"one_way_collision": {"type": "boolean", "description": "2D one-way collision. Default false."}
			},
			"required": ["node_path", "shape"],
			"additionalProperties": false
		},
		Callable(self, "_tool_setup_collision"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"shape_type": {"type": "string"},
				"dimension": {"type": "string"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "World"
	)

func _register_set_physics_layers(server_core: RefCounted) -> void:
	server_core.register_tool(
		"set_physics_layers",
		"Set collision_layer and/or collision_mask on a physics node. Accepts an integer bitmask or an array of layer numbers (1-32).",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"collision_layer": {"type": "integer", "description": "Layer bitmask or array of layer numbers."},
				"collision_mask": {"type": "integer", "description": "Mask bitmask or array of layer numbers."}
			},
			"required": ["node_path"],
			"additionalProperties": false
		},
		Callable(self, "_tool_set_physics_layers"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"collision_layer": {"type": "integer"},
				"collision_layer_info": {"type": "array"},
				"collision_mask": {"type": "integer"},
				"collision_mask_info": {"type": "array"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "World"
	)

func _register_get_physics_layers(server_core: RefCounted) -> void:
	server_core.register_tool(
		"get_physics_layers",
		"Read collision_layer and collision_mask from a physics node, including resolved layer names.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"}
			},
			"required": ["node_path"],
			"additionalProperties": false
		},
		Callable(self, "_tool_get_physics_layers"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"type": {"type": "string"},
				"collision_layer": {"type": "integer"},
				"collision_mask": {"type": "integer"}
			}
		},
		{"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "World"
	)

func _register_add_raycast(server_core: RefCounted) -> void:
	server_core.register_tool(
		"add_raycast",
		"Add a RayCast2D or RayCast3D to a node with configurable target position, collision mask, and hit settings.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"name": {"type": "string", "description": "Ray node name. Default 'RayCast'."},
				"dimension": {"type": "string", "description": "2d or 3d. Auto-detected when omitted."},
				"enabled": {"type": "boolean", "description": "Enabled on start. Default true."},
				"collision_mask": {"type": "integer", "description": "Collision mask bitmask. Default 1."},
				"collide_with_areas": {"type": "boolean", "description": "Hit areas. Default false."},
				"collide_with_bodies": {"type": "boolean", "description": "Hit bodies. Default true."},
				"hit_from_inside": {"type": "boolean", "description": "Detect from inside. Default false."},
				"target_x": {"type": "number", "description": "Target X. Default 0."},
				"target_y": {"type": "number", "description": "Target Y. Default 50 (2D) or -1 (3D)."},
				"target_z": {"type": "number", "description": "Target Z (3D). Default 0."}
			},
			"required": ["node_path"],
			"additionalProperties": false
		},
		Callable(self, "_tool_add_raycast"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"type": {"type": "string"},
				"target_position": {"type": "string"},
				"collision_mask": {"type": "integer"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "World"
	)

func _register_setup_physics_body(server_core: RefCounted) -> void:
	server_core.register_tool(
		"setup_physics_body",
		"Configure physics body properties. CharacterBody: motion_mode, floor_* settings, max_slides, slide_on_ceiling. RigidBody: mass, gravity_scale, damp, freeze, contact monitoring.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"motion_mode": {"type": "string", "description": "CharacterBody: grounded or floating."},
				"floor_stop_on_slope": {"type": "boolean"},
				"floor_max_angle": {"type": "number"},
				"floor_snap_length": {"type": "number"},
				"wall_min_slide_angle": {"type": "number"},
				"max_slides": {"type": "integer"},
				"slide_on_ceiling": {"type": "boolean"},
				"mass": {"type": "number"},
				"gravity_scale": {"type": "number"},
				"linear_damp": {"type": "number"},
				"angular_damp": {"type": "number"},
				"freeze": {"type": "boolean"},
				"freeze_mode": {"type": "string", "description": "RigidBody: static or kinematic."},
				"contact_monitor": {"type": "boolean"},
				"max_contacts_reported": {"type": "integer"}
			},
			"required": ["node_path"],
			"additionalProperties": false
		},
		Callable(self, "_tool_setup_physics_body"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"type": {"type": "string"},
				"applied": {"type": "object"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "World"
	)

func _register_get_collision_info(server_core: RefCounted) -> void:
	server_core.register_tool(
		"get_collision_info",
		"Read collision shapes, raycasts, layers, and body settings from a physics node (including children).",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"include_children": {"type": "boolean", "description": "Scan child nodes for shapes/raycasts. Default true."}
			},
			"required": ["node_path"],
			"additionalProperties": false
		},
		Callable(self, "_tool_get_collision_info"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"type": {"type": "string"},
				"collision_shapes": {"type": "array"},
				"raycasts": {"type": "array"}
			}
		},
		{"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "World"
	)

# ============================================================================
# Navigation tools (Batch 3)
# ============================================================================

func _is_3d_context(node: Node) -> bool:
	if node is Node3D:
		return true
	if node is Node2D:
		return false
	var parent := node.get_parent()
	while parent != null:
		if parent is Node3D:
			return true
		if parent is Node2D:
			return false
		parent = parent.get_parent()
	return false

func _tool_setup_navigation_region(params: Dictionary) -> Dictionary:
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var node: Node = _resolve_node_path(node_path)
	if not node:
		return {"error": "Node not found: " + node_path}

	var force_mode: String = String(params.get("mode", "auto"))
	var is_3d: bool
	match force_mode:
		"2d":
			is_3d = false
		"3d":
			is_3d = true
		_:
			is_3d = _is_3d_context(node)

	if is_3d:
		var region := NavigationRegion3D.new()
		region.name = String(params.get("name", "NavigationRegion3D"))
		var nav_mesh := NavigationMesh.new()
		nav_mesh.agent_radius = float(params.get("agent_radius", 0.5))
		nav_mesh.agent_height = float(params.get("agent_height", 1.5))
		nav_mesh.agent_max_climb = float(params.get("agent_max_climb", 0.25))
		nav_mesh.agent_max_slope = float(params.get("agent_max_slope", 45.0))
		nav_mesh.cell_size = float(params.get("cell_size", 0.25))
		nav_mesh.cell_height = float(params.get("cell_height", 0.25))
		region.navigation_mesh = nav_mesh
		if params.has("navigation_layers"):
			region.navigation_layers = int(params["navigation_layers"])
		var error: Dictionary = _add_child_with_undo(node, region, scene_root, "MCP: Add NavigationRegion3D")
		if not error.is_empty():
			return error
		return {
			"node_path": str(region.get_path()),
			"type": "NavigationRegion3D",
			"agent_radius": nav_mesh.agent_radius,
			"agent_height": nav_mesh.agent_height,
			"cell_size": nav_mesh.cell_size,
			"created": true
		}
	else:
		var region := NavigationRegion2D.new()
		region.name = String(params.get("name", "NavigationRegion2D"))
		var nav_poly := NavigationPolygon.new()
		if params.has("source_geometry_mode"):
			var mode_str: String = str(params["source_geometry_mode"])
			match mode_str:
				"root_node":
					nav_poly.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
				"groups_with_children":
					nav_poly.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
				"groups_explicit":
					nav_poly.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_EXPLICIT
		if params.has("cell_size"):
			nav_poly.cell_size = float(params["cell_size"])
		if params.has("agent_radius"):
			nav_poly.agent_radius = float(params["agent_radius"])
		region.navigation_polygon = nav_poly
		if params.has("navigation_layers"):
			region.navigation_layers = int(params["navigation_layers"])
		var error: Dictionary = _add_child_with_undo(node, region, scene_root, "MCP: Add NavigationRegion2D")
		if not error.is_empty():
			return error
		return {
			"node_path": str(region.get_path()),
			"type": "NavigationRegion2D",
			"cell_size": nav_poly.cell_size,
			"created": true
		}

func _tool_bake_navigation_mesh(params: Dictionary) -> Dictionary:
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var node: Node = _resolve_node_path(node_path)
	if not node:
		return {"error": "Node not found: " + node_path}

	if node is NavigationRegion3D:
		var region: NavigationRegion3D = node as NavigationRegion3D
		if region.navigation_mesh == null:
			return {"error": "NavigationRegion3D has no NavigationMesh resource"}
		region.bake_navigation_mesh()
		_mark_scene_unsaved()
		return {"node_path": node_path, "type": "NavigationRegion3D", "baked": true}
	elif node is NavigationRegion2D:
		var region: NavigationRegion2D = node as NavigationRegion2D
		if region.navigation_polygon == null:
			var nav_poly := NavigationPolygon.new()
			region.navigation_polygon = nav_poly
		if params.has("outline"):
			var outline_data: Array = params["outline"]
			var outline := PackedVector2Array()
			for point: Variant in outline_data:
				if point is Array and (point as Array).size() >= 2:
					outline.append(Vector2(float(point[0]), float(point[1])))
				elif point is Dictionary:
					outline.append(Vector2(float(point.get("x", 0)), float(point.get("y", 0))))
			if outline.size() >= 3:
				while region.navigation_polygon.get_outline_count() > 0:
					region.navigation_polygon.remove_outline(0)
				region.navigation_polygon.add_outline(outline)
				region.navigation_polygon.make_polygons_from_outlines()
				_mark_scene_unsaved()
				return {"node_path": node_path, "type": "NavigationRegion2D", "outline_vertices": outline.size(), "baked": true}
			else:
				return {"error": "Outline must have at least 3 vertices"}
		else:
			region.bake_navigation_polygon()
			_mark_scene_unsaved()
			return {"node_path": node_path, "type": "NavigationRegion2D", "baked": true}
	return {"error": "Node '" + node_path + "' is not a NavigationRegion2D or NavigationRegion3D"}

func _mark_scene_unsaved() -> void:
	var editor_interface: EditorInterface = _get_editor_interface()
	if editor_interface and editor_interface.has_method("mark_scene_as_unsaved"):
		editor_interface.mark_scene_as_unsaved()

func _tool_setup_navigation_agent(params: Dictionary) -> Dictionary:
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var node: Node = _resolve_node_path(node_path)
	if not node:
		return {"error": "Node not found: " + node_path}

	var force_mode: String = String(params.get("mode", "auto"))
	var is_3d: bool
	match force_mode:
		"2d":
			is_3d = false
		"3d":
			is_3d = true
		_:
			is_3d = _is_3d_context(node)

	var agent_name: String = String(params.get("name", "NavigationAgent3D" if is_3d else "NavigationAgent2D"))

	if is_3d:
		var agent := NavigationAgent3D.new()
		agent.name = agent_name
		if params.has("path_desired_distance"):
			agent.path_desired_distance = float(params["path_desired_distance"])
		if params.has("target_desired_distance"):
			agent.target_desired_distance = float(params["target_desired_distance"])
		if params.has("radius"):
			agent.radius = float(params["radius"])
		if params.has("neighbor_distance"):
			agent.neighbor_distance = float(params["neighbor_distance"])
		if params.has("max_neighbors"):
			agent.max_neighbors = int(params["max_neighbors"])
		if params.has("max_speed"):
			agent.max_speed = float(params["max_speed"])
		if params.has("avoidance_enabled"):
			agent.avoidance_enabled = bool(params["avoidance_enabled"])
		if params.has("navigation_layers"):
			agent.navigation_layers = int(params["navigation_layers"])
		var error: Dictionary = _add_child_with_undo(node, agent, scene_root, "MCP: Add NavigationAgent3D")
		if not error.is_empty():
			return error
		return {
			"node_path": str(agent.get_path()),
			"type": "NavigationAgent3D",
			"radius": agent.radius,
			"max_speed": agent.max_speed,
			"avoidance_enabled": agent.avoidance_enabled,
			"navigation_layers": agent.navigation_layers,
			"created": true
		}
	else:
		var agent := NavigationAgent2D.new()
		agent.name = agent_name
		if params.has("path_desired_distance"):
			agent.path_desired_distance = float(params["path_desired_distance"])
		if params.has("target_desired_distance"):
			agent.target_desired_distance = float(params["target_desired_distance"])
		if params.has("radius"):
			agent.radius = float(params["radius"])
		if params.has("neighbor_distance"):
			agent.neighbor_distance = float(params["neighbor_distance"])
		if params.has("max_neighbors"):
			agent.max_neighbors = int(params["max_neighbors"])
		if params.has("max_speed"):
			agent.max_speed = float(params["max_speed"])
		if params.has("avoidance_enabled"):
			agent.avoidance_enabled = bool(params["avoidance_enabled"])
		if params.has("navigation_layers"):
			agent.navigation_layers = int(params["navigation_layers"])
		var error: Dictionary = _add_child_with_undo(node, agent, scene_root, "MCP: Add NavigationAgent2D")
		if not error.is_empty():
			return error
		return {
			"node_path": str(agent.get_path()),
			"type": "NavigationAgent2D",
			"radius": agent.radius,
			"max_speed": agent.max_speed,
			"avoidance_enabled": agent.avoidance_enabled,
			"navigation_layers": agent.navigation_layers,
			"created": true
		}

func _tool_set_navigation_layers(params: Dictionary) -> Dictionary:
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var node: Node = _resolve_node_path(node_path)
	if not node:
		return {"error": "Node not found: " + node_path}

	var is_nav_node: bool = node is NavigationRegion2D or node is NavigationRegion3D or node is NavigationAgent2D or node is NavigationAgent3D
	if not is_nav_node:
		return {"error": "Node '" + node_path + "' is not a navigation region or agent"}

	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	var undo_redo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()

	if params.has("layers"):
		var layers_val: int = int(params["layers"])
		var old_l: Variant = node.get("navigation_layers")
		undo_redo.create_action("MCP: Set navigation layers")
		undo_redo.add_do_property(node, "navigation_layers", layers_val)
		undo_redo.add_undo_property(node, "navigation_layers", old_l)
		undo_redo.commit_action()
		editor_interface.mark_scene_as_unsaved()
		return {"node_path": node_path, "navigation_layers": layers_val, "updated": true}

	if params.has("layer_bits"):
		var bits: Array = params["layer_bits"]
		var current_layers: int = 0
		for bit: Variant in bits:
			var layer_num: int = int(bit)
			if layer_num >= 1 and layer_num <= 32:
				current_layers |= (1 << (layer_num - 1))
		var old_b: Variant = node.get("navigation_layers")
		undo_redo.create_action("MCP: Set navigation layers")
		undo_redo.add_do_property(node, "navigation_layers", current_layers)
		undo_redo.add_undo_property(node, "navigation_layers", old_b)
		undo_redo.commit_action()
		editor_interface.mark_scene_as_unsaved()
		return {"node_path": node_path, "navigation_layers": current_layers, "layer_bits": bits, "updated": true}

	if params.has("layer_names"):
		var names: Array = params["layer_names"]
		var current_layers: int = 0
		var is_2d: bool = node is NavigationRegion2D or node is NavigationAgent2D
		var prefix: String = "layer_names/2d_navigation/layer_" if is_2d else "layer_names/3d_navigation/layer_"
		for i in range(1, 33):
			var setting_key: String = prefix + str(i)
			if ProjectSettings.has_setting(setting_key):
				var layer_name: String = str(ProjectSettings.get_setting(setting_key))
				if layer_name in names:
					current_layers |= (1 << (i - 1))
		var old_n: Variant = node.get("navigation_layers")
		undo_redo.create_action("MCP: Set navigation layers")
		undo_redo.add_do_property(node, "navigation_layers", current_layers)
		undo_redo.add_undo_property(node, "navigation_layers", old_n)
		undo_redo.commit_action()
		editor_interface.mark_scene_as_unsaved()
		return {"node_path": node_path, "navigation_layers": current_layers, "layer_names": names, "updated": true}

	return {"error": "Must provide 'layers' (bitmask), 'layer_bits' (array of layer numbers), or 'layer_names' (array of named layers)"}

func _collect_navigation_nodes(node: Node, regions: Array, agents: Array) -> void:
	if node is NavigationRegion2D:
		var region: NavigationRegion2D = node as NavigationRegion2D
		var region_info: Dictionary = {
			"path": str(region.get_path()),
			"type": "NavigationRegion2D",
			"enabled": region.enabled,
			"navigation_layers": region.navigation_layers,
			"has_polygon": region.navigation_polygon != null
		}
		if region.navigation_polygon != null:
			var nav_poly: NavigationPolygon = region.navigation_polygon
			region_info["outline_count"] = nav_poly.get_outline_count()
			region_info["polygon_count"] = nav_poly.get_polygon_count()
			region_info["cell_size"] = nav_poly.cell_size
			region_info["agent_radius"] = nav_poly.agent_radius
		regions.append(region_info)
	elif node is NavigationRegion3D:
		var region: NavigationRegion3D = node as NavigationRegion3D
		var region_info: Dictionary = {
			"path": str(region.get_path()),
			"type": "NavigationRegion3D",
			"enabled": region.enabled,
			"navigation_layers": region.navigation_layers,
			"has_mesh": region.navigation_mesh != null
		}
		if region.navigation_mesh != null:
			var nav_mesh: NavigationMesh = region.navigation_mesh
			region_info["agent_radius"] = nav_mesh.agent_radius
			region_info["agent_height"] = nav_mesh.agent_height
			region_info["agent_max_climb"] = nav_mesh.agent_max_climb
			region_info["agent_max_slope"] = nav_mesh.agent_max_slope
			region_info["cell_size"] = nav_mesh.cell_size
			region_info["cell_height"] = nav_mesh.cell_height
		regions.append(region_info)
	if node is NavigationAgent2D:
		var agent: NavigationAgent2D = node as NavigationAgent2D
		agents.append({
			"path": str(agent.get_path()),
			"type": "NavigationAgent2D",
			"radius": agent.radius,
			"max_speed": agent.max_speed,
			"path_desired_distance": agent.path_desired_distance,
			"target_desired_distance": agent.target_desired_distance,
			"neighbor_distance": agent.neighbor_distance,
			"max_neighbors": agent.max_neighbors,
			"avoidance_enabled": agent.avoidance_enabled,
			"navigation_layers": agent.navigation_layers
		})
	elif node is NavigationAgent3D:
		var agent: NavigationAgent3D = node as NavigationAgent3D
		agents.append({
			"path": str(agent.get_path()),
			"type": "NavigationAgent3D",
			"radius": agent.radius,
			"max_speed": agent.max_speed,
			"path_desired_distance": agent.path_desired_distance,
			"target_desired_distance": agent.target_desired_distance,
			"neighbor_distance": agent.neighbor_distance,
			"max_neighbors": agent.max_neighbors,
			"avoidance_enabled": agent.avoidance_enabled,
			"navigation_layers": agent.navigation_layers
		})
	for child in node.get_children():
		_collect_navigation_nodes(child, regions, agents)

func _tool_get_navigation_info(params: Dictionary) -> Dictionary:
	var scene_root: Node = _get_user_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}
	var node_path: String = String(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "Missing required parameter: node_path"}
	var node: Node = _resolve_node_path(node_path)
	if not node:
		return {"error": "Node not found: " + node_path}

	var regions: Array = []
	var agents: Array = []
	_collect_navigation_nodes(node, regions, agents)

	var layer_names_2d: Dictionary = {}
	var layer_names_3d: Dictionary = {}
	for i in range(1, 33):
		var key_2d: String = "layer_names/2d_navigation/layer_" + str(i)
		var key_3d: String = "layer_names/3d_navigation/layer_" + str(i)
		if ProjectSettings.has_setting(key_2d):
			var name_2d: String = str(ProjectSettings.get_setting(key_2d))
			if not name_2d.is_empty():
				layer_names_2d[i] = name_2d
		if ProjectSettings.has_setting(key_3d):
			var name_3d: String = str(ProjectSettings.get_setting(key_3d))
			if not name_3d.is_empty():
				layer_names_3d[i] = name_3d

	return {
		"node_path": node_path,
		"regions": regions,
		"agents": agents,
		"region_count": regions.size(),
		"agent_count": agents.size(),
		"layer_names_2d": layer_names_2d,
		"layer_names_3d": layer_names_3d
	}

# ============================================================================
# Registration helpers (Batch 3 navigation)
# ============================================================================

func _register_setup_navigation_region(server_core: RefCounted) -> void:
	server_core.register_tool(
		"setup_navigation_region",
		"Create a NavigationRegion2D or NavigationRegion3D with configurable agent and cell properties.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string", "description": "Parent node path."},
				"name": {"type": "string", "description": "Region node name."},
				"mode": {"type": "string", "description": "auto, 2d, or 3d. Default auto (detected from context)."},
				"agent_radius": {"type": "number", "description": "Agent radius."},
				"agent_height": {"type": "number", "description": "Agent height (3D)."},
				"agent_max_climb": {"type": "number", "description": "Max climb (3D)."},
				"agent_max_slope": {"type": "number", "description": "Max slope degrees (3D)."},
				"cell_size": {"type": "number", "description": "Cell size."},
				"cell_height": {"type": "number", "description": "Cell height (3D)."},
				"navigation_layers": {"type": "integer", "description": "Navigation layers bitmask."},
				"source_geometry_mode": {"type": "string", "description": "2D: root_node, groups_with_children, or groups_explicit."}
			},
			"required": ["node_path"],
			"additionalProperties": false
		},
		Callable(self, "_tool_setup_navigation_region"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"type": {"type": "string"},
				"created": {"type": "boolean"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "World"
	)

func _register_bake_navigation_mesh(server_core: RefCounted) -> void:
	server_core.register_tool(
		"bake_navigation_mesh",
		"Bake a NavigationRegion3D navigation mesh or build a NavigationRegion2D polygon from an outline or source geometry.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string", "description": "NavigationRegion2D or NavigationRegion3D node path."},
				"outline": {"type": "array", "description": "2D: outline vertices as [[x,y], ...] to build polygons from."}
			},
			"required": ["node_path"],
			"additionalProperties": false
		},
		Callable(self, "_tool_bake_navigation_mesh"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"type": {"type": "string"},
				"baked": {"type": "boolean"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "World"
	)

func _register_setup_navigation_agent(server_core: RefCounted) -> void:
	server_core.register_tool(
		"setup_navigation_agent",
		"Create a NavigationAgent2D or NavigationAgent3D with pathfinding and avoidance settings.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"name": {"type": "string"},
				"mode": {"type": "string", "description": "auto, 2d, or 3d."},
				"path_desired_distance": {"type": "number"},
				"target_desired_distance": {"type": "number"},
				"radius": {"type": "number"},
				"neighbor_distance": {"type": "number"},
				"max_neighbors": {"type": "integer"},
				"max_speed": {"type": "number"},
				"avoidance_enabled": {"type": "boolean"},
				"navigation_layers": {"type": "integer"}
			},
			"required": ["node_path"],
			"additionalProperties": false
		},
		Callable(self, "_tool_setup_navigation_agent"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"type": {"type": "string"},
				"radius": {"type": "number"},
				"max_speed": {"type": "number"},
				"created": {"type": "boolean"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false},
		"supplementary", "World"
	)

func _register_set_navigation_layers(server_core: RefCounted) -> void:
	server_core.register_tool(
		"set_navigation_layers",
		"Set navigation_layers on a navigation region or agent. Accepts a bitmask, an array of layer numbers, or named layers from ProjectSettings.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"layers": {"type": "integer", "description": "Bitmask value."},
				"layer_bits": {"type": "array", "description": "Array of layer numbers (1-32)."},
				"layer_names": {"type": "array", "description": "Array of named layers."}
			},
			"required": ["node_path"],
			"additionalProperties": false
		},
		Callable(self, "_tool_set_navigation_layers"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"navigation_layers": {"type": "integer"},
				"updated": {"type": "boolean"}
			}
		},
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "World"
	)

func _register_get_navigation_info(server_core: RefCounted) -> void:
	server_core.register_tool(
		"get_navigation_info",
		"List navigation regions and agents under a node, including their properties and named layers.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"}
			},
			"required": ["node_path"],
			"additionalProperties": false
		},
		Callable(self, "_tool_get_navigation_info"),
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"regions": {"type": "array"},
				"agents": {"type": "array"},
				"region_count": {"type": "integer"},
				"agent_count": {"type": "integer"}
			}
		},
		{"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false},
		"supplementary", "World"
	)
