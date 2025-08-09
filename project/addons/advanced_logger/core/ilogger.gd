@tool
class_name ILogger
extends RefCounted


func debug(_message: String, _context: Dictionary = {}, _tags: Array[String] = []) -> void:
	pass


func info(_message: String, _context: Dictionary = {}, _tags: Array[String] = []) -> void:
	pass


func warning(_message: String, _context: Dictionary = {}, _tags: Array[String] = []) -> void:
	pass


func error(_message: String, _context: Dictionary = {}, _tags: Array[String] = []) -> void:
	pass


func critical(_message: String, _context: Dictionary = {}, _tags: Array[String] = []) -> void:
	pass


func set_level(_level: int) -> Error:
	return Error.FAILED


func get_level() -> int:
	return 0


func add_tag(_tag: String) -> Error:
	return Error.FAILED


func remove_tag(_tag: String) -> Error:
	return Error.FAILED


func clear_tags() -> void:
	pass


func add_ignored_tag(_tag: String) -> Error:
	return Error.FAILED


func remove_ignored_tag(_tag: String) -> Error:
	return Error.FAILED


func clear_ignored_tags() -> void:
	pass


func set_show_timestamp(_show: bool) -> void:
	pass


func set_show_tags(_show: bool) -> void:
	pass


func set_use_colors(_use: bool) -> void:
	pass


func set_show_source(_show: bool) -> void:
	pass
