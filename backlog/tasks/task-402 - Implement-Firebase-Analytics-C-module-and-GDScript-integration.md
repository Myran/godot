---
id: task-402
title: Implement Firebase Analytics C++ module and GDScript integration
status: To Do
assignee: []
created_date: '2025-12-30 21:26'
updated_date: '2025-12-30 22:43'
labels:
  - firebase
  - analytics
  - cpp
  - gdscript
  - testing
dependencies:
  - task-403
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
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan - Firebase Analytics

### Phase 1: C++ Module Creation (analytics.h/cpp) - NEW FILES

**Key Insight**: Analytics is simpler than other Firebase services - mostly fire-and-forget synchronous calls, no async callbacks needed for most operations.

**1.1 Create analytics.h Header**
```cpp
#ifndef FirebaseAnalytics_h
#define FirebaseAnalytics_h

#include "core/object/ref_counted.h"
#include "core/os/mutex.h"
#include "firebase.h"
#include "firebase/analytics.h"
#include <atomic>
#include <mutex>

class FirebaseAnalytics : public RefCounted {
    GDCLASS(FirebaseAnalytics, RefCounted);

private:
    // Thread-safe singleton (follow database.h pattern)
    static std::mutex initialization_mutex;
    static std::atomic<bool> inited;
    static FirebaseAnalytics* singleton_instance;
    static std::mutex instance_mutex;
    
    FirebaseAnalytics();  // Private constructor

protected:
    static void _bind_methods();

public:
    static FirebaseAnalytics& get_instance();
    static void cleanup();
    
    FirebaseAnalytics(const FirebaseAnalytics&) = delete;
    ~FirebaseAnalytics();

    // Core Analytics Methods (fire-and-forget)
    void log_event(const String& event_name, const Dictionary& params);
    void set_user_property(const String& name, const String& value);
    void set_user_id(const String& user_id);
    void set_analytics_collection_enabled(bool enabled);
    void reset_analytics_data();
    
    // Predefined Event Helpers (game-focused)
    void log_level_start(const String& level_name);
    void log_level_end(const String& level_name, const String& success);
    void log_tutorial_begin();
    void log_tutorial_complete();
    void log_screen_view(const String& screen_name, const String& screen_class);
    void log_select_content(const String& content_type, const String& item_id);
    
    // GameTwo-specific helpers
    void log_battle_start(const String& battle_type, int player_level);
    void log_battle_end(const String& battle_type, bool victory, int duration_seconds);
    void log_card_played(const String& card_id, const String& card_name);
};

#endif // FirebaseAnalytics_h
```

**1.2 Implement Core Methods (analytics.cpp)**
```cpp
#include "analytics.h"
#include "convertor.h"
#include "firebase/analytics.h"
#include "firebase/analytics/event_names.h"
#include "firebase/analytics/parameter_names.h"
#include "core/object/message_queue.h"

// Static member initialization
std::mutex FirebaseAnalytics::initialization_mutex;
std::atomic<bool> FirebaseAnalytics::inited(false);
FirebaseAnalytics* FirebaseAnalytics::singleton_instance = nullptr;
std::mutex FirebaseAnalytics::instance_mutex;

FirebaseAnalytics& FirebaseAnalytics::get_instance() {
    std::lock_guard<std::mutex> lock(instance_mutex);
    if (!singleton_instance) {
        singleton_instance = new FirebaseAnalytics();
    }
    return *singleton_instance;
}

FirebaseAnalytics::FirebaseAnalytics() {
    if (!inited.load()) {
        std::lock_guard<std::mutex> init_lock(initialization_mutex);
        if (!inited.load()) {
            print_line("[Analytics C++] Initializing Firebase Analytics...");
            firebase::App* app = Firebase::AppId();
            if (app != nullptr) {
                // Analytics initialization is synchronous
                firebase::analytics::Initialize(*app);
                inited.store(true);
                print_line("[Analytics C++] Firebase Analytics initialized successfully.");
            }
        }
    }
}

// Log custom event with parameters
void FirebaseAnalytics::log_event(const String& event_name, const Dictionary& params) {
    if (!inited) {
        print_error("[Analytics C++] Analytics not initialized.");
        return;
    }
    
    // Validate event name (Firebase rules: alphanumeric + underscore, <=40 chars)
    if (event_name.length() > 40) {
        print_error("[Analytics C++] Event name too long (max 40 chars): " + event_name);
        return;
    }
    
    // Convert Dictionary to Firebase parameters
    std::vector<firebase::analytics::Parameter> fb_params;
    Array keys = params.keys();
    for (int i = 0; i < keys.size(); i++) {
        String key = keys[i];
        Variant value = params[key];
        
        // Validate parameter name (max 40 chars)
        if (key.length() > 40) {
            print_error("[Analytics C++] Parameter name too long: " + key);
            continue;
        }
        
        // Convert based on type
        if (value.get_type() == Variant::STRING) {
            String str_val = value;
            // Validate string value (max 100 chars)
            if (str_val.length() > 100) {
                str_val = str_val.substr(0, 100);
            }
            fb_params.push_back(firebase::analytics::Parameter(
                key.utf8().get_data(), str_val.utf8().get_data()));
        } else if (value.get_type() == Variant::INT) {
            fb_params.push_back(firebase::analytics::Parameter(
                key.utf8().get_data(), (int64_t)value));
        } else if (value.get_type() == Variant::FLOAT) {
            fb_params.push_back(firebase::analytics::Parameter(
                key.utf8().get_data(), (double)value));
        }
    }
    
    // Fire-and-forget (no callback needed)
    firebase::analytics::LogEvent(
        event_name.utf8().get_data(),
        fb_params.data(),
        fb_params.size()
    );
    
    print_verbose("[Analytics C++] Logged event: " + event_name);
}

// Set user property
void FirebaseAnalytics::set_user_property(const String& name, const String& value) {
    if (!inited) return;
    
    firebase::analytics::SetUserProperty(
        name.utf8().get_data(),
        value.utf8().get_data()
    );
    print_verbose("[Analytics C++] Set user property: " + name + " = " + value);
}

// Set user ID for cross-device tracking
void FirebaseAnalytics::set_user_id(const String& user_id) {
    if (!inited) return;
    
    firebase::analytics::SetUserId(user_id.utf8().get_data());
    print_verbose("[Analytics C++] Set user ID: " + user_id);
}

// Enable/disable analytics collection (GDPR compliance)
void FirebaseAnalytics::set_analytics_collection_enabled(bool enabled) {
    if (!inited) return;
    
    firebase::analytics::SetAnalyticsCollectionEnabled(enabled);
    print_line("[Analytics C++] Analytics collection " + String(enabled ? "enabled" : "disabled"));
}

// Predefined event helpers using Firebase constants
void FirebaseAnalytics::log_level_start(const String& level_name) {
    Dictionary params;
    params[firebase::analytics::kParameterLevelName] = level_name;
    log_event(firebase::analytics::kEventLevelStart, params);
}

void FirebaseAnalytics::log_level_end(const String& level_name, const String& success) {
    Dictionary params;
    params[firebase::analytics::kParameterLevelName] = level_name;
    params[firebase::analytics::kParameterSuccess] = success;
    log_event(firebase::analytics::kEventLevelEnd, params);
}

void FirebaseAnalytics::log_screen_view(const String& screen_name, const String& screen_class) {
    Dictionary params;
    params[firebase::analytics::kParameterScreenName] = screen_name;
    params[firebase::analytics::kParameterScreenClass] = screen_class;
    log_event(firebase::analytics::kEventScreenView, params);
}

// GameTwo-specific event helpers
void FirebaseAnalytics::log_battle_start(const String& battle_type, int player_level) {
    Dictionary params;
    params["battle_type"] = battle_type;
    params["player_level"] = player_level;
    log_event("battle_start", params);
}

void FirebaseAnalytics::log_battle_end(const String& battle_type, bool victory, int duration_seconds) {
    Dictionary params;
    params["battle_type"] = battle_type;
    params["victory"] = victory ? "true" : "false";
    params["duration_seconds"] = duration_seconds;
    log_event("battle_end", params);
}

void FirebaseAnalytics::log_card_played(const String& card_id, const String& card_name) {
    Dictionary params;
    params["card_id"] = card_id;
    params["card_name"] = card_name;
    log_event("card_played", params);
}

void FirebaseAnalytics::_bind_methods() {
    ClassDB::bind_method(D_METHOD("log_event", "event_name", "params"), &FirebaseAnalytics::log_event);
    ClassDB::bind_method(D_METHOD("set_user_property", "name", "value"), &FirebaseAnalytics::set_user_property);
    ClassDB::bind_method(D_METHOD("set_user_id", "user_id"), &FirebaseAnalytics::set_user_id);
    ClassDB::bind_method(D_METHOD("set_analytics_collection_enabled", "enabled"), &FirebaseAnalytics::set_analytics_collection_enabled);
    ClassDB::bind_method(D_METHOD("reset_analytics_data"), &FirebaseAnalytics::reset_analytics_data);
    
    // Predefined events
    ClassDB::bind_method(D_METHOD("log_level_start", "level_name"), &FirebaseAnalytics::log_level_start);
    ClassDB::bind_method(D_METHOD("log_level_end", "level_name", "success"), &FirebaseAnalytics::log_level_end);
    ClassDB::bind_method(D_METHOD("log_tutorial_begin"), &FirebaseAnalytics::log_tutorial_begin);
    ClassDB::bind_method(D_METHOD("log_tutorial_complete"), &FirebaseAnalytics::log_tutorial_complete);
    ClassDB::bind_method(D_METHOD("log_screen_view", "screen_name", "screen_class"), &FirebaseAnalytics::log_screen_view);
    
    // GameTwo-specific
    ClassDB::bind_method(D_METHOD("log_battle_start", "battle_type", "player_level"), &FirebaseAnalytics::log_battle_start);
    ClassDB::bind_method(D_METHOD("log_battle_end", "battle_type", "victory", "duration_seconds"), &FirebaseAnalytics::log_battle_end);
    ClassDB::bind_method(D_METHOD("log_card_played", "card_id", "card_name"), &FirebaseAnalytics::log_card_played);
}
```

### Phase 2: Build System Integration

**2.1 Update SCsub**
```python
# Add to source files
env.add_source_files(env.modules_sources, "analytics.cpp")

# Link Analytics library
if env['platform'] == 'android':
    env.Prepend(LIBS=[File("#/../firebase/firebase_cpp_sdk/libs/android/.../libfirebase_analytics.a")])
# ... other platforms
```

### Phase 3: GDScript Service Layer

**3.1 Create analytics_service.gd**
```gdscript
class_name AnalyticsService
extends RefCounted

var _cpp_analytics: Object
var _is_collection_enabled: bool = true

func _init() -> void:
    if ClassDB.class_exists("FirebaseAnalytics"):
        _cpp_analytics = ClassDB.instantiate("FirebaseAnalytics")

func log_event(event_name: String, params: Dictionary = {}) -> void:
    if not is_instance_valid(_cpp_analytics):
        return
    _cpp_analytics.log_event(event_name, params)

func set_user_property(name: String, value: String) -> void:
    if not is_instance_valid(_cpp_analytics):
        return
    _cpp_analytics.set_user_property(name, value)

func set_user_id(user_id: String) -> void:
    if not is_instance_valid(_cpp_analytics):
        return
    _cpp_analytics.set_user_id(user_id)

func set_collection_enabled(enabled: bool) -> void:
    _is_collection_enabled = enabled
    if is_instance_valid(_cpp_analytics):
        _cpp_analytics.set_analytics_collection_enabled(enabled)
```

**3.2 Create analytics_backend.gd (Game-specific)**
```gdscript
class_name AnalyticsBackend
extends RefCounted

var _analytics_service: AnalyticsService

func _init() -> void:
    _analytics_service = AnalyticsService.new()

# GameTwo-specific event tracking
func track_battle_started(battle_type: String, player_level: int) -> void:
    _analytics_service.log_event("battle_start", {
        "battle_type": battle_type,
        "player_level": player_level
    })

func track_battle_completed(battle_type: String, victory: bool, duration: int) -> void:
    _analytics_service.log_event("battle_end", {
        "battle_type": battle_type,
        "victory": "true" if victory else "false",
        "duration_seconds": duration
    })

func track_card_played(card: Card) -> void:
    _analytics_service.log_event("card_played", {
        "card_id": card.id,
        "card_name": card.display_name
    })

func track_screen(screen_name: String) -> void:
    _analytics_service.log_event("screen_view", {
        "screen_name": screen_name
    })
```

### Phase 4: Debug Actions & Test Configurations

**4.1 Create project/debug/actions/firebase_analytics/**
- `analytics_log_event_test_action.gd`
- `analytics_user_property_test_action.gd`
- `analytics_predefined_events_test_action.gd`
- `analytics_collection_toggle_test_action.gd`
- `analytics_game_events_test_action.gd`

**4.2 Create tests/debug_configs/**
- `firebase-analytics-layer.json`
- `firebase-analytics-events.json`
- `firebase-analytics-user.json`

### Key Implementation Notes

**No Async Callbacks Needed:**
- Analytics is fire-and-forget
- Events are batched by Firebase SDK automatically
- No OnCompletion handlers required

**Parameter Validation (Firebase Rules):**
- Event names: alphanumeric + underscore, max 40 chars
- Parameter names: max 40 chars
- String values: max 100 chars
- Max 25 custom user properties
- Max 500 event types

**GDPR/Privacy Controls:**
- `set_analytics_collection_enabled(false)` for opt-out
- Call before any events if user opts out

### Key Reference Files
- `godot/modules/firebase/database.h:88-95` - Thread-safe singleton pattern
- Firebase docs: LogEvent, SetUserProperty, kEvent* constants
<!-- SECTION:PLAN:END -->
