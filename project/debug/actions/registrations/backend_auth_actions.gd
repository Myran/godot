class_name BackendAuthActions
extends RefCounted

## Registers backend AuthService layer debug actions.
## These test the production auth path that the game actually uses.
## Complements cpp.firebase.auth.* tests which validate the C++ layer.

## Using load() instead of preload() to avoid Android export packaging issues.
## Preload is evaluated at parse-time and can fail if files aren't indexed properly.


static func register_all(registry: DebugActionRegistry) -> void:
	var helper: RegistrationHelper = RegistrationHelper.new(registry, "Backend Auth")

	# Load action classes dynamically - provides better error handling
	var sign_in_anonymous_script: GDScript = load(
		"res://debug/actions/backend_auth/backend_auth_sign_in_anonymous_action.gd"
	)
	var sign_in_then_sign_out_script: GDScript = load(
		"res://debug/actions/backend_auth/backend_auth_sign_in_then_sign_out_action.gd"
	)
	var get_id_token_flow_script: GDScript = load(
		"res://debug/actions/backend_auth/backend_auth_get_id_token_flow_action.gd"
	)
	var anonymous_check_script: GDScript = load(
		"res://debug/actions/backend_auth/backend_auth_anonymous_check_action.gd"
	)
	var error_handling_script: GDScript = load(
		"res://debug/actions/backend_auth/backend_auth_error_handling_action.gd"
	)
	var state_transitions_script: GDScript = load(
		"res://debug/actions/backend_auth/backend_auth_state_transitions_action.gd"
	)

	# Core authentication operations
	if sign_in_anonymous_script:
		helper.register(sign_in_anonymous_script.new())
	if sign_in_then_sign_out_script:
		helper.register(sign_in_then_sign_out_script.new())
	if get_id_token_flow_script:
		helper.register(get_id_token_flow_script.new())

	# State and validation tests
	if anonymous_check_script:
		helper.register(anonymous_check_script.new())
	if state_transitions_script:
		helper.register(state_transitions_script.new())

	# Error handling tests
	if error_handling_script:
		helper.register(error_handling_script.new())

	helper.complete()
