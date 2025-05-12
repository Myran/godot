@tool
extends EditorScript
## Script to update the iOS export preset to include the logger files
## Run this script from the Godot editor before exporting

func _run() -> void:
	print("\n=== Advanced Logger: Updating iOS Export Preset ===")
	
	# Path to the export presets file
	var preset_path = "res://export_presets.cfg"
	
	# Load the current export presets
	var config = ConfigFile.new()
	var err = config.load(preset_path)
	
	if err != OK:
		push_error("Failed to load export presets: " + str(err))
		return
	
	# Find the iOS preset
	var ios_preset_index = -1
	var section_name = ""
	
	for section in config.get_sections():
		if section.begins_with("preset.") and config.has_section_key(section, "platform"):
			var platform = config.get_value(section, "platform", "")
			if platform == "iOS":
				ios_preset_index = section.split(".")[1].to_int()
				section_name = section
				print("Found iOS export preset at index: " + str(ios_preset_index))
				break
	
	if ios_preset_index == -1:
		push_error("No iOS export preset found!")
		return
	
	# Get the current include filter
	var include_filter = config.get_value(section_name, "include_filter", "")
	print("Current include filter: '" + include_filter + "'")
	
	# Addon files to explicitly include
	var addon_files = [
		"addons/advanced_logger/*.gd", 
		"addons/advanced_logger/core/*.gd",
		"addons/advanced_logger/utils/*.gd",
		"addons/advanced_logger/settings.cfg"
	]
	
	# Check if our addon files are already included
	var updated = false
	for addon_pattern in addon_files:
		if not include_filter.contains(addon_pattern):
			if include_filter.length() > 0 and not include_filter.ends_with(","):
				include_filter += ", "
			include_filter += addon_pattern
			updated = true
	
	if updated:
		# Save the updated include filter
		config.set_value(section_name, "include_filter", include_filter)
		err = config.save(preset_path)
		
		if err == OK:
			print("Successfully updated iOS export preset with include filter: '" + include_filter + "'")
		else:
			push_error("Failed to save export preset: " + str(err))
	else:
		print("Include filter already contains all required patterns - no changes needed")
	
	print("=== iOS Export Preset Update Complete ===\n")
