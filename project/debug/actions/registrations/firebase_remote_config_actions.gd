class_name FirebaseRemoteConfigActions
extends RefCounted

const RemoteConfigAvailabilityActionClass = preload(
	"res://debug/actions/firebase_remote_config/remote_config_availability_action.gd"
)
const RemoteConfigFetchAndActivateActionClass = preload(
	"res://debug/actions/firebase_remote_config/remote_config_fetch_and_activate_action.gd"
)
const RemoteConfigGetValuesActionClass = preload(
	"res://debug/actions/firebase_remote_config/remote_config_get_values_action.gd"
)
const RemoteConfigGetKeysActionClass = preload(
	"res://debug/actions/firebase_remote_config/remote_config_get_keys_action.gd"
)
const RemoteConfigGetFetchInfoActionClass = preload(
	"res://debug/actions/firebase_remote_config/remote_config_get_fetch_info_action.gd"
)
const RemoteConfigGetJSONActionClass = preload(
	"res://debug/actions/firebase_remote_config/remote_config_get_json_action.gd"
)


static func register_all(registry: DebugActionRegistry) -> void:
	var helper: RegistrationHelper = RegistrationHelper.new(registry, "C++ Firebase")

	helper.register(RemoteConfigAvailabilityActionClass.new())
	helper.register(RemoteConfigFetchAndActivateActionClass.new())
	helper.register(RemoteConfigGetValuesActionClass.new())
	helper.register(RemoteConfigGetKeysActionClass.new())
	helper.register(RemoteConfigGetFetchInfoActionClass.new())
	helper.register(RemoteConfigGetJSONActionClass.new())

	helper.complete()
