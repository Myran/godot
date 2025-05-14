extends Control

signal fb_success(res: Dictionary)
@warning_ignore("unused_signal")
signal _apple_success(res: Dictionary)
# 'timed_out' signal is no longer relevant with GDScript timers removed.

# Constants
const FAKE_INTERSTITIAL_AD_UNIT_IOS: String = "ca-app-pub-3940256099942544/4411468910"
const FAKE_REWARDED_VIDEO_AD_UNIT_IOS: String = "ca-app-pub-3940256099942544/1712485313"
const _RTDB_TEST_PREFIX: String = "_test_rtdb_"
const _AUTH_TEST_PREFIX: String = "_test_auth_"
const _CONFIG_TEST_PREFIX: String = "_test_config_"
const _test_base_path: Array[String] = ["debug_tests", "rtdb"]

# Firebase Module Instances
var auth: Object = null
var db: Object = null  # Instance of C++ FirebaseDatabase
var remote_config: Object = null
var messaging: Object = null

# Other Module Instances
var godot_apple_auth: Object = null
var admob: Object = null

# UI References
@onready var status_label: RichTextLabel = %DebugRichTextLabel
@onready var close_button: Button = %Button_close
@onready var item_list_navigator: ItemList = %DebugItemList

# Navigation State & Constants
enum ViewLevel { MAIN_CATEGORIES, GROUP_LIST, TEST_LIST }
var _current_view_level: ViewLevel = ViewLevel.MAIN_CATEGORIES
var _current_category_info: Dictionary = {}
var _current_group_info: Dictionary = {}
const CATEGORIES_DEFINITION: Array[Dictionary] = [
	{
		"name": "RTDB Tests",
		"prefix": _RTDB_TEST_PREFIX,
		"module_var_name": "db",
		"has_run_all": true
	},
	{
		"name": "Auth Tests",
		"prefix": _AUTH_TEST_PREFIX,
		"module_var_name": "auth",
		"has_run_all": true
	},
	{
		"name": "Config Tests",
		"prefix": _CONFIG_TEST_PREFIX,
		"module_var_name": "remote_config",
		"has_run_all": true
	}
]
const ITEM_TYPE_CATEGORY: String = "category"
const ITEM_TYPE_GROUP: String = "group"
const ITEM_TYPE_TEST: String = "test_item"
const ITEM_TYPE_BACK_TO_MAIN: String = "back_to_main"
const ITEM_TYPE_BACK_TO_GROUPS: String = "back_to_groups"
const ITEM_TYPE_RUN_ALL_CATEGORY_TESTS: String = "run_all_category_tests"
const BACK_TO_MAIN_MENU_TEXT: String = "< Back to Main Menu"
const BACK_TO_GROUPS_TEXT: String = "< Back to Test Groups"

# RTDB Test State
var _next_request_id: int = 0
var _pending_requests: Dictionary = {}  # Stores request_id_int -> PendingRequestData instance
var _transaction_count: int = 0  # Declaration for RTDB tests

var _is_running_all_tests: bool = false
var _current_run_all_category_prefix: String = ""


class PendingRequestData:
	extends RefCounted
	signal completed(success: bool, data: Variant)
	var operation: String
	var path: Array[String]
	var request_id: int
	var _parent_debug_node: Node
	var _is_completed_internally: bool = false

	func _init(
		p_request_id: int, p_operation: String, p_path: Array[String], p_parent_debug_node: Node
	):
		request_id = p_request_id
		operation = p_operation
		path = p_path
		_parent_debug_node = p_parent_debug_node

	func complete_request(success: bool, data: Variant) -> void:
		if _is_completed_internally:
			Log.warning(
				"PendingReqData id %d (%s) already completed." % [request_id, operation],
				{},
				["debug"]
			)
			return
		_is_completed_internally = true
		Log.debug(
			"PendingReqData id %d (%s) emitting 'completed'." % [request_id, operation],
			{"s": success},
			["debug"]
		)
		completed.emit(success, data)

	func _mark_as_stuck_or_cancelled(
		reason_data: Dictionary = {
			"error_code": "CANCELLED", "message": "Operation cancelled/stuck"
		}
	):
		if _is_completed_internally:
			return
		_is_completed_internally = true
		Log.warning(
			"PendingReqData id %d (%s) marked STUCK/CANCELLED." % [request_id, operation],
			{},
			["debug"]
		)
		completed.emit(false, reason_data)


#-----------------------------------------------------------------------------#
# Initialization                                                              #
#-----------------------------------------------------------------------------#
func _ready() -> void:
	Log.info("Debug Node _ready: Starting initialization.", {}, ["debug", "initialization"])
	Engine.print_error_messages = true

	var debug_text: String = "Build is debug" if OS.is_debug_build() else "build is release"
	var rtdb_label2_node: Node = get_node_or_null("%DebugRichTextLabel2")
	if is_instance_valid(rtdb_label2_node) and rtdb_label2_node is RichTextLabel:
		(rtdb_label2_node as RichTextLabel).text = str("OS: ", OS.get_name(), " | ", debug_text)
	var rtdb_label3_node: Node = get_node_or_null("%DebugRichTextLabel3")
	if is_instance_valid(rtdb_label3_node) and rtdb_label3_node is RichTextLabel:
		(rtdb_label3_node as RichTextLabel).text = str(
			"Commit: ", Engine.get_version_info()["hash"]
		)

	_initialize_firebase_modules()

	if is_instance_valid(item_list_navigator):
		item_list_navigator.item_activated.connect(_on_navigator_item_activated)
	else:
		Log.error(
			"DebugItemList node ('item_list_navigator') not found!",
			{},
			["debug", "ui", Log.TAG_ERROR]
		)

	_populate_main_categories_view()
	if is_instance_valid(close_button):
		close_button.pressed.connect(_on_Button_close_pressed.bind(), CONNECT_DEFERRED)
	else:
		Log.error("Close button node not found!", {}, ["debug", "ui", Log.TAG_ERROR])
	Log.info("Debug Node _ready: Initialization complete.", {}, ["debug", "initialization"])


func _initialize_firebase_modules() -> void:
	Log.debug("Checking for Firebase modules...", {}, ["debug", "initialization", Log.TAG_FIREBASE])
	if ClassDB.class_exists("FirebaseDatabase"):
		db = ClassDB.instantiate("FirebaseDatabase")
		if is_instance_valid(db):
			Log.debug(
				"FirebaseDatabase instance created.",
				{"db": db},
				["debug", "initialization", Log.TAG_FIREBASE]
			)
			_connect_rtdb_signals_dynamically()
		else:
			Log.error(
				"Failed to instantiate FirebaseDatabase!",
				{},
				["debug", "initialization", Log.TAG_FIREBASE, Log.TAG_ERROR]
			)
			if is_instance_valid(status_label):
				status_label.text = "[ERROR] Failed to instantiate FirebaseDatabase"
	else:
		Log.warning(
			"FirebaseDatabase C++ module class not found.",
			{},
			["debug", "initialization", Log.TAG_FIREBASE]
		)
		if is_instance_valid(status_label):
			status_label.text = "[WARN] FirebaseDatabase C++ module not found"

	if ClassDB.class_exists("FirebaseRemoteConfig"):
		remote_config = ClassDB.instantiate("FirebaseRemoteConfig")
		if is_instance_valid(remote_config):
			var lce = remote_config.connect("loaded", Callable(self, "remote_config_loaded"))
			if lce != OK:
				Log.error("Failed to connect remote_config 'loaded'", {}, ["debug"])

	if Engine.has_singleton("Auth"):
		auth = Engine.get_singleton("Auth")

	if Engine.has_singleton("GodotAppleAuth"):
		godot_apple_auth = Engine.get_singleton("GodotAppleAuth")
		if is_instance_valid(godot_apple_auth):
			var cce = godot_apple_auth.connect("credential", Callable(self, "_on_credential"))
			if cce != OK:
				Log.error("Fail GAppleAuth cred conn", {}, ["debug"])
				var ace = godot_apple_auth.connect(
					"authorization", Callable(self, "_on_authorization")
				)
				if ace != OK:
					Log.error("Fail GAppleAuth auth conn", {}, ["debug"])


#-----------------------------------------------------------------------------#
# ItemList Navigation                                                         #
#-----------------------------------------------------------------------------#
func _populate_main_categories_view() -> void:
	_current_view_level = ViewLevel.MAIN_CATEGORIES
	_current_category_info = {}
	_current_group_info = {}
	item_list_navigator.clear()
	Log.debug("Populating main categories view", {}, ["debug_ui"])
	var item_idx: int = 0
	for category_def in CATEGORIES_DEFINITION:
		var module_instance_valid: bool = false
		var module_var_name = category_def.get("module_var_name", "")
		if not module_var_name.is_empty():
			var module_instance = get(module_var_name)
			module_instance_valid = is_instance_valid(module_instance)
		else:
			module_instance_valid = true
		if module_instance_valid:
			item_list_navigator.add_item(category_def.name)
			item_list_navigator.set_item_metadata(
				item_idx,
				{
					"type": ITEM_TYPE_CATEGORY,
					"name": category_def.name,
					"prefix": category_def.prefix,
					"has_run_all": category_def.get("has_run_all", false)
				}
			)
			item_idx += 1
		else:
			Log.debug(
				"Skipping category due to invalid/unconfigured module.",
				{"cat": category_def.name},
				["debug_ui"]
			)
	if item_list_navigator.item_count == 0:
		item_list_navigator.add_item("No debug categories available.")
		item_list_navigator.set_item_disabled(0, true)
	item_list_navigator.ensure_current_is_visible()


func _populate_groups_view(category_info: Dictionary) -> void:
	_current_view_level = ViewLevel.GROUP_LIST
	_current_category_info = category_info
	_current_group_info = {}
	item_list_navigator.clear()
	Log.debug("Populating groups view for category", {"category": category_info.name}, ["debug_ui"])
	var item_idx_counter: int = 0
	item_list_navigator.add_item(BACK_TO_MAIN_MENU_TEXT)
	item_list_navigator.set_item_metadata(item_idx_counter, {"type": ITEM_TYPE_BACK_TO_MAIN})
	item_idx_counter += 1
	if category_info.get("has_run_all", false):
		var run_all_text: String = "Run All " + category_info.name
		item_list_navigator.add_item(run_all_text)
		item_list_navigator.set_item_metadata(
			item_idx_counter,
			{
				"type": ITEM_TYPE_RUN_ALL_CATEGORY_TESTS,
				"category_prefix": category_info.prefix,
				"category_name": category_info.name
			}
		)
		item_idx_counter += 1
	var category_prefix: String = category_info.prefix
	var method_list: Array = get_method_list()
	var groups: Dictionary = {}
	for method_info_variant in method_list:
		var method_info: Dictionary = method_info_variant as Dictionary
		var method_name: String = method_info.name as String
		if method_name.begins_with(category_prefix):
			var name_after_prefix: String = method_name.trim_prefix(category_prefix)
			var underscore_pos: int = name_after_prefix.find("_")
			if underscore_pos > 0:
				var group_name_raw: String = name_after_prefix.substr(0, underscore_pos)  # group_name_raw is defined here
				if not group_name_raw.is_empty() and not group_name_raw.contains("."):
					if not groups.has(group_name_raw):
						groups[group_name_raw] = {
							"display_name": _format_name_for_display(group_name_raw), "count": 0
						}
					groups[group_name_raw].count += 1
	var sorted_group_keys = groups.keys()
	sorted_group_keys.sort()
	for group_name_raw_key in sorted_group_keys:  # Use a different var name to avoid confusion if needed, though scope is fine
		var group_data = groups[group_name_raw_key]
		item_list_navigator.add_item(group_data.display_name)
		item_list_navigator.set_item_metadata(
			item_idx_counter,
			{
				"type": ITEM_TYPE_GROUP,
				"name_raw": group_name_raw_key,
				"display_name": group_data.display_name,
				"category_prefix": category_prefix,
				"category_name": category_info.name
			}
		)
		item_idx_counter += 1
	var has_run_all_item = category_info.get("has_run_all", false)
	var min_expected_items_before_groups = 1
	if has_run_all_item:
		min_expected_items_before_groups += 1
	if groups.is_empty() and item_list_navigator.item_count == min_expected_items_before_groups:
		item_list_navigator.add_item("No further test groups in " + category_info.name + ".")
		item_list_navigator.set_item_disabled(item_idx_counter, true)
	item_list_navigator.ensure_current_is_visible()


func _populate_tests_view(group_info: Dictionary) -> void:
	_current_view_level = ViewLevel.TEST_LIST
	_current_group_info = group_info
	item_list_navigator.clear()
	Log.debug(
		"Populating tests view for group",
		{"cat": group_info.category_name, "grp": group_info.display_name},
		["debug_ui"]
	)
	var item_idx_counter: int = 0
	item_list_navigator.add_item(BACK_TO_GROUPS_TEXT)
	item_list_navigator.set_item_metadata(
		item_idx_counter,
		{
			"type": ITEM_TYPE_BACK_TO_GROUPS,
			"category_prefix": group_info.category_prefix,
			"category_name": group_info.category_name,
			"category_has_run_all": _current_category_info.get("has_run_all", false)
		}
	)
	item_idx_counter += 1
	var category_prefix: String = group_info.category_prefix
	var group_name_raw: String = group_info.name_raw
	var full_prefix_for_tests: String = category_prefix + group_name_raw + "_"
	var method_list: Array = get_method_list()
	method_list.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return (a.name as String) < (b.name as String)
	)
	var items_added: bool = false
	for method_info_variant in method_list:
		var method_info: Dictionary = method_info_variant as Dictionary
		var method_name: String = method_info.name as String
		if method_name.begins_with(full_prefix_for_tests):
			var test_name_raw: String = method_name.trim_prefix(full_prefix_for_tests)
			if not test_name_raw.is_empty() and not test_name_raw.contains("."):
				var display_test_name: String = _format_name_for_display(test_name_raw)
				item_list_navigator.add_item(display_test_name)
				item_list_navigator.set_item_metadata(
					item_idx_counter,
					{
						"type": ITEM_TYPE_TEST,
						"method_name": method_name,
						"display_name": display_test_name
					}
				)
				item_idx_counter += 1
				items_added = true
	if not items_added:
		item_list_navigator.add_item("No tests found in this group.")
		item_list_navigator.set_item_disabled(item_idx_counter, true)
	item_list_navigator.ensure_current_is_visible()


func _on_navigator_item_activated(index: int) -> void:
	if (
		not is_instance_valid(item_list_navigator)
		or index < 0
		or index >= item_list_navigator.item_count
	):
		Log.error("Nav item invalid idx.", {"i": index}, ["debug_ui"])
		return
	var metadata: Dictionary = item_list_navigator.get_item_metadata(index)
	if metadata.is_empty():
		Log.warning("No metadata for item.", {"i": index}, ["debug_ui"])
		return
	var item_type: String = metadata.get("type", "")
	Log.debug("Item activated", {"t": item_type, "m": metadata}, ["debug_ui"])
	match item_type:
		ITEM_TYPE_CATEGORY:
			_populate_groups_view(metadata)
		ITEM_TYPE_GROUP:
			_populate_tests_view(metadata)
		ITEM_TYPE_TEST:
			var method_name: String = metadata.get("method_name")
			if has_method(method_name):
				Log.info("Exec test: %s" % method_name, {}, ["debug", "test"])
				if is_instance_valid(status_label):
					status_label.text = "Running: %s..." % metadata.get("display_name", method_name)
				call_deferred(method_name)  # call_deferred is important
			else:
				Log.error("Method not found: %s" % method_name, {}, ["debug", "ui", Log.TAG_ERROR])
				if is_instance_valid(status_label):
					status_label.text = "[ERR] Test method '%s' not found!" % method_name
		ITEM_TYPE_BACK_TO_MAIN:
			_populate_main_categories_view()
		ITEM_TYPE_BACK_TO_GROUPS:
			var c_info = {
				"name": metadata.category_name,
				"prefix": metadata.category_prefix,
				"has_run_all": metadata.get("category_has_run_all", false)
			}
			_populate_groups_view(c_info)
		ITEM_TYPE_RUN_ALL_CATEGORY_TESTS:
			var cp: String = metadata.get("category_prefix")
			var cn: String = metadata.get("category_name")
			Log.info("Exec 'Run All' for: %s" % cn, {}, ["debug", "test"])
			if is_instance_valid(status_label):
				status_label.text = "Starting all %s tests..." % cn
				_run_all_tests_by_prefix(cp)
		_:
			Log.warning("Unknown item type in nav.", {"t": item_type}, ["debug_ui"])


func _format_name_for_display(name_part: String) -> String:
	if name_part.is_empty():
		return ""
	return name_part.replace("_", " ").capitalize()


#-----------------------------------------------------------------------------#
# Firebase RTDB: Signal Connections & Request Handling                        #
#-----------------------------------------------------------------------------#
func _connect_rtdb_signals_dynamically() -> void:
	if not is_instance_valid(db):
		Log.error("DB invalid for signals.", {}, [Log.TAG_FIREBASE, Log.TAG_ERROR])
		return
	Log.debug("Connecting RTDB signals...", {}, [Log.TAG_FIREBASE])
	var rtdb_signals: Array[String] = [
		"get_value_completed",
		"get_value_error",
		"set_value_completed",
		"push_and_update_completed",
		"remove_value_completed",
		"query_completed",
		"query_error",
		"transaction_completed",
		"child_added",
		"child_changed",
		"child_moved",
		"child_removed",
		"connection_state_changed",
		"db_error"
	]
	for sig_name in rtdb_signals:
		var handler_name: String = "_on_rtdb_" + sig_name
		if not has_method(handler_name):
			Log.warning(
				"No handler for RTDB sig", {"s": sig_name, "h": handler_name}, [Log.TAG_FIREBASE]
			)
			continue
		var h_call: Callable = Callable(self, handler_name)
		if not db.is_connected(sig_name, h_call):
			var err: Error = db.connect(sig_name, h_call, CONNECT_DEFERRED)
			if err != OK:
				Log.error(
					"Fail connect RTDB sig",
					{"s": sig_name, "h": handler_name, "e": error_string(err)},
					[Log.TAG_FIREBASE, Log.TAG_ERROR]
				)
			else:
				Log.debug(
					"Connected RTDB sig", {"s": sig_name, "h": handler_name}, [Log.TAG_FIREBASE]
				)


func _handle_rtdb_completion_from_cpp_signal(
	request_id: int,
	success: bool,
	data_or_error: Variant,
	operation_name_for_log: String = "UnknownOp"
) -> void:
	Log.debug(
		"RTDB C++ signal received for req_id: %d" % request_id,
		{
			"op_log": operation_name_for_log,
			"success": success,
			"pending_exists": _pending_requests.has(request_id)
		},
		["debug", "firebase", "rtdb_flow"]
	)
	if not _pending_requests.has(request_id):
		Log.warning(
			(
				"RTDB completion signal for unknown or already handled req_id: %d. Op: %s"
				% [request_id, operation_name_for_log]
			),
			{"data_or_error": data_or_error},
			["debug", "firebase", "rtdb_flow"]
		)
		return
	var pending_req_data: PendingRequestData = _pending_requests[request_id]
	_pending_requests.erase(request_id)
	if get_parent().visible and is_instance_valid(status_label):
		var display_path: String = "/".join(pending_req_data.path)
		if success:
			var result_str: String = (
				JSON.stringify(data_or_error, "  ")
				if typeof(data_or_error) in [TYPE_DICTIONARY, TYPE_ARRAY]
				else str(data_or_error)
			)
			status_label.text = (
				"Success (Req %d): %s\nPath: %s\nResult: %s"
				% [request_id, pending_req_data.operation, display_path, result_str]
			)
		else:
			var error_dict: Dictionary = (
				data_or_error
				if data_or_error is Dictionary
				else {"error_code": "UNKNOWN", "message": str(data_or_error)}
			)
			status_label.text = (
				"Error (Req %d): %s\nPath: %s\nCode: %s\nMsg: %s"
				% [
					request_id,
					pending_req_data.operation,
					display_path,
					error_dict.get("error_code", "N/A"),
					error_dict.get("message", "N/A")
				]
			)
	if is_instance_valid(pending_req_data):
		pending_req_data.complete_request(success, data_or_error)
	else:
		Log.critical(
			"PendingRequestData object invalid for req_id %d from C++ signal!" % request_id,
			{},
			["debug", "firebase", Log.TAG_CRITICAL]
		)


func _make_rtdb_request(
	operation_name: String, path_suffix: Array[String], args: Array = []
) -> Array:
	if not is_instance_valid(db):
		if is_instance_valid(status_label):
			status_label.text = "[ERROR] RTDB not initialized."
		Log.error(
			"Attempted RTDB request but db is null",
			{"operation": operation_name},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return [false, {"error_code": "DB_NULL", "message": "RTDB not initialized."}]
	var request_id: int = _next_request_id
	_next_request_id += 1
	if _pending_requests.has(request_id):
		Log.critical(
			(
				"CRITICAL: Key %d for op '%s' was ALREADY in _pending_requests! State corruption."
				% [request_id, operation_name]
			),
			{},
			["debug", "firebase", Log.TAG_ERROR]
		)
		var old_prd = _pending_requests.get(request_id)
		if is_instance_valid(old_prd) and old_prd is PendingRequestData:
			(old_prd as PendingRequestData)._mark_as_stuck_or_cancelled(
				{"error_code": "OVERWRITTEN", "message": "Request ID overwritten"}
			)
		_pending_requests.erase(request_id)
	var full_path: Array[String] = _test_base_path.duplicate()
	full_path.append_array(path_suffix)
	var pending_req_data := PendingRequestData.new(request_id, operation_name, full_path, self)
	_pending_requests[request_id] = pending_req_data
	var call_args: Array = [request_id, full_path]
	call_args.append_array(args)
	Log.debug(
		"Making RTDB request (awaitable)",
		{"req_id": request_id, "op": operation_name, "path": full_path, "args_count": args.size()},
		[Log.TAG_FIREBASE, Log.TAG_NETWORK]
	)
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = (
			"Sending req %d: %s\nPath: %s" % [request_id, operation_name, "/".join(full_path)]
		)
	db.callv(operation_name, call_args)
	Log.debug(
		(
			"Awaiting 'completed' signal for PendingRequestData req_id: %d, op: %s"
			% [request_id, operation_name]
		),
		{},
		["debug", "firebase", "rtdb_flow"]
	)
	var result_tuple: Array = await pending_req_data.completed
	Log.debug(
		(
			"Await for PendingRequestData req_id: %d (op: %s) FINISHED. Success: %s"
			% [
				request_id,
				operation_name,
				str(result_tuple[0] if result_tuple.size() > 0 else "N/A")
			]
		),
		{},
		["debug", "firebase", "rtdb_flow"]
	)
	if _pending_requests.has(request_id):
		Log.warning(
			(
				"RTDB Req %d (op: %s) STILL in _pending_requests AFTER await. Force cleaning."
				% [request_id, operation_name]
			),
			{},
			["debug", "firebase", Log.TAG_ERROR]
		)
		_pending_requests.erase(request_id)
	return result_tuple


func _on_rtdb_get_value_completed(request_id: int, _rtdb_key: String, value: Variant) -> void:
	_handle_rtdb_completion_from_cpp_signal(request_id, true, value, "get_value")


func _on_rtdb_get_value_error(
	request_id: int, _rtdb_key: String, error_code: String, error_message: String
) -> void:
	_handle_rtdb_completion_from_cpp_signal(
		request_id, false, {"error_code": error_code, "message": error_message}, "get_value_error"
	)


func _on_rtdb_set_value_completed(request_id: int, success: bool, error_message: String) -> void:
	_handle_rtdb_completion_from_cpp_signal(
		request_id,
		success,
		success if success else {"error_code": "SET_FAILED", "message": error_message},
		"set_value"
	)


func _on_rtdb_push_and_update_completed(
	request_id: int, push_id: String, success: bool, error_message: String
) -> void:
	_handle_rtdb_completion_from_cpp_signal(
		request_id,
		success,
		push_id if success else {"error_code": "PUSH_FAILED", "message": error_message},
		"push_and_update"
	)


func _on_rtdb_remove_value_completed(request_id: int, success: bool, error_message: String) -> void:
	_handle_rtdb_completion_from_cpp_signal(
		request_id,
		success,
		success if success else {"error_code": "REMOVE_FAILED", "message": error_message},
		"remove_value"
	)


func _on_rtdb_query_completed(request_id: int, _rtdb_key: String, value: Variant) -> void:
	_handle_rtdb_completion_from_cpp_signal(request_id, true, value, "query")


func _on_rtdb_query_error(
	request_id: int, _rtdb_key: String, error_code: String, error_message: String
) -> void:
	_handle_rtdb_completion_from_cpp_signal(
		request_id, false, {"error_code": error_code, "message": error_message}, "query_error"
	)


func _on_rtdb_transaction_completed(
	request_id: int, _rtdb_key: String, value: Variant, success: bool, error_message: String
) -> void:
	if success and value is int:
		_transaction_count = value
		_handle_rtdb_completion_from_cpp_signal(
			request_id,
			success,
			value if success else {"error_code": "TRANSACTION_FAILED", "message": error_message},
			"transaction"
		)


func _on_rtdb_child_added(key: String, value: Variant) -> void:
	var rs = (
		JSON.stringify(value, "  ")
		if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY]
		else str(value)
	)
	var m = "[L] Added: K:%s V:%s" % [key, rs]
	Log.info("RTDB Listener", {"e": "added", "k": key}, ["test"])
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = m


func _on_rtdb_child_changed(key: String, value: Variant) -> void:
	var rs = (
		JSON.stringify(value, "  ")
		if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY]
		else str(value)
	)
	var m = "[L] Changed: K:%s V:%s" % [key, rs]
	Log.info("RTDB Listener", {"e": "changed", "k": key}, ["test"])
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = m


func _on_rtdb_child_moved(key: String, value: Variant) -> void:
	var rs = (
		JSON.stringify(value, "  ")
		if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY]
		else str(value)
	)
	var m = "[L] Moved: K:%s V:%s" % [key, rs]
	Log.info("RTDB Listener", {"e": "moved", "k": key}, ["test"])
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = m


func _on_rtdb_child_removed(key: String, value: Variant) -> void:
	var rs = (
		JSON.stringify(value, "  ")
		if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY]
		else str(value)
	)
	var m = "[L] Removed: K:%s V:%s" % [key, rs]
	Log.info("RTDB Listener", {"e": "removed", "k": key}, ["test"])
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = m


func _on_rtdb_connection_state_changed(connected: bool) -> void:
	var connection_status_text = "Connected" if connected else "Disconnected"
	var m = "[S] Connection: " + connection_status_text
	Log.info("RTDB Status", {"e": "connection", "c": connected})
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = m  # Renamed local var


func _on_rtdb_db_error(code: String, message: String) -> void:
	var m = "[E] DB Error: C:%s M:%s" % [code, message]
	Log.error("RTDB Error", {"c": code, "m": message})
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = m


# --- RTDB Test Functions ---
# --- RTDB Test Functions ---
func _test_rtdb_basic_set_simple_value() -> Array:
	Log.debug("RTDB Test: Set Simple Value", {}, ["test"])
	_transaction_count += 1
	return await _make_rtdb_request(
		"set_value_async", ["simple_value"], ["Basic Value " + str(_transaction_count)]
	)


func _test_rtdb_basic_get_simple_value() -> Array:
	Log.debug("RTDB Test: Get Simple Value", {}, ["test"])
	return await _make_rtdb_request("get_value_async", ["simple_value"])


func _test_rtdb_basic_push_item() -> Array:
	Log.debug("RTDB Test: Push Item", {}, ["test"])
	_transaction_count += 1
	var push_data: Dictionary = {
		"msg": "Pushed " + str(_transaction_count), "ts": Time.get_unix_time_from_system()
	}
	return await _make_rtdb_request("push_and_update_async", ["pushed_items"], [push_data])


func _test_rtdb_basic_set_dictionary() -> Array:
	Log.debug("RTDB Test: Set Dictionary", {}, ["test"])
	_transaction_count += 1
	var dict_data: Dictionary = {
		"a": "Dict A " + str(_transaction_count), "b": true, "c": _transaction_count
	}
	return await _make_rtdb_request("set_value_async", ["dictionary_target"], [dict_data])


func _test_rtdb_basic_delete_dictionary() -> Array:
	Log.debug("RTDB Test: Delete Dictionary", {}, ["test"])
	return await _make_rtdb_request("remove_value_async", ["dictionary_target"])


func _test_rtdb_advanced_query_top_2_scores() -> Array:
	Log.debug("RTDB Test: Query Top 2 Scores", {}, ["test"])
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = "Setting up query data..."
	var ps_base: Array[String] = ["query_items"]
	var setup_paths_suffixes = [["item1"], ["item2"], ["item3"]]
	var setup_data: Array[Dictionary] = [
		{"name": "A", "score": 50}, {"name": "B", "score": 100}, {"name": "C", "score": 75}
	]
	for i in range(setup_paths_suffixes.size()):
		var current_path_suffix: Array[String] = ps_base.duplicate()
		current_path_suffix.append_array(setup_paths_suffixes[i])
		var setup_result: Array = await _make_rtdb_request(
			"set_value_async", current_path_suffix, [setup_data[i]]
		)
		if not setup_result[0]:
			Log.error("Setup failed for query", {"r": setup_result[1]}, ["test", Log.TAG_ERROR])
			return [false, {"error": "Setup failed", "d": setup_result[1]}]
	var qp: Dictionary = {"orderByChild": "score", "limitToLast": 2}
	Log.debug("Executing query", {"p": ps_base, "qp": qp}, ["test"])
	return await _make_rtdb_request("query_ordered_data_async", ps_base, [qp])


func _test_rtdb_advanced_increment_transaction() -> Array:
	Log.debug("RTDB Test: Increment Transaction", {}, ["test"])
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = "Deleting counter..."
	var counter_path_suffix: Array[String] = ["counter"]
	var delete_result: Array = await _make_rtdb_request("remove_value_async", counter_path_suffix)
	if not delete_result[0]:
		var err_p: Dictionary = delete_result[1] if delete_result[1] is Dictionary else {}
		var err_msg_l = str(err_p.get("message", "")).to_lower()
		if not (err_msg_l.contains("not found") or err_msg_l.contains("no data exists")):
			Log.warning("Problem deleting counter", {"r": err_p}, ["test"])
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = "Setting initial counter to 0.0..."
	var set_result: Array = await _make_rtdb_request("set_value_async", counter_path_suffix, [0.0])
	if not set_result[0]:
		Log.error("Failed to set initial counter", {"r": set_result[1]}, ["test", Log.TAG_ERROR])
		return [false, {"error": "Failed to set initial counter", "d": set_result[1]}]
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = "Running transaction..."
	return await _make_rtdb_request("run_transaction_async", counter_path_suffix, [1.0])  # RP: Ensure float if C++ expects float for counter; if int, 1 is fine. Assuming 1.0 for safety given 0.0 above.


func _test_rtdb_advanced_set_server_timestamp() -> Array:
	Log.debug("RTDB Test: Set Server Timestamp", {}, ["test"])
	return await _make_rtdb_request("set_server_timestamp_async", ["server_time"])


var _listener_path_suffix: Array[String] = ["live_data"]  # Used by add/remove/trigger
var _listen_count: int = 0  # Used by trigger


func _test_rtdb_listeners_add() -> Array:
	Log.debug("RTDB Test: Add Listener", {}, ["test"])
	if not is_instance_valid(db):
		if get_parent().visible and is_instance_valid(status_label):
			status_label.text = "[ERROR] RTDB not init."
		return [false, {"error_code": "DB_NULL", "message": "RTDB not initialized"}]

	var fp_listener: Array[String] = _test_base_path.duplicate()
	fp_listener.append_array(_listener_path_suffix)
	db.add_listener_at_path(fp_listener)

	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = "Added listener:\n%s" % [str(fp_listener)]

	var path_for_status_set: Array[String] = fp_listener.duplicate()
	path_for_status_set.append("status")
	# Use _make_rtdb_request for the auxiliary set_value operation
	var set_status_result: Array = await _make_rtdb_request(
		"set_value_async", path_for_status_set, ["listening_init"]
	)
	if not set_status_result[0]:
		Log.warning(
			"Failed to set initial listener status in RTDB",
			{"error_info": set_status_result[1]},
			["test", "rtdb"]
		)
		# Decide if this failure should make the overall _test_rtdb_listeners_add fail
		# For now, we'll still return true for the listener add request itself.
	return [true, {"message": "Listener add requested for path: %s" % str(fp_listener)}]


func _test_rtdb_listeners_trigger_change() -> Array:
	Log.debug("RTDB Test: Trigger Listener Change", {}, ["test"])
	if not is_instance_valid(db):
		if get_parent().visible and is_instance_valid(status_label):
			status_label.text = "[ERROR] RTDB not init."
		return [false, {"error_code": "DB_NULL", "message": "RTDB not initialized"}]

	_listen_count += 1
	var listener_base: Array[String] = _test_base_path.duplicate()
	listener_base.append_array(_listener_path_suffix)

	var path_count: Array[String] = listener_base.duplicate()
	path_count.append("count")

	var path_status: Array[String] = listener_base.duplicate()
	path_status.append("status")

	# Use _make_rtdb_request for the auxiliary set_value operations
	var set_count_result: Array = await _make_rtdb_request(
		"set_value_async", path_count, [_listen_count]
	)
	if not set_count_result[0]:
		Log.warning(
			"Failed to set listener count in RTDB",
			{"error_info": set_count_result[1]},
			["test", "rtdb"]
		)
		# Potentially return an error or handle as appropriate

	var set_status_result: Array = await _make_rtdb_request(
		"set_value_async", path_status, ["triggered_" + str(_listen_count)]
	)
	if not set_status_result[0]:
		Log.warning(
			"Failed to set listener status in RTDB",
			{"error_info": set_status_result[1]},
			["test", "rtdb"]
		)
		# Potentially return an error or handle as appropriate

	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = "Triggered listener change (count: %d)" % _listen_count
	# The success of this test function now depends on the success of the _make_rtdb_request calls.
	# We'll consider it successful if both DB writes were ack'd, even if the listener itself has issues (that's a separate test).
	var overall_success = set_count_result[0] and set_status_result[0]
	var result_payload = {
		"message": "Listener change trigger sent (count: %d)" % _listen_count,
		"count_set_success": set_count_result[0],
		"status_set_success": set_status_result[0],
		"count_set_payload": set_count_result[1],
		"status_set_payload": set_status_result[1]
	}
	return [overall_success, result_payload]


func _test_rtdb_listeners_remove() -> Array:
	Log.debug("RTDB Test: Remove Listener", {}, ["test"])
	if not is_instance_valid(db):
		if get_parent().visible and is_instance_valid(status_label):
			status_label.text = "[ERROR] RTDB not init."
		return [false, {"error_code": "DB_NULL", "message": "RTDB not initialized"}]

	var fp_listener: Array[String] = _test_base_path.duplicate()
	fp_listener.append_array(_listener_path_suffix)
	db.remove_listener_at_path(fp_listener)

	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = "Removed listener:\n%s" % [str(fp_listener)]
	return [true, {"message": "Listener remove requested for path: %s" % str(fp_listener)}]


func _test_rtdb_connection_monitor() -> Array:
	Log.debug("RTDB Test: Monitor Connection", {}, ["test"])
	if not is_instance_valid(db):
		if get_parent().visible and is_instance_valid(status_label):
			status_label.text = "[ERROR] RTDB not init."
		return [false, {"error_code": "DB_NULL", "message": "RTDB not initialized"}]
	db.monitor_connection_state()
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = "Monitoring connection..."
	return [true, {"message": "Connection monitoring started"}]


#-----------------------------------------------------------------------------#
# "Test All" Sequential Runner                                                #
#-----------------------------------------------------------------------------#
func _run_all_tests_by_prefix(test_prefix: String) -> void:
	if _is_running_all_tests:
		Log.warning(
			(
				"Run All '%s' active. New '%s' ignored."
				% [
					_current_run_all_category_prefix.trim_prefix("_test_").trim_suffix("_"),
					test_prefix.trim_prefix("_test_").trim_suffix("_")
				]
			),
			{},
			["debug"]
		)
		if is_instance_valid(status_label):
			status_label.text = "A 'Run All' test sequence is already active."
		return
	_is_running_all_tests = true
	_current_run_all_category_prefix = test_prefix
	var module_name: String = test_prefix.trim_prefix("_test_").trim_suffix("_")
	Log.info(
		"Preparing to run all %s tests. Cleaning prior pending." % module_name.to_upper(),
		{},
		["debug", "test"]
	)
	var pending_ids = _pending_requests.keys()
	if not pending_ids.is_empty():
		Log.warning(
			"Found %d lingering requests. Cleaning." % pending_ids.size(),
			{},
			["debug", Log.TAG_ERROR]
		)
		for req_id in pending_ids:
			var prd = _pending_requests.get(req_id)
			if is_instance_valid(prd):
				Log.debug(
					"Cleaning lingering req %d (op: %s)" % [req_id, prd.operation], {}, ["debug"]
				)
				prd._mark_as_stuck_or_cancelled(
					{"error_code": "RUN_ALL_CLEANUP", "message": "Cleaned by new Run All"}
				)
				_pending_requests.clear()
	var module_instance: Object = null
	match module_name:
		"rtdb":
			module_instance = db
		"auth":
			module_instance = auth
		"config":
			module_instance = remote_config
	if not is_instance_valid(module_instance):
		if is_instance_valid(status_label):
			status_label.text = "Cannot run: %s module not init." % module_name.to_upper()
			Log.error("Module null for %s tests." % module_name, {}, ["debug", Log.TAG_ERROR])
			_is_running_all_tests = false
			_current_run_all_category_prefix = ""
			return
	var original_mouse_filter = Control.MOUSE_FILTER_STOP
	var original_modulate_alpha = 1.0
	if is_instance_valid(item_list_navigator):
		original_mouse_filter = item_list_navigator.mouse_filter
		original_modulate_alpha = item_list_navigator.modulate.a
		item_list_navigator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_list_navigator.modulate.a = 0.5
	Log.info(
		"Starting sequential %s tests..." % module_name.to_upper(),
		{},
		["debug", "test", module_name]
	)
	var method_list: Array = get_method_list()
	method_list.sort_custom(func(a, b): return (a.name as String) < (b.name as String))
	await _run_sequential_tests(method_list, test_prefix, module_name)
	if is_instance_valid(item_list_navigator):
		item_list_navigator.mouse_filter = original_mouse_filter
		item_list_navigator.modulate.a = original_modulate_alpha
	Log.info("Finished 'Run All' for %s tests." % module_name.to_upper(), {}, ["debug", "test"])
	_is_running_all_tests = false
	_current_run_all_category_prefix = ""


func _run_sequential_tests(method_list: Array, test_prefix: String, module_name: String) -> void:
	var tests_run: int = 0
	var tests_passed: int = 0
	var tests_failed: int = 0
	for method_info_variant in method_list:
		var method_info: Dictionary = (
			method_info_variant if method_info_variant is Dictionary else {}
		)
		if not method_info.has("name"):
			continue
		var method_name: String = method_info.name if method_info.name is String else ""
		if not method_name.begins_with(test_prefix):
			continue
		tests_run += 1
		var skip_test: bool = false
		if (
			module_name == "rtdb"
			and (method_name.contains("_listeners_") or method_name.contains("_connection_"))
		):
			Log.info("Skipping manual test: %s" % method_name, {}, ["debug", "test", module_name])
			skip_test = true
		if skip_test:
			continue
		var display_method_name: String = _format_name_for_display(
			method_name.trim_prefix(test_prefix)
		)
		if get_parent().visible and is_instance_valid(status_label):
			status_label.text = "Running: %s..." % display_method_name
		Log.info("Executing test: %s" % method_name, {}, ["debug", "test", module_name])
		var result_tuple: Array = await call(method_name)
		var success: bool = false
		var payload: Variant = null
		if result_tuple.size() == 2 and result_tuple[0] is bool:
			success = result_tuple[0]
			payload = result_tuple[1]
		else:
			Log.error(
				"Test '%s' bad return: %s" % [method_name, str(result_tuple)],
				{},
				["debug", Log.TAG_ERROR]
			)
			payload = {"error": "Bad return format", "d": str(result_tuple)}
		if success:
			tests_passed += 1
			if get_parent().visible and is_instance_valid(status_label):
				status_label.text = "PASS: %s" % display_method_name
				Log.info(
					"Test PASSED: %s" % method_name, {"p": payload}, ["debug", "test", module_name]
				)
		else:
			tests_failed += 1
			if get_parent().visible and is_instance_valid(status_label):
				status_label.text = "FAIL: %s\nDetails: %s" % [display_method_name, str(payload)]
				Log.error(
					"Test FAILED: %s" % method_name,
					{"err": payload},
					["debug", "test", module_name, Log.TAG_ERROR]
				)
		await get_tree().create_timer(0.05).timeout
	var summary: String = (
		"%s Tests: %d Run, %d Passed, %d Failed"
		% [module_name.to_upper(), tests_run, tests_passed, tests_failed]
	)
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = summary
		Log.info(summary, {}, ["debug", "test", module_name])


#-----------------------------------------------------------------------------#
# Other Module Handlers & General UI                                          #
#-----------------------------------------------------------------------------#
func _on_Button_close_pressed() -> void:
	debug.action(debug.DebugEventType.EVENT_CLOSE_DB_DEBUG_MENU)


func _test_auth_basic_sign_in_anonymous() -> Array:
	Log.debug("Auth Test: Sign In Anonymous", {}, ["test"])
	if not is_instance_valid(auth):
		if get_parent().visible and is_instance_valid(status_label):
			status_label.text = "[ERROR] Auth not initialized."
			return [false, {"error_code": "AUTH_NULL", "message": "Auth module not initialized."}]
	var login_result: int = auth.login()
	var success: bool = login_result == OK
	var payload: Variant = (
		{"login_result_code": login_result}
		if success
		else {
			"error_code": "LOGIN_FAILED",
			"message": "Anonymous login failed with code: %d" % login_result
		}
	)
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = (
			"Anon Login %s: Code %d" % ["Success" if success else "Failed", login_result]
		)
		Log.info(
			"Anonymous login result", {"result": login_result, "success": success}, ["test", "auth"]
		)
		return [success, payload]
	return []


func _test_config_basic_fetch() -> Array:
	Log.debug("Config Test: Fetch", {}, ["test"])
	if not is_instance_valid(remote_config):
		if get_parent().visible and is_instance_valid(status_label):
			status_label.text = "[ERROR] Remote Config not initialized."
			return [
				false,
				{"error_code": "CONFIG_NULL", "message": "Remote Config module not initialized."}
			]
	remote_config.set_instant_fetching()
	var rc_value: String = remote_config.get_string("test_string", "local_default_for_test")
	var success: bool = rc_value != "local_default_for_test"
	var payload: Variant = {"fetched_value": rc_value, "was_default": not success}
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = (
			"RC Value: %s (Fetched: %s)" % [rc_value, "Yes" if success else "No/Default"]
		)
		Log.info(
			"Remote Config fetch test",
			{"value": rc_value, "success_assumption": success},
			["test", "config"]
		)
		return [success, payload]
	return []


func _on_Button_remote_config_string_pressed() -> void:
	pass


func remote_config_loaded() -> void:
	pass


func messaging_token() -> void:
	pass


func messaging_message(_msg_data: Dictionary) -> void:
	pass


func _on_Button_func_is_interstitial_loaded_pressed() -> void:
	pass


func _on_Button_func_is_reward_loaded_pressed() -> void:
	pass


func _on_Button_load_interstitial_pressed() -> void:
	pass


func _on_Button_play_interstitial_pressed() -> void:
	pass


func _on_Button_load_rewarded_video_pressed() -> void:
	pass


func _on_Button_play_rewarded_video_pressed() -> void:
	pass


func _on_Button_sign_in_anon_pressed() -> void:
	pass


func logged_in(_res: String) -> void:
	pass


func facebook_login_success(_result: Dictionary) -> void:
	pass


func _on_Button_sign_in_facebook_pressed() -> void:
	pass


func _on_Button_unlink_Facebook_pressed() -> void:
	pass


func _on_Button_link_Facebook_pressed() -> void:
	pass


func _on_Auth_Apple_login_pressed() -> void:
	pass


func _on_Auth_Apple_log_out_pressed() -> void:
	pass


func _on_Auth_Apple_link_pressed() -> void:
	pass


func _on_Auth_Apple_unlink_pressed() -> void:
	pass


func account_linked(_res: String) -> void:
	pass


func account_unlinked(_res: String) -> void:
	pass


func _on_Auth_Apple_has_provider_pressed() -> void:
	pass


func _on_Auth_fb_has_provider_pressed() -> void:
	pass


func _on_Button_sign_out_pressed() -> void:
	pass


func _on_Button_get_all_info_pressed() -> void:
	pass


func _on_credential(_result: Dictionary) -> void:
	pass


func _on_authorization(_result: Dictionary) -> void:
	pass
