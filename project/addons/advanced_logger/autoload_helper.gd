@tool
extends EditorPlugin
## Helper script to update autoload path after refactoring
##
## This is a temporary script that should be run once to update
## the autoload path in the project settings after the refactoring.

func _enter_tree() -> void:
	print("Updating Advanced Logger autoload path...")
	
	# Check if the autoload exists with the old path
	if ProjectSettings.has_setting("autoload/Log"):
		# Get the current value
		var current_value = ProjectSettings.get_setting("autoload/Log")
		
		# Check if it's using the old path
		if current_value == "res://addons/advanced_logger/logger.gd":
			# Update to the new path
			ProjectSettings.set_setting("autoload/Log", "res://addons/advanced_logger/core/logger.gd")
			print("Autoload path updated to: res://addons/advanced_logger/core/logger.gd")
			
			# Save the project settings
			ProjectSettings.save()
		else:
			print("Autoload path is already updated or different: " + current_value)
	else:
		print("Autoload 'Log' not found in project settings.")

func _exit_tree() -> void:
	# This helper doesn't need to stay active
	pass
