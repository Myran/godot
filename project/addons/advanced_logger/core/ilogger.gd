@tool
class_name ILogger
extends RefCounted
## Interface for Logger implementations
##
## Defines the common interface that all logger implementations should follow.
## This enables easier extension and alternative implementations.


## Log a debug message
## Parameters:
## - message: The message to log
## - context: Optional context information (JSON-serializable dictionary)
## - tags: Optional tags for filtering
func debug(_message: String, _context: Dictionary = {}, _tags: Array[String] = []) -> void:
	pass


## Log an info message
## Parameters:
## - message: The message to log
## - context: Optional context information (JSON-serializable dictionary)
## - tags: Optional tags for filtering
func info(_message: String, _context: Dictionary = {}, _tags: Array[String] = []) -> void:
	pass


## Log a warning message
## Parameters:
## - message: The message to log
## - context: Optional context information (JSON-serializable dictionary)
## - tags: Optional tags for filtering
func warning(_message: String, _context: Dictionary = {}, _tags: Array[String] = []) -> void:
	pass


## Log an error message
## Parameters:
## - message: The message to log
## - context: Optional context information (JSON-serializable dictionary)
## - tags: Optional tags for filtering
func error(_message: String, _context: Dictionary = {}, _tags: Array[String] = []) -> void:
	pass


## Log a critical message
## Parameters:
## - message: The message to log
## - context: Optional context information (JSON-serializable dictionary)
## - tags: Optional tags for filtering
func critical(_message: String, _context: Dictionary = {}, _tags: Array[String] = []) -> void:
	pass


## Set the minimum log level
## Parameters:
## - level: The minimum log level to display
func set_level(_level: int) -> Error:
	return Error.FAILED


## Get the current minimum log level
func get_level() -> int:
	return 0


## Add a tag to the active tags list
## Parameters:
## - tag: The tag to add
## Returns: OK if successful, otherwise an error code
func add_tag(_tag: String) -> Error:
	return Error.FAILED


## Remove a tag from the active tags list
## Parameters:
## - tag: The tag to remove
## Returns: OK if successful, otherwise an error code
func remove_tag(_tag: String) -> Error:
	return Error.FAILED


## Clear all active tags
func clear_tags() -> void:
	pass


## Add a tag to the ignored tags list
## Parameters:
## - tag: The tag to add
## Returns: OK if successful, otherwise an error code
func add_ignored_tag(_tag: String) -> Error:
	return Error.FAILED


## Remove a tag from the ignored tags list
## Parameters:
## - tag: The tag to remove
## Returns: OK if successful, otherwise an error code
func remove_ignored_tag(_tag: String) -> Error:
	return Error.FAILED


## Clear all ignored tags
func clear_ignored_tags() -> void:
	pass


## Set whether to show timestamps in log output
## Parameters:
## - show: Whether to show timestamps
func set_show_timestamp(_show: bool) -> void:
	pass


## Set whether to show tags in log output
## Parameters:
## - show: Whether to show tags
func set_show_tags(_show: bool) -> void:
	pass


## Set whether to use colors in log output
## Parameters:
## - use: Whether to use colors
func set_use_colors(_use: bool) -> void:
	pass


## Set whether to show source information in log output
## Parameters:
## - show: Whether to show source information
func set_show_source(_show: bool) -> void:
	pass
