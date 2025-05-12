# File: project/debug/debug.gd
# Updated to test the new C++ Firebase Realtime Database module
# Includes AUTOMATIC TABBED button creation based on function names.
# Convention: _test_rtdb_[group_name]_[test_description]
# Example:    _test_rtdb_basic_set_simple_value

extends Control

signal fb_success(res: Dictionary)
# Intentionally unused for future implementation
@warning_ignore("unused_signal")
signal _apple_success(res: Dictionary) # Prefixed with underscore to avoid warning
@warning_ignore("unused_signal")
signal timed_out # Adding warning ignore for unused signal

# Constants for AdMob (kept for completeness, but not the focus)
const FAKE_INTERSTITIAL_AD_UNIT_IOS: String = "ca-app-pub-3940256099942544/4411468910"
const FAKE_REWARDED_VIDEO_AD_UNIT_IOS: String = "ca-app-pub-3940256099942544/1712485313"

# Firebase Module Instances (nullable)
var auth: Object = null
var db: Object = null
var remote_config: Object = null
var messaging: Object = null

# Other Module Instances (nullable)
var godot_apple_auth: Object = null
var admob: Object = null

# --- UI References ---
@onready var status_label: RichTextLabel = %DebugRichTextLabel
@onready var close_button: Button = %Button_close
@onready var tab_container: TabContainer = %TabContainer # Ensure this exists in your scene!

# RTDB Test State
var _next_request_id: int = 0
var _pending_requests: Dictionary = {}
const _test_base_path: Array[String] = ["debug_tests", "rtdb"]
var _listener_path_suffix: Array[String] = ["live_data"]
var _listen_count: int = 0
var _transaction_count: int = 0
const _RTDB_TEST_PREFIX: String = "_test_rtdb_"
# Define connection status to avoid implicit type inference
var connection_status: String = ""



#-----------------------------------------------------------------------------#
# Initialization                                                              #
#-----------------------------------------------------------------------------#

func setup(init_args: Dictionary) -> void:
	Log.debug("Debug setup with arguments", init_args, ["debug", "initialization"])

func _ready() -> void:
	Log.info("Debug Node _ready: Starting initialization.", {}, ["debug", "initialization"])
	Engine.print_error_messages = true
	Engine.print_to_stdout = true
	var debug_text: String = "Build is debug" if OS.is_debug_build() else "build is release"
	%DebugRichTextLabel2.text = str("OS: ", OS.get_name(), debug_text)
	%DebugRichTextLabel3.text = str("Commit: ", Engine.get_version_info()["hash"])

	# --- Initialize Firebase Database C++ Module ---
	Log.debug("Checking for FirebaseDatabase class...", {}, ["debug", "initialization", Log.TAG_FIREBASE])
	if ClassDB.class_exists("FirebaseDatabase"):
		Log.info("FirebaseDatabase class found. Instantiating...", {}, ["debug", "initialization", Log.TAG_FIREBASE])
		db = ClassDB.instantiate("FirebaseDatabase")
		if db:
			Log.debug("FirebaseDatabase instance created successfully.", {"db_instance": db}, ["debug", "initialization", Log.TAG_FIREBASE])
			_connect_rtdb_signals()
			_create_rtdb_test_tabs_from_methods()
		else:
			Log.error("Failed to instantiate FirebaseDatabase!", {}, ["debug", "initialization", Log.TAG_FIREBASE, Log.TAG_ERROR])
			status_label.text = "[ERROR] Failed to instantiate FirebaseDatabase"
			if tab_container: tab_container.visible = false; Log.warning("Hiding TabContainer as DB init failed.", {}, ["debug", "ui"])
	else:
		Log.warning("FirebaseDatabase C++ module class not found.", {}, ["debug", "initialization", Log.TAG_FIREBASE])
		status_label.text = "[WARN] FirebaseDatabase C++ module not found"
		if tab_container: tab_container.visible = false; Log.warning("Hiding TabContainer as DB class not found.", {}, ["debug", "ui"])

	# --- Initialize Other Firebase Modules (Optional) ---
	if ClassDB.class_exists("FirebaseRemoteConfig"): Log.info("Checking for FirebaseRemoteConfig...", {}, ["debug", "initialization"]); remote_config = ClassDB.instantiate("FirebaseRemoteConfig"); if remote_config: remote_config.connect("loaded", Callable(self, "remote_config_loaded"))
	# if ClassDB.class_exists("FirebaseMessaging"): Log.info("Checking for FirebaseMessaging...", {}, ["debug", "initialization"]); messaging = ClassDB.instantiate("FirebaseMessaging"); if messaging: messaging.connect("token", Callable(self, "messaging_token")); messaging.connect("message", Callable(self, "messaging_message"))
	if Engine.has_singleton("Auth"): Log.info("Checking for Auth singleton...", {}, ["debug", "initialization"]); auth = Engine.get_singleton("Auth")

	# --- Initialize Other SDKs (Placeholders) ---
	if Engine.has_singleton("GodotAppleAuth"): Log.info("Checking for GodotAppleAuth singleton...", {}, ["debug", "initialization"]); godot_apple_auth = Engine.get_singleton("GodotAppleAuth"); if godot_apple_auth: godot_apple_auth.connect("credential", Callable(self, "_on_credential")); godot_apple_auth.connect("authorization", Callable(self, "_on_authorization"))
	if Engine.has_singleton("Facebook") or Engine.has_singleton("GodotFacebook"): Log.info("Facebook SDK available.", {}, [Log.TAG_FACEBOOK]); # Connect signals if needed
	# if ClassDB.class_exists("FirebaseAdmob"): Log.info("Checking for FirebaseAdmob class...", {}, ["debug", "initialization"]); admob = ClassDB.instantiate("FirebaseAdmob") # Connect signals if needed

	# --- Connect UI Buttons (Non-RTDB ones) ---
	Log.debug("Connecting non-RTDB UI buttons...", {}, ["debug", "ui", "initialization"])
	if close_button:
		var close_conn_err: int = close_button.pressed.connect(_on_Button_close_pressed,ConnectFlags.CONNECT_DEFERRED)
		if close_conn_err == OK:
			Log.debug("Connected close_button (%Button_close) pressed signal.", {}, ["debug", "ui"])
		else:
			Log.error("Failed to connect close_button (%Button_close) pressed signal!", {"error": error_string(close_conn_err)}, ["debug", "ui", Log.TAG_ERROR])
	else:
		Log.error("Close button node (%Button_close) not found!", {}, ["debug", "ui", Log.TAG_ERROR])

	Log.info("Debug Node _ready: Initialization complete.", {}, ["debug", "initialization"])

#-----------------------------------------------------------------------------#
# Firebase RTDB: Automatic Button Creation                                    #
#-----------------------------------------------------------------------------#

## Creates tabs and buttons based on methods prefixed with _test_rtdb_
func _create_rtdb_test_tabs_from_methods() -> void:
	Log.debug("Starting automatic RTDB button creation...", {}, ["debug", "ui", "rtdb"])
	if not tab_container:
		Log.error("Cannot create RTDB buttons: TabContainer node (%TabContainer) not found!", {}, ["debug", "ui", Log.TAG_ERROR])
		return

	Log.debug("Clearing previous dynamic RTDB tabs...", {}, ["debug", "ui", "rtdb"])
	var cleared_count: int = 0
	for i: int in range(tab_container.get_tab_count() - 1, -1, -1):
		var child: Control = tab_container.get_tab_control(i)
		if child and child.has_meta("_dynamic_rtdb_tab"):
			tab_container.remove_child(child)
			child.queue_free()
			cleared_count += 1
	Log.debug("Cleared %d dynamic tabs." % cleared_count, {}, ["debug", "ui", "rtdb"])

	var method_list: Array = get_method_list()
	Log.debug("Found %d total methods in script." % method_list.size(), {}, ["debug", "ui", "rtdb"])
	var created_button_count: int = 0
	var group_containers: Dictionary = {}

	var sort_func: Callable = func(a: Dictionary, b: Dictionary) -> bool:
		return a.name < b.name
	method_list.sort_custom(sort_func)

	for method_info: Dictionary in method_list:
		var method_name: String = method_info.name
		if method_name.begins_with(_RTDB_TEST_PREFIX):
			Log.debug("Found potential test method: %s" % method_name, {}, ["debug", "ui", "rtdb"])
			var name_without_prefix: String = method_name.trim_prefix(_RTDB_TEST_PREFIX)
			var underscore_pos: int = name_without_prefix.find("_")

			if underscore_pos <= 0:
				Log.warning("Method '%s' skipped: No '_' found after prefix." % method_name, {}, ["debug", "ui", "rtdb"])
				continue

			var group_name: String = name_without_prefix.substr(0, underscore_pos)
			var test_description: String = name_without_prefix.substr(underscore_pos + 1)

			if group_name.is_empty() or test_description.is_empty():
				Log.warning("Method '%s' skipped: Empty group or description." % method_name, {}, ["debug", "ui", "rtdb"])
				continue

			Log.debug("Parsed method '%s': Group='%s', Desc='%s'" % [method_name, group_name, test_description], {}, ["debug", "ui", "rtdb"])

			# Ensure Group Tab/Container Exists
			var target_container: VBoxContainer
			if not group_containers.has(group_name):
				Log.debug("Creating new container and tab for group: %s" % group_name, {}, ["debug", "ui", "rtdb"])
				target_container = VBoxContainer.new()
				target_container.name = "VBox_" + group_name
				target_container.set_meta("_dynamic_rtdb_tab", true)
				tab_container.add_child(target_container)
				var tab_idx: int = tab_container.get_tab_count() - 1
				var tab_title: String = _format_name_for_display(group_name)
				tab_container.set_tab_title(tab_idx, tab_title)
				group_containers[group_name] = target_container
				Log.debug("Added tab '%s' with container '%s'" % [tab_title, target_container.name], {}, ["debug", "ui", "rtdb"])
			else:
				target_container = group_containers[group_name]
				Log.debug("Using existing container for group: %s" % group_name, {}, ["debug", "ui", "rtdb"])

			# Create and Add Button
			var button_text: String = _format_name_for_display(test_description)
			var button: Button = Button.new()
			button.text = button_text
			button.name = "Btn_" + method_name

			Log.debug("Attempting to connect button '%s' to method '%s'" % [button_text, method_name], {}, ["debug", "ui", "rtdb"])
			var err: int = button.pressed.connect(Callable(self, method_name), CONNECT_DEFERRED)
			if err != OK:
				Log.error("Failed to connect button signal", {"text": button.text, "method": method_name, "error": error_string(err)}, ["debug", "ui", Log.TAG_ERROR])
				button.disabled = true
			else:
				button.disabled = (db == null)
				Log.debug("Successfully connected button '%s'." % button_text, {}, ["debug", "ui", "rtdb"])

			Log.debug("Adding button '%s' to container '%s'" % [button_text, target_container.name], {}, ["debug", "ui", "rtdb"])
			target_container.add_child(button)
			if not button.get_parent() == target_container:
				Log.error("Button '%s' failed to be added to container '%s'!" % [button_text, target_container.name], {}, ["debug", "ui", Log.TAG_ERROR])

			created_button_count += 1

	Log.info("Finished auto-button creation: %d buttons across %d tabs." % [created_button_count, group_containers.size()], {}, ["debug", "ui", "rtdb"])
	if created_button_count == 0 and db != null:
		Log.warning("No methods found with prefix '%s'. No RTDB test buttons created." % _RTDB_TEST_PREFIX, {}, ["debug", "ui", "rtdb"])

## Formats a snake_case name into a readable Title Case string
func _format_name_for_display(name_part: String) -> String:
	if name_part.is_empty(): return ""
	return name_part.replace("_", " ").capitalize()

#-----------------------------------------------------------------------------#
# Firebase RTDB: Signal Connections & Request Handling                        #
#-----------------------------------------------------------------------------#

func _connect_rtdb_signals() -> void:
	if db == null: return
	Log.debug("Connecting Firebase RTDB signals", {}, [Log.TAG_FIREBASE])
	var connection_handler: Callable = func(signal_name: String, handler: Callable) -> void:
		if not db.is_connected(signal_name, handler):
			var err: int = db.connect(signal_name, handler, CONNECT_DEFERRED)
			if err != OK:
				Log.error("Failed to connect RTDB signal", {"signal": signal_name, "error": error_string(err)}, [Log.TAG_FIREBASE, Log.TAG_ERROR])
	var connect_ok: Callable = connection_handler
	connect_ok.call("get_value_completed", Callable(self, "_on_rtdb_get_value_completed"))
	connect_ok.call("get_value_error", Callable(self, "_on_rtdb_get_value_error"))
	connect_ok.call("set_value_completed", Callable(self, "_on_rtdb_set_value_completed"))
	connect_ok.call("push_and_update_completed", Callable(self, "_on_rtdb_push_and_update_completed"))
	connect_ok.call("remove_value_completed", Callable(self, "_on_rtdb_remove_value_completed"))
	connect_ok.call("query_completed", Callable(self, "_on_rtdb_query_completed"))
	connect_ok.call("query_error", Callable(self, "_on_rtdb_query_error"))
	connect_ok.call("transaction_completed", Callable(self, "_on_rtdb_transaction_completed"))
	connect_ok.call("child_added", Callable(self, "_on_rtdb_child_added"))
	connect_ok.call("child_changed", Callable(self, "_on_rtdb_child_changed"))
	connect_ok.call("child_moved", Callable(self, "_on_rtdb_child_moved"))
	connect_ok.call("child_removed", Callable(self, "_on_rtdb_child_removed"))
	connect_ok.call("connection_state_changed", Callable(self, "_on_rtdb_connection_state_changed"))
	connect_ok.call("db_error", Callable(self, "_on_rtdb_db_error"))

func _make_rtdb_request(operation_name: String, path_suffix: Array[String], args: Array = []) -> void:
	if db == null:
		status_label.text = "[ERROR] RTDB not initialized."
		Log.error("Attempted RTDB request but db is null", {"operation": operation_name}, [Log.TAG_FIREBASE, Log.TAG_ERROR])
		return
	var request_id: int = _next_request_id; _next_request_id += 1
	var full_path: Array[String] = _test_base_path + path_suffix
	_pending_requests[request_id] = { "operation": operation_name, "path": full_path }
	var call_args: Array = [request_id, full_path]; call_args.append_array(args)
	Log.debug("Making RTDB request", { "req_id": request_id, "op": operation_name, "path": full_path, "args#": args.size() }, [Log.TAG_FIREBASE, Log.TAG_NETWORK])
	status_label.text = "Sending req %d: %s\nPath: %s" % [request_id, operation_name, full_path]
	db.callv(operation_name, call_args)

#-----------------------------------------------------------------------------#
# Firebase RTDB: Test Functions (Linked to Buttons)                           #
#-----------------------------------------------------------------------------#

# --- Group: basic ---
func _test_rtdb_basic_set_simple_value() -> void: Log.debug("RTDB Test: Set Simple Value", {}, ["test"]); _transaction_count += 1; _make_rtdb_request("set_value_async", ["simple_value"], ["Basic Value " + str(_transaction_count)])
func _test_rtdb_basic_get_simple_value() -> void: Log.debug("RTDB Test: Get Simple Value", {}, ["test"]); _make_rtdb_request("get_value_async", ["simple_value"])
func _test_rtdb_basic_push_item() -> void:
	Log.debug("RTDB Test: Push Item", {}, ["test"])
	_transaction_count += 1
	var push_data: Dictionary = {"msg": "Pushed " + str(_transaction_count), "ts": Time.get_unix_time_from_system()}
	_make_rtdb_request("push_and_update_async", ["pushed_items"], [push_data])
func _test_rtdb_basic_set_dictionary() -> void:
	Log.debug("RTDB Test: Set Dictionary", {}, ["test"])
	_transaction_count += 1
	var dict_data: Dictionary = {"a": "Dict A " + str(_transaction_count), "b": true, "c": _transaction_count}
	_make_rtdb_request("set_value_async", ["dictionary_target"], [dict_data])
func _test_rtdb_basic_delete_dictionary() -> void: Log.debug("RTDB Test: Delete Dictionary Target", {}, ["test"]); _make_rtdb_request("remove_value_async", ["dictionary_target"])

# --- Group: advanced ---
func _test_rtdb_advanced_query_top_2_scores() -> void:
	Log.debug("RTDB Test: Query Top 2 Scores", {}, ["test"])
	status_label.text = "Setting up query data..."
	var ps: Array = ["query_items"]
	_make_rtdb_request("set_value_async", ps + ["item1"], [{"name": "A", "score": 50}])
	_make_rtdb_request("set_value_async", ps + ["item2"], [{"name": "B", "score": 100}])
	_make_rtdb_request("set_value_async", ps + ["item3"], [{"name": "C", "score": 75}])
	call_deferred("_execute_query_test", ps)
func _execute_query_test(path_suffix: Array[String]) -> void:
	# Keep await to align with all backends even though it's redundant
	@warning_ignore("redundant_await")
	await get_tree().create_timer(1.0).timeout
	var qp: Dictionary = {"orderByChild": "score", "limitToLast": 2}
	_make_rtdb_request("query_ordered_data_async", path_suffix, [qp])
func _test_rtdb_advanced_increment_transaction() -> void: Log.debug("RTDB Test: Increment Transaction", {}, ["test"]); call_deferred("_execute_transaction_test")
func _execute_transaction_test() -> void:
	var crid: int = _next_request_id
	_next_request_id += 1
	var cp: Array[String] = _test_base_path + ["counter"]
	_pending_requests[crid] = { "operation": "get_value_check_for_transaction", "path": cp }
	db.callv("get_value_async", [crid, cp])
func _test_rtdb_advanced_set_server_timestamp() -> void: Log.debug("RTDB Test: Set Server Timestamp", {}, ["test"]); _make_rtdb_request("set_server_timestamp_async", ["server_time"])

# --- Group: listeners ---
func _test_rtdb_listeners_add() -> void:
	Log.debug("RTDB Test: Add Listener", {}, ["test"])
	if db:
		var fp: Array[String] = _test_base_path + _listener_path_suffix
		db.add_listener_at_path(fp)
		status_label.text = "Added listener:\n%s" % [fp]
		_listen_count = 0
		_make_rtdb_request("set_value_async", _listener_path_suffix, [{"status": "listening", "count": _listen_count}])
	else:
		status_label.text = "[ERROR] RTDB not init."
func _test_rtdb_listeners_trigger_change() -> void:
	Log.debug("RTDB Test: Trigger Listener Change", {}, ["test"])
	_listen_count += 1
	_make_rtdb_request("set_value_async", _listener_path_suffix + ["count"], [_listen_count])
	_make_rtdb_request("set_value_async", _listener_path_suffix + ["status"], ["triggered_" + str(_listen_count)])
func _test_rtdb_listeners_remove() -> void:
	Log.debug("RTDB Test: Remove Listener", {}, ["test"])
	if db:
		var fp: Array[String] = _test_base_path + _listener_path_suffix
		db.remove_listener_at_path(fp)
		status_label.text = "Removed listener:\n%s" % [fp]
	else:
		status_label.text = "[ERROR] RTDB not init."

# --- Group: connection ---
func _test_rtdb_connection_monitor() -> void:
	Log.debug("RTDB Test: Monitor Connection", {}, ["test"])
	if db:
		db.monitor_connection_state()
		status_label.text = "Monitoring connection..."
	else:
		status_label.text = "[ERROR] RTDB not init."
#-----------------------------------------------------------------------------#
# Firebase RTDB: Signal Handlers                                              #
#-----------------------------------------------------------------------------#

func _handle_rtdb_response(request_id: int, success: bool, result: Variant, error_code: String = "", error_message: String = "") -> void:
	if not _pending_requests.has(request_id):
		Log.warning("Response for unknown/timed-out RTDB request", {"req_id": request_id}, [Log.TAG_FIREBASE, "test"])
		return

	var req_data: Dictionary = _pending_requests[request_id]
	var op_name: String = req_data.operation
	var path: Array = req_data.path

	# Special handling for transaction pre-check
	if op_name == "get_value_check_for_transaction":
		_pending_requests.erase(request_id) # Remove check request first
		var relative_path: Array[String] = path.slice(len(_test_base_path)) # Get suffix for potential next request
		if not success or result == null:
			# Counter doesn't exist, initialize it first
			Log.debug("Transaction counter needs init.", {"path": path}, ["test"])
			var init_req_id: int = _next_request_id
			_next_request_id += 1
			_pending_requests[init_req_id] = {"operation": "set_value_for_transaction", "path": path}
			db.callv("set_value_async", [init_req_id, path, 0])
		else:
			# Counter exists, run the transaction immediately
			Log.debug("Transaction counter exists, running transaction.", {"path": path}, ["test"])
			_make_rtdb_request("run_transaction_async", relative_path, [1]) # Use relative path suffix
		return # Stop processing this specific response

	# Special handling for transaction initialization completion
	if op_name == "set_value_for_transaction":
		_pending_requests.erase(request_id) # Remove init request first
		var relative_path: Array[String] = path.slice(len(_test_base_path)) # Get suffix for next request
		if success:
			# Initialization successful, now run the transaction
			Log.debug("Transaction counter initialized, running transaction.", {"path": path}, ["test"])
			_make_rtdb_request("run_transaction_async", relative_path, [1]) # Use relative path suffix
		else:
			# Initialization failed
			Log.error("Failed init for transaction", {"path": path, "error": error_message}, ["test"])
			status_label.text = "Error: Failed init counter for transaction."
		return # Stop processing this specific response

	# --- General Response Handling ---
	if success:
		var result_str: String = JSON.stringify(result, "  ") if typeof(result) in [TYPE_DICTIONARY, TYPE_ARRAY] else str(result)
		Log.info("RTDB Success", {"req_id": request_id, "op": op_name, "path": path, "type": typeof(result)}, ["test"])
		status_label.text = "Success (Req %d): %s\nPath: %s\nResult: %s" % [request_id, op_name, path, result_str]
	else:
		Log.error("RTDB Error", {"req_id": request_id, "op": op_name, "path": path, "code": error_code, "msg": error_message}, ["test"])
		status_label.text = "Error (Req %d): %s\nPath: %s\nCode: %s\nMsg: %s" % [request_id, op_name, path, error_code, error_message]

	# Clean up the request now that it's fully handled
	if _pending_requests.has(request_id): # Check again as it might have been handled above
		_pending_requests.erase(request_id)

func _on_rtdb_get_value_completed(request_id: int, _key: String, value: Variant) -> void: _handle_rtdb_response(request_id, true, value)
func _on_rtdb_get_value_error(request_id: int, _key: String, error_code: String, error_message: String) -> void: _handle_rtdb_response(request_id, false, null, error_code, error_message)
func _on_rtdb_set_value_completed(request_id: int, success: bool, error_message: String) -> void:
	var result_variant: Variant = success # Explicit Variant assignment
	var error_code: String = "" if success else "SET_FAILED"
	_handle_rtdb_response(request_id, success, result_variant, error_code, error_message)

func _on_rtdb_push_and_update_completed(request_id: int, push_id: String, success: bool, error_message: String) -> void:
	var result_variant: Variant
	if success:
		result_variant = push_id
	else:
		result_variant = null
	var error_code: String = "" if success else "PUSH_FAILED"
	_handle_rtdb_response(request_id, success, result_variant, error_code, error_message)

func _on_rtdb_remove_value_completed(request_id: int, success: bool, error_message: String) -> void:
	var result_variant: Variant = success # Explicit Variant assignment
	var error_code: String = "" if success else "REMOVE_FAILED"
	_handle_rtdb_response(request_id, success, result_variant, error_code, error_message)

func _on_rtdb_query_completed(request_id: int, _key: String, value: Variant) -> void:
	_handle_rtdb_response(request_id, true, value)

func _on_rtdb_query_error(request_id: int, _key: String, error_code: String, error_message: String) -> void:
	_handle_rtdb_response(request_id, false, null, error_code, error_message)

func _on_rtdb_transaction_completed(request_id: int, _key: String, value: Variant, success: bool, error_message: String) -> void:
	if success and value is int:
		_transaction_count = value

	var error_code: String
	if success:
		error_code = ""
	else:
		error_code = "TRANSACTION_FAILED"

	_handle_rtdb_response(request_id, success, value, error_code, error_message)

func _on_rtdb_child_added(key: String, value: Variant) -> void:
	var rs: String = JSON.stringify(value, "  ") if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY] else str(value)
	var msg: String = "[LISTENER] Added:\nK: %s\nV: %s" % [key, rs]
	Log.info("RTDB Listener", {"evt": "added", "key": key}, ["test"])
	status_label.text = msg
func _on_rtdb_child_changed(key: String, value: Variant) -> void: var rs: String = JSON.stringify(value, "  ") if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY] else str(value); var msg: String = "[LISTENER] Changed:\nK: %s\nV: %s" % [key, rs]; Log.info("RTDB Listener", {"evt": "changed", "key": key}, ["test"]); status_label.text = msg
func _on_rtdb_child_moved(key: String, value: Variant) -> void: var rs: String = JSON.stringify(value, "  ") if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY] else str(value); var msg: String = "[LISTENER] Moved:\nK: %s\nV: %s" % [key, rs]; Log.info("RTDB Listener", {"evt": "moved", "key": key}, ["test"]); status_label.text = msg
func _on_rtdb_child_removed(key: String, value: Variant) -> void: var rs: String = JSON.stringify(value, "  ") if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY] else str(value); var msg: String = "[LISTENER] Removed:\nK: %s\nV: %s" % [key, rs]; Log.info("RTDB Listener", {"evt": "removed", "key": key}, ["test"]); status_label.text = msg
func _on_rtdb_connection_state_changed(connected: bool) -> void:
	connection_status = "Connected" if connected else "Disconnected"
	var msg: String = "[STATUS] Connection: " + connection_status
	Log.info("RTDB Status", {"evt": "connection", "connected": connected})
	status_label.text = msg
func _on_rtdb_db_error(code: String, message: String) -> void: var msg: String = "[ERROR] DB Error:\nCode: %s\nMsg: %s" % [code, message]; Log.error("RTDB Error", {"code": code, "msg": message}); status_label.text = msg

#-----------------------------------------------------------------------------#
# Other Module Handlers                                                       #
#-----------------------------------------------------------------------------#

func _on_Button_remote_config_string_pressed() -> void:
	if not remote_config:
		return
	Log.debug("RC button", {}, ["ui"])
	remote_config.set_instant_fetching()
	var rc_s: String = remote_config.get_string("test_string", "local")
	Log.debug("RC value", {"value": rc_s}, ["rc"])
	status_label.text = str("RC string: ", rc_s)
func remote_config_loaded() -> void: Log.info("RC loaded", {}, ["rc"]); status_label.text = "Remote Config: Loaded"
func messaging_token() -> void:
	if not messaging:
		return
	var t: String = messaging.token()
	Log.info("Messaging token", {"token": t}, ["msg"])
	status_label.text = "Msg Token:\n" + str(t)
func messaging_message(msg_data: Dictionary) -> void: Log.info("Messaging message", {"msg": msg_data}, ["msg"]); status_label.text = "Msg Rcvd:\n" + JSON.stringify(msg_data, "  ")
# AdMob handlers
func _on_Button_func_is_interstitial_loaded_pressed() -> void:
	if not admob:
		status_label.text = "[ERROR] AdMob N/A."
		return
	status_label.text = str("Is interstitial loaded: ", admob.is_interstitial_loaded())

func _on_Button_func_is_reward_loaded_pressed() -> void:
	if not admob:
		status_label.text = "[ERROR] AdMob N/A."
		return
	status_label.text = str("Is reward loaded: ", admob.is_rewarded_video_loaded())

func _on_Button_load_interstitial_pressed() -> void:
	if not admob:
		status_label.text = "[ERROR] AdMob N/A."
		return
	status_label.text = "Loading interstitial..."
	admob.load_interstitial(FAKE_INTERSTITIAL_AD_UNIT_IOS)

func _on_Button_play_interstitial_pressed() -> void:
	if not admob:
		status_label.text = "[ERROR] AdMob N/A."
		return
	status_label.text = "Playing interstitial..."
	admob.show_interstitial()

func _on_Button_load_rewarded_video_pressed() -> void:
	if not admob:
		status_label.text = "[ERROR] AdMob N/A."
		return
	status_label.text = "Loading rewarded video..."
	admob.load_rewarded_video(FAKE_REWARDED_VIDEO_AD_UNIT_IOS)

func _on_Button_play_rewarded_video_pressed() -> void:
	if not admob:
		status_label.text = "[ERROR] AdMob N/A."
		return
	status_label.text = "Playing rewarded video..."
	admob.show_rewarded_video()
func _on_Button_sign_in_anon_pressed() -> void:
	if not auth:
		status_label.text = "[ERROR] Auth N/A."
		return
	Log.debug("Auth Anon Sign in", {}, ["test"])
	# Keep await to align with all backends even though it's redundant
	@warning_ignore("redundant_await")
	var login_result: int = await auth.login()
	Log.info("Anon login result", {"res": login_result}, ["auth"])
	status_label.text = str("Anon Login Res: ", login_result)
func logged_in(res: String) -> void: print("_auth Logged in: ", res); status_label.text = str("Auth Logged in: ", res)
func facebook_login_success(result: Dictionary) -> void: fb_success.emit(result)
func _on_Button_sign_in_facebook_pressed() -> void:
	if not auth:
		return
	# Keep await to align with all backends even though it's redundant
	@warning_ignore("redundant_await")
	var sign_in_result: int = await auth.sign_in_facebook()
	status_label.text = "FB Sign in res: " + str(sign_in_result)
func _on_Button_unlink_Facebook_pressed() -> void:
	if not auth:
		return
	auth.unlink_facebook()
func _on_Button_link_Facebook_pressed() -> void:
	if not auth:
		return
	# @warning_ignore: redundant_await
	var rc: int = await auth.link_facebook()
	status_label.text = "FB Link res: " + str(rc)
func _on_Auth_Apple_login_pressed() -> void:
	if not auth:
		return
	# @warning_ignore: redundant_await
	var rc: int = await auth.sign_in_apple()
	status_label.text = "Apple Sign in res: " + str(rc)
func _on_Auth_Apple_log_out_pressed() -> void:
	if not auth:
		return
	auth.log_out_apple()
	status_label.text = "Apple Logout called"
func _on_Auth_Apple_link_pressed() -> void:
	if not auth:
		return
	# @warning_ignore: redundant_await
	var rc: int = await auth.link_apple()
	status_label.text = "Apple Link res: " + str(rc)
func _on_Auth_Apple_unlink_pressed() -> void:
	if not auth:
		return
	auth.unlink_apple()
	status_label.text = "Apple Unlink called"
func account_linked(res: String) -> void: Log.info("Account linked", {"res": res}, ["auth"]); status_label.text = "Account Link Res: " + res
func account_unlinked(res: String) -> void: Log.info("Account unlinked", {"res": res}, ["auth"]); status_label.text = "Account Unlink Res: " + res
func _on_Auth_Apple_has_provider_pressed() -> void:
	if not auth:
		return
	status_label.text = str("Apple Connected: ", auth.is_connected_to_apple())
func _on_Auth_fb_has_provider_pressed() -> void:
	if not auth:
		return
	status_label.text = str("Facebook Connected: ", auth.is_connected_to_facebook())
func _on_Button_sign_out_pressed() -> void:
	if not auth:
		return
	var s: bool = auth.log_out_facebook()
	status_label.text = "FB Logout res: " + str(s)
func _on_Button_get_all_info_pressed() -> void:
	if not auth or not auth.firebase_auth:
		return
	var pt: String = JSON.stringify(auth.firebase_auth.providers(), " ")
	status_label.text = "UID: %s\nProviders: %s" % [auth.uid(), pt]

# Corrected Apple Auth Credential Handler
func _on_credential(result: Dictionary) -> void:
	Log.debug("Apple credential received", {"result": result}, [Log.TAG_APPLE, "auth"])
	if result.has("error"):
		print("Apple Credential Error: ", result.error)
	else:
		if result.has("state"):
			print("Apple Credential State: ", result.state)
		else:
			print("Apple Credential Result (no 'state' key): ", result)

func _on_authorization(result: Dictionary) -> void: Log.debug("Apple authorization", {"res": result}, [Log.TAG_APPLE, "auth"]); emit_signal("apple_auth_respons", result)
# AdMob handlers
#func _on_Button_func_is_interstitial_loaded_pressed() -> void: if not admob: return; status_label.text = str("AdMob Interstitial: ", admob.is_interstitial_loaded())
#func _on_Button_func_is_reward_loaded_pressed() -> void: if not admob: return; status_label.text = str("AdMob Rewarded: ", admob.is_rewarded_loaded())
#func interstitial_loading_result(res: String) -> void: print("AdMob Interstitial load: ", res)
#func rewarded_completed() -> void: print("AdMob Rewarded complete"); status_label.text = "AdMob: Rewarded complete"
#func rewarded_state(state: String) -> void: print("AdMob Rewarded state: ", state)
#func interstitial_state(state: String) -> void: print("AdMob Interstitial state: ", state)
#func _on_Button_load_interstitial_pressed() -> void: if not admob: return; admob.load_interstitial(FAKE_INTERSTITIAL_AD_UNIT_IOS)
#func _on_Button_play_interstitial_pressed() -> void: if not admob: return; admob.show_interstitial()
#func _on_Button_load_rewarded_video_pressed() -> void: if not admob: return; admob.load_rewarded(FAKE_REWARDED_VIDEO_AD_UNIT_IOS)
#func _on_Button_play_rewarded_video_pressed() -> void: if not admob: return; admob.show_rewarded()
#func rewarded_loading_result(res: String) -> void: print("AdMob Rewarded load: ", res)

#-----------------------------------------------------------------------------#
# General Debug UI Handlers                                                   #
#-----------------------------------------------------------------------------#

func _on_Button_close_pressed() -> void:
	Log.debug("Close button pressed.", {}, ["debug", "ui"])
	debug.action(debug.DebugEventType.EVENT_CLOSE_DB_DEBUG_MENU)
