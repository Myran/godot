@tool
extends EditorScript
## Helper script to ensure logger files are exported
## Run this script from the Godot editor before export

## Run the script to mark all logger files for export
func _run() -> void:
	print("\n=== Advanced Logger: Marking Files for Export ===")
	
	# Get the EditorExportPlugin class directly
	var editor_interface = EditorInterface.new()
	var ExportPlugin = load("res://addons/advanced_logger/advanced_logger_export_plugin.gd")
	
	if not ExportPlugin:
		push_error("Failed to load export plugin script")
		return
		
	# Core files that must be included
	var core_files = [
		"res://addons/advanced_logger/core/logger.gd",
		"res://addons/advanced_logger/core/logger_colors.gd",
		"res://addons/advanced_logger/core/log_formatter.gd",
		"res://addons/advanced_logger/core/ilogger.gd",
		"res://addons/advanced_logger/utils/config_manager.gd",
		"res://addons/advanced_logger/utils/tag_manager.gd",
		"res://addons/advanced_logger/utils/android_logger_helper.gd",
		"res://addons/advanced_logger/utils/ios_logger_helper.gd",
		"res://addons/advanced_logger/utils/export_verifier.gd",
		"res://addons/advanced_logger/settings.cfg"
	]
	
	# Get project settings
	var editor_settings = editor_interface.get_editor_settings()
	
	# Add each file to the export resources
	var export_resources = ProjectSettings.get_setting("editor/export/resources", [])
	var updated = false
	
	for file_path in core_files:
		if FileAccess.file_exists(file_path):
			if not export_resources.has(file_path):
				export_resources.append(file_path)
				updated = true
				print("Added to export resources: " + file_path)
			else:
				print("Already in export resources: " + file_path)
		else:
			push_warning("File does not exist: " + file_path)
	
	# Save the updated resources setting
	if updated:
		ProjectSettings.set_setting("editor/export/resources", export_resources)
		var save_result = ProjectSettings.save()
		if save_result == OK:
			print("Successfully saved project settings with export resources")
		else:
			push_error("Failed to save project settings: " + str(save_result))
	
	print("=== Logger Files Marked for Export ===\n")
