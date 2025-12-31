---
id: task-402
title: >-
  Implement Firebase Analytics C++ module (library already linked) and GDScript
  integration
status: To Do
assignee: []
created_date: '2025-12-30 21:26'
updated_date: '2025-12-31 11:53'
labels:
  - firebase
  - analytics
  - cpp
  - gdscript
  - testing
dependencies:
  - task-403
  - task-406
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Overview

Implement complete Firebase Analytics (Google Analytics for Firebase) integration following the established RTDB architecture patterns. Analytics is simpler than other Firebase services as it's primarily fire-and-forget.

## Architecture Reference

Follow the 3-layer pattern from RTDB:
1. **C++ Module Layer** - `godot/modules/firebase/analytics.h/cpp` (NEW)
2. **GDScript Service Layer** - `project/firebase/analytics_service.gd` (NEW)
3. **Backend Abstraction** - `project/data/backends/analytics_backend.gd` (NEW)

## Implementation Scope

### C++ Module Layer (`godot/modules/firebase/analytics.h/cpp`)
Analytics is simpler - mostly synchronous fire-and-forget calls:
- Thread-safe singleton with std::mutex
- Most operations don't need async callbacks
- Type conversion for event parameters

**Core Methods:**
- `log_event(event_name, parameters_dictionary)` - Log custom event
- `set_user_property(property_name, value)` - Set user property
- `set_user_id(user_id)` - Set user ID for cross-device tracking
- `set_analytics_collection_enabled(enabled)` - Enable/disable collection
- `reset_analytics_data()` - Clear analytics data

**Predefined Event Helpers:**
- `log_level_start(level_name)` - Game level started
- `log_level_end(level_name, success)` - Game level completed
- `log_tutorial_begin()` / `log_tutorial_complete()` - Tutorial tracking
- `log_purchase(item_id, item_name, value, currency)` - In-app purchase
- `log_screen_view(screen_name)` - Screen view tracking

### GDScript Service Layer (`project/firebase/analytics_service.gd`)
- AnalyticsService class wrapping C++ FirebaseAnalytics
- Event parameter validation
- Convenient wrappers for common game events
- Session tracking helpers
- No async needed (fire-and-forget)

### Backend Abstraction (`project/data/backends/analytics_backend.gd`)
- AnalyticsBackend class for unified analytics access
- Game-specific event helpers (battle started, card played, etc.)
- User journey tracking

### Debug Actions (`project/debug/actions/firebase_analytics/`)
- `analytics_log_event_test_action.gd` - Custom event logging
- `analytics_user_property_test_action.gd` - User property setting
- `analytics_predefined_events_test_action.gd` - Predefined event helpers
- `analytics_collection_toggle_test_action.gd` - Enable/disable collection
- `analytics_game_events_test_action.gd` - Game-specific events

### Test Configurations (`tests/debug_configs/`)
- `firebase-analytics-layer.json` - All analytics tests
- `firebase-analytics-events.json` - Event logging tests
- `firebase-analytics-user.json` - User property tests

## Reference Files
- `godot/modules/firebase/database.h/cpp` - C++ singleton pattern
- `godot/modules/firebase/convertor.cpp` - Type conversion
- `project/firebase/database_service.gd` - GDScript service pattern

## Notes
- Analytics is fire-and-forget, no async callbacks needed
- Events are batched by Firebase SDK automatically
- Consider GDPR/privacy controls (collection toggle)
- Debug mode for DebugView in Firebase Console
- Event names must be alphanumeric with underscores (<=40 chars)
- Parameter names max 40 chars, string values max 100 chars
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 C++ FirebaseAnalytics class with thread-safe singleton pattern
- [ ] #2 Event logging works with custom parameters
- [ ] #3 User property setting works correctly
- [ ] #4 User ID tracking for cross-device analytics
- [ ] #5 Predefined event helpers for common game events
- [ ] #6 Analytics collection toggle for privacy controls
- [ ] #7 AnalyticsService GDScript wrapper with validation
- [ ] #8 AnalyticsBackend provides game-specific event helpers
- [ ] #9 5+ debug actions covering events, properties, predefined events
- [ ] #10 Test configurations for all platforms (Android, iOS, macOS, Windows)
- [ ] #11 Cross-platform testing passes on at least Android and desktop
- [ ] #12 Parameter validation follows Firebase naming rules

- [ ] #13 #13 C++ layer contains ONLY generic methods (log_event, set_user_property, set_user_id)
- [ ] #14 #14 Game-specific event helpers (battle_start, card_played) implemented in GDScript, NOT C++
- [ ] #15 #15 Debug mode for Firebase DebugView implemented (platform-specific flags)
- [ ] #16 #16 Thread-safe singleton pattern matching database.h
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan (Based on quickstart-cpp Analysis)

### Key Discovery: SIMPLEST IMPLEMENTATION
Analytics is **fire-and-forget** - NO async callbacks needed for event logging!
Only `GetAnalyticsInstanceId()` returns a Future.

### Phase 1: C++ Module (analytics.h/cpp)

**Headers Required:**
```cpp
#include "firebase/analytics.h"
#include "firebase/analytics/event_names.h"
#include "firebase/analytics/parameter_names.h"
#include "firebase/analytics/user_property_names.h"
```

**Initialization (copy from database.h pattern):**
```cpp
static std::mutex initialization_mutex;
static std::atomic<bool> inited{false};
static std::atomic<bool> is_shutting_down{false};

void FirebaseAnalytics::initialize() {
    std::lock_guard<std::mutex> lock(initialization_mutex);
    if (inited) return;
    
    firebase::App* app = Firebase::AppId();
    if (app) {
        firebase::analytics::Initialize(*app);
        firebase::analytics::SetAnalyticsCollectionEnabled(true);
        inited = true;
    }
}
```

**Methods to Expose (ALL synchronous except one!):**
```cpp
// Configuration
void set_user_id(String user_id);
void set_user_property(String name, String value);
void set_analytics_collection_enabled(bool enabled);
void set_session_timeout(int milliseconds);

// Event Logging (FIRE-AND-FORGET - no callbacks!)
void log_event(String event_name);
void log_event_string(String event_name, String param_name, String value);
void log_event_int(String event_name, String param_name, int value);
void log_event_float(String event_name, String param_name, float value);
void log_event_params(String event_name, Dictionary params);

// Only async method
void get_instance_id_async(int request_id);  // Emits signal with result
```

**Pre-defined Event Constants (expose as class constants):**
- `EVENT_LOGIN`, `EVENT_SIGN_UP`, `EVENT_LEVEL_UP`
- `EVENT_POST_SCORE`, `EVENT_JOIN_GROUP`, `EVENT_SCREEN_VIEW`
- `PARAM_SCORE`, `PARAM_LEVEL`, `PARAM_CHARACTER`

### Phase 2: GDScript Service

**Simple wrapper (no complex async handling needed):**
```gdscript
class_name AnalyticsService extends Node

var _native: FirebaseAnalytics

func log_event(event_name: String, params: Dictionary = {}) -> void:
    if params.is_empty():
        _native.log_event(event_name)
    else:
        _native.log_event_params(event_name, params)

func set_user_id(user_id: String) -> void:
    _native.set_user_id(user_id)
```

### Phase 3: Integration with Auth

When user signs in, call:
```gdscript
analytics_service.set_user_id(auth_service.get_uid())
```

### Why This is Simplest
1. No Future handling for 95% of operations
2. No callbacks needed
3. No request ID tracking
4. No rate limiting needed
5. Can test immediately after implementation
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## CTO Review Notes (2025-12-31)

### Lowest Risk Task - Good Starting Point

Analytics is the simplest service:
- Fire-and-forget (no async callbacks)
- No complex state management
- Immediate product value

### Critical Corrections

**1. Game-Specific Helpers Must Be in GDScript, NOT C++**

The implementation plan puts game logic in C++:
```cpp
// DON'T DO THIS IN C++
void log_battle_start(const String& battle_type, int player_level);
void log_card_played(const String& card_id, const String& card_name);
```

If game design changes, we must rebuild C++ templates. Instead:

**C++ (generic only):**
```cpp
void log_event(const String& event_name, const Dictionary& params);
void set_user_property(const String& name, const String& value);
void set_user_id(const String& user_id);
void set_analytics_collection_enabled(bool enabled);
void reset_analytics_data();
```

**GDScript (game-specific):**
```gdscript
# analytics_service.gd
func track_battle_start(battle_type: String, level: int) -> void:
    _log_event("battle_start", {"type": battle_type, "level": level})

func track_card_played(card: Card) -> void:
    _log_event("card_played", {"id": card.id, "name": card.display_name})
```

**2. Debug Mode for DebugView**

Firebase DebugView requires platform-specific flags. Add:
```cpp
void set_debug_mode(bool enabled);

// Platform-specific implementation:
#if defined(__ANDROID__)
    // Requires: adb shell setprop debug.firebase.analytics.app <package_name>
    // Can't set programmatically - document for developers
#elif defined(__APPLE__)
    // Requires: -FIRAnalyticsDebugEnabled launch argument
    // Document how to set in Xcode scheme
#endif
```

Alternatively, just document the debug setup in CLAUDE.md rather than trying to automate.

### Implementation Order Recommendation

1. Start with task-402 (Analytics) as proof-of-concept
2. Proves the C++ → GDScript pattern works
3. Low risk, fast feedback loop
4. Then move to task-399 (Auth) which is more complex

## Revised Scope (2025-12-31)

### Key Discovery: Analytics Library Already Linked!

Exploration of SCsub revealed that `libfirebase_analytics.a` is **already linked on ALL platforms**:
- Android: arm32, arm64, x86_64
- iOS: device-arm64
- macOS: Universal (arm64 + x86_64)
- Windows: x64 MSVC

**This means NO build system changes needed!** We can immediately implement the C++ module.

### What's Actually Needed:

**C++ Implementation (new files, but simpler than database):**
1. Create `analytics.h` with thread-safe singleton
2. Create `analytics.cpp` with fire-and-forget methods
3. NO async callbacks needed (Analytics is synchronous)
4. NO MessageQueue marshalling needed (no worker thread callbacks)
5. Simple parameter validation

**Why Analytics is Simpler:**
- Fire-and-forget pattern (no completion callbacks)
- Events batched by Firebase SDK automatically
- No state to manage (unlike Auth, Database)
- No listeners (unlike Database, Remote Config)

### Simplified C++ Pattern:
```cpp
// analytics.cpp - Much simpler than database.cpp
void FirebaseAnalytics::log_event(const String& event_name, const Dictionary& params) {
    if (!inited) return;
    
    // Convert params to Firebase format
    std::vector<firebase::analytics::Parameter> fb_params;
    // ... conversion ...
    
    // Fire-and-forget - no callback, no future, no async
    firebase::analytics::LogEvent(event_name.utf8().get_data(), fb_params.data(), fb_params.size());
}
```

### Risk Assessment:
- **Before**: Unknown build complexity
- **After**: Library ready, just implement C++ wrapper - LOW risk
- Simplest of all Firebase services to implement

### Implementation Order Recommendation:
Start with task-402 (Analytics) as **proof-of-concept**:
1. Simplest Firebase service
2. Proves C++ → GDScript pattern works
3. Immediate product value (event tracking)
4. Fast feedback loop for subsequent tasks

### Files to Create:
- `godot/modules/firebase/analytics.h` - Header
- `godot/modules/firebase/analytics.cpp` - Implementation
- `project/firebase/analytics_service.gd` - GDScript service
- Debug actions in `project/debug/actions/firebase_analytics/`
- Test configs in `tests/debug_configs/`

### Files to Modify:
- `godot/modules/firebase/register_types.cpp` - Register class
- `project/firebase/firebase_service.gd` - Add analytics accessor
<!-- SECTION:NOTES:END -->
