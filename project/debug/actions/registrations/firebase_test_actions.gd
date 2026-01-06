class_name FirebaseTestActions
extends RefCounted

## Registration file for all Firebase SDK TDD test actions.
## Call register_all() from debug initialization to register all 31 tests.

## Preload base class first to ensure it's available for all test classes
const _BASE_CLASS: GDScript = preload(
	"res://debug/actions/firebase_tests/firebase_test_action_base.gd"
)

## Preload all test classes to ensure they're available
const TestLogEventBasic: GDScript = preload(
	"res://debug/actions/firebase_tests/analytics/test_log_event_basic.gd"
)
const TestLogEventParams: GDScript = preload(
	"res://debug/actions/firebase_tests/analytics/test_log_event_params.gd"
)
const TestSetUserId: GDScript = preload(
	"res://debug/actions/firebase_tests/analytics/test_set_user_id.gd"
)
const TestSetUserProperty: GDScript = preload(
	"res://debug/actions/firebase_tests/analytics/test_set_user_property.gd"
)
const TestCollectionEnabled: GDScript = preload(
	"res://debug/actions/firebase_tests/analytics/test_collection_enabled.gd"
)
const TestResetData: GDScript = preload(
	"res://debug/actions/firebase_tests/analytics/test_reset_data.gd"
)

const TestSignInAnonymous: GDScript = preload(
	"res://debug/actions/firebase_tests/auth/test_sign_in_anonymous.gd"
)
const TestSignInCustomToken: GDScript = preload(
	"res://debug/actions/firebase_tests/auth/test_sign_in_custom_token.gd"
)
const TestSignInEmail: GDScript = preload(
	"res://debug/actions/firebase_tests/auth/test_sign_in_email.gd"
)
const TestGetIdToken: GDScript = preload(
	"res://debug/actions/firebase_tests/auth/test_get_id_token.gd"
)
const TestSignOut: GDScript = preload("res://debug/actions/firebase_tests/auth/test_sign_out.gd")
const TestGetUid: GDScript = preload("res://debug/actions/firebase_tests/auth/test_get_uid.gd")
const TestIsLoggedIn: GDScript = preload(
	"res://debug/actions/firebase_tests/auth/test_is_logged_in.gd"
)
const TestStateChanged: GDScript = preload(
	"res://debug/actions/firebase_tests/auth/test_state_changed.gd"
)

const TestGetBoolean: GDScript = preload(
	"res://debug/actions/firebase_tests/remote_config/test_get_boolean.gd"
)
const TestGetString: GDScript = preload(
	"res://debug/actions/firebase_tests/remote_config/test_get_string.gd"
)
const TestGetInt: GDScript = preload(
	"res://debug/actions/firebase_tests/remote_config/test_get_int.gd"
)
const TestFetchAndActivate: GDScript = preload(
	"res://debug/actions/firebase_tests/remote_config/test_fetch_and_activate.gd"
)
const TestFetchAsync: GDScript = preload(
	"res://debug/actions/firebase_tests/remote_config/test_fetch_async.gd"
)
const TestActivateAsync: GDScript = preload(
	"res://debug/actions/firebase_tests/remote_config/test_activate_async.gd"
)
const TestGetKeys: GDScript = preload(
	"res://debug/actions/firebase_tests/remote_config/test_get_keys.gd"
)
const TestSetDefaults: GDScript = preload(
	"res://debug/actions/firebase_tests/remote_config/test_set_defaults.gd"
)

const TestDocumentGet: GDScript = preload(
	"res://debug/actions/firebase_tests/firestore/test_document_get.gd"
)
const TestDocumentSet: GDScript = preload(
	"res://debug/actions/firebase_tests/firestore/test_document_set.gd"
)
const TestDocumentUpdate: GDScript = preload(
	"res://debug/actions/firebase_tests/firestore/test_document_update.gd"
)
const TestDocumentDelete: GDScript = preload(
	"res://debug/actions/firebase_tests/firestore/test_document_delete.gd"
)
const TestQuery: GDScript = preload(
	"res://debug/actions/firebase_tests/firestore/test_simple_query.gd"
)
const TestFirestoreErrorHandling: GDScript = preload(
	"res://debug/actions/firebase_tests/firestore/test_error_handling.gd"
)

const TestSteamInit: GDScript = preload("res://debug/actions/firebase_tests/steam/test_init.gd")
const TestSteamGetTicket: GDScript = preload(
	"res://debug/actions/firebase_tests/steam/test_get_ticket.gd"
)
const TestSteamSignInFlow: GDScript = preload(
	"res://debug/actions/firebase_tests/steam/test_sign_in_flow.gd"
)
const TestSteamNoClientError: GDScript = preload(
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

	# Firestore tests (6)
	_register_firestore_tests(helper)

	# Steam tests (4, desktop only)
	_register_steam_tests(helper)

	helper.complete()


static func _register_analytics_tests(helper: RegistrationHelper) -> void:
	helper.register(TestLogEventBasic.new())
	helper.register(TestLogEventParams.new())
	helper.register(TestSetUserId.new())
	helper.register(TestSetUserProperty.new())
	helper.register(TestCollectionEnabled.new())
	helper.register(TestResetData.new())


static func _register_auth_tests(helper: RegistrationHelper) -> void:
	helper.register(TestSignInAnonymous.new())
	helper.register(TestSignInCustomToken.new())
	helper.register(TestSignInEmail.new())
	helper.register(TestGetIdToken.new())
	helper.register(TestSignOut.new())
	helper.register(TestGetUid.new())
	helper.register(TestIsLoggedIn.new())
	helper.register(TestStateChanged.new())


static func _register_remote_config_tests(helper: RegistrationHelper) -> void:
	helper.register(TestGetBoolean.new())
	helper.register(TestGetString.new())
	helper.register(TestGetInt.new())
	helper.register(TestFetchAndActivate.new())
	helper.register(TestFetchAsync.new())
	helper.register(TestActivateAsync.new())
	helper.register(TestGetKeys.new())
	helper.register(TestSetDefaults.new())


static func _register_firestore_tests(helper: RegistrationHelper) -> void:
	helper.register(TestDocumentGet.new())
	helper.register(TestDocumentSet.new())
	helper.register(TestDocumentUpdate.new())
	helper.register(TestDocumentDelete.new())
	helper.register(TestQuery.new())
	helper.register(TestFirestoreErrorHandling.new())


static func _register_steam_tests(helper: RegistrationHelper) -> void:
	helper.register(TestSteamInit.new())
	helper.register(TestSteamGetTicket.new())
	helper.register(TestSteamSignInFlow.new())
	helper.register(TestSteamNoClientError.new())
