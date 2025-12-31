---
id: task-401
title: Implement Cloud Firestore C++ module and GDScript integration
status: To Do
assignee: []
created_date: '2025-12-30 21:26'
updated_date: '2025-12-31 11:53'
labels:
  - firebase
  - firestore
  - cpp
  - gdscript
  - testing
dependencies:
  - task-403
  - task-399
  - task-406
priority: high
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

- [ ] #13 #13 Firestore library existence verified in Firebase C++ SDK before implementation begins
- [ ] #14 #14 Query params schema explicitly defined and documented
- [ ] #15 #15 Subcollection/nested document paths supported (e.g., users/uid/posts/postId)
- [ ] #16 #16 Offline persistence explicitly configured (enabled with size limits OR disabled)
- [ ] #17 #17 Thread-safe singleton pattern matching database.h
- [ ] #18 #18 Shutdown safety with is_shutting_down flag
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan (Based on quickstart-cpp Analysis)

### Key Discovery: Firestore REQUIRES Auth
From firestore/testapp/src/common_main.cc:
```cpp
// Sign in first!
auth->SignInAnonymously();
// Then initialize Firestore
firebase::firestore::Firestore* firestore = Firestore::GetInstance(app, &result);
```

Firestore security rules require authenticated user. **MUST complete task-399 first.**

### Pre-Implementation: Verify Library Exists
```bash
# Check if Firestore library is linked
ls firebase/firebase_cpp_sdk/libs/android/arm64-v8a/ | grep -i firestore
ls firebase/firebase_cpp_sdk/libs/ios/ | grep -i firestore
```

If NOT found, this task becomes:
1. Research Firestore C++ SDK availability
2. Potentially upgrade Firebase SDK
3. Re-scope implementation approach

### Phase 1: C++ Module (firestore.h/cpp)

**Headers Required:**
```cpp
#include "firebase/firestore.h"
// Includes: Firestore, CollectionReference, DocumentReference, 
// Query, WriteBatch, Transaction, FieldValue, MapFieldValue,
// DocumentSnapshot, QuerySnapshot, ListenerRegistration
```

**Initialization (after Auth):**
```cpp
static std::mutex initialization_mutex;
static std::atomic<bool> inited{false};
static std::atomic<bool> is_shutting_down{false};
static firebase::firestore::Firestore* firestore{nullptr};

void FirebaseFirestore::initialize() {
    std::lock_guard<std::mutex> lock(initialization_mutex);
    if (inited) return;
    
    // Verify user is authenticated
    firebase::auth::Auth* auth = firebase::auth::Auth::GetAuth(Firebase::AppId());
    if (!auth->current_user().is_valid()) {
        print_error("[Firestore] Cannot initialize - user not authenticated");
        return;
    }
    
    firebase::InitResult result;
    firestore = firebase::firestore::Firestore::GetInstance(Firebase::AppId(), &result);
    if (result == firebase::kInitResultSuccess) {
        firestore->set_log_level(firebase::kLogLevelDebug);
        inited = true;
    }
}
```

### Phase 2: Document Operations

**Methods to Expose:**
```cpp
// Document CRUD
void get_document_async(int request_id, Array path);      // ["users", "user123"]
void set_document_async(int request_id, Array path, Dictionary data);
void update_document_async(int request_id, Array path, Dictionary data);
void delete_document_async(int request_id, Array path);

// Collection queries
void query_collection_async(int request_id, String collection, Dictionary query_params);

// Batch writes
int start_batch();
void batch_set(int batch_id, Array path, Dictionary data);
void batch_update(int batch_id, Array path, Dictionary data);
void batch_delete(int batch_id, Array path);
void commit_batch_async(int request_id, int batch_id);
```

**Type Conversion (extend convertor.cpp):**
```cpp
// GDScript Dictionary → Firestore MapFieldValue
firebase::firestore::MapFieldValue toFirestoreMap(const Dictionary& dict) {
    firebase::firestore::MapFieldValue result;
    for (const auto& key : dict.keys()) {
        result[key.operator String().utf8().get_data()] = toFieldValue(dict[key]);
    }
    return result;
}

firebase::firestore::FieldValue toFieldValue(const Variant& v) {
    switch (v.get_type()) {
        case Variant::STRING: return FieldValue::String(v.operator String().utf8().get_data());
        case Variant::INT: return FieldValue::Integer(v.operator int64_t());
        case Variant::FLOAT: return FieldValue::Double(v.operator double());
        case Variant::BOOL: return FieldValue::Boolean(v.operator bool());
        case Variant::DICTIONARY: return FieldValue::Map(toFirestoreMap(v));
        case Variant::ARRAY: return FieldValue::Array(toFirestoreArray(v));
        // ... null, timestamp, geopoint
    }
}
```

### Phase 3: Query Builder

```cpp
// Query methods chained in GDScript, executed as Dictionary
// query_params: {
//   "where": [{"field": "score", "op": ">", "value": 100}],
//   "order_by": [{"field": "score", "direction": "desc"}],
//   "limit": 10
// }

void FirebaseFirestore::query_collection_async(int request_id, String collection, Dictionary query_params) {
    firebase::firestore::Query query = firestore->Collection(collection.utf8().get_data());
    
    // Apply where clauses
    Array wheres = query_params.get("where", Array());
    for (int i = 0; i < wheres.size(); i++) {
        Dictionary clause = wheres[i];
        String field = clause["field"];
        String op = clause["op"];
        Variant value = clause["value"];
        
        if (op == "==") query = query.WhereEqualTo(field.utf8().get_data(), toFieldValue(value));
        else if (op == ">") query = query.WhereGreaterThan(field.utf8().get_data(), toFieldValue(value));
        // ... other operators
    }
    
    // Execute query...
}
```

### Phase 4: Real-Time Listeners

```cpp
// Listener management
int add_document_listener(Array path);
int add_collection_listener(String collection, Dictionary query_params);
void remove_listener(int listener_id);

// Internal tracking
std::map<int, firebase::firestore::ListenerRegistration> active_listeners;
```

### Phase 5: GDScript Service

```gdscript
class_name FirestoreService extends Node

signal document_result(request_id: int, success: bool, data: Dictionary, error: String)
signal query_result(request_id: int, success: bool, documents: Array, error: String)
signal document_changed(listener_id: int, document: Dictionary)

var _native: FirebaseFirestore

func get_document(path: Array) -> Dictionary:
    var request = FirebaseRequest.new(_request_id_counter)
    _native.get_document_async(request.request_id, path)
    return await request.completed

func set_document(path: Array, data: Dictionary) -> Dictionary:
    var request = FirebaseRequest.new(_request_id_counter)
    _native.set_document_async(request.request_id, path, data)
    return await request.completed
```

### Complexity Assessment
This is the MOST COMPLEX task:
- New C++ module from scratch
- Complex type conversion (nested maps, arrays, timestamps, geopoints)
- Query builder with multiple operators
- Real-time listeners with lifecycle management
- Batch writes and transactions
- Depends on Auth being complete

### Recommended: Staged Implementation
1. **v1**: Basic CRUD (get, set, update, delete)
2. **v2**: Simple queries (where, limit)
3. **v3**: Real-time listeners
4. **v4**: Batch writes, transactions

Start with v1, validate on all platforms, then expand.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## CTO Review Notes (2025-12-31)

### HIGHEST RISK TASK - Extra Scrutiny Required

This is the most complex task in the epic. It creates a NEW C++ module from scratch.

### Critical Pre-Implementation Verification

**1. Verify Firestore Library Exists**
Before writing any code:
```bash
# Check if libfirebase_firestore exists in our SDK
ls -la firebase/firebase_cpp_sdk/libs/android/arm64-v8a/ | grep firestore
ls -la firebase/firebase_cpp_sdk/libs/ios/device-arm64/ | grep firestore
ls -la firebase/firebase_cpp_sdk/libs/macos/universal/ | grep firestore
ls -la firebase/firebase_cpp_sdk/libs/windows/VS2019/MT/x64/Release/ | grep firestore
```
If missing, need to download updated SDK or reconsider scope.

**2. Query Params Schema Must Be Explicit**
The plan shows `Dictionary query_params` but doesn't define schema. Document explicitly:
```cpp
// query_params schema:
// {
//   "where": [{"field": "status", "op": "==", "value": "active"}],
//   "order_by": "created_at",
//   "order_direction": "desc",  // or "asc"
//   "limit": 10,
//   "start_after": "document_id"  // for pagination
// }
//
// Supported operators: "==", "!=", "<", "<=", ">", ">=", "array-contains", "in"
```

**3. Subcollection Paths Not Handled**
Firestore paths can be nested: `users/uid/posts/postId`. Current plan only shows:
```cpp
firestore_instance->Collection(collection).Document(document_id);
```
Need path parser:
```cpp
firebase::firestore::DocumentReference parse_document_path(const String& path) {
    // Parse "users/abc123/posts/post456" into proper reference chain
    PackedStringArray parts = path.split("/");
    // Alternate Collection/Document calls
}
```

**4. Offline Persistence Decision Required**
Firestore has offline persistence by default on mobile. This causes:
- Stale data reads (cache vs server)
- Pending writes queue growing
- Disk usage growth

Must explicitly decide:
```cpp
firebase::firestore::Settings settings;
settings.set_persistence_enabled(false);  // Simpler, no cache issues
// OR
settings.set_persistence_enabled(true);
settings.set_cache_size_bytes(10 * 1024 * 1024);  // 10MB limit
firestore_instance->set_settings(settings);
```

**5. Transaction Support (Defer to v2)**
Firestore transactions are critical for data consistency but complex. Recommend:
- v1: CRUD operations only
- v2: Add transaction support

Document this explicitly in acceptance criteria.

### Risk Mitigation

1. **Implement in phases**: Get document CRUD working first, then queries
2. **Test heavily on Android first**: Most complex platform
3. **Consider Cloud Functions proxy**: If C++ complexity is too high, use Functions as intermediary

## Revised Scope (2025-12-31)

### CRITICAL: Firestore Library Status UNKNOWN

Unlike Analytics (which is linked), Firestore was NOT found in the SCsub exploration. **Before implementing, MUST verify:**

```bash
# Run these commands to check Firestore library existence
ls -la firebase/firebase_cpp_sdk/libs/android/arm64-v8a/ | grep -i firestore
ls -la firebase/firebase_cpp_sdk/libs/ios/device-arm64/ | grep -i firestore
ls -la firebase/firebase_cpp_sdk/libs/macos/universal/ | grep -i firestore
ls -la firebase/firebase_cpp_sdk/libs/windows/VS2019/MT/x64/Release/ | grep -i firestore
```

### If Firestore Library EXISTS:
1. Add library linking to SCsub (copy pattern from database)
2. Proceed with C++ implementation
3. Follow database.h patterns exactly

### If Firestore Library MISSING:
Options:
1. **Download newer Firebase C++ SDK** that includes Firestore
2. **Use Cloud Functions as proxy** - GDScript calls Function, Function accesses Firestore
3. **Defer task** until SDK is updated

### Why Firestore is Highest Risk:
1. **New C++ module from scratch** (unlike Auth/Remote Config which exist)
2. **Complex data model** (documents, collections, subcollections)
3. **Query system** needs careful design
4. **Offline persistence** adds complexity
5. **Library may not exist** in current SDK

### Recommended Approach:
1. **First**: Verify library existence (blocking check)
2. **Second**: Complete task-399 (Auth) and task-400 (Remote Config) first
3. **Third**: Implement Firestore last with full database.h patterns

### Existing Patterns to Leverage:
From `database.cpp` (51KB reference implementation):
- Thread-safe singleton: lines 88-120
- MessageQueue marshalling: lines 404-453
- Main thread handlers: lines 814-862
- Type conversion: `convertor.cpp`
- Signal structure: 14+ signals defined

### Firestore-Specific Considerations:
1. **Document paths** can be nested (users/uid/posts/postId)
2. **Queries** more complex than RTDB (where, orderBy, startAt, etc.)
3. **Offline persistence** enabled by default on mobile
4. **Transactions** needed for atomic operations
5. **Batch writes** for multiple document updates
<!-- SECTION:NOTES:END -->
