@tool
class_name MCPEditorScriptCommands
extends MCPBaseCommandProcessor

func process_command(client_id: int, command_type: String, params: Dictionary, command_id: String) -> bool:
	match command_type:
		"execute_editor_script":
			_execute_editor_script(client_id, params, command_id)
			return true
	return false  # Command not handled

func _execute_editor_script(client_id: int, params: Dictionary, command_id: String) -> void:
	var code: String = params.get("code", "")

	if code.is_empty():
		return _send_error(client_id, "Code cannot be empty", command_id)

	var script_node := Node.new()
	script_node.name = "EditorScriptExecutor"
	add_child(script_node)

	var script: Script = GDScript.new()

	var output: Array = []
	var error_message: String = ""
	var execution_result: Variant = null

	var modified_code: String = _replace_print_calls(code)

	var script_content: String = """@tool
extends Node

signal execution_completed

var result: int = null
var _output_array: Array = []
var _error_message: String = ""
var _parent

func custom_print(values: Array) -> void:
	var output_str: String = ""
	if values is Array:
		for i in range(values.size()):
			if i > 0:
				output_str += " "
			output_str += str(values[i])
	else:
		output_str = str(values)

	_output_array.append(output_str)
	print(output_str)  # Still print to the console for debugging

func run() -> void:
	print("Executing script... ready func")
	_parent = get_parent()
	var scene: Node = get_tree().edited_scene_root

	var err: int = _execute_code()

	if err != OK:
		_error_message = "Failed to execute script with error: " + str(err)

	execution_completed.emit()

func _execute_code() -> int:
{user_code}
	return OK
"""

	var processed_lines: Array[String] = []
	var lines: PackedStringArray = modified_code.split("\n")
	for line in lines:
		var processed_line: String = line

		var space_count: int = 0
		for i in range(line.length()):
			if line[i] == " ":
				space_count += 1
			else:
				break

		if space_count > 0:
			var tabs: String = ""
			for _i in range(space_count / 4): # Integer division
				tabs += "\t"
			processed_line = tabs + line.substr(space_count)

		processed_lines.append(processed_line)

	var indented_code: String = ""
	for line in processed_lines:
		indented_code += "\t" + line + "\n"

	script_content = script_content.replace("{user_code}", indented_code)
	script.source_code = script_content

	var error: Error = script.reload()
	if error != OK:
		remove_child(script_node)
		script_node.queue_free()
		return _send_error(client_id, "Script parsing error: " + str(error), command_id)

	script_node.set_script(script)

	script_node.connect("execution_completed", _on_script_execution_completed.bind(script_node, client_id, command_id))

	script_node.run()


func _on_script_execution_completed(script_node: Node, client_id: int, command_id: String) -> void:
	var execution_result: Variant = script_node.get("result")
	var output: Array = script_node._output_array
	var error_message: String = script_node._error_message

	remove_child(script_node)
	script_node.queue_free()

	var result_data: Dictionary = {
		"success": error_message.is_empty(),
		"output": output
	}

	print("result_data: ", result_data)

	if not error_message.is_empty():
		result_data["error"] = error_message
	elif execution_result != null:
		result_data["result"] = execution_result

	_send_success(client_id, result_data, command_id)

func _replace_print_calls(code: String) -> String:
	var regex: RegEx = RegEx.new()
	regex.compile("print\\s*\\(([^\\)]+)\\)")

	var result: Array[RegExMatch] = regex.search_all(code)
	var modified_code: String = code

	for i in range(result.size() - 1, -1, -1):
		var match_obj: RegExMatch = result[i]
		var full_match: String = match_obj.get_string()
		var arg_content: String = match_obj.get_string(1)

		var replacement: String = "custom_print([" + arg_content + ")"

		var start: int = match_obj.get_start()
		var end: int = match_obj.get_end()

		modified_code = modified_code.left(start) + replacement + modified_code.substr(end)

	return modified_code
