class_name DataBackend
extends RefCounted

# These signals are used by derived classes
# Used by the DataSource class to track when data is retrieved
signal value_received(data: Dictionary)
# Used to notify when initialization is complete
signal startup_completed

## Initialize the backend
## @return bool True if initialization was successful
func initialize() -> bool:
	Log.info("DataBackend.initialize called on base class", {}, [Log.TAG_DB])
	Log.error("Method not implemented in base class", {"method": "initialize"}, [Log.TAG_DB, Log.TAG_ERROR])
	return false

## Check if the backend is available and ready for use
## @return bool True if the backend is available
func is_available() -> bool:
	Log.error("Method not implemented in base class", {"method": "is_available"}, [Log.TAG_DB, Log.TAG_ERROR])
	return false

## Get data from the specified path and key
## @param path Array The path to the data
## @param key String The key to retrieve
## @return Variant The retrieved data
func get_data(path: Array, key: String) -> Variant:
	Log.debug("DataBackend.get_data called with", {"path": path, "key": key}, [Log.TAG_DB])
	Log.error("Method not implemented in base class", {"method": "get_data", "path": path, "key": key}, [Log.TAG_DB, Log.TAG_ERROR])
	return null

## Set data at the specified path and key
## @param path Array The path to set data at
## @param key String The key to set
## @param data Variant The data to set
## @return bool True if data was set successfully
func set_data(path: Array, key: String, _data: Variant) -> bool:
	Log.debug("DataBackend.set_data called with", {"path": path, "key": key}, [Log.TAG_DB])
	Log.error("Method not implemented in base class", {"method": "set_data", "path": path, "key": key}, [Log.TAG_DB, Log.TAG_ERROR])
	return false

## Push data to a collection, generating a unique ID
## @param path Array The path to push data to
## @param data Variant The data to push
## @return String The generated unique ID
func push_data(path: Array, _data: Variant) -> String:
	Log.debug("DataBackend.push_data called with", {"path": path}, [Log.TAG_DB])
	Log.error("Method not implemented in base class", {"method": "push_data", "path": path}, [Log.TAG_DB, Log.TAG_ERROR])
	return ""

## Remove data at the specified path and key
## @param path Array The path to remove data from
## @param key String The key to remove
## @return bool True if data was removed successfully
func remove_data(path: Array, key: String) -> bool:
	Log.debug("DataBackend.remove_data called with", {"path": path, "key": key}, [Log.TAG_DB])
	Log.error("Method not implemented in base class", {"method": "remove_data", "path": path, "key": key}, [Log.TAG_DB, Log.TAG_ERROR])
	return false
