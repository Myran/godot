class_name DataSource
extends Node

signal startup_completed
const DEFAULT_SHEETS_ID: String = "1WTKwZ8aXSeQVEVT8qeNtwUZepVZh7wv5skRGn_zFUsY"

var cards: CardCollection = null
var levels: LevelCollection = null
var items: ItemCollection = null
var players: PlayerCollection = null
var events: EventCollection = null
var rules: RulesCollection = null

var test_group: int = 0

var using_local_data: bool = false
var _backend: DataBackend = null
var _initialized: bool = false


func _ready() -> void:
	Log.info("DataSource initializing", {"instance_id": get_instance_id()}, [Log.TAG_DB])
	_initialized = false

	call_deferred("_initialize")


func _initialize() -> void:
	Log.debug(
		"Starting DataSource initialization", {"instance_id": get_instance_id()}, [Log.TAG_DB]
	)

	@warning_ignore("redundant_await")
	_backend = await BackendFactory.create_backend()

	using_local_data = _backend.get_class() == "LocalJSONBackend"

	Log.debug(
		"Backend created",
		{
			"backend_type": _backend.get_class() if _backend != null else "null",
			"using_local_data": using_local_data,
			"instance_id": get_instance_id()
		},
		[Log.TAG_DB]
	)

	_initialize_collections()

	if _backend != null:
		if not _backend.startup_completed.is_connected(_on_backend_startup_completed):
			_backend.startup_completed.connect(_on_backend_startup_completed)

	Log.debug("Waiting for backend startup", {"instance_id": get_instance_id()}, [Log.TAG_DB])


func _on_backend_startup_completed() -> void:
	Log.info(
		"DataSource initialization complete",
		{"firebase_available": is_firebase_available(), "instance_id": get_instance_id()},
		[Log.TAG_DB]
	)

	_initialized = true
	startup_completed.emit()

	_log_active_collections()


func _initialize_collections() -> void:
	Log.debug(
		"Initializing collections",
		{"test_group": test_group, "instance_id": get_instance_id()},
		[Log.TAG_DB]
	)

	var initialization_success: bool = true

	initialization_success = initialization_success and _initialize_collection("cards")
	initialization_success = initialization_success and _initialize_collection("levels")
	initialization_success = initialization_success and _initialize_collection("items")
	initialization_success = initialization_success and _initialize_collection("players")
	initialization_success = initialization_success and _initialize_collection("events")
	initialization_success = initialization_success and _initialize_collection("rules")

	if initialization_success:
		Log.debug(
			"DataSource collections initialized successfully",
			{"instance_id": get_instance_id()},
			[Log.TAG_DB]
		)
	else:
		Log.error(
			"Some collections failed to initialize",
			{"instance_id": get_instance_id()},
			[Log.TAG_DB, Log.TAG_ERROR]
		)


func _initialize_collection(collection_name: String) -> bool:
	Log.debug(
		"Initializing collection",
		{"collection_name": collection_name, "instance_id": get_instance_id()},
		[Log.TAG_DB]
	)

	var success: bool = true

	match collection_name:
		"cards":
			success = _safely_create_collection(
				func() -> void: cards = CardCollection.new(_backend, test_group), "cards"
			)
		"levels":
			success = _safely_create_collection(
				func() -> void: levels = LevelCollection.new(_backend, test_group), "levels"
			)
		"items":
			success = _safely_create_collection(
				func() -> void: items = ItemCollection.new(_backend, test_group), "items"
			)
		"players":
			success = _safely_create_collection(
				func() -> void: players = PlayerCollection.new(_backend), "players"
			)
		"events":
			success = _safely_create_collection(
				func() -> void: events = EventCollection.new(_backend, test_group), "events"
			)
		"rules":
			success = _safely_create_collection(
				func() -> void: rules = RulesCollection.new(_backend, test_group), "rules"
			)
		_:
			Log.error(
				"Unknown collection name",
				{"collection_name": collection_name, "instance_id": get_instance_id()},
				[Log.TAG_DB, Log.TAG_ERROR]
			)
			success = false

	return success


func _safely_create_collection(creation_function: Callable, collection_name: String) -> bool:
	Log.debug(
		"Initializing collection",
		{"collection_name": collection_name, "instance_id": get_instance_id()},
		[Log.TAG_DB]
	)

	creation_function.call()

	Log.debug(
		"Successfully initialized collection",
		{"collection_name": collection_name, "instance_id": get_instance_id()},
		[Log.TAG_DB]
	)

	return true


func set_test_group(group: int) -> void:
	test_group = group
	_initialize_collections()


func is_firebase_available() -> bool:
	var available: bool = false
	if _backend.get_class() == "FirebaseBackend":
		var firebase_backend: FirebaseBackend = _backend
		available = firebase_backend.is_available()
	elif _backend.get_class() == "FirebaseServiceBackend":
		var firebase_service_backend: FirebaseServiceBackend = _backend
		available = firebase_service_backend.is_available()

	Log.debug(
		"Firebase availability check",
		{"available": available, "backend_type": _backend.get_class()},
		[Log.TAG_DB]
	)
	return available


func is_initialized() -> bool:
	return _initialized


func activate_card_cache() -> void:
	Log.info(
		"Activating card cache", {"instance_id": get_instance_id()}, [Log.TAG_CACHE, Log.TAG_DB]
	)

	var request_start_time: int = Time.get_ticks_msec()
	@warning_ignore("redundant_await")
	var card_data: Array[Dictionary] = await cards.get_all(true)
	var request_duration: int = Time.get_ticks_msec() - request_start_time

	Log.info(
		"Card cache activated",
		{
			"count": card_data.size(),
			"duration_ms": request_duration,
			"data_source": "firebase" if is_firebase_available() else "local",
			"instance_id": get_instance_id()
		},
		[Log.TAG_CACHE, Log.TAG_DB]
	)


func setup_player_data() -> bool:
	Log.info("Setting up player data", {"instance_id": get_instance_id()}, [Log.TAG_DB])

	if players == null:
		Log.error(
			"Cannot setup player data - players collection not initialized",
			{"instance_id": get_instance_id()},
			[Log.TAG_DB, Log.TAG_ERROR]
		)
		return false

	var auth: Object = Engine.get_singleton("Auth")
	var auth_success: bool = true

	if auth != null and auth.is_available():
		Log.debug(
			"Auth singleton available, attempting login",
			{"instance_id": get_instance_id()},
			[Log.TAG_DB]
		)

		@warning_ignore("redundant_await")
		var auth_result: int = await auth.login()
		var success_code: int = 0  # FirebaseAuthError.Code.NONE value
		auth_success = (auth_result == success_code)

		if OS.has_feature("editor"):
			Log.debug(
				"Running in editor, forcing login success",
				{"instance_id": get_instance_id()},
				[Log.TAG_DB]
			)
			auth_success = true

		if not auth_success:
			Log.warning(
				"Login failed during player data setup",
				{"error_code": auth_result, "instance_id": get_instance_id()},
				[Log.TAG_DB, Log.TAG_ERROR]
			)
			return false
	else:
		Log.warning(
			"Auth singleton not available",
			{"instance_id": get_instance_id()},
			[Log.TAG_DB, Log.TAG_WARNING]
		)

	var data: Dictionary = players.get_default_data()
	Log.debug(
		"Created default player data",
		{"field_count": data.keys().size(), "instance_id": get_instance_id()},
		[Log.TAG_DB]
	)

	@warning_ignore("redundant_await")
	var save_success: bool = await players.save_user_data(data)

	if not save_success:
		Log.error(
			"Failed to save player data",
			{"instance_id": get_instance_id()},
			[Log.TAG_DB, Log.TAG_ERROR]
		)
		return false

	Log.info(
		"Player data setup complete",
		{"success": save_success, "instance_id": get_instance_id()},
		[Log.TAG_DB]
	)
	return true


func clear_all_caches() -> void:
	Log.info(
		"Clearing all collection caches",
		{"instance_id": get_instance_id()},
		[Log.TAG_DB, Log.TAG_CACHE]
	)

	if cards != null:
		cards.clear_cache()

	if levels != null:
		levels.clear_cache()

	if items != null:
		items.clear_cache()

	if events != null:
		events.clear_cache()

	if rules != null:
		rules.clear_cache()

	if players != null:
		players.clear_cache()

	Log.debug("All caches cleared", {"instance_id": get_instance_id()}, [Log.TAG_DB, Log.TAG_CACHE])


func _log_active_collections() -> void:
	var collection_status: Dictionary = {
		"cards": cards != null,
		"levels": levels != null,
		"items": items != null,
		"players": players != null,
		"events": events != null,
		"rules": rules != null
	}

	var active_count: int = 0
	for collection_name: String in collection_status:
		if collection_status[collection_name]:
			active_count += 1

	Log.debug(
		"Active collections",
		{
			"collections": collection_status,
			"active_count": active_count,
			"backend_type": _backend.get_class() if _backend != null else "none",
			"instance_id": get_instance_id()
		},
		[Log.TAG_DB]
	)
