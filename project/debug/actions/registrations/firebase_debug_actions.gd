class_name FirebaseDebugActions
extends RefCounted

const FirebaseServiceDiagnosticActionClass = preload(
	"res://debug/actions/firebase_debug/firebase_service_diagnostic_action.gd"
)


static func register_all(registry: DebugActionRegistry) -> void:
	Log.info(
		"Registering Firebase Debug actions...", {}, ["debug", "firebase_debug", "registration"]
	)

	var counters: Array[int] = [0, 0]  # [registered, failed]

	_register_with_count(
		registry,
		FirebaseServiceDiagnosticActionClass.new(),
		"FirebaseServiceDiagnosticAction",
		counters
	)

	Log.info(
		"Firebase Debug actions registration completed",
		{"total_actions": counters[0], "failed_actions": counters[1]},
		["debug", "firebase_debug", "registration"]
	)


static func _register_with_count(
	registry: DebugActionRegistry, action: DebugAction, name: String, counters: Array[int]
) -> void:
	if registry.register_action(action):
		counters[0] += 1
	else:
		counters[1] += 1
		Log.error(
			"Failed to register Firebase Debug action: " + name,
			{},
			["debug", "firebase_debug", "registration"]
		)
