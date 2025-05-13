# File: project/debug/debug.gd
# Enhanced with automated signal connections and a more generic dynamic menu builder.
# Refactored RTDB request handling for cleaner signal management.

extends Control

signal fb_success(res: Dictionary)
@warning_ignore("unused_signal")
signal _apple_success(res: Dictionary)
@warning_ignore("unused_signal")
signal timed_out

# Constants
const FAKE_INTERSTITIAL_AD_UNIT_IOS: String = "ca-app-pub-3940256099942544/4411468910"
const FAKE_REWARDED_VIDEO_AD_UNIT_IOS: String = "ca-app-pub-3940256099942544/1712485313"
const _RTDB_TEST_PREFIX: String = "_test_rtdb_" # Specific prefix for RTDB tests
const _AUTH_TEST_PREFIX: String = "_test_auth_" # Specific prefix for Auth tests
const _CONFIG_TEST_PREFIX: String = "_test_config_" # Specific prefix for Config tests
const _test_base_path: Array[String] = ["debug_tests", "rtdb"] # Keep as Array[String]
const DEFAULT_TIMEOUT: float = 10.0 # Default timeout for RTDB operations

# Firebase Module Instances
var auth: Object = null
var db: Object = null # Instance of C++ FirebaseDatabase
var remote_config: Object = null
var messaging: Object = null

# Other Module Instances
var godot_apple_auth: Object = null
var admob: Object = null

# --- UI References ---
@onready var status_label: RichTextLabel = %DebugRichTextLabel
@onready var close_button: Button = %Button_close
@onready var rtdb_tests_button: Button = %RTDBTestsButton
@onready var auth_tests_button: Button = %AuthTestsButton
@onready var config_tests_button: Button = %ConfigTestsButton
@onready var general_actions_container: VBoxContainer = %GeneralActionsContainer

var test_all_rtdb_button: Button # Dynamically created
var test_all_auth_button: Button # Dynamically created
var test_all_config_button: Button # Dynamically created

# Stores main PopupMenu nodes for different debug categories
var _main_popups: Dictionary = {} # e.g., {"rtdb": PopupMenu, "auth": PopupMenu}
# Stores dynamically created submenu PopupMenu nodes to manage their lifecycle (group_name -> PopupMenu)
var _dynamic_submenus: Dictionary = {}

# RTDB Test State
var _next_request_id: int = 0
# Stores request_id_int -> PendingRequestData instance
var _pending_requests: Dictionary = {}
var _listener_path_suffix: Array[String] = ["live_data"] # Keep as Array[String]
var _listen_count: int = 0
var _transaction_count: int = 0
var connection_status: String = ""

# Custom class for pending request data, now handles its own completion and timeout
class PendingRequestData extends RefCounted:
	signal completed(success: bool, data: Variant) # Emits [success, payload_or_error_dict]

	var operation: String
	var path: Array[String] # Keep as Array[String]
	var request_id: int
	var timeout_timer: Timer
	var _parent_debug_node: Node # Reference to the main Debug node
	var _is_completed_internally: bool = false # Prevents double emission

	func _init(p_request_id: int, p_operation: String, p_path: Array[String], p_parent_debug_node: Node):
		request_id = p_request_id
		operation = p_operation
		path = p_path
		_parent_debug_node = p_parent_debug_node # Store parent for context

		timeout_timer = Timer.new()
		timeout_timer.name = "RTDBReqTimer_%d" % request_id
		_parent_debug_node.add_child(timeout_timer) # Timer needs to be in scene tree
		timeout_timer.one_shot = true
		var connect_err: Error = timeout_timer.timeout.connect(_on_timeout)
		if connect_err != OK:
			Log.error("Failed to connect timeout_timer signal for PendingRequestData", {"req_id": request_id, "error": error_string(connect_err)}, ["debug", "firebase", Log.TAG_ERROR])


	func start_timeout(duration: float) -> void:
		if is_instance_valid(timeout_timer):
			timeout_timer.wait_time = duration
			timeout_timer.start()

	func _on_timeout() -> void:
		if _is_completed_internally: return

		Log.warning("RTDB Request TIMEOUT", {"req_id": request_id, "operation": operation, "path": path}, ["debug", "firebase", Log.TAG_ERROR])
		var error_payload := {"error_code": "TIMEOUT", "message": "Operation timed out for %s at %s" % [operation, str(path)]}

		# Call the central completion handler in the parent Debug node
		if is_instance_valid(_parent_debug_node) and _parent_debug_node.has_method("_handle_rtdb_completion_from_pending_request"):
			_parent_debug_node._handle_rtdb_completion_from_pending_request(request_id, false, error_payload)
		else:
			# Fallback if parent is gone or method missing (shouldn't happen ideally)
			_mark_completed_and_emit(false, error_payload)


	func _cleanup_timer() -> void:
		if is_instance_valid(timeout_timer):
			timeout_timer.stop()
			if timeout_timer.timeout.is_connected(_on_timeout):
				timeout_timer.timeout.disconnect(_on_timeout)
			timeout_timer.queue_free() # Important to free it
			timeout_timer = null

	# Called by the main Debug node when the actual C++ response comes in OR by _on_timeout
	func complete_request(success: bool, data: Variant) -> void:
		if _is_completed_internally: return
		_mark_completed_and_emit(success, data)

	func _mark_completed_and_emit(success: bool, data: Variant) -> void:
		_is_completed_internally = true
		_cleanup_timer() # Stop timeout if it hasn't fired and clean up
		completed.emit(success, data) # This is what the `await` waits for


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
	var rtdb_label2_node: Node = get_node_or_null("%DebugRichTextLabel2")
	if is_instance_valid(rtdb_label2_node) and rtdb_label2_node is RichTextLabel:
		var rtdb_label2: RichTextLabel = rtdb_label2_node
		rtdb_label2.text = str("OS: ", OS.get_name(), debug_text)

	var rtdb_label3_node: Node = get_node_or_null("%DebugRichTextLabel3")
	if is_instance_valid(rtdb_label3_node) and rtdb_label3_node is RichTextLabel:
		var rtdb_label3: RichTextLabel = rtdb_label3_node
		rtdb_label3.text = str("Commit: ", Engine.get_version_info()["hash"])

	_initialize_firebase_modules()
	_setup_dynamic_test_menu_for_rtdb()
	_setup_additional_test_menus()
	_setup_test_all_buttons()

	if is_instance_valid(close_button):
		var close_conn_err: Error = close_button.pressed.connect(_on_Button_close_pressed.bind(), CONNECT_DEFERRED)
		if close_conn_err != OK:
			Log.error("Failed to connect close_button pressed signal!", {"error": error_string(close_conn_err)}, ["debug", "ui", Log.TAG_ERROR])
	else:
		Log.error("Close button node not found!", {}, ["debug", "ui", Log.TAG_ERROR])

	Log.info("Debug Node _ready: Initialization complete.", {}, ["debug", "initialization"])

func _initialize_firebase_modules() -> void:
	Log.debug("Checking for Firebase modules...", {}, ["debug", "initialization", Log.TAG_FIREBASE])
	if ClassDB.class_exists("FirebaseDatabase"):
		Log.info("FirebaseDatabase class found. Instantiating...", {}, ["debug", "initialization", Log.TAG_FIREBASE])
		db = ClassDB.instantiate("FirebaseDatabase")
		if is_instance_valid(db):
			Log.debug("FirebaseDatabase instance created successfully.", {"db_instance": db}, ["debug", "initialization", Log.TAG_FIREBASE])
			_connect_rtdb_signals_dynamically()
		else:
			Log.error("Failed to instantiate FirebaseDatabase!", {}, ["debug", "initialization", Log.TAG_FIREBASE, Log.TAG_ERROR])
			if is_instance_valid(status_label): status_label.text = "[ERROR] Failed to instantiate FirebaseDatabase"
			if is_instance_valid(rtdb_tests_button): rtdb_tests_button.disabled = true
	else:
		Log.warning("FirebaseDatabase C++ module class not found.", {}, ["debug", "initialization", Log.TAG_FIREBASE])
		if is_instance_valid(status_label): status_label.text = "[WARN] FirebaseDatabase C++ module not found"
		if is_instance_valid(rtdb_tests_button): rtdb_tests_button.disabled = true

	if ClassDB.class_exists("FirebaseRemoteConfig"):
		remote_config = ClassDB.instantiate("FirebaseRemoteConfig")
		if is_instance_valid(remote_config):
			remote_config.connect("loaded", Callable(self, "remote_config_loaded")) # Keep direct method name if it exists
	if Engine.has_singleton("Auth"): auth = Engine.get_singleton("Auth")
	if Engine.has_singleton("GodotAppleAuth"):
		godot_apple_auth = Engine.get_singleton("GodotAppleAuth")
		if is_instance_valid(godot_apple_auth):
			godot_apple_auth.connect("credential", Callable(self, "_on_credential"))
			godot_apple_auth.connect("authorization", Callable(self, "_on_authorization"))


#-----------------------------------------------------------------------------#
# Dynamic Menu Creation (Generalized) - (Largely Unchanged)                   #
#-----------------------------------------------------------------------------#
func _setup_dynamic_test_menu_for_rtdb() -> void:
	if not is_instance_valid(rtdb_tests_button):
		Log.error("RTDBTestsButton node not found! Cannot create RTDB test menu.", {}, ["debug", "ui", Log.TAG_ERROR])
		return
	var main_rtdb_popup: PopupMenu = PopupMenu.new(); main_rtdb_popup.name = "RTDBMainPopupMenu"
	add_child(main_rtdb_popup); _main_popups["rtdb"] = main_rtdb_popup
	rtdb_tests_button.pressed.connect(func(): var pos = rtdb_tests_button.global_position + Vector2(0, rtdb_tests_button.size.y); main_rtdb_popup.popup_on_parent(Rect2(pos, Vector2.ZERO)))
	_build_dynamic_menu_from_prefix(main_rtdb_popup, _RTDB_TEST_PREFIX, Callable(self, "_on_dynamic_test_item_pressed"))

func _setup_additional_test_menus() -> void:
	if is_instance_valid(auth_tests_button):
		var p: PopupMenu = PopupMenu.new(); p.name = "AuthMainPopupMenu"; add_child(p); _main_popups["auth"] = p
		auth_tests_button.pressed.connect(func(): var pos = auth_tests_button.global_position + Vector2(0, auth_tests_button.size.y); p.popup_on_parent(Rect2(pos, Vector2.ZERO)))
		_build_dynamic_menu_from_prefix(p, _AUTH_TEST_PREFIX, Callable(self, "_on_dynamic_test_item_pressed"))
	if is_instance_valid(config_tests_button):
		var p: PopupMenu = PopupMenu.new(); p.name = "ConfigMainPopupMenu"; add_child(p); _main_popups["config"] = p
		config_tests_button.pressed.connect(func(): var pos = config_tests_button.global_position + Vector2(0, config_tests_button.size.y); p.popup_on_parent(Rect2(pos, Vector2.ZERO)))
		_build_dynamic_menu_from_prefix(p, _CONFIG_TEST_PREFIX, Callable(self, "_on_dynamic_test_item_pressed"))

func _setup_test_all_buttons() -> void:
	if not is_instance_valid(general_actions_container): Log.error("GeneralActionsContainer not found!", {}, ["debug","ui",Log.TAG_ERROR]); return
	test_all_rtdb_button = Button.new(); test_all_rtdb_button.text = "Run All RTDB Tests"; general_actions_container.add_child(test_all_rtdb_button)
	test_all_rtdb_button.pressed.connect(func(): _run_all_tests_by_prefix(_RTDB_TEST_PREFIX))
	if is_instance_valid(auth):
		test_all_auth_button = Button.new(); test_all_auth_button.text = "Run All Auth Tests"; general_actions_container.add_child(test_all_auth_button)
		test_all_auth_button.pressed.connect(func(): _run_all_tests_by_prefix(_AUTH_TEST_PREFIX))
	if is_instance_valid(remote_config):
		test_all_config_button = Button.new(); test_all_config_button.text = "Run All Config Tests"; general_actions_container.add_child(test_all_config_button)
		test_all_config_button.pressed.connect(func(): _run_all_tests_by_prefix(_CONFIG_TEST_PREFIX))

func _build_dynamic_menu_from_prefix(main_popup_menu: PopupMenu, method_prefix: String, item_pressed_callback: Callable) -> void:
	# ... (This function remains largely the same as your original, handling UI creation)
	Log.debug("Building dynamic menu", {"prefix": method_prefix}, ["debug", "ui"])
	if not is_instance_valid(main_popup_menu):
		Log.error("Cannot build dynamic menu: main_popup_menu is invalid.", {"prefix": method_prefix}, ["debug", "ui", Log.TAG_ERROR]); return
	for key in _dynamic_submenus.keys():
		if key.begins_with(method_prefix + "_submenu_"):
			var submenu_node: PopupMenu = _dynamic_submenus[key]
			if is_instance_valid(submenu_node): submenu_node.queue_free()
			_dynamic_submenus.erase(key)
	main_popup_menu.clear()
	var method_list: Array = get_method_list()
	method_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.name as String) < (b.name as String))
	var current_prefix_submenus: Dictionary = {}; var main_menu_item_id_counter: int = 0
	for method_info_variant in method_list:
		var method_info: Dictionary = method_info_variant as Dictionary; var method_name: String = method_info.name as String
		if method_name.begins_with(method_prefix):
			var name_after_prefix: String = method_name.trim_prefix(method_prefix); var underscore_pos: int = name_after_prefix.find("_")
			if underscore_pos <= 0: Log.warning("Skipping method: Invalid format.", {"m": method_name, "p": method_prefix}, ["debug","ui"]); continue
			var group_name: String = name_after_prefix.substr(0, underscore_pos); var test_name: String = name_after_prefix.substr(underscore_pos + 1)
			if group_name.is_empty() or test_name.is_empty(): Log.warning("Skipping method: Empty group/test name.", {"m": method_name}, ["debug","ui"]); continue
			var submenu_node: PopupMenu; var submenu_registry_key: String = method_prefix + "_submenu_" + group_name
			if not current_prefix_submenus.has(group_name):
				submenu_node = PopupMenu.new(); submenu_node.name = submenu_registry_key; add_child(submenu_node)
				var err_c = submenu_node.id_pressed.connect(item_pressed_callback.bind(submenu_node)); if err_c != OK: Log.error("Failed to connect submenu for %s" % submenu_registry_key,{"e":error_string(err_c)},["debug","ui"])
				current_prefix_submenus[group_name] = submenu_node; _dynamic_submenus[submenu_registry_key] = submenu_node
				main_popup_menu.add_submenu_item(_format_name_for_display(group_name), submenu_node.name, main_menu_item_id_counter); main_menu_item_id_counter += 1
			else: submenu_node = current_prefix_submenus[group_name]
			var display_test_name: String = _format_name_for_display(test_name); var submenu_item_id: int = submenu_node.item_count
			submenu_node.add_item(display_test_name, submenu_item_id); submenu_node.set_item_metadata(submenu_item_id, method_name)

func _on_dynamic_test_item_pressed(item_id: int, bound_submenu: PopupMenu) -> void:
	# ... (This function remains the same)
	if not is_instance_valid(bound_submenu): Log.error("Bound submenu invalid.", {}, ["debug","ui",Log.TAG_ERROR]); return
	var method_name_meta: Variant = bound_submenu.get_item_metadata(item_id)
	if method_name_meta is String:
		var method_name: String = method_name_meta
		if has_method(method_name): Log.info("Executing dynamic test: %s" % method_name, {}, ["debug","test"]); call_deferred(method_name)
		else: Log.error("Method '%s' not found for item ID %d." % [method_name, item_id], {}, ["debug","ui",Log.TAG_ERROR])
	else: Log.error("Invalid metadata for item ID %d." % item_id, {"type": typeof(method_name_meta)}, ["debug","ui",Log.TAG_ERROR])

func _format_name_for_display(name_part: String) -> String:
	if name_part.is_empty():
		return ""
	return name_part.replace("_", " ").capitalize()

#-----------------------------------------------------------------------------#
# Firebase RTDB: Automated Signal Connections & Request Handling              #
#-----------------------------------------------------------------------------#
func _connect_rtdb_signals_dynamically() -> void:
	# ... (This function remains the same)
	if not is_instance_valid(db): Log.error("Cannot connect RTDB signals: db invalid.", {}, [Log.TAG_FIREBASE,Log.TAG_ERROR]); return
	Log.debug("Automated connection of Firebase RTDB signals...", {}, [Log.TAG_FIREBASE])
	var rtdb_signals: Array[String] = ["get_value_completed","get_value_error","set_value_completed","push_and_update_completed","remove_value_completed","query_completed","query_error","transaction_completed","child_added","child_changed","child_moved","child_removed","connection_state_changed","db_error"]
	for sig_name in rtdb_signals:
		var handler_name: String = "_on_rtdb_" + sig_name
		if not has_method(handler_name): Log.warning("Handler not found for RTDB signal", {"s": sig_name, "h": handler_name}, [Log.TAG_FIREBASE]); continue
		var handler_call: Callable = Callable(self, handler_name)
		if not db.is_connected(sig_name, handler_call):
			var err: Error = db.connect(sig_name, handler_call, CONNECT_DEFERRED)
			if err != OK: Log.error("Failed to connect RTDB signal", {"s": sig_name, "h": handler_name, "e": error_string(err)}, [Log.TAG_FIREBASE,Log.TAG_ERROR])
			else: Log.debug("Connected RTDB signal", {"s": sig_name, "h": handler_name}, [Log.TAG_FIREBASE])

# Centralized handler for completing a pending RTDB request (called by C++ signal handlers or timeout)
func _handle_rtdb_completion_from_pending_request(request_id: int, success: bool, data_or_error: Variant) -> void:
	if not _pending_requests.has(request_id):
		# Already handled (e.g., C++ response beat timeout, or vice-versa, or already cleaned up)
		Log.warning("Completion for unknown or already handled RTDB request_id: %d" % request_id, {}, ["debug", "firebase"])
		return

	var pending_req_data: PendingRequestData = _pending_requests[request_id]
	_pending_requests.erase(request_id) # Remove from tracking *before* emitting its signal

	# Update UI status label
	if get_parent().visible and is_instance_valid(status_label):
		var display_path: String = "/".join(pending_req_data.path) # More readable path
		if success:
			var result_str: String = JSON.stringify(data_or_error, "  ") if typeof(data_or_error) in [TYPE_DICTIONARY, TYPE_ARRAY] else str(data_or_error)
			status_label.text = "Success (Req %d): %s\nPath: %s\nResult: %s" % [request_id, pending_req_data.operation, display_path, result_str]
		else:
			var error_dict: Dictionary = data_or_error if data_or_error is Dictionary else {"error_code": "UNKNOWN", "message": str(data_or_error)}
			status_label.text = "Error (Req %d): %s\nPath: %s\nCode: %s\nMsg: %s" % [request_id, pending_req_data.operation, display_path, error_dict.get("error_code", "N/A"), error_dict.get("message", "N/A")]

	pending_req_data.complete_request(success, data_or_error)


# Refactored RTDB request maker
func _make_rtdb_request(operation_name: String, path_suffix: Array[String], args: Array = []) -> Array: # Returns [bool, Variant]
	if not is_instance_valid(db):
		if is_instance_valid(status_label): status_label.text = "[ERROR] RTDB not initialized."
		Log.error("Attempted RTDB request but db is null", {"operation": operation_name}, [Log.TAG_FIREBASE, Log.TAG_ERROR])
		return [false, {"error_code": "DB_NULL", "message": "RTDB not initialized."}]

	var request_id: int = _next_request_id; _next_request_id += 1
	var full_path: Array[String] = _test_base_path.duplicate() # Ensure it's Array[String]
	full_path.append_array(path_suffix)

	var pending_req_data := PendingRequestData.new(request_id, operation_name, full_path, self)
	_pending_requests[request_id] = pending_req_data

	var call_args: Array = [request_id, full_path] # Path must be Array for C++ call
	call_args.append_array(args)

	Log.debug("Making RTDB request (awaitable)", { "req_id": request_id, "op": operation_name, "path": full_path, "args_count": args.size() }, [Log.TAG_FIREBASE, Log.TAG_NETWORK])
	if get_parent().visible and is_instance_valid(status_label): status_label.text = "Sending req %d: %s\nPath: %s" % [request_id, operation_name, full_path]

	db.callv(operation_name, call_args)
	pending_req_data.start_timeout(DEFAULT_TIMEOUT)

	var result_tuple: Array = await pending_req_data.completed # Awaits [success, data_or_error_dict]

	# Safety cleanup: If the request is somehow still in _pending_requests after await, remove it.
	# This can happen if the signal was emitted but the await didn't immediately clear the entry
	# due to some re-entrancy or deferred execution nuance not caught by earlier logic.
	if _pending_requests.has(request_id):
		Log.warning("RTDB Request %d was still in _pending_requests after its await completed. Force cleaning." % request_id, {}, ["debug", "firebase", Log.TAG_ERROR])
		var prd_to_clean: PendingRequestData = _pending_requests.get(request_id)
		if is_instance_valid(prd_to_clean):
			prd_to_clean._cleanup_timer() # Ensure timer is gone
		_pending_requests.erase(request_id)

	return result_tuple


# --- RTDB C++ Signal Handlers ---
# These now call the central _handle_rtdb_completion_from_pending_request
func _on_rtdb_get_value_completed(request_id: int, _rtdb_key: String, value: Variant) -> void:
	_handle_rtdb_completion_from_pending_request(request_id, true, value)

func _on_rtdb_get_value_error(request_id: int, _rtdb_key: String, error_code: String, error_message: String) -> void:
	_handle_rtdb_completion_from_pending_request(request_id, false, {"error_code": error_code, "message": error_message})

func _on_rtdb_set_value_completed(request_id: int, success: bool, error_message: String) -> void:
	var payload = success if success else {"error_code": "SET_FAILED", "message": error_message}
	_handle_rtdb_completion_from_pending_request(request_id, success, payload)

func _on_rtdb_push_and_update_completed(request_id: int, push_id: String, success: bool, error_message: String) -> void:
	var payload = push_id if success else {"error_code": "PUSH_FAILED", "message": error_message}
	_handle_rtdb_completion_from_pending_request(request_id, success, payload)

func _on_rtdb_remove_value_completed(request_id: int, success: bool, error_message: String) -> void:
	var payload = success if success else {"error_code": "REMOVE_FAILED", "message": error_message}
	_handle_rtdb_completion_from_pending_request(request_id, success, payload)

func _on_rtdb_query_completed(request_id: int, _rtdb_key: String, value: Variant) -> void:
	_handle_rtdb_completion_from_pending_request(request_id, true, value)

func _on_rtdb_query_error(request_id: int, _rtdb_key: String, error_code: String, error_message: String) -> void:
	_handle_rtdb_completion_from_pending_request(request_id, false, {"error_code": error_code, "message": error_message})

func _on_rtdb_transaction_completed(request_id: int, _rtdb_key: String, value: Variant, success: bool, error_message: String) -> void:
	if success and value is int: _transaction_count = value # Keep existing side-effect
	var payload = value if success else {"error_code": "TRANSACTION_FAILED", "message": error_message}
	_handle_rtdb_completion_from_pending_request(request_id, success, payload)

# Listener signals (not part of request/response flow, just update UI) - Unchanged
func _on_rtdb_child_added(key: String, value: Variant) -> void: var rs = JSON.stringify(value,"  ") if typeof(value) in [TYPE_DICTIONARY,TYPE_ARRAY] else str(value); var m = "[L] Added: K:%s V:%s" % [key,rs]; Log.info("RTDB Listener",{"e":"added","k":key},["test"]); if get_parent().visible and is_instance_valid(status_label): status_label.text=m
func _on_rtdb_child_changed(key: String, value: Variant) -> void: var rs = JSON.stringify(value,"  ") if typeof(value) in [TYPE_DICTIONARY,TYPE_ARRAY] else str(value); var m = "[L] Changed: K:%s V:%s" % [key,rs]; Log.info("RTDB Listener",{"e":"changed","k":key},["test"]); if get_parent().visible and is_instance_valid(status_label): status_label.text=m
func _on_rtdb_child_moved(key: String, value: Variant) -> void: var rs = JSON.stringify(value,"  ") if typeof(value) in [TYPE_DICTIONARY,TYPE_ARRAY] else str(value); var m = "[L] Moved: K:%s V:%s" % [key,rs]; Log.info("RTDB Listener",{"e":"moved","k":key},["test"]); if get_parent().visible and is_instance_valid(status_label): status_label.text=m
func _on_rtdb_child_removed(key: String, value: Variant) -> void: var rs = JSON.stringify(value,"  ") if typeof(value) in [TYPE_DICTIONARY,TYPE_ARRAY] else str(value); var m = "[L] Removed: K:%s V:%s" % [key,rs]; Log.info("RTDB Listener",{"e":"removed","k":key},["test"]); if get_parent().visible and is_instance_valid(status_label): status_label.text=m
func _on_rtdb_connection_state_changed(connected: bool) -> void: connection_status = "Connected" if connected else "Disconnected"; var m = "[S] Connection: " + connection_status; Log.info("RTDB Status",{"e":"connection","c":connected}); if get_parent().visible and is_instance_valid(status_label): status_label.text=m
func _on_rtdb_db_error(code: String, message: String) -> void: var m = "[E] DB Error: C:%s M:%s" % [code,message]; Log.error("RTDB Error",{"c":code,"m":message}); if get_parent().visible and is_instance_valid(status_label): status_label.text=m


# --- RTDB Test Functions (updated to use new _make_rtdb_request and expect [bool, Variant] return) ---
# Note: These now directly return the result of _make_rtdb_request

func _test_rtdb_basic_set_simple_value() -> Array:
	Log.debug("RTDB Test: Set Simple Value (awaitable)", {}, ["test"]); _transaction_count += 1
	return await _make_rtdb_request("set_value_async", ["simple_value"], ["Basic Value " + str(_transaction_count)])

func _test_rtdb_basic_get_simple_value() -> Array:
	Log.debug("RTDB Test: Get Simple Value (awaitable)", {}, ["test"])
	return await _make_rtdb_request("get_value_async", ["simple_value"])

func _test_rtdb_basic_push_item() -> Array:
	Log.debug("RTDB Test: Push Item (awaitable)", {}, ["test"]); _transaction_count += 1
	var push_data: Dictionary = {"msg": "Pushed " + str(_transaction_count), "ts": Time.get_unix_time_from_system()}
	return await _make_rtdb_request("push_and_update_async", ["pushed_items"], [push_data])

func _test_rtdb_basic_set_dictionary() -> Array:
	Log.debug("RTDB Test: Set Dictionary (awaitable)", {}, ["test"]); _transaction_count += 1
	var dict_data: Dictionary = {"a": "Dict A " + str(_transaction_count), "b": true, "c": _transaction_count}
	return await _make_rtdb_request("set_value_async", ["dictionary_target"], [dict_data])

func _test_rtdb_basic_delete_dictionary() -> Array:
	Log.debug("RTDB Test: Delete Dictionary Target (awaitable)", {}, ["test"])
	return await _make_rtdb_request("remove_value_async", ["dictionary_target"])

func _test_rtdb_advanced_query_top_2_scores() -> Array:
	Log.debug("RTDB Test: Query Top 2 Scores (awaitable)", {}, ["test"])
	if get_parent().visible and is_instance_valid(status_label): status_label.text = "Setting up query data..."
	var ps_base: Array[String] = ["query_items"]

	# CORRECTED: Ensure elements of setup_paths are explicitly Array[String]
	var path1: Array[String] = []
	path1.assign(ps_base + ["item1"]) # ps_base is Array[String], ["item1"] is Array[String]

	var path2: Array[String] = []
	path2.assign(ps_base + ["item2"])

	var path3: Array[String] = []
	path3.assign(ps_base + ["item3"])

	var setup_paths = [path1, path2, path3] # setup_paths is an Array of Array[String]

	var setup_data: Array[Dictionary] = [{"name": "A", "score": 50}, {"name": "B", "score": 100}, {"name": "C", "score": 75}]

	for i in range(setup_paths.size()):
		var current_path_for_call: Array[String] = setup_paths[i] as Array[String] # Cast is fine here as elements are now correctly typed

		if not (current_path_for_call is Array[String]): # Simplified check after cast
			Log.error("Internal error: current_path_for_call is not an Array[String] after cast or was null.", {"path_element_type": typeof(setup_paths[i])}, ["test", Log.TAG_ERROR])
			return [false, {"error": "Internal test error: path construction failed (type issue)"}]

		var setup_result: Array = await _make_rtdb_request("set_value_async", current_path_for_call, [setup_data[i]])
		if not setup_result[0]: # Check success bool
			Log.error("Setup failed for query test", {"result": setup_result[1]}, ["test", Log.TAG_ERROR])
			return [false, {"error": "Setup failed", "details": setup_result[1]}]

	var qp: Dictionary = {"orderByChild": "score", "limitToLast": 2}
	Log.debug("Executing query part of _test_rtdb_advanced_query_top_2_scores", {"path": ps_base, "query_params": qp}, ["test"])
	return await _make_rtdb_request("query_ordered_data_async", ps_base, [qp])


func _test_rtdb_advanced_increment_transaction() -> Array:
	Log.debug("RTDB Test: Increment Transaction (awaitable)", {}, ["test"])
	if get_parent().visible and is_instance_valid(status_label): status_label.text = "Deleting counter..."
	var counter_path_suffix: Array[String] = ["counter"]

	var delete_result: Array = await _make_rtdb_request("remove_value_async", counter_path_suffix)
	# We proceed even if delete "fails" (e.g., if path didn't exist)
	if not delete_result[0]:
		var error_payload: Dictionary = delete_result[1] if delete_result[1] is Dictionary else {}
		var error_msg_lower = str(error_payload.get("message","")).to_lower()
		if not (error_msg_lower.contains("not found") or error_msg_lower.contains("no data exists")):
			Log.warning("Problem deleting counter before transaction, but proceeding", {"result": error_payload}, ["test"])

	if get_parent().visible and is_instance_valid(status_label): status_label.text = "Setting initial counter to 0.0..."
	var set_result: Array = await _make_rtdb_request("set_value_async", counter_path_suffix, [0.0])
	if not set_result[0]:
		Log.error("Failed to set initial counter for transaction", {"result": set_result[1]}, ["test", Log.TAG_ERROR])
		return [false, {"error": "Failed to set initial counter", "details": set_result[1]}]

	if get_parent().visible and is_instance_valid(status_label): status_label.text = "Running transaction..."
	return await _make_rtdb_request("run_transaction_async", counter_path_suffix, [1.0]) # Increment by 1.0 (float)

func _test_rtdb_advanced_set_server_timestamp() -> Array:
	Log.debug("RTDB Test: Set Server Timestamp (awaitable)", {}, ["test"])
	return await _make_rtdb_request("set_server_timestamp_async", ["server_time"])

# --- Group: listeners (These are manual, no await, return indicates action taken) ---
func _test_rtdb_listeners_add() -> Array: # Returns [bool, Dict] to fit pattern, though not awaited by _run_all
	Log.debug("RTDB Test: Add Listener (manual test)", {}, ["test"])
	if is_instance_valid(db):
		var fp: Array[String] = _test_base_path.duplicate()
		fp.append_array(_listener_path_suffix) # fp is now _test_base_path + _listener_path_suffix

		db.add_listener_at_path(fp) # Use the full path to add the listener

		if get_parent().visible and is_instance_valid(status_label):
			status_label.text = "Added listener:\n%s" % [str(fp)] # Display the full path
		_listen_count = 0

		# Set an initial value to confirm listener is active (best effort, no await here)
		var local_dummy_request_id: int = -1 # Define a local dummy request_id for this call

		# Construct the path for setting the status: _test_base_path/live_data/status
		var path_for_status_set: Array[String] = fp.duplicate() # Start with the full listener path
		path_for_status_set.append("status")                   # Append the "status" child key

		var set_args: Array = [local_dummy_request_id, path_for_status_set, "listening_init"]

		Log.debug("RTDB Listener Test: Firing initial set_value_async", {"args": set_args}, ["test", Log.TAG_FIREBASE])
		db.callv("set_value_async", set_args) # Fire-and-forget initial set for listener

		return [true, {"message": "Listener add requested for path: %s" % str(fp)}]
	else:
		if get_parent().visible and is_instance_valid(status_label):
			status_label.text = "[ERROR] RTDB not init."
		return [false, {"error_code": "DB_NULL", "message": "RTDB not initialized"}]

func _test_rtdb_listeners_trigger_change() -> Array:
	Log.debug("RTDB Test: Trigger Listener Change (manual test)", {}, ["test"])
	if not is_instance_valid(db): return [false, {"error_code": "DB_NULL", "message": "RTDB not initialized"}]
	_listen_count += 1
	var path_count : Array[String] = _listener_path_suffix.duplicate(); path_count.append_array(["count"])
	var path_status : Array[String] = _listener_path_suffix.duplicate(); path_status.append_array(["status"])
	# These are fire-and-forget to trigger the listener, C++ signals will update UI
	# Use a dummy request_id for the C++ call as these aren't tracked by _pending_requests
	var dummy_req_id_count = -100 - _listen_count
	var dummy_req_id_status = -200 - _listen_count
	db.callv("set_value_async", [dummy_req_id_count, _test_base_path + path_count, _listen_count])
	db.callv("set_value_async", [dummy_req_id_status, _test_base_path + path_status, "triggered_" + str(_listen_count)])
	if get_parent().visible and is_instance_valid(status_label): status_label.text = "Triggered listener change (count: %d)" % _listen_count
	return [true, {"message": "Listener change trigger sent"}]


func _test_rtdb_listeners_remove() -> Array:
	Log.debug("RTDB Test: Remove Listener (manual test)", {}, ["test"])
	if is_instance_valid(db):
		var fp: Array[String] = _test_base_path.duplicate(); fp.append_array(_listener_path_suffix)
		db.remove_listener_at_path(fp)
		if get_parent().visible and is_instance_valid(status_label): status_label.text = "Removed listener:\n%s" % [fp]
		return [true, {"message": "Listener remove requested for path: %s" % str(fp)}]
	else:
		if get_parent().visible and is_instance_valid(status_label): status_label.text = "[ERROR] RTDB not init."
		return [false, {"error_code": "DB_NULL", "message": "RTDB not initialized"}]

func _test_rtdb_connection_monitor() -> Array:
	Log.debug("RTDB Test: Monitor Connection (manual test)", {}, ["test"])
	if is_instance_valid(db):
		db.monitor_connection_state()
		if get_parent().visible and is_instance_valid(status_label): status_label.text = "Monitoring connection..."
		return [true, {"message": "Connection monitoring started"}]
	else:
		if get_parent().visible and is_instance_valid(status_label): status_label.text = "[ERROR] RTDB not init."
		return [false, {"error_code": "DB_NULL", "message": "RTDB not initialized"}]


#-----------------------------------------------------------------------------#
# "Test All" Sequential Runner (Updated to handle [bool, Variant] from tests) #
#-----------------------------------------------------------------------------#
func _run_all_tests_by_prefix(test_prefix: String) -> void:
	var module_name: String = test_prefix.trim_prefix("_test_").trim_suffix("_")
	var module_instance: Object = null
	match module_name:
		"rtdb": module_instance = db
		"auth": module_instance = auth
		"config": module_instance = remote_config
	if not is_instance_valid(module_instance):
		if get_parent().visible and is_instance_valid(status_label): status_label.text = "Cannot run: %s module not init." % module_name.to_upper()
		Log.error("Attempted %s tests, but module null." % module_name,{},["debug","test",Log.TAG_ERROR]); return
	var test_button: Button = null
	match module_name:
		"rtdb": test_button = test_all_rtdb_button
		"auth": test_button = test_all_auth_button
		"config": test_button = test_all_config_button
	if is_instance_valid(test_button): test_button.disabled = true
	Log.info("Starting sequential %s tests..." % module_name.to_upper(),{},["debug","test",module_name])
	var method_list: Array = get_method_list()
	method_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.name as String) < (b.name as String))
	_run_sequential_tests(method_list, test_prefix, module_name, test_button)


func _run_sequential_tests(method_list: Array, test_prefix: String, module_name: String, test_button: Button) -> void:
	var tests_run: int = 0; var tests_passed: int = 0; var tests_failed: int = 0
	for method_info_variant in method_list:
		var method_info: Dictionary = method_info_variant if method_info_variant is Dictionary else {}; if not method_info.has("name"): continue
		var method_name: String = method_info.name if method_info.name is String else ""; if not method_name.begins_with(test_prefix): continue
		var skip_test: bool = false
		if module_name == "rtdb" and (method_name.contains("_listeners_") or method_name.contains("_connection_")):
			Log.info("Skipping manual test in 'Run All': %s" % method_name,{},["debug","test",module_name]); skip_test = true
		if skip_test: continue
		tests_run += 1
		var display_method_name: String = _format_name_for_display(method_name.trim_prefix(test_prefix))
		if get_parent().visible and is_instance_valid(status_label): status_label.text = "Running: %s..." % display_method_name
		Log.info("Executing test: %s" % method_name,{},["debug","test",module_name])

		var result_tuple: Array = await call(method_name) # Test methods now return [bool, Variant]
		var success: bool = false; var payload: Variant = null
		if result_tuple.size() == 2 and result_tuple[0] is bool:
			success = result_tuple[0]; payload = result_tuple[1]
		else:
			Log.error("Test '%s' bad return format: %s" % [method_name,str(result_tuple)],{},["debug","test",module_name,Log.TAG_ERROR])
			payload = {"error":"Bad return format", "details":str(result_tuple)}

		if success:
			tests_passed += 1
			if get_parent().visible and is_instance_valid(status_label): status_label.text = "PASS: %s" % display_method_name
			Log.info("Test PASSED: %s" % method_name, {"payload": payload}, ["debug","test",module_name])
		else:
			tests_failed += 1
			if get_parent().visible and is_instance_valid(status_label): status_label.text = "FAIL: %s\nDetails: %s" % [display_method_name, str(payload)]
			Log.error("Test FAILED: %s" % method_name, {"error_details": payload}, ["debug","test",module_name,Log.TAG_ERROR])
		await get_tree().create_timer(0.2).timeout # Short delay
	var summary: String = "%s Tests: %d Run, %d Passed, %d Failed" % [module_name.to_upper(),tests_run,tests_passed,tests_failed]
	if get_parent().visible and is_instance_valid(status_label): status_label.text = summary
	Log.info(summary,{},["debug","test",module_name])
	if is_instance_valid(test_button): test_button.disabled = false

#-----------------------------------------------------------------------------#
# Other Module Handlers & General UI (Placeholders - Unchanged)               #
#-----------------------------------------------------------------------------#
func _on_Button_remote_config_string_pressed() -> void: pass
func remote_config_loaded() -> void: pass
func messaging_token() -> void: pass
func messaging_message(_msg_data: Dictionary) -> void: pass
func _on_Button_func_is_interstitial_loaded_pressed() -> void: pass
func _on_Button_func_is_reward_loaded_pressed() -> void: pass
func _on_Button_load_interstitial_pressed() -> void: pass
func _on_Button_play_interstitial_pressed() -> void: pass
func _on_Button_load_rewarded_video_pressed() -> void: pass
func _on_Button_play_rewarded_video_pressed() -> void: pass
func _on_Button_sign_in_anon_pressed() -> void: pass
func logged_in(_res: String) -> void: pass # Parameter type might be int from C++
func facebook_login_success(_result: Dictionary) -> void: pass
func _on_Button_sign_in_facebook_pressed() -> void: pass
func _on_Button_unlink_Facebook_pressed() -> void: pass
func _on_Button_link_Facebook_pressed() -> void: pass
func _on_Auth_Apple_login_pressed() -> void: pass
func _on_Auth_Apple_log_out_pressed() -> void: pass
func _on_Auth_Apple_link_pressed() -> void: pass
func _on_Auth_Apple_unlink_pressed() -> void: pass
func account_linked(_res: String) -> void: pass # Parameter type might be int
func account_unlinked(_res: String) -> void: pass
func _on_Auth_Apple_has_provider_pressed() -> void: pass
func _on_Auth_fb_has_provider_pressed() -> void: pass
func _on_Button_sign_out_pressed() -> void: pass
func _on_Button_get_all_info_pressed() -> void: pass
func _on_credential(_result: Dictionary) -> void: pass
func _on_authorization(_result: Dictionary) -> void: pass

func _on_Button_close_pressed() -> void:
	Log.debug("Close button pressed.", {}, ["debug", "ui"])
	debug.action(debug.DebugEventType.EVENT_CLOSE_DB_DEBUG_MENU)

# --- Auth and Config Test Placeholders (Unchanged from your original logic flow, just ensure they work with the new runner) ---
func _test_auth_basic_sign_in_anonymous() -> Array: # Must return [bool, Variant]
	Log.debug("Auth Test: Sign In Anonymous", {}, ["test"])
	if not is_instance_valid(auth):
		if get_parent().visible and is_instance_valid(status_label): status_label.text = "[ERROR] Auth not initialized."
		return [false, {"error_code": "AUTH_NULL", "message": "Auth module not initialized."}]

	# This is a synchronous call in the provided Auth.gd, adapt if it becomes async
	var login_result: int = auth.login()
	var success: bool = (login_result == OK) # Assuming OK (0) is success
	var payload: Variant = {"login_result_code": login_result} if success else {"error_code": "LOGIN_FAILED", "message": "Anonymous login failed with code: %d" % login_result}

	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = "Anon Login %s: Code %d" % ["Success" if success else "Failed", login_result]
	Log.info("Anonymous login result", {"result": login_result, "success": success}, ["test", "auth"])
	return [success, payload]

func _test_config_basic_fetch() -> Array: # Must return [bool, Variant]
	Log.debug("Config Test: Fetch", {}, ["test"])
	if not is_instance_valid(remote_config):
		if get_parent().visible and is_instance_valid(status_label): status_label.text = "[ERROR] Remote Config not initialized."
		return [false, {"error_code": "CONFIG_NULL", "message": "Remote Config module not initialized."}]

	# Assuming RemoteConfig fetch might be async or require a specific call pattern.
	# For this example, let's assume get_string triggers a fetch if needed or uses cached.
	# If 'loaded' signal is crucial, this test needs to await it.
	# For simplicity, direct get:
	remote_config.set_instant_fetching() # Ensure it tries to fetch
	# Await loaded might be needed here if not instant
	# await remote_config.loaded

	var rc_value: String = remote_config.get_string("test_string", "local_default_for_test")
	var success: bool = rc_value != "local_default_for_test" # Basic check: did it change from default?
	var payload: Variant = {"fetched_value": rc_value, "was_default": not success}

	if get_parent().visible and is_instance_valid(status_label):
		status_label.text = "RC Value: %s (Fetched: %s)" % [rc_value, "Yes" if success else "No/Default"]
	Log.info("Remote Config fetch test", {"value": rc_value, "success_assumption": success}, ["test", "config"])
	return [success, payload]
