class_name FirestoreDebugAction
extends DebugAction

# Base class for Firestore debug actions
# Provides common utilities for accessing FirebaseFirestore C++ instance
# Follows the pattern of other Firebase debug actions (auth, remote_config)

# Cache references for performance
var _cpp_firestore: Object = null
var _firestore_service: Object = null


func _init() -> void:
	super._init()
	category = "Firebase SDK"


# Check if FirebaseFirestore C++ class is available
func is_cpp_firestore_available() -> bool:
	return ClassDB.class_exists("FirebaseFirestore")


# Get C++ FirebaseFirestore instance
func get_cpp_firestore() -> Object:
	if _cpp_firestore != null:
		return _cpp_firestore

	if not is_cpp_firestore_available():
		Log.error("FirebaseFirestore C++ class not registered", {}, ["debug", "firestore"])
		return null

	# Create new instance (Firestore uses shared singleton internally)
	_cpp_firestore = FirebaseFirestore.new()

	if not is_instance_valid(_cpp_firestore):
		Log.error("Failed to create FirebaseFirestore instance", {}, ["debug", "firestore"])
		return null

	Log.debug("FirebaseFirestore C++ instance created", {}, ["debug", "firestore"])
	return _cpp_firestore


# Get FirestoreService GDScript wrapper
func get_firestore_service() -> Object:
	if _firestore_service != null:
		return _firestore_service

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.root:
		Log.warning(
			"SceneTree not available for FirestoreService access", {}, ["debug", "firestore"]
		)
		return null

	# Check if autoload exists
	_firestore_service = tree.root.get_node_or_null("/root/FirestoreService")

	if not is_instance_valid(_firestore_service):
		Log.warning("FirestoreService autoload not found", {}, ["debug", "firestore"])
		return null

	Log.debug("FirestoreService GDScript instance found", {}, ["debug", "firestore"])
	return _firestore_service


# Generate test document data
func get_test_document_data() -> Dictionary:
	return {
		"name": "TestPlayer",
		"level": 42,
		"score": 1337,
		"is_active": true,
		"last_login": Time.get_unix_time_from_system(),
		"stats": {"wins": 10, "losses": 3, "win_rate": 0.77},
		"cards": ["fireball", "heal", "shield"]
	}


# Generate test collection name with timestamp for uniqueness
func get_test_collection_name() -> String:
	var timestamp: int = Time.get_unix_time_from_system()
	return "test_collection_" + str(timestamp)


# Generate test document ID
func get_test_document_id() -> String:
	return "test_doc_" + str(Time.get_ticks_msec())
