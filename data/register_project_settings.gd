@tool
extends EditorScript

## Script to register project settings for the refactored data source implementation.
## Run this script from the editor to ensure all required settings are registered.

func _run() -> void:
	print("Registering GameTwo project settings...")
	
	# Data file paths
	_register_setting(
		"gametwo/data/default_db_file",
		"res://resources/data.json",
		TYPE_STRING,
		PROPERTY_HINT_FILE,
		"*.json",
		"Path to the default JSON database file"
	)
	
	_register_setting(
		"gametwo/data/battle_db_file",
		"res://resources/gameone-577cb-export.json",
		TYPE_STRING,
		PROPERTY_HINT_FILE,
		"*.json",
		"Path to the battle database JSON file"
	)
	
	# Sheets ID
	_register_setting(
		"gametwo/data/sheets_id",
		"1WTKwZ8aXSeQVEVT8qeNtwUZepVZh7wv5skRGn_zFUsY",
		TYPE_STRING,
		PROPERTY_HINT_NONE,
		"",
		"Identifier for the Google Sheets document in JSON structure"
	)
	
	# Cache settings
	_register_setting(
		"gametwo/data/cache_ttl_seconds",
		300,  # 5 minutes default TTL
		TYPE_INT,
		PROPERTY_HINT_RANGE,
		"0,3600,1",
		"Time-to-live for cached data in seconds (0 = no expiration)"
	)
	
	_register_setting(
		"gametwo/data/use_cache",
		true,
		TYPE_BOOL,
		PROPERTY_HINT_NONE,
		"",
		"Whether to use caching for data collections"
	)
	
	print("GameTwo project settings registered successfully.")

## Helper function to register a project setting if it doesn't exist
func _register_setting(name: String, default_value: Variant, type: int, hint: int = PROPERTY_HINT_NONE, hint_string: String = "", description: String = "") -> void:
	if not ProjectSettings.has_setting(name):
		ProjectSettings.set_setting(name, default_value)
		ProjectSettings.set_initial_value(name, default_value)
		ProjectSettings.add_property_info({
			"name": name,
			"type": type,
			"hint": hint,
			"hint_string": hint_string
		})
		
		print("Registered setting: " + name)
	else:
		print("Setting already exists: " + name)
		
	# Ensure the setting has the correct metadata
	ProjectSettings.set_as_basic(name, true)
	
	# Add to favorites for easy discovery
	var favorites = ProjectSettings.get_favorites() if ProjectSettings.has_method("get_favorites") else []
	if not (name in favorites):
		favorites.append(name)
		if ProjectSettings.has_method("set_favorites"):
			ProjectSettings.set_favorites(favorites)
	
	# Add the description as a comment in the project.godot file
	var property_info = {
		"name": name,
		"type": type,
		"hint": hint,
		"hint_string": hint_string
	}
	
	if not description.is_empty():
		property_info["description"] = description
		
	ProjectSettings.add_property_info(property_info)
	
	# Save the project settings to ensure changes are persisted
	ProjectSettings.save()
