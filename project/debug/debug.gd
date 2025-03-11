extends Control

signal fb_success(res: Dictionary)
signal apple_success(res: Dictionary)

# const kBannerAdUnitAndroid: String = "ca-app-pub-3940256099942544/6300978111"
# const kInterstitialAdUnitAndroid: String = "ca-app-pub-3940256099942544/1033173712"
# const kBannerAdUnitIOS: String = "ca-app-pub-3940256099942544/2934735716"
# const kFakeBannerAdUnitIOS: String = "ca-app-pub-3940256099942544/2934735716"
const FAKE_INTERSTITIAL_AD_UNIT_IOS: String = "ca-app-pub-3940256099942544/4411468910"
# const kRealInterstitialAdUnitIOS: String = "ca-app-pub-8265399856187334~2529757314"
const FAKE_REWARDED_VIDEO_AD_UNIT_IOS: String = "ca-app-pub-3940256099942544/1712485313"
# const kRealAdappIdIOS: String = "ca-app-pub-8265399856187334~2529757314"

var admob: Object
var db: Object
var remote_config: Object
var messaging: Object
var count: int = 1
var godot_apple_auth: Object
var home_game: Node
var _auth: Object

@onready var status_label: RichTextLabel = %DebugRichTextLabel


func setup(init_args: Dictionary) -> void:
	print("setup with args", init_args)


func _ready() -> void:
	var debug_text: String
	if OS.is_debug_build():
		debug_text = "Build is debug"
	else:
		debug_text = "build is release"
	%DebugRichTextLabel2.text = str("OS: ", OS.get_name(), debug_text)
	%DebugRichTextLabel3.text = str("Commit: ", Engine.get_version_info()["hash"])

	if ClassDB.class_exists("FirebaseDatabase"):
		print("RealTime Database Singelton exists")
		db = ClassDB.instantiate("FirebaseDatabase")
		print("RealTime Database instance: ", db)
		db.connect("get_value", Callable(self, "get_value"), CONNECT_DEFERRED)
		db.connect("child_changed", Callable(self, "child_changed"), CONNECT_DEFERRED)
		db.connect("child_moved", Callable(self, "child_moved"), CONNECT_DEFERRED)
		db.connect("child_removed", Callable(self, "child_removed"), CONNECT_DEFERRED)
		db.connect("child_added", Callable(self, "child_added"), CONNECT_DEFERRED)

		# Connect to new signals for advanced features
		db.connect("query_result", Callable(self, "on_ui_query_result"), CONNECT_DEFERRED)
		db.connect("transaction_completed", Callable(self, "on_ui_transaction_completed"), CONNECT_DEFERRED)
		db.connect("connection_state_changed", Callable(self, "on_ui_connection_state_changed"), CONNECT_DEFERRED)
		db.connect("db_error", Callable(self, "on_ui_db_error"), CONNECT_DEFERRED)

		db.set_db_root(["users"])

	# Check if we're running in test mode
	check_for_test_mode()

	if ClassDB.class_exists("FirebaseRemoteConfig"):
		print("Remote Config exists")
		remote_config = ClassDB.instantiate("FirebaseRemoteConfig")
		remote_config.connect("loaded", Callable(self, "remote_config_loaded"))

	if Engine.has_singleton("Facebook") or Engine.has_singleton("GodotFacebook"):
		print("facebook singleton exists")
	else:
		print("Facebook singleton does not exist")


func messaging_token() -> void:
	print("Messaging: token set")


func messaging_message() -> void:
	print("Messaging: message: ")


func _on_Button_remote_config_string_pressed() -> void:
	print("Button remote config string press")
	remote_config.set_instant_fetching()
	var rc_string: String = "local value"
	rc_string = remote_config.get_string("test_string")
	printt("Remote string:", rc_string)
	status_label.text = str("Remote config string: ", rc_string)


func remote_config_loaded() -> void:
	printt("Remote config loaded")


func _on_Button_update_pressed() -> void:
	printt("Button update pressed")
	db.update_children(["update"], {"key1": "value", "key2": "value"})


func _on_Button_delete_pressed() -> void:
	print("Button delete pressed")
	db.remove_value(["tom"])


func _on_Button_push_child_pressed() -> void:
	var key: String = "pushed"
	var pushString: String = db.push_child(["push", key])
	printt("Pushed string key:", key, "return string", pushString)
	db.set_value(["push", pushString], count)
	count = count + 1


func _on_Button_set_value_pressed() -> void:
	printt("Set value pressed")
	db.set_value(["tom"], str("Value", count))
	count = count + 1


func _on_Button_get_value_pressed() -> void:
	printt("Get_value pressed")
	db.get_value(["tom"])


func child_moved(key: String, value: Variant) -> void:
	printt("child moved", key, "value", value)


func child_added(key: String, value: Variant) -> void:
	printt("child added", key, "value", value)


func child_removed(key: String, value: Variant) -> void:
	printt("child removed", key, "value", value)


func child_changed(key: String, value: Variant) -> void:
	printt("Child changed:", "key:", key, "value", value)
	status_label.call_deferred("set_text", str("Value changed: ", key, "\n", "value: ", value))


func get_value(key: String, value: Variant) -> void:
	printt("key:", key, "Value:", value)
	status_label.text = str("Get_value for key: ", key, "\n", "Value: ", value)


func _on_Button_send_all_tracking_events_pressed() -> void:
	print("Tracking button pressed")
	if ClassDB.class_exists("FirebaseAnalytics"):
		print("FirebaseAnalytics exists")
		var a: Object = ClassDB.instantiate("FirebaseAnalytics")
		a.log_event("testlog_event")
		a.log_int("testlog_int", "int", 99)
		a.log_long("testlog_long", "long", 99)
		a.log_double("testlog_double", "double", 99)
		a.log_string("testlog_string", "string", "stringToLog")
		a.log_params("testlog_params", {"string": "start", "int": 99, "bool": true})
		a.user_property("has_test_property", "test_propery")
		a.user_id("0")
		a.screen_name("start_screen", "start_class")
		a.log_event("earn_virtual_currency")


func logged_in(res: String) -> void:
	print("_auth: DEBUG  Logged in: ", res)
	status_label.text = str("Auth: Logged in: ", res)


func _on_Button_sign_in_anon_pressed() -> void:
	print("button: sign in anon")
	var retval: int = await auth.login()
	print(str("login result: ", retval))
	status_label.call_deferred("set_text", str("login result: ", retval))


func facebook_login_success(res: Dictionary) -> void:
	fb_success.emit(res)


func _on_Button_sign_in_facebook_pressed() -> void:
	auth.sign_in_facebook()


func _on_Button_unlink_Facebook_pressed() -> void:
	auth.unlink_facebook()


func _on_Button_link_Facebook_pressed() -> void:
	auth.link_facebook()


func _on_Auth_Apple_login_pressed() -> void:
	print("button: apple login")
	if godot_apple_auth.is_available():
		print("apple auth is available")
		godot_apple_auth.sign_in()
		var result: Dictionary = await apple_success
		_auth.sign_in_apple(result.token, result.nonce)
		var auth_res: String = await _auth.logged_in()
		if auth_res == "":
			print("Firebase auth login success")
		else:
			print("Firebase auth login failed with error: ", auth_res)
	else:
		print("apple auth is not available")


func _on_Auth_Apple_log_out_pressed() -> void:
	print("button: apple log out")
	godot_apple_auth.sign_out()


func _on_Auth_Apple_link_pressed() -> void:
	print("button: link to Apple ")
	if !godot_apple_auth:
		print("apple auth does not exist")
		return
	godot_apple_auth.sign_in()
	var result: Dictionary = await apple_success
	print("apple login success")
	_auth.link_to_apple(result.token, result.nonce)
	var res: String = await _auth.account_linked
	if res == "":
		print("Apple account linked successfully")
	else:
		print("Apple account link unsuccessful error:", res)


func _on_Auth_Apple_unlink_pressed() -> void:
	print("Button: unlink apple")
	_auth.unlink_provider("apple.com")
	var res: String = await _auth.account_unlinked()
	if res == "":
		print("Apple account unlinked successfully")
	else:
		print("Apple account unlink unsuccessful error:", res)


func account_linked(_res: String) -> void:
	print("Account linked result:", _res)


func _on_Auth_Apple_has_provider_pressed() -> void:
	status_label.text = str("Auth: Is account connected to apple:", is_connected_to_apple())


func _on_Auth_fb_has_provider_pressed() -> void:
	status_label.text = str("Auth: Is account connected to facebook:", is_connected_to_facebook())


func _on_Button_sign_out_pressed() -> void:
	print("button: sign out")
	auth.log_out_facebook()


func _on_Button_get_all_info_pressed() -> void:
	print("button: show all info (Not implemented)")


func is_connected_to_facebook() -> bool:
	return check_provider_connection("facebook.com")


func is_connected_to_apple() -> bool:
	return check_provider_connection("apple.com")


func check_provider_connection(provider_name: String) -> bool:
	if _auth.is_logged_in():
		for provider : Dictionary in _auth.providers():
			if provider.name == provider_name:
				return true
	else:
		print("not logged in")
	return false


func _on_Button_close_pressed() -> void:
	visible = false


func _on_credential(result: Dictionary) -> void:
	if result.has("error"):
		print(result.error)
	else:
		print(result.state)


func _on_authorization(result: Dictionary) -> void:
	if result.has("error"):
		print(result.error)
		status_label.text = str(result.error)
	else:
		print("apple auth:")
		print("token: ", result.token)
		print("used_id: ", result.user_id)
		print("email ", result.email)
		print("name ", result.name)
		print("nonce ", result.nonce)
		status_label.text = str(
			"Apple auth:",
			"\n",
			"Name: ",
			result.name,
			"\n",
			"Mail:",
			result.email,
			"\n",
			"User_id:",
			result.user_id,
			"\n",
			"token: ",
			result.token,
			"\n",
			"nonce:",
			result.nonce
		)
		print("attempting to connect apple sign in to firebase")
		emit_signal("apple_success", result)


func _on_Button_func_is_interstitial_loaded_pressed() -> void:
	print("Return Value: is_interstitial_loaded:", admob.is_interstitial_loaded())
	status_label.text = str("Return Value: is_interstitial_loaded:", admob.is_interstitial_loaded())


func _on_Button_func_is_reward_loaded_pressed() -> void:
	status_label.text = str("Return Value: is_rewarded_loaded:", admob.is_rewarded_loaded())


func interstitial_loading_result(res: String) -> void:
	print("interstitial_loading_result", res)


func rewarded_completed() -> void:
	print("Rewarded completed")
	status_label.text = "Rewarded completed"


func rewarded_state(state: String) -> void:
	print("rewarded state changed:", state)


func interstitial_state(state: String) -> void:
	print("interstitial state changed:", state)


func _on_Button_load_interstitial_pressed() -> void:
	admob.load_interstitial(FAKE_INTERSTITIAL_AD_UNIT_IOS)


func _on_Button_play_interstitial_pressed() -> void:
	print("button play interstital pressed")
	admob.show_interstitial()


func _on_Button_load_rewarded_video_pressed() -> void:
	print("Button load rewarded video pressed")
	admob.load_rewarded(FAKE_REWARDED_VIDEO_AD_UNIT_IOS)


func _on_Button_play_rewarded_video_pressed() -> void:
	print("Button play rewarded video pressed")
	admob.show_rewarded()


func rewarded_loading_result(res: String) -> void:
	print("Rewarded loading result", res)


# Firebase Testing System
var firebase_tests_running: bool = false
var firebase_test_results: Dictionary = {}
var firebase_test_count: int = 0
var firebase_tests_passed: int = 0
var firebase_tests_failed: int = 0

# Check for test command line parameter
func check_for_test_mode() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_args()
	for arg: String in arguments:
		if arg == "--test" or arg == "--test-firebase":
			print("Test mode detected, running Firebase tests...")
			call_deferred("run_firebase_tests")
			return

# Main test runner function
func run_firebase_tests() -> void:
	print("===== STARTING FIREBASE DATABASE TESTS =====")
	firebase_tests_running = true
	firebase_test_count = 0
	firebase_tests_passed = 0
	firebase_tests_failed = 0
	firebase_test_results.clear()

	if not ClassDB.class_exists("FirebaseDatabase"):
		_log_test_result("firebase_available", false, "FirebaseDatabase class not found")
		_complete_tests()
		return

	# Setup database with test path
	db = ClassDB.instantiate("FirebaseDatabase")
	if not db:
		_log_test_result("firebase_init", false, "Failed to instantiate FirebaseDatabase")
		_complete_tests()
		return

	_log_test_result("firebase_init", true, "FirebaseDatabase initialized successfully")

	# Connect to signals
	db.connect("get_value", Callable(self, "_on_test_get_value"), CONNECT_DEFERRED)
	db.connect("child_changed", Callable(self, "child_changed"), CONNECT_DEFERRED)
	db.connect("child_moved", Callable(self, "child_moved"), CONNECT_DEFERRED)
	db.connect("child_removed", Callable(self, "child_removed"), CONNECT_DEFERRED)
	db.connect("child_added", Callable(self, "child_added"), CONNECT_DEFERRED)
	db.connect("query_result", Callable(self, "on_test_query_result"), CONNECT_DEFERRED)
	db.connect("transaction_completed", Callable(self, "on_test_transaction_completed"), CONNECT_DEFERRED)
	db.connect("connection_state_changed", Callable(self, "on_test_connection_state_changed"), CONNECT_DEFERRED)
	db.connect("db_error", Callable(self, "on_test_db_error"), CONNECT_DEFERRED)

	# Setup test path - use a timestamp to avoid conflicts
	var timestamp: int = Time.get_unix_time_from_system()
	var test_path: Array[String] = ["firebase_tests", str(timestamp)]
	db.set_db_root(test_path)

	# Run tests sequentially with proper timing
	_test_set_value()
	await get_tree().create_timer(1.0).timeout
	_test_push_child()
	await get_tree().create_timer(1.0).timeout
	_test_update_children()
	await get_tree().create_timer(1.0).timeout
	_test_get_value()
	await get_tree().create_timer(1.0).timeout
	_test_query()
	await get_tree().create_timer(1.0).timeout
	_test_server_timestamp()
	await get_tree().create_timer(1.0).timeout
	_test_transaction()
	await get_tree().create_timer(1.0).timeout
	_test_connection_monitoring()
	await get_tree().create_timer(1.0).timeout

	# Clean up test data
	var cleanup_path: Array[String] = ["firebase_tests"]
	db.set_db_root(cleanup_path)
	db.remove_value([str(timestamp)])

	# Wait for cleanup to complete
	await get_tree().create_timer(1.0).timeout
	_complete_tests()

# Individual test functions
func _test_set_value() -> void:
	print("Testing set_value...")
	db.set_value(["test_value"], "test_string_value")
	db.set_value(["test_number"], 42)
	_log_test_result("set_value", true, "Set string and number values")

func _test_push_child() -> void:
	print("Testing push_child...")
	var push_key: String = db.push_child(["test_push"])
	if push_key.length() > 0:
		db.set_value(["test_push", push_key], "push_test_value")
		_log_test_result("push_child", true, "Pushed child with key: " + push_key)
	else:
		_log_test_result("push_child", false, "Failed to generate push key")

func _test_update_children() -> void:
	print("Testing update_children...")
	db.update_children(["test_update"], {"field1": "value1", "field2": "value2"})
	_log_test_result("update_children", true, "Updated multiple fields")

func _test_get_value() -> void:
	print("Testing get_value...")
	# Value will be received via the get_value signal handler
	db.get_value(["test_value"])

func _test_query() -> void:
	print("Testing query functionality...")
	# Setup test data for query
	db.set_value(["query_test", "item1"], {"name": "Item 1", "score": 10})
	db.set_value(["query_test", "item2"], {"name": "Item 2", "score": 25})
	db.set_value(["query_test", "item3"], {"name": "Item 3", "score": 5})

	# Query by score
	var query_params: Dictionary = {
		"orderByChild": "score",
		"limitToLast": 2  # Get top 2 scores
	}
	db.query_ordered_data(["query_test"], query_params)

func _test_server_timestamp() -> void:
	print("Testing server timestamp...")
	db.set_server_timestamp(["test_timestamp"])
	# Value will be received in a signal

func _test_transaction() -> void:
	print("Testing transaction...")
	# Initialize counter
	db.set_value(["test_transaction", "counter"], 10)
	await get_tree().create_timer(0.5).timeout
	# Run transaction to increment by 5
	db.run_transaction(["test_transaction", "counter"], 5)
	# Result handled by on_transaction_completed signal

func _test_connection_monitoring() -> void:
	print("Testing connection monitoring...")
	db.monitor_connection_state()
	# Will be notified via the connection_state_changed signal

# Signal handlers for test validation

func _on_test_get_value(key: String, value: Variant) -> void:
	printt("Test get_value received:", "key:", key, "Value:", value)
	if firebase_tests_running:
		_log_test_result("get_value", true, "Retrieved value: " + str(value))

func on_test_query_result(key: String, value: Variant) -> void:
	printt("Test query_result received:", "key:", key, "value:", value)
	if firebase_tests_running:
		var success: bool = typeof(value) == TYPE_DICTIONARY and value.size() > 0
		_log_test_result("query", success, "Query returned " + str(value.size()) + " results")

func on_test_transaction_completed(key: String, value: Variant, success: bool) -> void:
	printt("Test transaction_completed:", "success:", success, "key:", key, "value:", value)
	if firebase_tests_running:
		var expected_value: int = 15  # 10 + 5
		var value_correct: bool = typeof(value) == TYPE_INT and value == expected_value
		_log_test_result("transaction", success and value_correct,
			"Transaction " + ("succeeded" if success else "failed") +
			", value: " + str(value) + " (expected: " + str(expected_value) + ")")

func on_test_connection_state_changed(connected: bool) -> void:
	printt("Test connection state changed:", connected)
	if firebase_tests_running:
		_log_test_result("connection_monitoring", true, "Connection state: " + ("connected" if connected else "disconnected"))

func on_test_db_error(code: String, message: String) -> void:
	printt("Test database error:", "code:", code, "message:", message)
	if firebase_tests_running:
		_log_test_result("db_error", false, "Error " + code + ": " + message)

# Test utility functions

func _log_test_result(test_name: String, success: bool, message: String) -> void:
	firebase_test_count += 1
	if success:
		firebase_tests_passed += 1
		print("✅ PASS: " + test_name + " - " + message)
	else:
		firebase_tests_failed += 1
		print("❌ FAIL: " + test_name + " - " + message)

	firebase_test_results[test_name] = {
		"success": success,
		"message": message
	}

	if status_label:
		status_label.text = "Running Firebase tests...\n" + \
			"Passed: " + str(firebase_tests_passed) + "\n" + \
			"Failed: " + str(firebase_tests_failed) + "\n" + \
			"Last test: " + test_name

func _complete_tests() -> void:
	print("\n===== FIREBASE TEST RESULTS =====")
	print("Total tests: " + str(firebase_test_count))
	print("Passed: " + str(firebase_tests_passed))
	print("Failed: " + str(firebase_tests_failed))
	print("Success rate: " + str(round(100.0 * firebase_tests_passed / max(1, firebase_test_count))) + "%")
	print("===============================")

	firebase_tests_running = false

	if status_label:
		status_label.text = "Firebase Tests Completed\n" + \
			"Total: " + str(firebase_test_count) + "\n" + \
			"Passed: " + str(firebase_tests_passed) + "\n" + \
			"Failed: " + str(firebase_tests_failed) + "\n" + \
			"Success rate: " + str(round(100.0 * firebase_tests_passed / max(1, firebase_test_count))) + "%"

	# Exit the application if running in test mode
	var arguments: Array[String] = OS.get_cmdline_args()
	if arguments.has("--test") or arguments.has("--test-firebase"):
		await get_tree().create_timer(0.5).timeout
		get_tree().quit(0 if firebase_tests_failed == 0 else 1)

# New Firebase Advanced Features handling

func _on_Button_firebase_advanced_pressed() -> void:
	print("Testing Firebase Advanced Features")
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Select Firebase Feature to Test"
	dialog.dialog_text = "Select a feature to test:"

	var option_button: OptionButton = OptionButton.new()
	option_button.add_item("Query Ordered Data", 0)
	option_button.add_item("Server Timestamp", 1)
	option_button.add_item("Run Transaction", 2)
	option_button.add_item("Monitor Connection State", 3)

	dialog.add_child(option_button as Node)
	add_child(dialog as Node)

	dialog.popup_centered(Vector2(300, 200))

	# Wait for dialog confirmation
	dialog.confirmed.connect(func() -> void:
		var result: int = option_button.selected
		match result:
			0: # Query Ordered Data
				_test_ui_query_ordered_data()
			1: # Server Timestamp
				_test_ui_server_timestamp()
			2: # Run Transaction
				_test_ui_transaction()
			3: # Monitor Connection State
				_test_ui_connection_monitoring()

		dialog.queue_free()
	)


func _test_ui_query_ordered_data() -> void:
	print("Testing Query Ordered Data")

	# First set some test data
	db.set_db_root(["test_query"])
	db.set_value(["test_query", "item1"], {"name": "Item 1", "score": 10})
	db.set_value(["test_query", "item2"], {"name": "Item 2", "score": 25})
	db.set_value(["test_query", "item3"], {"name": "Item 3", "score": 5})

	# Now query by score
	var query_params: Dictionary = {
			"orderByChild": "score",
			"limitToLast": 2  # Get top 2 scores
	}

	db.query_ordered_data(["test_query"], query_params)
	status_label.text = "Running query for top 2 scores..."


func _test_ui_server_timestamp() -> void:
	print("Testing Server Timestamp")
	db.set_server_timestamp(["test_timestamp"])
	status_label.text = "Setting server timestamp..."

	# Wait a moment then get the value to display
	await get_tree().create_timer(1.0).timeout
	db.get_value(["test_timestamp"])


func _test_ui_transaction() -> void:
	print("Testing Transaction")

	# Set initial counter value
	db.set_value(["test_transaction", "counter"], 10)

	# Now run a transaction that increments it by 5
	db.run_transaction(["test_transaction", "counter"], 5)
	status_label.text = "Running transaction to increment counter by 5..."


func _test_ui_connection_monitoring() -> void:
	print("Testing Connection Monitoring")
	db.monitor_connection_state()
	status_label.text = "Monitoring connection state..."


# Signal handlers for advanced features

func on_ui_query_result(key: String, value: Variant) -> void:
	print("Query result received - key: ", key, " value: ", value)

	var result_text: String = "Query Results:\n"

	if typeof(value) == TYPE_DICTIONARY:
			for item_key: String in value.keys():
					var item: Dictionary = value[item_key]
					if typeof(item) == TYPE_DICTIONARY and item.has("name") and item.has("score"):
							result_text += str(item.name, " - Score: ", item.score, "\n")
					else:
							result_text += str(item_key, ": ", item, "\n")
	else:
			result_text += str(value)

	status_label.text = result_text


func on_ui_transaction_completed(key: String, value: Variant, success: bool) -> void:
	print("Transaction completed - success: ", success, " key: ", key, " value: ", value)

	if success:
			status_label.text = str("Transaction successful!\nNew value: ", value)
	else:
			status_label.text = "Transaction failed!"


func on_ui_connection_state_changed(connected: bool) -> void:
	print("Connection state changed - connected: ", connected)
	status_label.text = str("Firebase connection state: ", "CONNECTED" if connected else "DISCONNECTED")


func on_ui_db_error(code: String, message: String) -> void:
	print("Database error - code: ", code, " message: ", message)
	status_label.text = str("Firebase error!\nCode: ", code, "\nMessage: ", message)
