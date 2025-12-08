class_name RegistrationHelper
extends RefCounted

## Helper class to eliminate duplicate registration boilerplate across action files.
## Handles counter tracking, logging, and error reporting.

var _registry: DebugActionRegistry
var _tag: String
var _counters: Array[int] = [0, 0]  # [registered, failed]


func _init(registry: DebugActionRegistry, tag: String) -> void:
	_registry = registry
	_tag = tag
	Log.info("Registering " + tag + " debug actions...", {}, ["debug", _tag, "registration"])


## Register an action with automatic counter tracking and error logging
func register(action: DebugAction) -> void:
	if _registry.register_action(action):
		_counters[0] += 1
	else:
		_counters[1] += 1
		Log.error(
			"Failed to register " + _tag + " action: " + action.action_name,
			{},
			["debug", _tag, "registration"]
		)


## Log completion summary with final counts
func complete() -> void:
	Log.info(
		_tag + " debug actions registration completed",
		{"total_actions": _counters[0], "failed_actions": _counters[1]},
		["debug", _tag, "registration"]
	)


## Get the count of successfully registered actions
func get_registered_count() -> int:
	return _counters[0]


## Get the count of failed registrations
func get_failed_count() -> int:
	return _counters[1]
