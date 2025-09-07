@tool
class_name MCPBaseCommandProcessor
extends Node

const GODOT_MCP_PLUGIN_META_KEY = "GodotMCPPlugin"

signal command_completed(client_id, command_type, result, command_id)

var _websocket_server: EditorPlugin = null

func process_command(client_id: int, command_type: String, params: Dictionary, command_id: String) -> bool:
	push_error("BaseCommandProcessor.process_command called directly")
	return false

func _send_success(client_id: int, result: Dictionary, command_id: String) -> void:
	var response: Dictionary = {
		"status": "success",
		"result": result
	}
	
	if not command_id.is_empty():
		response["commandId"] = command_id
	
	command_completed.emit(client_id, "success", result, command_id)
	
	if _websocket_server:
		_websocket_server.send_response(client_id, response)

func _send_error(client_id: int, message: String, command_id: String) -> void:
	var response: Dictionary = {
		"status": "error",
		"message": message
	}
	
	if not command_id.is_empty():
		response["commandId"] = command_id
	
	var error_result: Dictionary = {"error": message}
	command_completed.emit(client_id, "error", error_result, command_id)
	
	if _websocket_server:
		_websocket_server.send_response(client_id, response)
	print("Error: %s" % message)

func _get_editor_node(path: String) -> Node:
	var plugin: EditorPlugin = Engine.get_meta(GODOT_MCP_PLUGIN_META_KEY)
	if not plugin:
		print(GODOT_MCP_PLUGIN_META_KEY + " not found in Engine metadata")
		return null
		
	var editor_interface: EditorInterface = plugin.get_editor_interface()
	var edited_scene_root: Node = editor_interface.get_edited_scene_root()
	
	if not edited_scene_root:
		print("No edited scene found")
		return null
		
	if path == "/root" or path == "":
		return edited_scene_root
		
	if path.begins_with("/root/"):
		path = path.substr(6)  # Remove "/root/"
	elif path.begins_with("/"):
		path = path.substr(1)  # Remove leading "/"
	
	return edited_scene_root.get_node_or_null(path)

func _mark_scene_modified() -> void:
	var plugin: EditorPlugin = Engine.get_meta(GODOT_MCP_PLUGIN_META_KEY)
	if not plugin:
		print(GODOT_MCP_PLUGIN_META_KEY + " not found in Engine metadata")
		return
	
	var editor_interface: EditorInterface = plugin.get_editor_interface()
	var edited_scene_root: Node = editor_interface.get_edited_scene_root()
	
	if edited_scene_root:
		editor_interface.mark_scene_as_unsaved()

func _get_undo_redo() -> EditorUndoRedoManager:
	var plugin: EditorPlugin = Engine.get_meta(GODOT_MCP_PLUGIN_META_KEY)
	if not plugin or not plugin.has_method("get_undo_redo"):
		print("Cannot access UndoRedo from plugin")
		return null
		
	return plugin.get_undo_redo()

func _is_safe_expression(value: String) -> bool:
	# Security: Only allow safe Godot type constructors
	var allowed_prefixes: Array[String] = [
		"Vector", "Transform", "Rect", "Color", "Quat", "Basis", 
		"Plane", "AABB", "Projection", "PackedVector", "PackedString", 
		"PackedFloat", "PackedInt", "PackedColor", "PackedByteArray",
		"Dictionary", "Array"
	]
	
	# Check for allowed prefixes
	var has_allowed_prefix: bool = false
	for prefix in allowed_prefixes:
		if value.begins_with(prefix):
			has_allowed_prefix = true
			break
	
	if not has_allowed_prefix:
		return false
	
	# Security: Reject potentially dangerous patterns
	var dangerous_patterns: Array[String] = [
		"Engine.", "OS.", "ProjectSettings.", "get_singleton",
		"load(", "preload(", "ResourceLoader.", "FileAccess.",
		"DirAccess.", "ClassDB."
	]
	
	for pattern in dangerous_patterns:
		if pattern in value:
			print("Security: Rejected potentially dangerous expression: %s" % value)
			return false
	
	return true

func _parse_property_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_STRING and _is_safe_expression(value):
		var expression: Expression = Expression.new()
		var error: int = expression.parse(value, [])
		
		if error == OK:
			var result: Variant = expression.execute([], null, true)
			if not expression.has_execute_failed():
				print("Successfully parsed %s as %s" % [value, result])
				return result
			else:
				print("Failed to execute expression for: %s" % value)
		else:
			print("Failed to parse expression: %s (Error: %d)" % [value, error])
	
	return value
