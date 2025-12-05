@tool
extends EditorPlugin
## Debug Framework plugin - provides debug menu and action system.
## Only activates autoloads in debug builds.

const REGISTRY_PATH := "res://addons/debug_framework/core/debug_action_registry.gd"


func _enter_tree() -> void:
	if OS.is_debug_build():
		add_autoload_singleton("DebugRegistry", REGISTRY_PATH)


func _exit_tree() -> void:
	remove_autoload_singleton("DebugRegistry")
