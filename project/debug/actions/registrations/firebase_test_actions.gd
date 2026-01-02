class_name FirebaseTestActions
extends RefCounted

## Registration file for all Firebase SDK TDD test actions.
## Call register_all() from debug initialization to register all 31 tests.

## Preload base class first to ensure it's available for all test classes
const _BASE_CLASS: GDScript = preload(
	"res://debug/actions/firebase_tests/firebase_test_action_base.gd"
)

## Preload all test classes to ensure they're available
const _TestLogEventBasic: GDScript = preload(
	"res://debug/actions/firebase_tests/analytics/test_log_event_basic.gd"
)
const _TestLogEventParams: GDScript = preload(
	"res://debug/actions/firebase_tests/analytics/test_log_event_params.gd"
)
const _TestSetUserId: GDScript = preload(
	"res://debug/actions/firebase_tests/analytics/test_set_user_id.gd"
)
const _TestSetUserProperty: GDScript = preload(
	"res://debug/actions/firebase_tests/analytics/test_set_user_property.gd"
)
const _TestCollectionEnabled: GDScript = preload(
	"res://debug/actions/firebase_tests/analytics/test_collection_enabled.gd"
)
const _TestResetData: GDScript = preload(
	"res://debug/actions/firebase_tests/analytics/test_reset_data.gd"
)

const _TestSignInAnonymous: GDScript = preload(
	"res://debug/actions/firebase_tests/auth/test_sign_in_anonymous.gd"
)
const _TestSignInCustomToken: GDScript = preload(
	"res://debug/actions/firebase_tests/auth/test_sign_in_custom_token.gd"
)
const _TestSignInEmail: GDScript = preload(
	"res://debug/actions/firebase_tests/auth/test_sign_in_email.gd"
)
const _TestGetIdToken: GDScript = preload(
	"res://debug/actions/firebase_tests/auth/test_get_id_token.gd"
)
const _TestSignOut: GDScript = preload("res://debug/actions/firebase_tests/auth/test_sign_out.gd")
const _TestGetUid: GDScript = preload("res://debug/actions/firebase_tests/auth/test_get_uid.gd")
const _TestIsLoggedIn: GDScript = preload(
	"res://debug/actions/firebase_tests/auth/test_is_logged_in.gd"
)
const _TestStateChanged: GDScript = preload(
	"res://debug/actions/firebase_tests/auth/test_state_changed.gd"
)

const _TestGetBoolean: GDScript = preload(
	"res://debug/actions/firebase_tests/remote_config/test_get_boolean.gd"
)
const _TestGetString: GDScript = preload(
	"res://debug/actions/firebase_tests/remote_config/test_get_string.gd"
)
const _TestGetInt: GDScript = preload(
	"res://debug/actions/firebase_tests/remote_config/test_get_int.gd"
)
const _TestFetchAndActivate: GDScript = preload(
	"res://debug/actions/firebase_tests/remote_config/test_fetch_and_activate.gd"
)
const _TestFetchAsync: GDScript = preload(
	"res://debug/actions/firebase_tests/remote_config/test_fetch_async.gd"
)
const _TestActivateAsync: GDScript = preload(
	"res://debug/actions/firebase_tests/remote_config/test_activate_async.gd"
)
const _TestGetKeys: GDScript = preload(
	"res://debug/actions/firebase_tests/remote_config/test_get_keys.gd"
)
const _TestSetDefaults: GDScript = preload(
	"res://debug/actions/firebase_tests/remote_config/test_set_defaults.gd"
)

const _TestDocumentGet: GDScript = preload(
	"res://debug/actions/firebase_tests/firestore/test_document_get.gd"
)
const _TestDocumentSet: GDScript = preload(
	"res://debug/actions/firebase_tests/firestore/test_document_set.gd"
)
const _TestDocumentUpdate: GDScript = preload(
	"res://debug/actions/firebase_tests/firestore/test_document_update.gd"
)
const _TestDocumentDelete: GDScript = preload(
	"res://debug/actions/firebase_tests/firestore/test_document_delete.gd"
)
const _TestQuery: GDScript = preload(
	"res://debug/actions/firebase_tests/firestore/test_simple_query.gd"
)

const _TestSteamInit: GDScript = preload("res://debug/actions/firebase_tests/steam/test_init.gd")
const _TestSteamGetTicket: GDScript = preload(
	"res://debug/actions/firebase_tests/steam/test_get_ticket.gd"
)
const _TestSteamSignInFlow: GDScript = preload(
	"res://debug/actions/firebase_tests/steam/test_sign_in_flow.gd"
)
const _TestSteamNoClientError: GDScript = preload(
	"res://debug/actions/firebase_tests/steam/test_no_client_error.gd"
)


static func register_all(registry: DebugActionRegistry) -> void:
	var helper: RegistrationHelper = RegistrationHelper.new(registry, "firebase-test")

	# Analytics tests (6)
	_register_analytics_tests(helper)

	# Auth tests (8)
	_register_auth_tests(helper)

	# Remote Config tests (8)
	_register_remote_config_tests(helper)

	# Firestore tests (5)
	_register_firestore_tests(helper)

	# Steam tests (4, desktop only)
	_register_steam_tests(helper)

	helper.complete()


static func _register_analytics_tests(helper: RegistrationHelper) -> void:
	helper.register(_TestLogEventBasic.new())
	helper.register(_TestLogEventParams.new())
	helper.register(_TestSetUserId.new())
	helper.register(_TestSetUserProperty.new())
	helper.register(_TestCollectionEnabled.new())
	helper.register(_TestResetData.new())


static func _register_auth_tests(helper: RegistrationHelper) -> void:
	helper.register(_TestSignInAnonymous.new())
	helper.register(_TestSignInCustomToken.new())
	helper.register(_TestSignInEmail.new())
	helper.register(_TestGetIdToken.new())
	helper.register(_TestSignOut.new())
	helper.register(_TestGetUid.new())
	helper.register(_TestIsLoggedIn.new())
	helper.register(_TestStateChanged.new())


static func _register_remote_config_tests(helper: RegistrationHelper) -> void:
	helper.register(_TestGetBoolean.new())
	helper.register(_TestGetString.new())
	helper.register(_TestGetInt.new())
	helper.register(_TestFetchAndActivate.new())
	helper.register(_TestFetchAsync.new())
	helper.register(_TestActivateAsync.new())
	helper.register(_TestGetKeys.new())
	helper.register(_TestSetDefaults.new())


static func _register_firestore_tests(helper: RegistrationHelper) -> void:
	helper.register(_TestDocumentGet.new())
	helper.register(_TestDocumentSet.new())
	helper.register(_TestDocumentUpdate.new())
	helper.register(_TestDocumentDelete.new())
	helper.register(_TestQuery.new())


static func _register_steam_tests(helper: RegistrationHelper) -> void:
	helper.register(_TestSteamInit.new())
	helper.register(_TestSteamGetTicket.new())
	helper.register(_TestSteamSignInFlow.new())
	helper.register(_TestSteamNoClientError.new())
