extends Node


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_cleanup_singletons()


func _exit_tree() -> void:
	_cleanup_singletons()


func _cleanup_singletons() -> void:
	SessionManager.end_gameplay_session()

	if ResourceLoader.exists("res://addons/advanced_logger/utils/config_manager.gd"):
		var _ConfigManager: GDScript = load("res://addons/advanced_logger/utils/config_manager.gd")
		if _ConfigManager and _ConfigManager.has_method("cleanup"):
			_ConfigManager.cleanup()


	print("Singleton cleanup completed")
