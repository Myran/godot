class_name DataBackend
extends RefCounted

@warning_ignore("unused_signal")
signal value_received(data: Dictionary[String, Variant])
@warning_ignore("unused_signal")
signal startup_completed


func initialize() -> bool:
	Log.info("DataBackend.initialize called on base class", {}, [Log.TAG_DB])
	Log.error(
		"Method not implemented in base class",
		{"method": "initialize"},
		[Log.TAG_DB, Log.TAG_ERROR]
	)
	return false


func is_available() -> bool:
	Log.error(
		"Method not implemented in base class",
		{"method": "is_available"},
		[Log.TAG_DB, Log.TAG_ERROR]
	)
	return false


func get_data(path: Array[Variant], key: String) -> Variant:
	Log.debug("DataBackend.get_data called with", {"path": path, "key": key}, [Log.TAG_DB])
	Log.error(
		"Method not implemented in base class",
		{"method": "get_data", "path": path, "key": key},
		[Log.TAG_DB, Log.TAG_ERROR]
	)
	return null


func set_data(path: Array[Variant], key: String, _data: Variant) -> bool:
	Log.debug("DataBackend.set_data called with", {"path": path, "key": key}, [Log.TAG_DB])
	Log.error(
		"Method not implemented in base class",
		{"method": "set_data", "path": path, "key": key},
		[Log.TAG_DB, Log.TAG_ERROR]
	)
	return false


func push_data(path: Array[Variant], _data: Variant) -> String:
	Log.debug("DataBackend.push_data called with", {"path": path}, [Log.TAG_DB])
	Log.error(
		"Method not implemented in base class",
		{"method": "push_data", "path": path},
		[Log.TAG_DB, Log.TAG_ERROR]
	)
	return ""


func remove_data(path: Array[Variant], key: String) -> bool:
	Log.debug("DataBackend.remove_data called with", {"path": path, "key": key}, [Log.TAG_DB])
	Log.error(
		"Method not implemented in base class",
		{"method": "remove_data", "path": path, "key": key},
		[Log.TAG_DB, Log.TAG_ERROR]
	)
	return false
