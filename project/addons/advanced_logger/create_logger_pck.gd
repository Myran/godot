@tool
extends EditorScript
## Script to create a standalone PCK for the logger
## Run this script from the Godot editor before exporting

func _run() -> void:
	print("\n=== Advanced Logger: Creating Standalone PCK ===")
	
	# Define the PCK output path
	var pck_path = "res://addons/advanced_logger/logger.pck"
	
	# Define files to include in the PCK
	var files_to_pack = [
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
	
	# Create PCK packer
	var packer = PCKPacker.new()
	var err = packer.pck_start(pck_path)
	
	if err != OK:
		push_error("Failed to start PCK packing: " + str(err))
		return
	
	# Add each file to the PCK
	var files_packed = 0
	for file_path in files_to_pack:
		if FileAccess.file_exists(file_path):
			err = packer.add_file(file_path, file_path)
			if err == OK:
				print("Added to PCK: " + file_path)
				files_packed += 1
			else:
				push_warning("Failed to add file to PCK: " + file_path + " (Error: " + str(err) + ")")
		else:
			push_warning("File does not exist: " + file_path)
	
	# Finish the PCK
	packer.flush(true)
	
	print("PCK created at: " + pck_path)
	print("Total files packed: " + str(files_packed) + "/" + str(files_to_pack.size()))
	
	# Now make sure the PCK itself is included in the export
	var export_files = ProjectSettings.get_setting("editor/export/resources", [])
	
	if not export_files.has(pck_path) and FileAccess.file_exists(pck_path):
		export_files.append(pck_path)
		ProjectSettings.set_setting("editor/export/resources", export_files)
		var save_result = ProjectSettings.save()
		
		if save_result == OK:
			print("Added PCK file to export resources list")
		else:
			push_error("Failed to save project settings: " + str(save_result))
	
	print("=== PCK Creation Complete ===\n")
