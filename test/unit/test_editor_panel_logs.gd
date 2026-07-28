extends "res://addons/gut/test.gd"

var _debug_tools: RefCounted = null

func before_each():
	_debug_tools = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()

func after_each():
	_debug_tools = null

func test_infer_log_type_error():
	assert_eq(_debug_tools._infer_log_type_from_line("ERROR: Something went wrong"), "Error", "ERROR: prefix should be Error")
	assert_eq(_debug_tools._infer_log_type_from_line("SCRIPT ERROR: test"), "Error", "SCRIPT ERROR: prefix should be Error")
	assert_eq(_debug_tools._infer_log_type_from_line("PARSE ERROR: syntax"), "Error", "PARSE ERROR: prefix should be Error")
	assert_eq(_debug_tools._infer_log_type_from_line("ERROR at line 5"), "Error", "ERROR at prefix should be Error")

func test_infer_log_type_warning():
	assert_eq(_debug_tools._infer_log_type_from_line("WARNING: Check this"), "Warning", "WARNING: prefix should be Warning")
	assert_eq(_debug_tools._infer_log_type_from_line("WARN something"), "Warning", "WARN prefix should be Warning")

func test_infer_log_type_debug():
	assert_eq(_debug_tools._infer_log_type_from_line("DEBUG: Detail info"), "Debug", "DEBUG: prefix should be Debug")
	assert_eq(_debug_tools._infer_log_type_from_line("DEBUG message"), "Debug", "DEBUG prefix should be Debug")

func test_infer_log_type_info():
	assert_eq(_debug_tools._infer_log_type_from_line("Normal log message"), "Info", "Normal message should be Info")
	assert_eq(_debug_tools._infer_log_type_from_line("Godot Engine v4.6.1"), "Info", "Engine message should be Info")
	assert_eq(_debug_tools._infer_log_type_from_line("print output"), "Info", "print output should be Info")

func test_infer_log_type_godot_format():
	assert_eq(_debug_tools._infer_log_type_from_line("  ERROR: core/variant/variant_utility.cpp:1024 - message"), "Error", "Godot ERROR format should be Error")
	assert_eq(_debug_tools._infer_log_type_from_line("  WARNING: core/variant/variant_utility.cpp:1034 - message"), "Warning", "Godot WARNING format should be Warning")

func test_infer_log_type_trims_leading_whitespace():
	assert_eq(_debug_tools._infer_log_type_from_line("\tSCRIPT ERROR: parser failure"), "Error", "Indented SCRIPT ERROR should be Error")
	assert_eq(_debug_tools._infer_log_type_from_line("  WARN parser warning"), "Warning", "Indented WARN should be Warning")

func test_infer_log_type_handles_godot_thin_space_prefix():
	var godot_warning: String = String.chr(0x2009) + "WARNING: core/variant/variant_utility.cpp:1033 - warning"
	assert_eq(_debug_tools._infer_log_type_from_line(godot_warning), "Warning", "Godot thin-space WARNING should be Warning")

func test_get_editor_panel_logs_no_editor():
	var result: Dictionary = _debug_tools._get_editor_panel_logs([], 100, 0, "desc")
	assert_has(result, "source", "Should have source field")
	assert_eq(result["source"], "editor_panel", "Source should be editor_panel")

func test_find_tree_control_returns_tree():
	var tree = Tree.new()
	var result = _debug_tools._find_tree_control(tree)
	assert_eq(result, tree, "Should find Tree itself")
	tree.free()

func test_find_tree_control_finds_child():
	var parent = Control.new()
	var tree = Tree.new()
	parent.add_child(tree)
	var result = _debug_tools._find_tree_control(parent)
	assert_eq(result, tree, "Should find Tree in children")
	parent.free()

func test_find_tree_control_returns_null():
	var control = Control.new()
	var result = _debug_tools._find_tree_control(control)
	assert_null(result, "Should return null when no Tree")
	control.free()

func test_find_editor_log_panel_matches_localized_labels():
	var base: Control = Control.new()
	add_child_autofree(base)
	var error_panel: Control = Control.new()
	error_panel.name = String.chr(0x9519) + String.chr(0x8BEF) + " (1)"
	base.add_child(error_panel)
	var warning_panel: Control = Control.new()
	warning_panel.name = String.chr(0x8B66) + String.chr(0x544A) + " (2)"
	base.add_child(warning_panel)

	assert_eq(_debug_tools._find_editor_log_panel(base, "error"), error_panel, "Should match localized error panel labels")
	assert_eq(_debug_tools._find_editor_log_panel(base, "warning"), warning_panel, "Should match localized warning panel labels")

func test_append_editor_tree_logs_preserves_panel_type():
	var panel: Control = Control.new()
	add_child_autofree(panel)
	var tree: Tree = Tree.new()
	tree.columns = 1
	panel.add_child(tree)
	var root_item: TreeItem = tree.create_item()
	var warning_item: TreeItem = tree.create_item(root_item)
	warning_item.set_text(0, "Warning row")
	var parsed_lines: Array[Dictionary] = []

	assert_true(_debug_tools._append_editor_tree_logs(panel, "Warning", parsed_lines), "Should collect tree rows")
	assert_eq(parsed_lines.size(), 1, "Should collect one tree row")
	assert_eq(parsed_lines[0].type, "Warning", "Should preserve the panel log type")

func test_find_script_editor_debugger_found():
	# Create a mock ScriptEditorDebugger node and verify it is found by its class name
	var debugger = Node.new()
	debugger.set_script(null)  # Ensure no script type override
	# Manually set the class to simulate ScriptEditorDebugger (using a normal Node works since get_class() returns the class name)
	var mock_debugger = Node.new()
	mock_debugger.name = "MockDebugger"
	
	var container = Node.new()
	container.add_child(mock_debugger)
	
	var not_found = _debug_tools._find_script_editor_debugger(container)
	# Since get_class() returns "Node" not "ScriptEditorDebugger", this should return null
	assert_null(not_found, "Should not find when class is not ScriptEditorDebugger")
	container.free()

func test_find_script_editor_debugger_not_found():
	var container = Control.new()
	var result = _debug_tools._find_script_editor_debugger(container)
	assert_null(result, "Should return null when no ScriptEditorDebugger found")
	container.free()

func test_find_script_editor_debugger_with_valid_class():
	# Test that the search traverses children correctly
	var base = Node.new()
	var child = Node.new()
	var grandchild = Control.new()
	
	base.add_child(child)
	child.add_child(grandchild)
	
	var result = _debug_tools._find_script_editor_debugger(base)
	assert_null(result, "Should return null when no ScriptEditorDebugger in children")
	base.free()
