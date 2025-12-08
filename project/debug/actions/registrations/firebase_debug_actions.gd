class_name FirebaseDebugActions
extends RefCounted

const FirebaseServiceDiagnosticActionClass = preload(
	"res://debug/actions/firebase_debug/firebase_service_diagnostic_action.gd"
)


static func register_all(registry: DebugActionRegistry) -> void:
	var helper: RegistrationHelper = RegistrationHelper.new(registry, "Firebase Debug")

	helper.register(FirebaseServiceDiagnosticActionClass.new())

	helper.complete()
