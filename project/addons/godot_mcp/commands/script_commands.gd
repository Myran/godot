@tool
class_name MCPScriptCommands
extends MCPBaseCommandProcessor

func process_command(client_id: int, command_type: String, params: Dictionary, command_id: String) -> bool:
	match command_type:
		"create_script":
			_create_script(client_id, params, command_id)
			return true
		"edit_script":
			_edit_script(client_id, params, command_id)
			return true
		"get_script":
			_get_script(client_id, params, command_id)
			return true
		"get_script_metadata":
			_get_script_metadata(client_id, params, command_id)
			return true
		"get_current_script":
			_get_current_script(client_id, params, command_id)
			return true
		"create_script_template":
			_create_script_template(client_id, params, command_id)
			return true
	return false  # Command not handled

func _create_script(client_id: int, params: Dictionary, command_id: String) -> void:
	var script_path = params.get("script_path", "")
	var content = params.get("content", "")
	var node_path = params.get("node_path", "")
	
	if script_path.is_empty():
		return _send_error(client_id, "Script path cannot be empty", command_id)
	
	if not script_path.begins_with("res://"):
		script_path = "res://" + script_path
	
	if not script_path.ends_with(".gd"):
		script_path += ".gd"
	
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _send_error(client_id, "GodotMCPPlugin not found in Engine metadata", command_id)
	
	var editor_interface = plugin.get_editor_interface()
	var script_editor = editor_interface.get_script_editor()
	
	var dir = script_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var err = DirAccess.make_dir_recursive_absolute(dir)
		if err != OK:
			return _send_error(client_id, "Failed to create directory: %s (Error code: %d)" % [dir, err], command_id)
	
	var file = FileAccess.open(script_path, FileAccess.WRITE)
	if file == null:
		return _send_error(client_id, "Failed to create script file: %s" % script_path, command_id)
	
	file.store_string(content)
	file = null  # Close the file
	
	editor_interface.get_resource_filesystem().scan()
	
	if not node_path.is_empty():
		var node = _get_editor_node(node_path)
		if not node:
			return _send_error(client_id, "Node not found: %s" % node_path, command_id)
		
		await get_tree().create_timer(0.5).timeout
		
		var script = load(script_path)
		if not script:
			return _send_error(client_id, "Failed to load script: %s" % script_path, command_id)
		
		var undo_redo = _get_undo_redo()
		if not undo_redo:
			node.set_script(script)
			_mark_scene_modified()
		else:
			undo_redo.create_action("Assign Script")
			undo_redo.add_do_method(node, "set_script", script)
			undo_redo.add_undo_method(node, "set_script", node.get_script())
			undo_redo.commit_action()
		
		_mark_scene_modified()
	
	var script_resource = load(script_path)
	if script_resource:
		editor_interface.edit_script(script_resource)
	
	_send_success(client_id, {
		"script_path": script_path,
		"node_path": node_path
	}, command_id)

func _edit_script(client_id: int, params: Dictionary, command_id: String) -> void:
	var script_path = params.get("script_path", "")
	var content = params.get("content", "")
	
	if script_path.is_empty():
		return _send_error(client_id, "Script path cannot be empty", command_id)
	
	if content.is_empty():
		return _send_error(client_id, "Content cannot be empty", command_id)
	
	if not script_path.begins_with("res://"):
		script_path = "res://" + script_path
	
	if not FileAccess.file_exists(script_path):
		return _send_error(client_id, "Script file not found: %s" % script_path, command_id)
	
	var file = FileAccess.open(script_path, FileAccess.WRITE)
	if file == null:
		return _send_error(client_id, "Failed to open script file: %s" % script_path, command_id)
	
	file.store_string(content)
	file = null  # Close the file
	
	_send_success(client_id, {
		"script_path": script_path
	}, command_id)

func _get_script(client_id: int, params: Dictionary, command_id: String) -> void:
	var script_path = params.get("script_path", "")
	var node_path = params.get("node_path", "")
	
	if script_path.is_empty() and node_path.is_empty():
		return _send_error(client_id, "Either script_path or node_path must be provided", command_id)
	
	if not node_path.is_empty():
		var node = _get_editor_node(node_path)
		if not node:
			return _send_error(client_id, "Node not found: %s" % node_path, command_id)
		
		var script = node.get_script()
		if not script:
			return _send_error(client_id, "Node does not have a script: %s" % node_path, command_id)
		
		script_path = script.resource_path
	
	if not script_path.begins_with("res://"):
		script_path = "res://" + script_path
	
	if not FileAccess.file_exists(script_path):
		return _send_error(client_id, "Script file not found: %s" % script_path, command_id)
	
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		return _send_error(client_id, "Failed to open script file: %s" % script_path, command_id)
	
	var content = file.get_as_text()
	file = null  # Close the file
	
	_send_success(client_id, {
		"script_path": script_path,
		"content": content
	}, command_id)

func _get_script_metadata(client_id: int, params: Dictionary, command_id: String) -> void:
	var path = params.get("path", "")
	
	if path.is_empty():
		return _send_error(client_id, "Script path cannot be empty", command_id)
	
	if not path.begins_with("res://"):
		path = "res://" + path
	
	if not FileAccess.file_exists(path):
		return _send_error(client_id, "Script file not found: " + path, command_id)
	
	var script = load(path)
	if not script:
		return _send_error(client_id, "Failed to load script: " + path, command_id)
	
	var metadata = {
		"path": path,
		"language": "gdscript" if path.ends_with(".gd") else "csharp" if path.ends_with(".cs") else "unknown"
	}
	
	var class_name_str = ""
	var extends_class = ""
	
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		
		var class_regex = RegEx.new()
		class_regex.compile("class_name\\s+([a-zA-Z_][a-zA-Z0-9_]*)")
		var result = class_regex.search(content)
		if result:
			class_name_str = result.get_string(1)
		
		var extends_regex = RegEx.new()
		extends_regex.compile("extends\\s+([a-zA-Z_][a-zA-Z0-9_]*)")
		result = extends_regex.search(content)
		if result:
			extends_class = result.get_string(1)
		
		metadata["class_name"] = class_name_str
		metadata["extends"] = extends_class
		
		var methods = []
		var signals = []
		
		var method_regex = RegEx.new()
		method_regex.compile("func\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(")
		var method_matches = method_regex.search_all(content)
		
		for match_result in method_matches:
			methods.append(match_result.get_string(1))
		
		var signal_regex = RegEx.new()
		signal_regex.compile("signal\\s+([a-zA-Z_][a-zA-Z0-9_]*)")
		var signal_matches = signal_regex.search_all(content)
		
		for match_result in signal_matches:
			signals.append(match_result.get_string(1))
		
		metadata["methods"] = methods
		metadata["signals"] = signals
	
	_send_success(client_id, metadata, command_id)

func _get_current_script(client_id: int, params: Dictionary, command_id: String) -> void:
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _send_error(client_id, "GodotMCPPlugin not found in Engine metadata", command_id)
	
	var editor_interface = plugin.get_editor_interface()
	var script_editor = editor_interface.get_script_editor()
	var current_script = script_editor.get_current_script()
	
	if not current_script:
		return _send_success(client_id, {
			"script_found": false,
			"message": "No script is currently being edited"
		}, command_id)
	
	var script_path = current_script.resource_path
	
	var file = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		return _send_error(client_id, "Failed to open script file: %s" % script_path, command_id)
	
	var content = file.get_as_text()
	file = null  # Close the file
	
	_send_success(client_id, {
		"script_found": true,
		"script_path": script_path,
		"content": content
	}, command_id)

func _create_script_template(client_id: int, params: Dictionary, command_id: String) -> void:
	var extends_type = params.get("extends_type", "Node")
	var class_name_str = params.get("class_name", "")
	var include_ready = params.get("include_ready", true)
	var include_process = params.get("include_process", false)
	var include_physics = params.get("include_physics", false)
	var include_input = params.get("include_input", false)
	
	var content = "extends " + extends_type + "\n\n"
	
	if not class_name_str.is_empty():
		content += "class_name " + class_name_str + "\n\n"
	
	content += "# Member variables here\n\n"
	
	if include_ready:
		content += "func _ready():\n\tpass\n\n"
	
	if include_process:
		content += "func _process(delta):\n\tpass\n\n"
	
	if include_physics:
		content += "func _physics_process(delta):\n\tpass\n\n"
	
	if include_input:
		content += "func _input(event):\n\tpass\n\n"
	
	_send_success(client_id, {
		"content": content
	}, command_id)
