@tool
class_name MCPNodeCommands
extends MCPBaseCommandProcessor

func process_command(client_id: int, command_type: String, params: Dictionary, command_id: String) -> bool:
	match command_type:
		"create_node":
			_create_node(client_id, params, command_id)
			return true
		"delete_node":
			_delete_node(client_id, params, command_id)
			return true
		"update_node_property":
			_update_node_property(client_id, params, command_id)
			return true
		"get_node_properties":
			_get_node_properties(client_id, params, command_id)
			return true
		"list_nodes":
			_list_nodes(client_id, params, command_id)
			return true
	return false  # Command not handled

func _create_node(client_id: int, params: Dictionary, command_id: String) -> void:
	var parent_path: String = params.get("parent_path", "/root")
	var node_type: String = params.get("node_type", "Node")
	var node_name: String = params.get("node_name", "NewNode")
	
	if not ClassDB.class_exists(node_type):
		return _send_error(client_id, "Invalid node type: %s" % node_type, command_id)
	
	var plugin: EditorPlugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _send_error(client_id, "GodotMCPPlugin not found in Engine metadata", command_id)
	
	var editor_interface: EditorInterface = plugin.get_editor_interface()
	var edited_scene_root: Node = editor_interface.get_edited_scene_root()
	
	if not edited_scene_root:
		return _send_error(client_id, "No scene is currently being edited", command_id)
	
	var parent: Node = _get_editor_node(parent_path)
	if not parent:
		return _send_error(client_id, "Parent node not found: %s" % parent_path, command_id)
	
	var node: Node
	if ClassDB.can_instantiate(node_type):
		node = ClassDB.instantiate(node_type)
	else:
		return _send_error(client_id, "Cannot instantiate node of type: %s" % node_type, command_id)
	
	if not node:
		return _send_error(client_id, "Failed to create node of type: %s" % node_type, command_id)
	
	node.name = node_name
	
	parent.add_child(node)
	
	node.owner = edited_scene_root
	
	_mark_scene_modified()
	
	_send_success(client_id, {
		"node_path": parent_path + "/" + node_name
	}, command_id)

func _delete_node(client_id: int, params: Dictionary, command_id: String) -> void:
	var node_path: String = params.get("node_path", "")
	
	if node_path.is_empty():
		return _send_error(client_id, "Node path cannot be empty", command_id)
	
	var plugin: EditorPlugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _send_error(client_id, "GodotMCPPlugin not found in Engine metadata", command_id)
	
	var editor_interface: EditorInterface = plugin.get_editor_interface()
	var edited_scene_root: Node = editor_interface.get_edited_scene_root()
	
	if not edited_scene_root:
		return _send_error(client_id, "No scene is currently being edited", command_id)
	
	var node: Node = _get_editor_node(node_path)
	if not node:
		return _send_error(client_id, "Node not found: %s" % node_path, command_id)
	
	if node == edited_scene_root:
		return _send_error(client_id, "Cannot delete the root node", command_id)
	
	var parent: Node = node.get_parent()
	if not parent:
		return _send_error(client_id, "Node has no parent: %s" % node_path, command_id)
	
	parent.remove_child(node)
	node.queue_free()
	
	_mark_scene_modified()
	
	_send_success(client_id, {
		"deleted_node_path": node_path
	}, command_id)

func _update_node_property(client_id: int, params: Dictionary, command_id: String) -> void:
	var node_path: String = params.get("node_path", "")
	var property_name: String = params.get("property", "")
	var property_value: Variant = params.get("value")
	
	if node_path.is_empty():
		return _send_error(client_id, "Node path cannot be empty", command_id)
	
	if property_name.is_empty():
		return _send_error(client_id, "Property name cannot be empty", command_id)
	
	if property_value == null:
		return _send_error(client_id, "Property value cannot be null", command_id)
	
	var plugin: EditorPlugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return _send_error(client_id, "GodotMCPPlugin not found in Engine metadata", command_id)
	
	var node: Node = _get_editor_node(node_path)
	if not node:
		return _send_error(client_id, "Node not found: %s" % node_path, command_id)
	
	if not property_name in node:
		return _send_error(client_id, "Property %s does not exist on node %s" % [property_name, node_path], command_id)
	
	var parsed_value: Variant = _parse_property_value(property_value)
	
	var old_value: Variant = node.get(property_name)
	
	var undo_redo: EditorUndoRedoManager = _get_undo_redo()
	if not undo_redo:
		node.set(property_name, parsed_value)
		_mark_scene_modified()
	else:
		undo_redo.create_action("Update Property: " + property_name)
		undo_redo.add_do_property(node, property_name, parsed_value)
		undo_redo.add_undo_property(node, property_name, old_value)
		undo_redo.commit_action()
	
	_mark_scene_modified()
	
	_send_success(client_id, {
		"node_path": node_path,
		"property": property_name,
		"value": property_value,
		"parsed_value": str(parsed_value)
	}, command_id)

func _get_node_properties(client_id: int, params: Dictionary, command_id: String) -> void:
	var node_path: String = params.get("node_path", "")
	
	if node_path.is_empty():
		return _send_error(client_id, "Node path cannot be empty", command_id)
	
	var node: Node = _get_editor_node(node_path)
	if not node:
		return _send_error(client_id, "Node not found: %s" % node_path, command_id)
	
	var properties: Dictionary = {}
	var property_list: Array[Dictionary] = node.get_property_list()
	
	for prop in property_list:
		var name: String = prop["name"]
		if not name.begins_with("_"):  # Skip internal properties
			properties[name] = node.get(name)
	
	_send_success(client_id, {
		"node_path": node_path,
		"properties": properties
	}, command_id)

func _list_nodes(client_id: int, params: Dictionary, command_id: String) -> void:
	var parent_path: String = params.get("parent_path", "/root")
	
	var parent: Node = _get_editor_node(parent_path)
	if not parent:
		return _send_error(client_id, "Parent node not found: %s" % parent_path, command_id)
	
	var children: Array[Dictionary] = []
	for child in parent.get_children():
		children.append({
			"name": child.name,
			"type": child.get_class(),
			"path": str(child.get_path()).replace(str(parent.get_path()), parent_path)
		})
	
	_send_success(client_id, {
		"parent_path": parent_path,
		"children": children
	}, command_id)
