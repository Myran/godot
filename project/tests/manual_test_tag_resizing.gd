@tool
extends EditorScript
## Manual test script for tag resizing functionality
## Run this script directly from the Godot editor using "Run Current Scene"

func _run():
	print("\n========== MANUAL TAG RESIZING TEST ==========")
	
	# Access the plugin
	var editor_plugin = EditorPlugin.new()
	var plugin_path = "res://addons/advanced_logger/plugin.gd"
	var plugin_script = load(plugin_path)
	
	if not plugin_script:
		print("❌ Failed to load plugin script: " + plugin_path)
		return
	
	print("Loaded plugin script successfully")
	
	# First verify the dock is accessible
	var dock_path = "res://addons/advanced_logger/logger_dock.