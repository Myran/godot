class_name SingletonCleanup
extends RefCounted


static func cleanup_session() -> void:
	SessionManager.end_gameplay_session()


static func cleanup_config_manager() -> void:
	if ResourceLoader.exists("res://addons/advanced_logger/utils/config_manager.gd"):
		var ConfigManagerScript: GDScript = load(
			"res://addons/advanced_logger/utils/config_manager.gd"
		)
		if ConfigManagerScript and ConfigManagerScript.has_method("cleanup"):
			ConfigManagerScript.cleanup()


static func perform_full_cleanup() -> void:
	cleanup_session()
	cleanup_config_manager()
