class_name FirebaseAuthActions
extends RefCounted

const AuthSignInAnonymousActionClass = preload(
	"res://debug/actions/firebase_auth/auth_sign_in_anonymous_action.gd"
)
const AuthSignOutActionClass = preload("res://debug/actions/firebase_auth/auth_sign_out_action.gd")
const AuthGetUserInfoActionClass = preload(
	"res://debug/actions/firebase_auth/auth_get_user_info_action.gd"
)
const AuthSignInCustomTokenActionClass = preload(
	"res://debug/actions/firebase_auth/auth_sign_in_custom_token_action.gd"
)
const AuthGetIdTokenActionClass = preload(
	"res://debug/actions/firebase_auth/auth_get_id_token_action.gd"
)
const AuthStateListenerActionClass = preload(
	"res://debug/actions/firebase_auth/auth_state_listener_action.gd"
)
const AuthSignInFacebookActionClass = preload(
	"res://debug/actions/firebase_auth/auth_sign_in_facebook_action.gd"
)
const AuthSignInAppleActionClass = preload(
	"res://debug/actions/firebase_auth/auth_sign_in_apple_action.gd"
)


static func register_all(registry: DebugActionRegistry) -> void:
	var helper: RegistrationHelper = RegistrationHelper.new(registry, "C++ Firebase Auth")

	helper.register(AuthSignInAnonymousActionClass.new())
	helper.register(AuthSignOutActionClass.new())
	helper.register(AuthGetUserInfoActionClass.new())
	helper.register(AuthSignInCustomTokenActionClass.new())
	helper.register(AuthGetIdTokenActionClass.new())
	helper.register(AuthStateListenerActionClass.new())
	helper.register(AuthSignInFacebookActionClass.new())
	helper.register(AuthSignInAppleActionClass.new())

	helper.complete()
