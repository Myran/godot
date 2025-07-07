extends Node
## Singleton cleanup script to ensure proper cleanup of static instances


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_cleanup_singletons()


func _exit_tree() -> void:
	_cleanup_singletons()


func _cleanup_singletons() -> void:
	# End session if still active before cleanup
	SessionManager.end_gameplay_session()
	
	# Clean up the advanced logger ConfigManager
	if ResourceLoader.exists("res://addons/advanced_logger/utils/config_manager.gd"):
		var _ConfigManager: GDScript = load("res://addons/advanced_logger/utils/config_manager.gd")
		if _ConfigManager and _ConfigManager.has_method("cleanup"):
			_ConfigManager.cleanup()

	# Clean up any other static singletons here
	# ...

	print("Singleton cleanup completed")
