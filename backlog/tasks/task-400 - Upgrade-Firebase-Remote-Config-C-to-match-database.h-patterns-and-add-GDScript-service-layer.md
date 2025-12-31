---
id: task-400
title: >-
  Upgrade Firebase Remote Config C++ to match database.h patterns and add
  GDScript service layer
status: To Do
assignee: []
created_date: '2025-12-30 21:26'
updated_date: '2025-12-31 11:53'
labels:
  - firebase
  - remote-config
  - gdscript
  - testing
dependencies:
  - task-403
  - task-399
  - task-406
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Overview

**UPGRADE existing remote_config.cpp** to match the production-grade patterns in database.cpp, then add a proper GDScript service layer. The C++ module already exists with working value retrieval - it needs pattern upgrades, NOT rewriting.

## Existing Implementation Analysis

### What Already Works (remote_config.cpp - 5.3KB, 112 lines):
- ✅ `set_defaults(const Dictionary& params)` - Set default config values
- ✅ `get_boolean(const String& param)` - Get boolean config
- ✅ `get_double(const String& param)` - Get double config
- ✅ `get_int(const String& param)` - Get int64_t config
- ✅ `get_string(const String& param)` - Get string config
- ✅ `loaded()` - Check if config loaded
- ✅ `set_instant_fetching()` - Set fetch interval to 0 for testing
- ✅ `FetchAndActivate` with OnCompletion callback
- ✅ Signal: `loaded`

### What's Missing (must add from database.h pattern):
- ❌ Thread-safe singleton with `std::mutex` and `std::atomic`
- ❌ Request ID tracking
- ❌ Separate `fetch_async()` and `activate_async()` methods
- ❌ `get_json()` for Dictionary values
- ❌ `get_keys()` to list all config keys
- ❌ Error signal for fetch failures
- ❌ Shutdown safety with `is_shutting_down` flag

### GDScript Layer (does not exist yet):
- ❌ No `remote_config_service.gd`
- ❌ No backend abstraction

## Architecture Reference

Follow the 3-layer pattern from RTDB:
1. **C++ Module Layer** - `godot/modules/firebase/remote_config.h/cpp` (UPGRADE existing)
2. **GDScript Service Layer** - `project/firebase/remote_config_service.gd` (NEW)
3. **Backend Abstraction** - Integrate with `firebase_service.gd` (EXTEND)

## Implementation Approach: UPGRADE, NOT REWRITE

### Phase 1: Add Thread-Safe Singleton to Existing remote_config.h
```cpp
// ADD to existing remote_config.h - don't replace file
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
```

### Phase 2: Add Request ID Tracking
```cpp
// ADD new async methods with request IDs
void fetch_async(int p_request_id);
void activate_async(int p_request_id);
void fetch_and_activate_async(int p_request_id);  // Keep existing behavior
```

### Phase 3: Add MessageQueue Marshalling
```cpp
// MODIFY existing FetchAndActivate callback
rc->FetchAndActivate().OnCompletion([this, p_request_id](const firebase::Future<bool>& future) {
    bool success = (future.status() == firebase::kFutureStatusComplete);
    
    // Marshal to main thread (NEW)
    MessageQueue::get_singleton()->push_callable(
        callable_mp(this, &FirebaseRemoteConfig::_handle_fetch_on_main_thread)
            .bind(p_request_id, success, future.error(), String(future.error_message()))
    );
});
```

### Phase 4: Add New Signals
```cpp
ADD_SIGNAL(MethodInfo("fetch_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "error_message")));
ADD_SIGNAL(MethodInfo("activate_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::BOOL, "success")));
```

### Phase 5: Create GDScript Service Layer
- Use `FirebaseRequest` pattern from `firebase_request.gd`
- Add fetch throttling (12-hour minimum in production)
- Integrate with `firebase_service.gd`

## Reference Files (MUST READ BEFORE IMPLEMENTING)
- `godot/modules/firebase/remote_config.cpp` - Existing implementation
- `godot/modules/firebase/database.cpp:88-120` - Thread-safe singleton pattern
- `godot/modules/firebase/database.cpp:404-453` - MessageQueue marshalling
- `project/firebase/firebase_request.gd` - Async request pattern
- `project/firebase/database_service.gd` - Service layer pattern

## Critical: Preserve Existing Functionality
The current remote_config.cpp works for basic fetch and value retrieval. Changes must:
1. Preserve all existing method signatures
2. Keep `loaded` signal working (add new signals alongside)
3. Maintain backward compatibility with any existing usage
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

- [ ] #11 #11 Thread-safe singleton pattern matching database.h with std::mutex and std::atomic
- [ ] #12 #12 Shutdown safety with is_shutting_down flag preventing callbacks during cleanup
- [ ] #13 #13 Fetch interval throttling enforced (12-hour minimum in production, configurable for dev)
- [ ] #14 #14 SDK version verified to support real-time config listener (v11.0.0+ required, or feature removed)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan (Based on quickstart-cpp Analysis)

### Key Discovery: Missing Useful Methods
Our remote_config.cpp has basics but is missing key features and thread safety.

### Current State Analysis (remote_config.cpp)
**What We Have:**
- ✅ GetInstance()
- ✅ SetDefaults() with ConfigKeyValueVariant
- ✅ FetchAndActivate() (combined)
- ✅ GetBoolean(), GetDouble(), GetLong(), GetString()
- ✅ SetConfigSettings() for fetch interval
- ✅ "loaded" signal

**What's Missing (from quickstart):**
- ❌ **Fetch()** - Fetch without activate (for staged rollouts)
- ❌ **Activate()** - Activate without fetch
- ❌ **GetKeys()** - List all config keys
- ❌ **GetKeysByPrefix()** - Filter keys by prefix
- ❌ **GetInfo()** - Fetch status/timing info
- ❌ **GetData()** - Binary data retrieval
- ❌ Thread-safe singleton
- ❌ Proper shutdown handling

**Thread Safety Issues:**
```cpp
// Current (unsafe):
bool FirebaseRemoteConfig::inited = false;
bool FirebaseRemoteConfig::data_loaded = false;
void* FirebaseRemoteConfig::user_data;  // Dangerous!
firebase::remote_config::RemoteConfig *rc = nullptr;  // Global!
```

### Phase 1: Add Thread Safety

```cpp
// Replace with:
static std::mutex initialization_mutex;
static std::atomic<bool> inited{false};
static std::atomic<bool> data_loaded{false};
static std::atomic<bool> is_shutting_down{false};
static firebase::remote_config::RemoteConfig* rc{nullptr};
static FirebaseRemoteConfig* singleton_instance{nullptr};
```

### Phase 2: Add Missing Methods

**Separate Fetch/Activate:**
```cpp
void FirebaseRemoteConfig::fetch_async(int request_id, int cache_expiration_seconds) {
    auto future = rc->Fetch(cache_expiration_seconds);
    future.OnCompletion([request_id](const auto& future, void* data) {
        // Marshal to main thread
        // Emit fetch_complete signal
    }, this);
}

void FirebaseRemoteConfig::activate_async(int request_id) {
    auto future = rc->Activate();
    future.OnCompletion([request_id](const auto& future, void* data) {
        // Marshal to main thread
        // Emit activate_complete signal
    }, this);
}
```

**Key Enumeration:**
```cpp
Array FirebaseRemoteConfig::get_keys() {
    Array result;
    std::vector<std::string> keys = rc->GetKeys();
    for (const auto& key : keys) {
        result.append(String(key.c_str()));
    }
    return result;
}

Array FirebaseRemoteConfig::get_keys_by_prefix(String prefix) {
    Array result;
    std::vector<std::string> keys = rc->GetKeysByPrefix(prefix.utf8().get_data());
    for (const auto& key : keys) {
        result.append(String(key.c_str()));
    }
    return result;
}
```

**Fetch Info:**
```cpp
Dictionary FirebaseRemoteConfig::get_fetch_info() {
    Dictionary info;
    const auto& rc_info = rc->GetInfo();
    info["fetch_time"] = rc_info.fetch_time;
    info["last_fetch_status"] = rc_info.last_fetch_status;
    info["failure_reason"] = rc_info.last_fetch_failure_reason;
    info["throttled_end_time"] = rc_info.throttled_end_time;
    return info;
}
```

### Phase 3: GDScript Service

```gdscript
class_name RemoteConfigService extends Node

signal config_loaded
signal config_error(message: String)

var _native: FirebaseRemoteConfig

func get_feature_flag(key: String, default: bool = false) -> bool:
    if not _native.loaded():
        return default
    return _native.get_boolean(key)

func get_string(key: String, default: String = "") -> String:
    if not _native.loaded():
        return default
    return _native.get_string(key)
```

### Phase 4: New Signals
```cpp
ADD_SIGNAL(MethodInfo("fetch_complete", PropertyInfo(Variant::INT, "request_id"),
                      PropertyInfo(Variant::BOOL, "success")));
ADD_SIGNAL(MethodInfo("activate_complete", PropertyInfo(Variant::INT, "request_id"),
                      PropertyInfo(Variant::BOOL, "activated")));
```

### Use Cases Enabled
1. **Staged Rollouts**: Fetch during loading screen, activate on restart
2. **Feature Discovery**: GetKeys() to find available features
3. **Debugging**: GetInfo() to check throttling/errors
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## CTO Review Notes (2025-12-31)

### Critical Corrections Required

**1. Existing C++ Lacks Thread-Safe Singleton**
Current remote_config.h uses simple `static bool inited` which is NOT thread-safe. Must upgrade to match database.h pattern:
```cpp
static std::mutex initialization_mutex;
static std::atomic<bool> inited;
static FirebaseRemoteConfig* singleton_instance;
static std::mutex instance_mutex;
static std::atomic<bool> is_shutting_down;
```

**2. Real-Time Config Listener SDK Version**
`AddOnConfigUpdateListener` requires Firebase C++ SDK 11.0.0+. Before implementing:
```bash
# Verify SDK version in firebase_cpp_sdk
cat firebase/firebase_cpp_sdk/readme.md | head -20
```
If SDK is older, either upgrade or remove real-time listener from scope.

**3. Fetch Interval Enforcement Required**
Firebase throttles fetches. Must enforce client-side:
```gdscript
var _last_fetch_time: int = 0
const MIN_FETCH_INTERVAL_MS: int = 43200000  # 12 hours production
const DEV_FETCH_INTERVAL_MS: int = 60000     # 1 minute dev mode

func fetch() -> bool:
    var interval = DEV_FETCH_INTERVAL_MS if OS.is_debug_build() else MIN_FETCH_INTERVAL_MS
    var now = Time.get_ticks_msec()
    if now - _last_fetch_time < interval:
        push_warning("Remote Config fetch throttled")
        return false
    _last_fetch_time = now
    # ... proceed with fetch
```

### Implementation Simplification
Consider removing real-time config listener from initial scope. Remote Config typical usage:
1. Fetch on app start
2. Activate
3. Use values

Real-time updates add complexity without clear benefit for a game. Can be added in v2 if needed.

## Revised Scope (2025-12-31)

### Key Discovery: Remote Config C++ Already Exists!

Exploration revealed that `remote_config.cpp` (5.3KB, 112 lines) already has:
- All value retrieval methods (boolean, double, int, string)
- FetchAndActivate with callback
- Default value setting
- Loaded check

### What's Actually Needed:

**C++ Upgrade (not rewriting):**
1. Add thread-safe singleton pattern (copy from database.h)
2. Add request ID parameter to FetchAndActivate
3. Add separate `fetch_async()` and `activate_async()` methods
4. Add `get_json()` for Dictionary parsing
5. Add `get_keys()` to enumerate config
6. Add MessageQueue marshalling
7. Add error signals

**GDScript Creation:**
1. Create `remote_config_service.gd` using `FirebaseRequest` pattern
2. Add fetch throttling enforcement
3. Extend `firebase_service.gd` to expose service

### Risk Reduction:
- **Before**: Estimated as "new implementation" - MEDIUM risk
- **After**: Upgrade existing working code - LOW risk
- Existing FetchAndActivate MUST keep working

### SDK Version Consideration:
Real-time config listener (`AddOnConfigUpdateListener`) requires Firebase C++ SDK 11.0.0+. Check SDK version before implementing this feature - may need to defer to v2.

### Files to Modify:
- `godot/modules/firebase/remote_config.h` - Add singleton, new methods
- `godot/modules/firebase/remote_config.cpp` - Add MessageQueue, new implementations
- `project/firebase/firebase_service.gd` - Add remote config service accessor

### Files to Create:
- `project/firebase/remote_config_service.gd` - New service layer
- Debug actions in `project/debug/actions/firebase_remote_config/`
- Test configs in `tests/debug_configs/`
<!-- SECTION:NOTES:END -->
