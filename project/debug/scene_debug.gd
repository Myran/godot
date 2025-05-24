# project/debug/scene_debug.gd
extends Control

signal fb_success(res: Dictionary)
#@warning_ignore("unused_signal")
#signal _apple_success(res: Dictionary)
signal apple_auth_respons(res: Dictionary)
enum ViewLevel { MAIN_CATEGORIES, GROUP_LIST, TEST_LIST }
# Constants
const FAKE_INTERSTITIAL_AD_UNIT_IOS: String = "ca-app-pub-3940256099942544/4411468910"
const FAKE_REWARDED_VIDEO_AD_UNIT_IOS: String = "ca-app-pub-3940256099942544/1712485313"
const _RTDB_TEST_PREFIX: String = "_test_rtdb_"
const _AUTH_TEST_PREFIX: String = "_test_auth_"
const _CONFIG_TEST_PREFIX: String = "_test_config_"

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

# Firebase Module Instances
var auth: Object = null
var db: Object = null  # Instance of C++ FirebaseDatabase
var remote_config: Object = null
var messaging: Object = null
var godot_apple_auth: Object = null
var admob: Object = null
var _test_base_path: Array[String] = ["debug_tests", "rtdb"]

# Other Module Instances

var _current_view_level: ViewLevel = ViewLevel.MAIN_CATEGORIES
var _current_category_info: Dictionary = {}
var _current_group_info: Dictionary = {}
# RTDB Test State
var _next_request_id: int = 0
var _pending_requests: Dictionary = {}  # Stores request_id_int -> PendingRequestData instance
var _transaction_count: int = 0  # Declaration for RTDB tests

var _is_running_all_tests: bool = false
var _current_run_all_category_prefix: String = ""

var _listener_path_suffix: Array[String] = ["live_data"]
var _listen_count: int = 0

# UI References
@onready var status_label: RichTextLabel = %DebugRichTextLabel
@onready var item_list_navigator: ItemList = %DebugItemList

# Navigation State & Constants


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
	) -> void:
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
	) -> void:
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
	if is_instance_valid(status_label):
		var header_text: String = (
			"OS: %s | %s\nCommit: %s"
			% [OS.get_name(), debug_text, Engine.get_version_info()["hash"]]
		)
		status_label.text = header_text

	_initialize_firebase_modules()

	if is_instance_valid(item_list_navigator):
		# Use item_selected instead of item_activated to respond to single taps
		item_list_navigator.item_selected.connect(_on_navigator_item_activated)
	else:
		Log.error(
			"DebugItemList node ('item_list_navigator') not found!",
			{},
			["debug", "ui", Log.TAG_ERROR]
		)

	_populate_main_categories_view()
	%Panel.gui_input.connect(_on_panel_gui_input)


# Handle panel input (for tap-to-close functionality)
func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_released():
		Log.debug("Panel tapped, closing debug view", {}, ["debug", "ui"])
		_on_Button_close_pressed()

	#elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
	#Log.debug("Panel clicked, closing debug view", {}, ["debug", "ui"])
	#_on_Button_close_pressed()


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
			_update_status_text("[ERROR] Failed to instantiate FirebaseDatabase")
	else:
		Log.warning(
			"FirebaseDatabase C++ module class not found.",
			{},
			["debug", "initialization", Log.TAG_FIREBASE]
		)
		_update_status_text("[WARN] FirebaseDatabase C++ module not found")

	if ClassDB.class_exists("FirebaseRemoteConfig"):
		remote_config = ClassDB.instantiate("FirebaseRemoteConfig")
		if is_instance_valid(remote_config):
			var lce: Error = remote_config.connect("loaded", Callable(self, "remote_config_loaded"))
			if lce != OK:
				Log.error("Failed to connect remote_config 'loaded'", {}, ["debug"])

	if Engine.has_singleton("Auth"):
		auth = Engine.get_singleton("Auth")

	if Engine.has_singleton("GodotAppleAuth"):
		godot_apple_auth = Engine.get_singleton("GodotAppleAuth")
		if is_instance_valid(godot_apple_auth):
			var cce: Error = godot_apple_auth.connect(
				"credential", Callable(self, "_on_credential")
			)
			if cce != OK:
				Log.error("Fail GAppleAuth cred conn", {}, ["debug"])
			# Corrected to only one connection for 'authorization'
			var ace: Error = godot_apple_auth.connect(
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
	for category_def: Dictionary in CATEGORIES_DEFINITION:
		var module_instance_valid: bool = false
		var module_var_name: String = category_def.get("module_var_name", "")
		if not module_var_name.is_empty():
			var module_instance: Object = get(module_var_name)
			module_instance_valid = is_instance_valid(module_instance)
		else:
			module_instance_valid = true  # Category might not depend on a specific module instance
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
	for method_info_variant: Dictionary in method_list:
		# Already properly typed with Dictionary
		var method_info: Dictionary = method_info_variant
		var method_name: String = method_info.name
		if method_name.begins_with(category_prefix):
			var name_after_prefix: String = method_name.trim_prefix(category_prefix)
			var underscore_pos: int = name_after_prefix.find("_")
			if underscore_pos > 0:
				var group_name_raw: String = name_after_prefix.substr(0, underscore_pos)
				if not group_name_raw.is_empty() and not group_name_raw.contains("."):
					if not groups.has(group_name_raw):
						groups[group_name_raw] = {
							"display_name": _format_name_for_display(group_name_raw), "count": 0
						}
					groups[group_name_raw].count += 1
	var sorted_group_keys: Array[String]
	sorted_group_keys.assign(groups.keys())
	sorted_group_keys.sort()
	for group_name_raw_key: String in sorted_group_keys:
		var group_data: Dictionary = groups[group_name_raw_key]
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
	var has_run_all_item: bool = category_info.get("has_run_all", false)
	var min_expected_items_before_groups: int = 1
	if has_run_all_item:
		min_expected_items_before_groups += 1
	if groups.is_empty() and item_list_navigator.item_count == min_expected_items_before_groups:  # Check if only "Back" and "Run All" exist
		item_list_navigator.add_item("No further test groups in " + category_info.name + ".")
		item_list_navigator.set_item_disabled(item_idx_counter, true)  # RP: item_idx_counter should be correct here
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
	method_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.name < b.name)  # Sort for consistent order
	var items_added: bool = false
	for method_info_variant: Dictionary in method_list:
		var method_info: Dictionary = method_info_variant
		var method_name: String = method_info.name
		if method_name.begins_with(full_prefix_for_tests):
			var test_name_raw: String = method_name.trim_prefix(full_prefix_for_tests)
			if not test_name_raw.is_empty() and not test_name_raw.contains("."):  # Ensure it's a valid final part of method name
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
		item_list_navigator.set_item_disabled(item_idx_counter, true)  # RP: item_idx_counter should be correct
	item_list_navigator.ensure_current_is_visible()


# Testmove
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
			var method_name: String = metadata.get("method_name", "")
			var display_name: String = metadata.get("display_name", method_name)
			if has_method(method_name):
				Log.info("Exec test (manual): %s" % method_name, {}, ["debug", "test"])
				_update_status_text("Running: %s..." % display_name)

				var result_tuple: Array = await call(method_name)
				var success: bool = false
				var payload: Variant = null

				if result_tuple.size() == 2 and result_tuple[0] is bool:
					success = result_tuple[0]
					payload = result_tuple[1]
				else:
					Log.error(
						(
							"Test '%s' (manual) returned unexpected format: %s"
							% [method_name, str(result_tuple)]
						),
						{},
						["debug", Log.TAG_ERROR]
					)
					payload = {
						"error": "Bad return format from manual test", "details": str(result_tuple)
					}
					success = false  # Ensure failure on bad format

				if success:
					_update_status_text("PASS: %s" % display_name)
					Log.info(
						"Manual Test PASSED: %s" % method_name, {"p": payload}, ["debug", "test"]
					)
				else:
					_update_status_text("FAIL: %s\nDetails: %s" % [display_name, str(payload)])
					Log.error(
						"Manual Test FAILED: %s" % method_name,
						{"err": payload},
						["debug", "test", Log.TAG_ERROR]
					)
			else:
				Log.error("Method not found: %s" % method_name, {}, ["debug", "ui", Log.TAG_ERROR])
				_update_status_text("[ERR] Test method '%s' not found!" % method_name)
		ITEM_TYPE_BACK_TO_MAIN:
			_populate_main_categories_view()
		ITEM_TYPE_BACK_TO_GROUPS:
			var c_info: Dictionary = {
				"name": metadata.category_name,
				"prefix": metadata.category_prefix,
				"has_run_all": metadata.get("category_has_run_all", false)
			}
			_populate_groups_view(c_info)
		ITEM_TYPE_RUN_ALL_CATEGORY_TESTS:
			var cp: String = metadata.get("category_prefix")
			var cn: String = metadata.get("category_name")
			Log.info("Exec 'Run All' for: %s" % cn, {}, ["debug", "test"])
			_update_status_text("Starting all %s tests..." % cn)
			if not _is_running_all_tests:
				_run_all_tests_by_prefix(cp)
			else:
				Log.warning("Another 'Run All' test sequence is already active.", {}, ["debug"])
				_update_status_text("A 'Run All' test sequence is already active. Please wait.")
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
	for sig_name: String in rtdb_signals:
		var handler_name: String = "_on_rtdb_" + sig_name
		if not has_method(handler_name):
			Log.warning(
				"No handler for RTDB sig", {"s": sig_name, "h": handler_name}, [Log.TAG_FIREBASE]
			)
			continue
		var h_call: Callable = Callable(self, handler_name)
		if not db.is_connected(sig_name, h_call):  # Check before connecting
			var err: Error = db.connect(sig_name, h_call, CONNECT_DEFERRED)  # Use deferred for safety
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


# Helper function to update the status display while preserving header info
func _update_status_text(new_status: String) -> void:
	if is_instance_valid(status_label) and get_parent().visible:
		var debug_text: String = "Build is debug" if OS.is_debug_build() else "build is release"
		var header_text: String = (
			"OS: %s | %s\nCommit: %s\n\n"
			% [OS.get_name(), debug_text, Engine.get_version_info()["hash"]]
		)
		status_label.text = header_text + new_status


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

	var old_prd: Variant = _pending_requests[request_id]
	if not old_prd is PendingRequestData:
		Log.error(
			"Found invalid PendingRequestData object!",
			{"req_id": request_id},
			["debug", "firebase", Log.TAG_ERROR]
		)
		return
	# Direct assignment to ensure proper type
	var pending_req_data: PendingRequestData = old_prd
	_pending_requests.erase(request_id)  # Erase immediately

	var display_path: String = "/".join(pending_req_data.path)
	if success:
		var result_str: String
		if typeof(data_or_error) in [TYPE_DICTIONARY, TYPE_ARRAY]:
			result_str = JSON.stringify(data_or_error, "  ")
		else:
			result_str = str(data_or_error)
		_update_status_text(
			(
				"Success (Req %d): %s\nPath: %s\nResult: %s"
				% [request_id, pending_req_data.operation, display_path, result_str]
			)
		)
	else:
		var error_dict: Dictionary
		if data_or_error is Dictionary:
			error_dict = data_or_error
		else:
			error_dict = {"error_code": "UNKNOWN", "message": str(data_or_error)}
		_update_status_text(
			(
				"Error (Req %d): %s\nPath: %s\nCode: %s\nMsg: %s"
				% [
					request_id,
					pending_req_data.operation,
					display_path,
					error_dict.get("error_code", "N/A"),
					error_dict.get("message", "N/A")
				]
			)
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
		if get_parent().visible and is_instance_valid(status_label):
			status_label.text = "[ERROR] RTDB not initialized."
		Log.error(
			"Attempted RTDB request but db is null",
			{"operation": operation_name},
			[Log.TAG_FIREBASE, Log.TAG_ERROR]
		)
		return [false, {"error_code": "DB_NULL", "message": "RTDB not initialized."}]

	var request_id: int = _next_request_id
	_next_request_id += 1

	if _pending_requests.has(request_id):  # Should ideally not happen if _next_request_id is unique
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

	db.callv(operation_name, call_args)  # Call the C++ method

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

	# Defensive check: if the request is still in _pending_requests, it means
	# _handle_rtdb_completion_from_cpp_signal did not run for some reason (e.g., signal disconnect).
	if _pending_requests.has(request_id):
		Log.warning(
			(
				"RTDB Req %d (op: %s) STILL in _pending_requests AFTER await. Force cleaning."
				% [request_id, operation_name]
			),
			{},
			["debug", "firebase", Log.TAG_ERROR]
		)
		_pending_requests.erase(request_id)  # Clean up to prevent memory leaks or future issues

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
	# Assuming _transaction_count is updated based on the 'value' if successful
	if success and value is int:  # Or float, depending on what run_transaction_async returns
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
		status_label.text = m


func _on_rtdb_db_error(code: String, message: String) -> void:
	var m = "[E] DB Error: C:%s M:%s" % [code, message]
	Log.error("RTDB Error", {"c": code, "m": message})
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = m


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
	for i: int in range(setup_paths_suffixes.size()):
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
		if not (err_msg_l.contains("not found") or err_msg_l.contains("no data exists")):  # Allow "not found" for initial delete
			Log.warning("Problem deleting counter (may not exist)", {"r": err_p}, ["test"])
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = "Setting initial counter to 0..."  # Changed to 0 from 0.0 for int transaction
	var set_result: Array = await _make_rtdb_request("set_value_async", counter_path_suffix, [0])  # Set as int
	if not set_result[0]:
		Log.error("Failed to set initial counter", {"r": set_result[1]}, ["test", Log.TAG_ERROR])
		return [false, {"error": "Failed to set initial counter", "d": set_result[1]}]
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = "Running transaction..."
	return await _make_rtdb_request("run_transaction_async", counter_path_suffix, [1])  # Increment by int


func _test_rtdb_advanced_set_server_timestamp() -> Array:
	Log.debug("RTDB Test: Set Server Timestamp", {}, ["test"])
	return await _make_rtdb_request("set_server_timestamp_async", ["server_time"])


func _test_rtdb_listeners_add() -> Array:
	Log.debug("RTDB Test: Add Listener", {}, ["test"])
	if not is_instance_valid(db):
		if get_parent().visible and is_instance_valid(status_label):
			status_label.text = "[ERROR] RTDB not init."
		return [false, {"error_code": "DB_NULL", "message": "RTDB not initialized"}]

	var fp_listener: Array[String] = _test_base_path.duplicate()
	fp_listener.append_array(_listener_path_suffix)
	db.add_listener_at_path(fp_listener)  # This call is synchronous from GDScript's perspective

	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = "Added listener:\n%s" % [str(fp_listener)]

	var path_for_status_set: Array[String] = fp_listener.duplicate()
	path_for_status_set.append("status")
	var set_status_result: Array = await _make_rtdb_request(
		"set_value_async", path_for_status_set, ["listening_init"]
	)

	var success: bool = set_status_result[0]
	var payload: Dictionary = {
		"message":
		(
			"Listener add requested for path: %s. Initial status set: %s"
			% [str(fp_listener), "OK" if success else "FAIL"]
		),
		"status_set_payload": set_status_result[1]
	}
	if not success:
		Log.warning(
			"Failed to set initial listener status in RTDB",
			{"error_info": set_status_result[1]},
			["test", "rtdb"]
		)
	return [success, payload]


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

	var set_count_result: Array = await _make_rtdb_request(
		"set_value_async", path_count, [_listen_count]
	)
	var set_status_result: Array = await _make_rtdb_request(
		"set_value_async", path_status, ["triggered_" + str(_listen_count)]
	)

	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = "Triggered listener change (count: %d)" % _listen_count

	var overall_success: bool = set_count_result[0] and set_status_result[0]
	var result_payload: Dictionary = {
		"message": "Listener change trigger sent (count: %d)" % _listen_count,
		"count_set_success": set_count_result[0],
		"status_set_success": set_status_result[0],
		"count_set_payload": set_count_result[1] if set_count_result.size() > 1 else "N/A",  # RP: Safety for payload
		"status_set_payload": set_status_result[1] if set_status_result.size() > 1 else "N/A"  # RP: Safety for payload
	}
	if not overall_success:
		Log.warning(
			"One or more DB writes failed during listener trigger.",
			{"details": result_payload},
			["test", "rtdb"]
		)

	return [overall_success, result_payload]


func _test_rtdb_listeners_remove() -> Array:
	Log.debug("RTDB Test: Remove Listener", {}, ["test"])
	if not is_instance_valid(db):
		if get_parent().visible and is_instance_valid(status_label):
			status_label.text = "[ERROR] RTDB not init."
		return [false, {"error_code": "DB_NULL", "message": "RTDB not initialized"}]

	var fp_listener: Array[String] = _test_base_path.duplicate()
	fp_listener.append_array(_listener_path_suffix)
	db.remove_listener_at_path(fp_listener)  # Synchronous from GDScript perspective

	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = "Removed listener:\n%s" % [str(fp_listener)]
	return [true, {"message": "Listener remove requested for path: %s" % str(fp_listener)}]


func _test_rtdb_connection_monitor() -> Array:
	Log.debug("RTDB Test: Monitor Connection", {}, ["test"])
	if not is_instance_valid(db):
		if get_parent().visible and is_instance_valid(status_label):
			status_label.text = "[ERROR] RTDB not init."
		return [false, {"error_code": "DB_NULL", "message": "RTDB not initialized"}]
	db.monitor_connection_state()  # Synchronous from GDScript perspective
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
		for req_id: int in pending_ids:  # Iterate over a copy if modification occurs
			var prd = _pending_requests.get(req_id)
			if is_instance_valid(prd):
				Log.debug(
					"Cleaning lingering req %d (op: %s)" % [req_id, prd.operation], {}, ["debug"]
				)
				prd._mark_as_stuck_or_cancelled(
					{"error_code": "RUN_ALL_CLEANUP", "message": "Cleaned by new Run All"}
				)
		_pending_requests.clear()  # Clear after processing all

	var module_instance: Object = null
	match module_name:
		"rtdb":
			module_instance = db
		"auth":
			module_instance = auth
		"config":
			module_instance = remote_config
		_:  # Default case if module_name doesn't match
			Log.error("Unknown module for Run All: %s" % module_name, {}, ["debug", Log.TAG_ERROR])

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
	method_list.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var a_name: String = a.name
			var b_name: String = b.name
			return a_name < b_name
	)  # Ensure consistent order

	await _run_sequential_tests(method_list, test_prefix, module_name)
	if is_instance_valid(item_list_navigator):
		item_list_navigator.mouse_filter = original_mouse_filter
		item_list_navigator.modulate.a = original_modulate_alpha

	Log.info("Finished 'Run All' for %s tests." % module_name.to_upper(), {}, ["debug", "test"])
	_is_running_all_tests = false
	_current_run_all_category_prefix = ""


func _run_sequential_tests(method_list: Array, test_prefix: String, module_name: String) -> void:
	var tests_run: int = 0
	var tests_passed_count: int = 0
	var tests_failed_count: int = 0
	var passed_test_names: Array[String] = []  # Array to store names of passed tests

	for method_info_variant: Dictionary in method_list:
		var method_info: Dictionary = (
			method_info_variant if method_info_variant is Dictionary else {}
		)
		if not method_info.has("name"):
			continue  # Skip if no name, should not happen

		var method_name: String = method_info.name if method_info.name is String else ""
		if not method_name.begins_with(test_prefix):
			continue  # Skip methods not matching the current test prefix

		tests_run += 1
		var display_method_name: String = _format_name_for_display(
			method_name.trim_prefix(test_prefix)
		)

		if get_parent().visible and is_instance_valid(status_label):
			status_label.text = "Running: %s..." % display_method_name
		Log.info("Executing test: %s" % method_name, {}, ["debug", "test", module_name])

		var result_tuple: Array = await call(method_name)  # Await the async test method
		var success: bool = false
		var payload: Variant = null

		if result_tuple.size() == 2 and result_tuple[0] is bool:
			success = result_tuple[0]
			payload = result_tuple[1]
		else:
			Log.error(
				"Test '%s' returned unexpected format: %s" % [method_name, str(result_tuple)],
				{},
				["debug", Log.TAG_ERROR]
			)
			payload = {"error": "Bad return format from test", "details": str(result_tuple)}
			success = false  # Ensure failure on bad format

		if success:
			tests_passed_count += 1
			passed_test_names.append(display_method_name)  # Add to list of passed tests
			if get_parent().visible and is_instance_valid(status_label):
				status_label.text = "PASS: %s" % display_method_name
			Log.info(
				"Test PASSED: %s" % method_name, {"p": payload}, ["debug", "test", module_name]
			)
		else:
			tests_failed_count += 1
			if get_parent().visible and is_instance_valid(status_label):
				status_label.text = "FAIL: %s\nDetails: %s" % [display_method_name, str(payload)]
			Log.error(
				"Test FAILED: %s" % method_name,
				{"err": payload},
				["debug", "test", module_name, Log.TAG_ERROR]
			)

		await get_tree().create_timer(0.05).timeout  # Small delay between tests if needed

	var summary_passed_list_str: String = ""
	if not passed_test_names.is_empty():
		summary_passed_list_str = "\nPassed tests:\n - " + "\n - ".join(passed_test_names)

	var summary: String = (
		"%s Tests: %d Run, %d Passed, %d Failed.%s"
		% [
			module_name.to_upper(),
			tests_run,
			tests_passed_count,
			tests_failed_count,
			summary_passed_list_str
		]
	)
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = summary
	Log.info(summary, {}, ["debug", "test", module_name])


#-----------------------------------------------------------------------------#
# Other Module Handlers & General UI                                          #
#-----------------------------------------------------------------------------#
func _on_Button_close_pressed() -> void:
	DebugManager.action(DebugManager.DebugEventType.EVENT_CLOSE_DB_DEBUG_MENU)


func _test_auth_basic_sign_in_anonymous() -> Array:
	Log.debug("Auth Test: Sign In Anonymous", {}, ["test"])
	if not is_instance_valid(auth):
		if get_parent().visible and is_instance_valid(status_label):
			status_label.text = "[ERROR] Auth not initialized."
		return [false, {"error_code": "AUTH_NULL", "message": "Auth module not initialized."}]

	var login_result: int = await auth.login()  # Assuming auth.login() is async or returns a signal to await
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


func _test_config_basic_fetch() -> Array:
	Log.debug("Config Test: Fetch", {}, ["test"])
	if not is_instance_valid(remote_config):
		if get_parent().visible and is_instance_valid(status_label):
			status_label.text = "[ERROR] Remote Config not initialized."
		return [
			false, {"error_code": "CONFIG_NULL", "message": "Remote Config module not initialized."}
		]
	# Ensure instant fetching for test reliability if needed
	remote_config.set_instant_fetching()
	# The `loaded` signal might be better to await for reliable fetching in tests,
	# but for a basic test, direct get might suffice if defaults are set and fetch is quick.
	if not remote_config.loaded():  # Await if not loaded for more reliability
		await remote_config.loaded  # Wait for FetchAndActivate to complete
	var rc_value: String = remote_config.get_string("test_string", "local_default_for_test")
	var success: bool = rc_value != "local_default_for_test"  # Success if not default
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


# Placeholder for AdMob, assuming it might be re-integrated or tested later
func _on_Button_func_is_interstitial_loaded_pressed() -> void:
	Log.debug("Button: Is Interstitial Loaded pressed", {}, ["debug_ui", "admob_test"])
	# if is_instance_valid(admob): status_label.text = "Interstitial Loaded: " + str(admob.is_interstitial_loaded())


func _on_Button_func_is_reward_loaded_pressed() -> void:
	Log.debug("Button: Is Reward Loaded pressed", {}, ["debug_ui", "admob_test"])
	# if is_instance_valid(admob): status_label.text = "Reward Loaded: " + str(admob.is_rewarded_video_loaded())


func _on_Button_load_interstitial_pressed() -> void:
	Log.debug("Button: Load Interstitial pressed", {}, ["debug_ui", "admob_test"])
	# if is_instance_valid(admob): admob.load_interstitial()


func _on_Button_play_interstitial_pressed() -> void:
	Log.debug("Button: Play Interstitial pressed", {}, ["debug_ui", "admob_test"])
	# if is_instance_valid(admob): admob.show_interstitial()


func _on_Button_load_rewarded_video_pressed() -> void:
	Log.debug("Button: Load Rewarded Video pressed", {}, ["debug_ui", "admob_test"])
	# if is_instance_valid(admob): admob.load_rewarded_video()


func _on_Button_play_rewarded_video_pressed() -> void:
	Log.debug("Button: Play Rewarded Video pressed", {}, ["debug_ui", "admob_test"])
	# if is_instance_valid(admob): admob.show_rewarded_video()


# Auth Callbacks (from FirebaseAuth C++ module)
func logged_in(res_code: int) -> void:  # res is an int (error code)
	var success: bool = res_code == 0  # Assuming 0 means success
	var message: String = (
		"Firebase Login %s. Code: %d" % ["Succeeded" if success else "Failed", res_code]
	)
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = message
	Log.info(
		"Firebase Auth: Logged In callback",
		{"code": res_code, "success": success},
		["firebase", "auth"]
	)
	fb_success.emit({"type": "login", "success": success, "code": res_code})


func account_linked(res_code: int) -> void:  # res is an int (error code)
	var success: bool = res_code == 0
	var message: String = (
		"Firebase Account Link %s. Code: %d" % ["Succeeded" if success else "Failed", res_code]
	)
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = message
	Log.info(
		"Firebase Auth: Account Linked callback",
		{"code": res_code, "success": success},
		["firebase", "auth"]
	)
	fb_success.emit({"type": "link", "success": success, "code": res_code})


func account_unlinked(error_message: String) -> void:  # res is error_message (String)
	var success: bool = error_message.is_empty()  # No error message means success
	var message: String = "Firebase Account Unlink %s." % ["Succeeded" if success else "Failed"]
	if not success:
		message += " Error: %s" % error_message
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = message
	Log.info(
		"Firebase Auth: Account Unlinked callback",
		{"error": error_message, "success": success},
		["firebase", "auth"]
	)
	fb_success.emit({"type": "unlink", "success": success, "error_message": error_message})


# Facebook Callbacks (from project/facebook/facebook.gd)
func facebook_login_success(token: String) -> void:
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = "Facebook Login Success: Token received."
	Log.info("Facebook SDK: Login Success", {"token_len": token.length()}, ["facebook", "auth"])
	fb_success.emit({"type": "fb_login", "success": true, "token": token})


# Apple Auth Callbacks (from project/firebase/auth.gd which wraps GodotAppleAuth)
func _on_credential(result: Dictionary) -> void:  # From GodotAppleAuth
	var success = not result.has("error")
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = (
			"Apple Credential Status: %s"
			% ("OK" if success else result.get("error", "Unknown Error"))
		)
	Log.info(
		"Apple Auth: Credential Callback", {"result": result, "success": success}, ["apple", "auth"]
	)
	apple_auth_respons.emit(result)  # Forward to test methods if they await this


func _on_authorization(result: Dictionary) -> void:  # From GodotAppleAuth
	var success = not result.has("error")
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = (
			"Apple Authorization: %s"
			% ("Success" if success else result.get("error", "Unknown Error"))
		)
	Log.info(
		"Apple Auth: Authorization Callback",
		{"result": result, "success": success},
		["apple", "auth"]
	)
	apple_auth_respons.emit(result)


# Remote Config Callbacks
func remote_config_loaded() -> void:
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = "Remote Config: Data loaded and activated."
	Log.info("Remote Config: Loaded callback received.", {}, ["firebase", "config"])


# Firebase Messaging Callbacks (if used in tests)
func messaging_token() -> void:  # Placeholder, actual token string needed from signal
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = "FCM Token Received (see logs)."
	Log.info("FCM: Token received.", {}, ["firebase", "messaging"])


func messaging_message(msg_data: Dictionary) -> void:
	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = "FCM Message Received: From " + msg_data.get("from", "N/A")
	Log.info("FCM: Message received.", {"data": msg_data}, ["firebase", "messaging"])


# --- UI Button Handlers (Simplified, actual test logic is in _test_* methods) ---
func _on_Button_sign_in_anon_pressed() -> void:
	call_deferred("_test_auth_basic_sign_in_anonymous")


func _on_Button_sign_in_facebook_pressed() -> void:
	Log.debug("UI: Sign In Facebook pressed.", {}, ["debug_ui", "auth"])
	# _test_auth_facebook_sign_in() # Example if you had such a test


func _on_Button_unlink_Facebook_pressed() -> void:
	Log.debug("UI: Unlink Facebook pressed.", {}, ["debug_ui", "auth"])
	# _test_auth_facebook_unlink()


func _on_Button_link_Facebook_pressed() -> void:
	Log.debug("UI: Link Facebook pressed.", {}, ["debug_ui", "auth"])
	# _test_auth_facebook_link()


func _on_Auth_Apple_login_pressed() -> void:
	Log.debug("UI: Apple Login pressed.", {}, ["debug_ui", "auth"])
	# _test_auth_apple_sign_in()


func _on_Auth_Apple_log_out_pressed() -> void:
	Log.debug("UI: Apple Logout pressed.", {}, ["debug_ui", "auth"])
	# _test_auth_apple_log_out()


func _on_Auth_Apple_link_pressed() -> void:
	Log.debug("UI: Apple Link pressed.", {}, ["debug_ui", "auth"])
	# _test_auth_apple_link()


func _on_Auth_Apple_unlink_pressed() -> void:
	Log.debug("UI: Apple Unlink pressed.", {}, ["debug_ui", "auth"])
	# _test_auth_apple_unlink()


func _on_Auth_Apple_has_provider_pressed() -> void:
	Log.debug("UI: Apple Has Provider pressed.", {}, ["debug_ui", "auth"])
	# if is_instance_valid(auth): status_label.text = "Apple Linked: " + str(auth.check_provider_connection("apple.com"))


func _on_Auth_fb_has_provider_pressed() -> void:
	Log.debug("UI: FB Has Provider pressed.", {}, ["debug_ui", "auth"])
	# if is_instance_valid(auth): status_label.text = "FB Linked: " + str(auth.check_provider_connection("facebook.com"))


func _on_Button_sign_out_pressed() -> void:
	Log.debug("UI: Sign Out pressed.", {}, ["debug_ui", "auth"])
	# if is_instance_valid(auth): auth.firebase_auth.sign_out(); status_label.text = "Sign out called."


func _on_Button_get_all_info_pressed() -> void:
	Log.debug("UI: Get All Info pressed.", {}, ["debug_ui", "auth"])
	# if is_instance_valid(auth) and auth.firebase_auth.is_logged_in():
	# 	var info_text = "UID: %s\nName: %s\nEmail: %s\nPhoto: %s\nProviders: %s" % [
	# 		auth.firebase_auth.uid(),
	# 		auth.firebase_auth.user_name(),
	# 		auth.firebase_auth.email(),
	# 		auth.firebase_auth.photo_url(),
	# 		JSON.stringify(auth.firebase_auth.providers())
	# 	]
	# 	status_label.text = info_text
	# else:
	# 	status_label.text = "Not logged in to Firebase."


func _on_Button_remote_config_string_pressed() -> void:
	call_deferred("_test_config_basic_fetch")
