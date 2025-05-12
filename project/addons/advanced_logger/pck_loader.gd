@tool
extends Node
## PCK loader for the Advanced Logger
## This script loads the logger from a PCK file at runtime

func _enter_tree() -> void:
	# Only do this for iOS in the exported project
	if OS.get_name() == "iOS" and not Engine.is_editor_hint():
		call_deferred("_load_logger_pck")

func _ready() -> void:
	# Call PCK verification after fully loaded
	if OS.get_name() == "iOS" and not Engine.is_editor_hint():
		call_deferred("_verify_pck_loading")

## Load the logger PCK file
func _load_logger_pck() -> void:
	print("[Advanced Logger] PCK Loader: Attempting to load logger PCK...")
	
	# Define paths to check for the PCK
	var pck_paths = [
		"res://addons/advanced_logger/logger.pck",
		"user://logger.pck",
		"res://logger.pck"
	]
	
	var pck_loaded = false
	
	# Try each path
	for pck_path in pck_paths:
		if FileAccess.file_exists(pck_path):
			var success = ProjectSettings.load_resource_pack(pck_path, true)
			if success:
				print("[Advanced Logger] Successfully loaded logger PCK from: " + pck_path)
				pck_loaded = true
				break
			else:
				print("[Advanced Logger] Failed to load PCK from: " + pck_path)
	
	if not pck_loaded:
		print("[Advanced Logger] Warning: Could not find logger PCK file")
		print("[Advanced Logger] Attempting to load logger directly...")
		
		# Try to directly load logger files
		_load_logger_directly()

## Try to load logger files directly
func _load_logger_directly() -> void:
	# Key logger files to try loading
	var core_files = [
		"res://addons/advanced_logger/core/logger.gd",
		"addons/advanced_logger/core/logger.gd",
		