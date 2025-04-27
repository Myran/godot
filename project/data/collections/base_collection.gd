class_name BaseCollection
extends RefCounted

var _backend: DataBackend
var _base_path: Array[Variant] = []
var _collection_name: String = ""

## Initialize the collection with backend and path information
## @param backend The data backend to use
## @param base_path Base path for the collection in the database
## @param collection_name Human-readable name for the collection
func _init(backend: DataBackend, base_path: Array = [], collection_name: String = "") -> void:
	_backend = backend
	_base_path = base_path
	_collection_name = collection_name
	Log.debug("BaseCollection initialized", {
		"collection_name": _collection_name,
		"base_path": _base_path
	}, [Log.TAG_DB])

## Get the full path for this collection
## @return The complete path to this collection
func _get_path() -> Array[Variant]:
	return _base_path.duplicate()
