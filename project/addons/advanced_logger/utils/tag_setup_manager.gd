@tool
class_name TagSetupManager
extends RefCounted
## Manages tag setups for the Advanced Logger
##
## Centralizes creation, loading, updating, and deleting of tag configurations,
## supporting multiple named setups for different logging scenarios.

signal setup_changed(setup_name: String, is_new: bool)
signal setup_deleted(setup_name: String)
signal setup_renamed(old_name: String, new_name: String)

var _config: ConfigManager

## Initialize with config manager dependency
func _init(config_manager: ConfigManager) -> void:
	_config = config_manager

## Get a specific tag setup
## Returns an empty dictionary if setup doesn't exist
func get_setup(name: String) -> Dictionary:
	if name == null:
		if _config.get_show_editor_debug():
			print_rich("[color=#%s]ERROR: Attempted to get setup with null name[/color]" % [LoggerColors.ERROR_HTML])
		return {}
	if name.is_empty():
		if _config.get_show_editor_debug():
			print_rich("[color=#%s]ERROR: Attempted to get setup with empty name[/color]" % [LoggerColors.ERROR_HTML])
		return {}

	# Get all setups and print the available keys for debugging
	var all_setups = _config.get_all_tag_setups()
	var available_names = all_setups.keys()
	if _config.get_show_editor_debug():
		print_rich("[color=#%s]DEBUG: Available setup names: %s[/color]" % [LoggerColors.DEBUG_HTML, available_names])

	# Check if the exact name exists
	if all_setups.has(name):
		if _config.get_show_editor_debug():
			print_rich("[color=#%s]DEBUG: Found exact match for setup name: '%s'[/color]" % [LoggerColors.DEBUG_HTML, name])
		return _config.get_tag_setup(name)

	# If not found, try case-insensitive matching
	for setup_name in available_names:
		if setup_name.to_lower() == name.to_lower():
			if _config.get_show_editor_debug():
				print_rich("[color=#%s]DEBUG: Found case-insensitive match: '%s' for '%s'[/color]" %
					[LoggerColors.WARNING_HTML, setup_name, name])
			return _config.get_tag_setup(setup_name)

	# Not found
	if _config.get_show_editor_debug():
		print_rich("[color=#%s]WARNING: No matching setup found for name: '%s'[/color]" % [LoggerColors.WARNING_HTML, name])
	return {}

## Get all available tag setups
## Returns a dictionary of name -> setup data
func get_all_setups() -> Dictionary:
	return _config.get_all_tag_setups()

## Save a new or update existing setup
## Returns OK if successful, otherwise returns an error code
func save_setup(name: String, active_tags: Array[String], ignored_tags: Array[String]) -> Error:
	if name.is_empty():
		return ERR_INVALID_PARAMETER

	var setup_data = {
		"active_tags": active_tags.duplicate(),
		"ignored_tags": ignored_tags.duplicate()
	}

	var is_new = !get_all_setups().has(name)
	_config.set_tag_setup(name, setup_data)
	var result = _config.save()

	if result == OK:
		setup_changed.emit(name, is_new)

	return result

## Rename an existing setup
## Returns OK if successful, otherwise returns an error code
func rename_setup(old_name: String, new_name: String) -> Error:
	if old_name.is_empty() or new_name.is_empty() or old_name == new_name:
		return ERR_INVALID_PARAMETER

	# Get existing setup
	var setup = get_setup(old_name)
	if setup.is_empty():
		return ERR_DOES_NOT_EXIST

	# Delete old and create new
	_config.set_value(_config.SECTION_SETUPS, old_name, null)
	_config.set_tag_setup(new_name, setup)
	var result = _config.save()

	if result == OK:
		setup_renamed.emit(old_name, new_name)

	return result

## Delete a tag setup
## Returns OK if successful, otherwise returns an error code
func delete_setup(name: String) -> Error:
	if name.is_empty():
		return ERR_INVALID_PARAMETER

	if !get_all_setups().has(name):
		return ERR_DOES_NOT_EXIST

	_config.set_value(_config.SECTION_SETUPS, name, null)
	var result = _config.save()

	if result == OK:
		setup_deleted.emit(name)

	return result

## Create default setups if none exist
func create_default_setups() -> void:
	var setups = get_all_setups()
	if setups.is_empty():
		save_setup("default", [], [])
		save_setup("debug_network", ["network"], [])
		save_setup("errors_only", ["level:error", "level:critical"], ["level:debug", "level:info", "level:warning"])
