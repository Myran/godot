# Firebase C++ Module

**Custom Godot module** - Integrates Firebase C++ SDK with Godot Engine for GameTwo.

This module provides the C++ bridge between Firebase SDK and GDScript, enabling authentication, database, and cloud functions.

## Architecture context (read first for non-trivial work)

- [data-and-firebase.md](../../../docs/technical/architecture/data-and-firebase.md) — three-tier data model, ARM64 `_safe_copy_variant` at three sites, rate-limiter constants, FIREBASE_TIMEOUT_SEC=45.0
- [build-and-deploy.md](../../../docs/technical/architecture/build-and-deploy.md) — Firebase SDK build-from-source (`build-firebase-libs`), SDK-injection markers (`//ADD_FIREBASE_BUILDSCRIPT_HERE_`, etc.), per-platform pipelines

---

## 📁 Module Structure

```
godot/modules/firebase/
├── config.py              # SCons build configuration
├── SCsub                  # SCons build script
├── register_types.h/cpp   # Module registration
├── convertor.h/cpp        # Type conversion (GDScript ↔ Firebase)
├── firebase.h             # Core Firebase header
├── firebase_common.cpp    # Shared Firebase logic (ALL platforms)
├── firebase_platform.mm   # Platform-specific init (Android/iOS/macOS)
├── firebase_windows.cpp   # Platform-specific init (Windows MSVC)
├── analytics.h/cpp        # Analytics service (ALL platforms) ✨ NEW
├── auth.h                 # Authentication header
├── auth.cpp               # Authentication service (ALL platforms)
├── database.h/cpp         # Realtime Database service
├── functions.h            # Cloud Functions service
├── messaging.h/cpp        # Cloud Messaging service
├── remote_config.h/cpp    # Remote Config service
└── AndroidManifest.xml    # Android permissions
```

---

## 🔧 Build System Integration

### **config.py - Platform Detection**
```python
def can_build(env, platform):
    if platform == "android":
        return True
    if platform == "ios":
        return True
    if platform == "macos":
        return True
    if platform == "windows":
        return True
    return False
```

**Platform Support:**
- ✅ **Android**: Full support (arm32, arm64, x86_64)
- ✅ **iOS**: Full support (arm64 device)
- ✅ **macOS**: Full support (arm64, x86_64 Universal 2)
- ✅ **Windows**: Full support (x86_64 MSVC) - Requires Windows VM with VS2022
- ❌ **Linux**: Not supported (no Firebase C++ SDK integration)

### **SCsub - Build Configuration**

**Architecture: Shared + Platform-Specific Code**

The module uses a shared architecture to minimize code duplication:

```python
# Shared C++ source files (ALL platforms)
env.add_source_files(env.modules_sources, "auth.cpp")
env.add_source_files(env.modules_sources, "convertor.cpp")
env.add_source_files(env.modules_sources, "database.cpp")
env.add_source_files(env.modules_sources, "firebase_common.cpp")  # Shared Firebase logic
env.add_source_files(env.modules_sources, "messaging.cpp")
env.add_source_files(env.modules_sources, "register_types.cpp")
env.add_source_files(env.modules_sources, "remote_config.cpp")

# Platform-specific Firebase initialization (createApplication, quit_app)
if env['platform'] == 'windows':
    env.add_source_files(env.modules_sources, "firebase_windows.cpp")  # Windows MSVC
else:
    env.add_source_files(env.modules_sources, "firebase_platform.mm")  # Android/iOS/macOS

# Include Firebase SDK headers
env.Append(CPPPATH="#/../firebase/firebase_cpp_sdk/include")
```

**iOS Library Linking:**
```python
if env['platform'] == 'iphone':
    env.Prepend(LIBS=[File("#/../firebase/firebase_cpp_sdk/libs/ios/device-arm64/libfirebase_app.a")])
    env.Prepend(LIBS=[File("#/../firebase/firebase_cpp_sdk/libs/ios/device-arm64/libfirebase_auth.a")])
    env.Prepend(LIBS=[File("#/../firebase/firebase_cpp_sdk/libs/ios/device-arm64/libfirebase_database.a")])
    # ... additional Firebase services
```

**Android Library Linking (Architecture-Specific):**
```python
if env['platform'] == 'android':
    if env['arch'] == 'arm32':
        env.Prepend(LIBS=[File("#/../firebase/firebase_cpp_sdk/libs/android/armeabi-v7a/libfirebase_app.a")])
    elif env['arch'] == 'arm64':
        env.Prepend(LIBS=[File("#/../firebase/firebase_cpp_sdk/libs/android/arm64-v8a/libfirebase_app.a")])
    elif env['arch'] == 'x86_64':
        env.Prepend(LIBS=[File("#/../firebase/firebase_cpp_sdk/libs/android/x86_64/libfirebase_app.a")])
```

**Critical**: Architecture must match device (arm64 for modern devices, x86_64 for emulators).

**Windows Library Linking (MSVC):**
```python
if env['platform'] == 'windows':
    if env['arch'] == 'x86_64':
        env.Prepend(LIBS=[File("#/../firebase/firebase_cpp_sdk/libs/windows/VS2019/MT/x64/Release/firebase_app.lib")])
        env.Prepend(LIBS=[File("#/../firebase/firebase_cpp_sdk/libs/windows/VS2019/MT/x64/Release/firebase_auth.lib")])
        env.Prepend(LIBS=[File("#/../firebase/firebase_cpp_sdk/libs/windows/VS2019/MT/x64/Release/firebase_database.lib")])
        # ... additional Firebase services
        # Windows system libraries (passed via LINKFLAGS to avoid SCons name mangling)
        env.Append(LINKFLAGS=['Userenv.lib'])  # For GetUserProfileDirectoryW
        env.Append(LINKFLAGS=['icu.lib'])      # For ICU timezone functions
```

**Note**: Windows requires MSVC build (VS2019/VS2022) - MinGW is NOT supported due to Firebase SDK ABI incompatibility.

---

## 🔀 Type Conversion System

### **Convertor Class**

**Purpose**: Safely convert between GDScript `Variant` and Firebase `firebase::Variant`

**Key Functions:**
```cpp
class Convertor {
public:
    // Firebase → GDScript
    static Variant fromFirebaseVariant(const firebase::Variant& arg);

    // GDScript → Firebase
    static firebase::Variant toFirebaseVariant(const String& arg);
    static firebase::Variant toFirebaseVariant(const Dictionary& arg);
    static firebase::Variant toFirebaseVariant(const Variant& arg);

    // Deep copy for GDScript-safe memory
    static Variant deepCopyVariant(const Variant& arg);
};
```

### **Type Mapping**

| GDScript Type | Firebase Type | Notes |
|---------------|---------------|-------|
| `String` | `std::string` | UTF-8 encoding |
| `int` | `int64_t` | 64-bit integer |
| `float` | `double` | Double precision |
| `bool` | `bool` | Direct mapping |
| `Dictionary` | `std::map<Variant, Variant>` | Recursive conversion |
| `Array` | `std::vector<Variant>` | Recursive conversion |
| `null` | `Variant::Null()` | Firebase null type |

### **Memory Safety**

**Critical**: Firebase C++ SDK uses different memory management than GDScript

```cpp
// ✅ CORRECT - Deep copy ensures GDScript owns memory
Variant data = Convertor::fromFirebaseVariant(firebase_data);
Variant safe_copy = Convertor::deepCopyVariant(data);
return safe_copy;  // Safe to use in GDScript

// ❌ FORBIDDEN - Shallow copy causes crashes
return Convertor::fromFirebaseVariant(firebase_data);  // Firebase owns memory
```

**Why**: Firebase SDK memory may be freed while GDScript still references it.

---

## 🔥 Firebase Services

### **Core Initialization (firebase.mm)**

**Initialization Pattern:**
```cpp
// Initialize Firebase App (required for all services)
firebase::App* app = firebase::App::Create(
    firebase::AppOptions(),
    get_jni_env(),  // Android JNIEnv*
    get_activity()  // Android Activity
);

// Initialize services
firebase::auth::Auth* auth = firebase::auth::Auth::GetAuth(app);
firebase::database::Database* database = firebase::database::Database::GetInstance(app);
```

**Platform-Specific:**
- **iOS**: Uses `.mm` (Objective-C++) for UIKit integration
- **Android**: Requires JNI environment and Activity reference

### **Authentication (auth.h/mm)**

**Exposed Methods:**
```cpp
// Sign in with email/password
void sign_in_with_email_and_password(String email, String password);

// Sign out
void sign_out();

// Get current user
Dictionary get_current_user();

// Auth state listener
signal auth_state_changed(Dictionary user);
```

**iOS-Specific (`auth.mm`):**
- Uses Objective-C++ for iOS-specific Auth UI
- Handles keychain integration
- Manages iOS authentication flow

### **Realtime Database (database.h/cpp)**

**Exposed Methods:**
```cpp
// Read data
void get_value(String path);

// Write data
void set_value(String path, Variant data);

// Update data
void update_children(String path, Dictionary data);

// Remove data
void remove_value(String path);

// Listen for changes
void listen_for_value_events(String path);
void stop_listening(String path);
```

**Data Conversion:**
```cpp
// GDScript → Firebase
Dictionary gd_data = {"name": "Player", "level": 5};
firebase::Variant fb_data = Convertor::toFirebaseVariant(gd_data);
database_ref.SetValue(fb_data);

// Firebase → GDScript
firebase::Future<firebase::database::DataSnapshot> future = database_ref.GetValue();
firebase::database::DataSnapshot snapshot = future.result();
Variant gd_result = Convertor::fromFirebaseVariant(snapshot.value());
```

### **Cloud Functions (functions.h)**

**Exposed Methods:**
```cpp
// Call cloud function
void call_function(String function_name, Dictionary data);

// Result callback
signal function_result(String function_name, Dictionary result);
signal function_error(String function_name, String error);
```

### **Cloud Messaging (messaging.h/cpp)**

**Exposed Methods:**
```cpp
// Get FCM token
String get_token();

// Subscribe to topic
void subscribe_to_topic(String topic);

// Unsubscribe from topic
void unsubscribe_from_topic(String topic);

// Message received
signal message_received(Dictionary message);
```

### **Remote Config (remote_config.h/cpp)**

**Exposed Methods:**
```cpp
// Fetch remote config
void fetch_config();

// Activate fetched config
void activate_config();

// Get config value
Variant get_config_value(String key);

// Set defaults
void set_defaults(Dictionary defaults);
```

---

## 🔨 Build Requirements

### **Development Workflow**

```bash
# RECOMMENDED: One-command C++ workflow
just cpp-dev
# Combines: build templates → install template → deploy-android

# Manual workflow (alternative)
just build-android-templates     # 1. Compile C++ → .aar (3-15 min)
just install-android-template    # 2. Extract to project/android/build/
just deploy-android           # 3. Package + deploy (REQUIRED)
```

**Critical**:
- **After ANY C++ changes**: `just deploy-android` **MANDATORY** before Android testing
- **Reason**: Android uses compiled/cached templates that don't auto-update
- **iOS**: Similar workflow with `just build-install-ios`

### **Build Artifacts**

**Android:**
```
godot/bin/
└── android_templates/
    └── firebase.release.aar      # Compiled Firebase module
```

**iOS:**
```
godot/bin/
└── libgodot.ios.template_release.arm64.a
```

**Installation Location:**
```
project/android/build/
├── libs/
│   └── firebase.release.aar     # Installed module
└── src/
    └── AndroidManifest.xml      # Merged permissions
```

---

## 🚨 Critical Patterns & Safety

### **Async Operations**

**All Firebase operations are asynchronous:**

```cpp
// C++ side - Returns Future
firebase::Future<firebase::database::DataSnapshot> future = database_ref.GetValue();

// Monitor completion
while (future.status() == firebase::kFutureStatusPending) {
    // Wait for completion
}

if (future.error() == firebase::database::kErrorNone) {
    // Success
    firebase::database::DataSnapshot snapshot = future.result();
    Variant data = Convertor::fromFirebaseVariant(snapshot.value());
    emit_signal("data_received", data);
} else {
    // Error
    emit_signal("data_error", String(future.error_message()));
}
```

**GDScript Integration:**
```gdscript
# GDScript automatically handles async via signals/await
var result: Dictionary = await firebase_service.database_get("/path")
if result.success:
    process_data(result.data)
```

### **Thread Safety**

**Firebase SDK Threading:**
- ✅ **Main thread**: Safe for all operations
- ⚠️ **Background threads**: Limited operations allowed
- ❌ **Godot threads**: Do NOT call Firebase from Godot threads

**Pattern:**
```cpp
// ✅ CORRECT - Call from main thread
void _process(double delta) {
    if (pending_operation) {
        check_firebase_future();  // Safe - main thread
    }
}

// ❌ FORBIDDEN - Background thread
void background_thread_func() {
    database_ref.GetValue();  // CRASH - wrong thread
}
```

### **Memory Management**

#### **String UTF-8 Lifetime Pattern (CRITICAL)**

**Root Cause**: `String::utf8().get_data()` creates a **dangling pointer**.

```cpp
// ❌ CRASHES - Dangling pointer!
// String::utf8() returns a temporary CharString.
// get_data() points into that temporary.
// When temporary is destroyed, pointer becomes invalid.
const char* cstr = string_name.utf8().get_data();
firebase::analytics::LogEvent(cstr);  // CRASH: pointer invalid

// ✅ CORRECT - Store CharString to extend lifetime
CharString cs = string_name.utf8();     // CharString lives in this scope
firebase::analytics::LogEvent(cs.get_data());  // Pointer valid through call
```

**Why This Matters**:
- **Android JNI**: Strict UTF-8 validation (`Modified UTF-8` format). Dangling pointers read garbage bytes that fail JNI validation.
- **Desktop**: More lenient - may work randomly but will crash eventually.
- **Firebase SDK**: Reads string data asynchronously - pointer must remain valid.

**Pattern for All Functions**:
```cpp
void log_event(const String& event_name, const Dictionary& params) {
    // Store CharStrings to extend lifetime
    CharString event_cs = event_name.utf8();

    // Convert params (store each CharString)
    std::vector<firebase::analytics::Parameter> fb_params;
    for (const KeyValue& kv : params) {
        String key_str = kv.key;
        String value_str = kv.value;
        CharString key_cs = key_str.utf8();
        CharString value_cs = value_str.utf8();
        fb_params.push_back(firebase::analytics::Parameter(
            key_cs.get_data(),
            value_cs.get_data()
        ));
    }

    // Now safe to call Firebase SDK
    firebase::analytics::LogEvent(event_cs.get_data(), fb_params.data(), fb_params.size());
}
```

**Functions Affected** (must ALL follow this pattern):
- `log_event()`, `log_event_string()`, `log_event_int()`, `log_event_double()`, `log_event_params()`
- `set_user_property()`, `set_user_id()`
- `_convert_dict_to_parameters()` - parameter dictionary conversion

**Reference**: Fixed in `analytics.cpp` (task-402, 2025-12-31)

#### **Firebase Objects Lifetime**
```cpp
// ✅ CORRECT - Keep Firebase objects alive
class FirebaseService {
    firebase::App* app;                    // Must outlive services
    firebase::auth::Auth* auth;            // Must outlive app
    firebase::database::Database* database;

public:
    ~FirebaseService() {
        // Clean up in reverse order
        delete database;
        delete auth;
        delete app;
    }
};

// ❌ FORBIDDEN - Dangling pointers
firebase::App* app = firebase::App::Create(...);
delete app;  // Services still reference app - CRASH
```

### **Error Handling**

**Always check error codes:**
```cpp
firebase::Future<void> future = database_ref.SetValue(data);
future.OnCompletion([](const firebase::Future<void>& result) {
    if (result.error() == firebase::database::kErrorNone) {
        // Success
        emit_signal("write_success");
    } else {
        // Error
        String error_msg = String(result.error_message());
        int error_code = result.error();
        emit_signal("write_error", error_code, error_msg);
    }
});
```

**Common Error Codes:**
- `kErrorNone` (0): Success
- `kErrorPermissionDenied` (1): Security rules denied access
- `kErrorNotFound` (2): Data not found
- `kErrorUnavailable` (3): Service temporarily unavailable
- `kErrorNetworkError` (4): Network connection failed

---

## 🚨 Known Platform Limitations

### **Windows RTDB Error Handling (Task-516)**

**Issue**: Windows Firebase C++ SDK returns incorrect error information for permission denied scenarios in Realtime Database operations.

**Behavior Comparison:**

| Platform | `result.error()` | `result.error_message()` | Behavior |
|----------|------------------|--------------------------|----------|
| **macOS/iOS** | `8` (kErrorPermissionDenied) | `"This client does not have permission..."` | ✅ Correct |
| **Windows** | `0` (kErrorNone) | `""` (empty string) | ❌ SDK Bug |

**Root Cause Analysis:**

The Firebase C++ SDK for desktop platforms (Windows, macOS, Linux) shares the same source code in `extras/firebase-cpp-sdk/database/src/desktop/`. The divergence occurs in lower-level libraries:

1. **Error path**: Server → WebSocket (uWS) → JSON Parse (flatbuffers) → Connection → PersistentConnection → EventRegistration → Future
2. **Critical code** (`value_event_registration.cc:45-47`):
   ```cpp
   void ValueEventRegistration::FireCancelEvent(Error error) {
       listener_->OnCancelled(error, GetErrorMessage(error));  // Uses STATIC message!
   }
   ```
3. **Design limitation**: `GetErrorMessage(Error)` returns static strings from an enum lookup, NOT the server-provided error message
4. **Platform divergence**: uWebSockets/flatbuffers/libuv behave differently on Windows, causing error code 0 to be passed instead of the actual error

**GitHub Issue Search** (2026-02-03):
- No exact match found in firebase/firebase-cpp-sdk issues
- Related: Issue #1785 "[Bug] Errors fail to return all data from error object" (Auth, Windows) - same pattern of Windows-specific error information loss

**Workarounds Implemented:**

1. **C++ Defensive Fix** (`database.cpp`):
   ```cpp
   // Task-516: Windows Firebase SDK bug workaround
   // Check for error_message even when error code is 0
   if (status == firebase::kFutureStatusComplete && error == firebase::database::kErrorNone) {
       if (!error_msg.is_empty()) {
           // Error message present despite error code 0 - treat as error
           print_error("[RTDB C++] ... Error (SDK returned code 0 with message): " + error_msg);
           call_deferred(SNAME("emit_signal"), SNAME("get_value_error"), req_id, path_str, "SDK_ERROR_MSG", error_msg);
       }
       // ... normal handling
   }
   ```
   **Note**: This fix is retained but doesn't help on Windows since both error code AND error_message are empty.

2. **Test Framework Adaptation** (`firebase-rtdb-layer.json`):
   ```json
   {
     "action": "rtdb.testing.error_handling",
     "expected_result": {
       "type": "action_result_trust",
       "description": "Validates error handling via action success/failure (Windows SDK doesn't report permission errors in logs)"
     }
   }
   ```
   Changed from `expected_errors` (validates log patterns) to `action_result_trust` (validates action success/failure).

**Impact on Testing:**
- ✅ All 21 RTDB test actions PASS on Windows
- ✅ Error handling test correctly handles null results gracefully
- ⚠️ Windows logs won't show Firebase permission error details
- ✅ macOS/iOS continue to show full error messages

**Recommendations:**
- Do NOT rely on Windows Firebase RTDB error messages for debugging
- Use macOS or mobile platforms for Firebase permission error investigation
- The `action_result_trust` validation type is platform-agnostic and reliable

---

## 🔧 Platform-Specific Implementation

### **iOS (.mm files)**

**Objective-C++ Integration:**
```objc
// auth.mm - iOS-specific auth
@interface AuthHandler : NSObject
@end

@implementation AuthHandler
- (void)handleAuthResult:(FIRAuthDataResult*)result {
    // Convert iOS auth result to GDScript
    Dictionary user_data;
    user_data["uid"] = String([result.user.uid UTF8String]);
    user_data["email"] = String([result.user.email UTF8String]);

    // Emit to GDScript
    emit_signal("auth_success", user_data);
}
@end
```

**UIKit Integration:**
- Auth UI flows
- Keychain access
- App lifecycle events

### **Android (JNI)**

**JNI Environment:**
```cpp
// Get JNI environment
JNIEnv* env = get_jni_env();

// Get Android Activity
jobject activity = get_activity();

// Initialize Firebase with Android context
firebase::App* app = firebase::App::Create(
    firebase::AppOptions(),
    env,
    activity
);
```

**AndroidManifest.xml:**
```xml
<!-- Required permissions for Firebase -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Firebase services -->
<service
    android:name="com.google.firebase.components.ComponentDiscoveryService"
    android:exported="false">
    <meta-data
        android:name="com.google.firebase.components:com.google.firebase.auth.FirebaseAuthRegistrar"
        android:value="com.google.firebase.components.ComponentRegistrar" />
</service>
```

---

## 📖 Development Guidelines

### **Adding New Firebase Services**

1. **Add header/implementation files**
```cpp
// new_service.h
class NewService : public RefCounted {
    GDCLASS(NewService, RefCounted);

protected:
    static void _bind_methods();

public:
    void new_operation();
};

// new_service.cpp
void NewService::_bind_methods() {
    ClassDB::bind_method(D_METHOD("new_operation"), &NewService::new_operation);
}
```

2. **Register in register_types.cpp**
```cpp
void initialize_firebase_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    ClassDB::register_class<NewService>();
}
```

3. **Add to SCsub**
```python
# Link new Firebase service library
if env['platform'] == 'android':
    env.Prepend(LIBS=[File("#/../firebase/firebase_cpp_sdk/libs/android/.../libnew_service.a")])
```

4. **Expose to GDScript**
```gdscript
# project/firebase/new_service.gd
extends RefCounted
class_name NewService

var _native: Object

func _init() -> void:
    _native = NativeNewService.new()  # C++ binding

func new_operation() -> void:
    _native.new_operation()
```

### **Testing C++ Changes**

```bash
# Complete workflow
just cpp-dev  # Build + install + fastbuild

# Validate on device
just test-android-target firebase-test

# Debug logs
just logs-pattern TEST_ID "cpp.firebase.*"
```

### **Debugging C++ Module**

```bash
# Android native logs
just logs-android-device "Firebase"
just logs-android-device "FATAL"

# Look for crashes
just android-logs-tagged "DEBUG" 30 100

# iOS device logs
just ios-retrieve-logs-ipad
just ios-retrieve-logs-iphone
```

---

## 📚 Additional Resources

**Build Commands:**
```bash
just cpp-dev                      # One-command C++ workflow
just build-android-templates      # Build C++ module
just install-android-template     # Install to project
just deploy-android            # Deploy (REQUIRED)

just build-install-ios            # iOS build + deploy
```

**Testing:**
```bash
just test-android-target cpp-firebase-test
just logs-pattern TEST_ID "cpp.*"
```

**See Also:**
- `project/CLAUDE.md` - GDScript Firebase integration patterns
- `tests/CLAUDE.md` - Testing Firebase functionality
- `justfiles/CLAUDE.md` - Build system commands
- Root `CLAUDE.md` - Overall project workflows

---

**Key Principles:**
- ✅ **Platform-specific builds** - Android/iOS only (desktop platforms not supported)
- ✅ **Type safety** - Use Convertor for all GDScript ↔ Firebase conversions
- ✅ **Memory safety** - Deep copy variants, manage Firebase object lifetimes
- ✅ **Thread safety** - All Firebase calls from main thread only
- ✅ **Error handling** - Always check Future error codes
- ✅ **Async operations** - Use signals/callbacks for completion

*This module is critical infrastructure - changes require thorough testing across platforms.*
