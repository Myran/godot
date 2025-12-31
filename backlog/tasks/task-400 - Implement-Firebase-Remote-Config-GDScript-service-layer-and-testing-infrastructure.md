---
id: task-400
title: >-
  Implement Firebase Remote Config GDScript service layer and testing
  infrastructure
status: To Do
assignee: []
created_date: '2025-12-30 21:26'
updated_date: '2025-12-30 22:43'
labels:
  - firebase
  - remote-config
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

Implement complete Firebase Remote Config integration following the established RTDB architecture patterns. The C++ remote_config.h may exist but needs full GDScript service layer, backend abstraction, and comprehensive testing.

## Architecture Reference

Follow the 3-layer pattern from RTDB:
1. **C++ Module Layer** - `godot/modules/firebase/remote_config.h/cpp` (verify/enhance)
2. **GDScript Service Layer** - `project/firebase/remote_config_service.gd` (NEW)
3. **Backend Abstraction** - `project/data/backends/remote_config_backend.gd` (NEW)

## Implementation Scope

### GDScript Service Layer (`project/firebase/remote_config_service.gd`)
- RemoteConfigService class wrapping C++ FirebaseRemoteConfig
- Async fetch and activate pattern
- Value retrieval: `get_string()`, `get_int()`, `get_bool()`, `get_float()`, `get_json()`
- Default value support with fallbacks
- Cache management with fetch intervals
- Signals: `config_fetched`, `config_activated`, `fetch_failed`

### Backend Abstraction (`project/data/backends/remote_config_backend.gd`)
- RemoteConfigBackend class for unified config access
- Feature flag helper methods
- A/B test variant support

### Debug Actions (`project/debug/actions/firebase_remote_config/`)
- `remote_config_fetch_test_action.gd` - Fetch config from Firebase
- `remote_config_activate_test_action.gd` - Activate fetched config
- `remote_config_get_values_test_action.gd` - Retrieve typed values
- `remote_config_defaults_test_action.gd` - Default value fallback
- `remote_config_error_handling_test_action.gd` - Error scenarios

### Test Configurations (`tests/debug_configs/`)
- `firebase-remote-config-layer.json` - All remote config tests
- `firebase-remote-config-fetch.json` - Fetch/activate cycle
- `firebase-remote-config-values.json` - Value retrieval tests

## Reference Files
- `godot/modules/firebase/database.cpp` - C++ async pattern
- `project/firebase/database_service.gd` - GDScript service pattern
- `project/data/backends/firebase_service_backend.gd` - Backend pattern

## Notes
- Remote Config is ideal for feature flags, A/B testing, and dynamic configuration
- Fetch intervals should respect Firebase quotas (12-hour minimum for production)
- Consider developer mode with shorter fetch intervals for testing
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 RemoteConfigService class implemented with async fetch/activate pattern
- [ ] #2 Value retrieval works for all types: string, int, bool, float, JSON
- [ ] #3 Default values properly used as fallbacks when config unavailable
- [ ] #4 Fetch interval respects Firebase quotas
- [ ] #5 Config activation signals propagate correctly
- [ ] #6 RemoteConfigBackend provides feature flag helpers
- [ ] #7 5+ debug actions covering fetch, activate, values, defaults, errors
- [ ] #8 Test configurations for all platforms (Android, iOS, macOS, Windows)
- [ ] #9 Cross-platform testing passes on at least Android and desktop
- [ ] #10 Error handling tests validate throttling and network errors
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan - Firebase Remote Config

### Phase 1: C++ Layer Enhancement (remote_config.h/cpp)

**Current State Analysis:**
- Basic implementation exists with: set_defaults, get_boolean/double/int/string, loaded, set_instant_fetching
- FetchAndActivate with OnCompletion callback exists
- **Missing**: Thread-safe singleton, request IDs, real-time config update listener, manual fetch/activate separation

**1.1 Add Thread-Safe Singleton Pattern (Follow database.h)**
```cpp
// remote_config.h additions
private:
    static std::mutex initialization_mutex;
    static std::atomic<bool> inited;
    static FirebaseRemoteConfig* singleton_instance;
    static std::mutex instance_mutex;
    static std::atomic<bool> is_shutting_down;

public:
    static FirebaseRemoteConfig& get_instance();
    static void cleanup();
    static void begin_shutdown();
    static bool is_app_shutting_down();
```

**1.2 Add Separate Fetch and Activate Methods**
```cpp
// Firebase SDK pattern from documentation
void fetch_async(int p_request_id);
void activate_async(int p_request_id);
void fetch_and_activate_async(int p_request_id);

// Implementation pattern:
void FirebaseRemoteConfig::fetch_async(int p_request_id) {
    firebase::Future<void> future = rc->Fetch();
    future.OnCompletion([this, p_request_id](const firebase::Future<void>& result) {
        bool success = (result.status() == firebase::kFutureStatusComplete &&
                       result.error() == 0);
        MessageQueue::get_singleton()->push_callable(
            callable_mp(this, &FirebaseRemoteConfig::_handle_fetch_on_main_thread)
                .bind(p_request_id, success, result.error(), String(result.error_message()))
        );
    });
}
```

**1.3 Add Real-Time Config Update Listener (v11.0.0+ feature)**
```cpp
// Firebase SDK pattern from documentation
void add_config_update_listener();

// Implementation:
rc->AddOnConfigUpdateListener(
    [this](firebase::remote_config::ConfigUpdate& config_update,
           firebase::remote_config::RemoteConfigError error) {
        if (error != firebase::remote_config::kRemoteConfigErrorNone) {
            // Handle error
            return;
        }
        // Convert updated_keys to Godot Array
        Array updated_keys;
        for (const std::string& key : config_update.updated_keys) {
            updated_keys.append(String(key.c_str()));
        }
        // Marshal to main thread
        MessageQueue::get_singleton()->push_callable(
            callable_mp(this, &FirebaseRemoteConfig::_handle_config_update_on_main_thread)
                .bind(updated_keys)
        );
    });
```

**1.4 Add Main Thread Callback Handlers**
```cpp
void _handle_fetch_on_main_thread(int req_id, bool success, int error, String error_msg);
void _handle_activate_on_main_thread(int req_id, bool success, int error, String error_msg);
void _handle_config_update_on_main_thread(Array updated_keys);
```

**1.5 Add JSON Value Retrieval**
```cpp
Dictionary get_json(const String& param);  // Parse JSON string to Dictionary
Array get_keys();  // Get all available config keys
```

**1.6 Update Signal Bindings**
```cpp
ADD_SIGNAL(MethodInfo("fetch_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "error_message")));
ADD_SIGNAL(MethodInfo("activate_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "error_message")));
ADD_SIGNAL(MethodInfo("config_updated", PropertyInfo(Variant::ARRAY, "updated_keys")));
```

### Phase 2: GDScript Service Layer

**2.1 Create remote_config_service.gd**
```gdscript
class_name RemoteConfigService
extends RefCounted

signal config_fetched(success: bool)
signal config_activated(success: bool)
signal config_updated(updated_keys: Array)

var _firebase_service: Node
var _cpp_remote_config: Object
var _request_id_counter: int = 0
var _is_initialized: bool = false

func _init(firebase_service: Node) -> void:
    _firebase_service = firebase_service
    _initialize_cpp_remote_config()

func fetch_and_activate() -> bool:
    var request_id = _get_next_request_id()
    _cpp_remote_config.fetch_and_activate_async(request_id)
    var result = await _cpp_remote_config.loaded
    return true

func fetch() -> bool:
    var request_id = _get_next_request_id()
    _cpp_remote_config.fetch_async(request_id)
    var result = await _cpp_remote_config.fetch_completed
    return result[1]  # success

func activate() -> bool:
    var request_id = _get_next_request_id()
    _cpp_remote_config.activate_async(request_id)
    var result = await _cpp_remote_config.activate_completed
    return result[1]  # success

func get_string(key: String, default_value: String = "") -> String:
    if not _cpp_remote_config.loaded():
        return default_value
    return _cpp_remote_config.get_string(key)

func get_int(key: String, default_value: int = 0) -> int:
    if not _cpp_remote_config.loaded():
        return default_value
    return _cpp_remote_config.get_int(key)

func get_bool(key: String, default_value: bool = false) -> bool:
    if not _cpp_remote_config.loaded():
        return default_value
    return _cpp_remote_config.get_boolean(key)

func get_float(key: String, default_value: float = 0.0) -> float:
    if not _cpp_remote_config.loaded():
        return default_value
    return _cpp_remote_config.get_double(key)
```

**2.2 Create remote_config_backend.gd**
```gdscript
class_name RemoteConfigBackend
extends RefCounted

var _remote_config_service: RemoteConfigService

func _init(firebase_service: Node) -> void:
    _remote_config_service = RemoteConfigService.new(firebase_service)

func get_feature_flag(flag_name: String, default_value: bool = false) -> bool:
    return _remote_config_service.get_bool(flag_name, default_value)

func get_experiment_variant(experiment_name: String, default_variant: String = "control") -> String:
    return _remote_config_service.get_string(experiment_name, default_variant)
```

### Phase 3: Debug Actions

**3.1 Create project/debug/actions/firebase_remote_config/**
- `remote_config_fetch_test_action.gd` - Test fetch from Firebase
- `remote_config_activate_test_action.gd` - Test activate fetched config
- `remote_config_get_values_test_action.gd` - Test all type getters
- `remote_config_defaults_test_action.gd` - Test default value fallback
- `remote_config_error_handling_test_action.gd` - Test throttling, network errors

### Phase 4: Test Configurations

**4.1 Create tests/debug_configs/**
- `firebase-remote-config-layer.json` - All remote config tests
- `firebase-remote-config-fetch.json` - Fetch/activate cycle tests
- `firebase-remote-config-values.json` - Value retrieval tests

### Key Reference Files
- `godot/modules/firebase/remote_config.cpp:27-53` - Existing FetchAndActivate pattern
- `godot/modules/firebase/database.cpp:216-253` - Thread-safe singleton pattern
- `godot/modules/firebase/database.cpp:448-452` - MessageQueue marshalling
<!-- SECTION:PLAN:END -->
