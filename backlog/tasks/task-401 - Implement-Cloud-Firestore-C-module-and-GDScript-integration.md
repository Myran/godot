---
id: task-401
title: Implement Cloud Firestore C++ module and GDScript integration
status: To Do
assignee: []
created_date: '2025-12-30 21:26'
updated_date: '2025-12-30 22:43'
labels:
  - firebase
  - firestore
  - cpp
  - gdscript
  - testing
dependencies:
  - task-403
  - task-399
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Overview

Implement complete Cloud Firestore integration following the established RTDB architecture patterns. This is a larger task requiring new C++ implementation as Firestore is more complex than RTDB.

## Architecture Reference

Follow the 3-layer pattern from RTDB:
1. **C++ Module Layer** - `godot/modules/firebase/firestore.h/cpp` (NEW)
2. **GDScript Service Layer** - `project/firebase/firestore_service.gd` (NEW)
3. **Backend Abstraction** - `project/data/backends/firestore_backend.gd` (NEW)

## Implementation Scope

### C++ Module Layer (`godot/modules/firebase/firestore.h/cpp`)
Follow database.h/cpp patterns:
- Thread-safe singleton with std::mutex
- Future-based async with callback marshalling to main thread
- Type conversion via Convertor class
- Shutdown safety preventing callback-during-cleanup crashes

**Core Methods:**
- `document_get_async(request_id, collection_path, document_id)`
- `document_set_async(request_id, collection_path, document_id, data)`
- `document_update_async(request_id, collection_path, document_id, data)`
- `document_delete_async(request_id, collection_path, document_id)`
- `collection_query_async(request_id, collection_path, query_params)`

**Signals:**
- `document_get_completed(request_id, document_data, exists, error)`
- `document_set_completed(request_id, success, error)`
- `document_update_completed(request_id, success, error)`
- `document_delete_completed(request_id, success, error)`
- `query_completed(request_id, documents_array, error)`

### GDScript Service Layer (`project/firebase/firestore_service.gd`)
- FirestoreService class wrapping C++ FirebaseFirestore
- Document reference helpers (collection → document path)
- Async CRUD operations with FirebaseRequest pattern
- Query builder for simple queries
- Signals: mirror C++ signals for GDScript consumption

### Backend Abstraction (`project/data/backends/firestore_backend.gd`)
- FirestoreBackend class for unified Firestore access
- Document operations abstraction
- Collection access helpers

### Debug Actions (`project/debug/actions/firebase_firestore/`)
- `firestore_document_get_test_action.gd` - Get document
- `firestore_document_set_test_action.gd` - Create/overwrite document
- `firestore_document_update_test_action.gd` - Update document fields
- `firestore_document_delete_test_action.gd` - Delete document
- `firestore_collection_query_test_action.gd` - Query collection
- `firestore_error_handling_test_action.gd` - Error scenarios

### Test Configurations (`tests/debug_configs/`)
- `firebase-firestore-layer.json` - All Firestore tests
- `firebase-firestore-crud.json` - CRUD operations
- `firebase-firestore-queries.json` - Query tests

## Reference Files
- `godot/modules/firebase/database.h/cpp` - C++ singleton and async pattern
- `godot/modules/firebase/convertor.cpp` - Type conversion (extend for Firestore types)
- `project/firebase/database_service.gd` - GDScript service pattern

## Notes
- Firestore is more complex than RTDB (structured documents vs JSON tree)
- Consider subcollection support in future iteration
- Query support can be basic initially (where, orderBy, limit)
- Offline persistence may require additional C++ work
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 C++ FirebaseFirestore class with thread-safe singleton pattern
- [ ] #2 Worker thread → main thread callback marshalling implemented
- [ ] #3 Type conversion extended for Firestore document types
- [ ] #4 Document CRUD operations work: get, set, update, delete
- [ ] #5 Basic collection query support: where, orderBy, limit
- [ ] #6 FirestoreService GDScript wrapper with async pattern
- [ ] #7 FirestoreBackend implements consistent backend abstraction
- [ ] #8 6+ debug actions covering all CRUD operations and queries
- [ ] #9 Test configurations for all platforms (Android, iOS, macOS, Windows)
- [ ] #10 Cross-platform testing passes on at least Android and desktop
- [ ] #11 Error handling tests validate permission and not-found errors
- [ ] #12 Shutdown safety prevents crashes during app exit
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan - Cloud Firestore

### Phase 1: C++ Module Creation (firestore.h/cpp) - NEW FILES

**1.1 Create firestore.h Header**
```cpp
#ifndef FirebaseFirestore_h
#define FirebaseFirestore_h

#include "core/object/ref_counted.h"
#include "core/os/mutex.h"
#include "firebase.h"
#include "firebase/firestore.h"
#include <atomic>
#include <mutex>

class FirebaseFirestore : public RefCounted {
    GDCLASS(FirebaseFirestore, RefCounted);

private:
    // Thread-safe singleton (follow database.h pattern)
    static std::mutex initialization_mutex;
    static std::atomic<bool> inited;
    static FirebaseFirestore* singleton_instance;
    static std::mutex instance_mutex;
    static std::atomic<bool> is_shutting_down;
    
    static firebase::firestore::Firestore* firestore_instance;
    
    FirebaseFirestore();  // Private constructor

protected:
    static void _bind_methods();
    
    // Main thread callback handlers
    void _handle_document_get_on_main_thread(int req_id, String collection, String document, Dictionary data, bool exists, int error, String error_msg);
    void _handle_document_set_on_main_thread(int req_id, bool success, int error, String error_msg);
    void _handle_document_update_on_main_thread(int req_id, bool success, int error, String error_msg);
    void _handle_document_delete_on_main_thread(int req_id, bool success, int error, String error_msg);
    void _handle_collection_query_on_main_thread(int req_id, Array documents, int error, String error_msg);

public:
    static FirebaseFirestore& get_instance();
    static void cleanup();
    static void begin_shutdown();
    static bool is_app_shutting_down();
    
    FirebaseFirestore(const FirebaseFirestore&) = delete;
    ~FirebaseFirestore();

    // Document CRUD operations
    void document_get_async(int p_request_id, const String& collection, const String& document_id);
    void document_set_async(int p_request_id, const String& collection, const String& document_id, const Dictionary& data);
    void document_update_async(int p_request_id, const String& collection, const String& document_id, const Dictionary& data);
    void document_delete_async(int p_request_id, const String& collection, const String& document_id);
    
    // Collection operations
    void collection_add_async(int p_request_id, const String& collection, const Dictionary& data);
    void collection_query_async(int p_request_id, const String& collection, const Dictionary& query_params);
};

#endif // FirebaseFirestore_h
```

**1.2 Implement Core Methods (firestore.cpp)**
```cpp
// Document Get - Firebase SDK pattern from documentation
void FirebaseFirestore::document_get_async(int p_request_id, const String& collection, const String& document_id) {
    if (!inited || !firestore_instance) {
        call_deferred(SNAME("emit_signal"), SNAME("document_get_error"), p_request_id, "DB_NOT_INITIALIZED");
        return;
    }
    
    firebase::firestore::DocumentReference doc_ref = 
        firestore_instance->Collection(collection.utf8().get_data())
                          .Document(document_id.utf8().get_data());
    
    firebase::Future<firebase::firestore::DocumentSnapshot> future = doc_ref.Get();
    future.OnCompletion([this, p_request_id, collection, document_id](
            const firebase::Future<firebase::firestore::DocumentSnapshot>& result) {
        // WORKER THREAD - Extract thread-safe data only
        int error = result.error();
        String error_msg = result.error_message() ? String(result.error_message()) : "";
        
        Dictionary data;
        bool exists = false;
        
        if (result.status() == firebase::kFutureStatusComplete && 
            error == firebase::firestore::kErrorOk) {
            const firebase::firestore::DocumentSnapshot* snapshot = result.result();
            if (snapshot && snapshot->exists()) {
                exists = true;
                // Convert Firestore data to Dictionary
                std::map<std::string, firebase::firestore::FieldValue> fields = snapshot->GetData();
                for (const auto& field : fields) {
                    data[String(field.first.c_str())] = ConvertFieldValueToVariant(field.second);
                }
            }
        }
        
        // Marshal to main thread
        MessageQueue::get_singleton()->push_callable(
            callable_mp(this, &FirebaseFirestore::_handle_document_get_on_main_thread)
                .bind(p_request_id, collection, document_id, data, exists, error, error_msg)
        );
    });
}

// Document Set - Firebase SDK pattern
void FirebaseFirestore::document_set_async(int p_request_id, const String& collection, 
                                           const String& document_id, const Dictionary& data) {
    firebase::firestore::DocumentReference doc_ref = 
        firestore_instance->Collection(collection.utf8().get_data())
                          .Document(document_id.utf8().get_data());
    
    // Convert Dictionary to Firestore MapFieldValue
    firebase::firestore::MapFieldValue firestore_data = ConvertDictionaryToFieldMap(data);
    
    firebase::Future<void> future = doc_ref.Set(firestore_data);
    future.OnCompletion([this, p_request_id](const firebase::Future<void>& result) {
        bool success = (result.status() == firebase::kFutureStatusComplete &&
                       result.error() == firebase::firestore::kErrorOk);
        MessageQueue::get_singleton()->push_callable(
            callable_mp(this, &FirebaseFirestore::_handle_document_set_on_main_thread)
                .bind(p_request_id, success, result.error(), String(result.error_message()))
        );
    });
}

// Collection Add (auto-generate ID) - Firebase SDK pattern
void FirebaseFirestore::collection_add_async(int p_request_id, const String& collection, const Dictionary& data) {
    firebase::firestore::CollectionReference coll_ref = 
        firestore_instance->Collection(collection.utf8().get_data());
    
    firebase::firestore::MapFieldValue firestore_data = ConvertDictionaryToFieldMap(data);
    
    firebase::Future<firebase::firestore::DocumentReference> future = coll_ref.Add(firestore_data);
    future.OnCompletion([this, p_request_id](
            const firebase::Future<firebase::firestore::DocumentReference>& result) {
        // Extract document ID from result
        String doc_id = "";
        if (result.status() == firebase::kFutureStatusComplete &&
            result.error() == firebase::firestore::kErrorOk) {
            doc_id = String(result.result()->id().c_str());
        }
        // Marshal to main thread...
    });
}
```

**1.3 Type Conversion Helpers (add to convertor.cpp)**
```cpp
// Firestore FieldValue → Godot Variant
static Variant ConvertFieldValueToVariant(const firebase::firestore::FieldValue& field);

// Godot Dictionary → Firestore MapFieldValue  
static firebase::firestore::MapFieldValue ConvertDictionaryToFieldMap(const Dictionary& dict);
```

**1.4 Query Support**
```cpp
void FirebaseFirestore::collection_query_async(int p_request_id, const String& collection, 
                                               const Dictionary& query_params) {
    firebase::firestore::Query query = firestore_instance->Collection(collection.utf8().get_data());
    
    // Apply query modifiers from query_params
    if (query_params.has("where_field")) {
        String field = query_params["where_field"];
        String op = query_params["where_op"];
        Variant value = query_params["where_value"];
        // query = query.WhereEqualTo(field, value);
    }
    if (query_params.has("order_by")) {
        query = query.OrderBy(String(query_params["order_by"]).utf8().get_data());
    }
    if (query_params.has("limit")) {
        query = query.Limit(int(query_params["limit"]));
    }
    
    firebase::Future<firebase::firestore::QuerySnapshot> future = query.Get();
    // ... OnCompletion handler
}
```

**1.5 Signal Bindings**
```cpp
ADD_SIGNAL(MethodInfo("document_get_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::STRING, "collection"), PropertyInfo(Variant::STRING, "document_id"), PropertyInfo(Variant::DICTIONARY, "data"), PropertyInfo(Variant::BOOL, "exists")));
ADD_SIGNAL(MethodInfo("document_get_error", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::STRING, "error_code"), PropertyInfo(Variant::STRING, "error_message")));
ADD_SIGNAL(MethodInfo("document_set_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "error_message")));
ADD_SIGNAL(MethodInfo("document_update_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "error_message")));
ADD_SIGNAL(MethodInfo("document_delete_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "error_message")));
ADD_SIGNAL(MethodInfo("collection_add_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::STRING, "document_id"), PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "error_message")));
ADD_SIGNAL(MethodInfo("query_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::ARRAY, "documents")));
ADD_SIGNAL(MethodInfo("query_error", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::STRING, "error_code"), PropertyInfo(Variant::STRING, "error_message")));
```

### Phase 2: Build System Integration

**2.1 Update SCsub**
```python
# Add to source files
env.add_source_files(env.modules_sources, "firestore.cpp")

# Link Firestore library (platform-specific)
if env['platform'] == 'android':
    env.Prepend(LIBS=[File("#/../firebase/firebase_cpp_sdk/libs/android/.../libfirebase_firestore.a")])
if env['platform'] == 'iphone':
    env.Prepend(LIBS=[File("#/../firebase/firebase_cpp_sdk/libs/ios/device-arm64/libfirebase_firestore.a")])
if env['platform'] == 'macos':
    env.Prepend(LIBS=[File("#/../firebase/firebase_cpp_sdk/libs/macos/universal/libfirebase_firestore.a")])
if env['platform'] == 'windows':
    env.Prepend(LIBS=[File("#/../firebase/firebase_cpp_sdk/libs/windows/VS2019/MT/x64/Release/firebase_firestore.lib")])
```

**2.2 Update register_types.cpp**
```cpp
#include "firestore.h"

void initialize_firebase_module(ModuleInitializationLevel p_level) {
    // ... existing registrations
    ClassDB::register_class<FirebaseFirestore>();
}
```

### Phase 3: GDScript Service Layer

**3.1 Create firestore_service.gd**
```gdscript
class_name FirestoreService
extends RefCounted

var _firebase_service: Node
var _cpp_firestore: Object
var _request_id_counter: int = 0

func get_document(collection: String, document_id: String) -> Dictionary:
    var request_id = _get_next_request_id()
    _cpp_firestore.document_get_async(request_id, collection, document_id)
    var result = await _cpp_firestore.document_get_completed
    return {"exists": result[4], "data": result[3], "error": ""}

func set_document(collection: String, document_id: String, data: Dictionary) -> bool:
    var request_id = _get_next_request_id()
    _cpp_firestore.document_set_async(request_id, collection, document_id, data)
    var result = await _cpp_firestore.document_set_completed
    return result[1]  # success

func add_document(collection: String, data: Dictionary) -> String:
    var request_id = _get_next_request_id()
    _cpp_firestore.collection_add_async(request_id, collection, data)
    var result = await _cpp_firestore.collection_add_completed
    return result[1]  # document_id
```

### Phase 4: Debug Actions & Test Configurations

**4.1 Create project/debug/actions/firebase_firestore/**
- `firestore_document_get_test_action.gd`
- `firestore_document_set_test_action.gd`
- `firestore_document_update_test_action.gd`
- `firestore_document_delete_test_action.gd`
- `firestore_collection_query_test_action.gd`
- `firestore_error_handling_test_action.gd`

**4.2 Create tests/debug_configs/**
- `firebase-firestore-layer.json`
- `firebase-firestore-crud.json`
- `firebase-firestore-queries.json`

### Key Reference Files
- `godot/modules/firebase/database.h` - Full thread-safe singleton pattern
- `godot/modules/firebase/database.cpp:404-453` - Async with MessageQueue
- Firebase docs: Collection.Add, Document.Get patterns
<!-- SECTION:PLAN:END -->
