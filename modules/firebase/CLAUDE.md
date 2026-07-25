# Firebase C++ Module

**Custom Godot module** — the C++ bridge between the Firebase C++ SDK and GDScript.

**Fully wired services:** Auth, Realtime Database, Firestore, Remote Config, Analytics. **Partial:** Cloud Messaging (token + receive only). **Not built:** Cloud Functions (commented-out stub — see below).

The two sections below are the reason this file exists. Everything after them is context.

---

## 🚨 Thread Safety — read this before writing ANY async callback

> **THE #1 recurring crash in this module.**
> A Godot container (`Dictionary`/`Array`/`Variant`/`String`, all CowData) built on a Firebase
> **worker thread** corrupts its internal `_p` pointer → intermittent **ARM64 `null-_p` / SIGBUS**
> in the field. It passes most test runs and then crashes on a device. This class cost a
> multi-session debug for RTDB (`b6e10f69c0`) and was then **re-introduced TWICE** — Firestore
> (task-1066) and Messaging (task-1077). It keeps happening because Godot's own *Thread-safe APIs*
> docs make it look fine (refcounts are atomic), so following the **engine** docs gives you the
> bug. Atomic refcounts do not save you here — the corruption is in the CowData build, not the count.

**The rule — every async callback runs on a Firebase SDK worker thread, NOT the main thread:**

`future.OnCompletion([...]{ })`, snapshot / child listeners, and FCM `OnMessage` / `OnTokenReceived`
all fire off-main. Inside them:

1. Construct **ONLY raw C++** — `firebase::Variant` / `std::string` / `std::map` / `std::vector` /
   `int` / `bool`, plus copies of self-owning SDK types (`firebase::Variant`, a copied
   `MapFieldValue`). Build **NO Godot object** (`Dictionary` / `Array` / `Variant` / `String`).
2. Store that raw payload under a `std::mutex`, keyed by an `int` id.
3. Hand **only the int id** to the main thread —
   `MessageQueue::get_singleton()->push_callable(callable_mp(this, &Svc::_handle_x_on_main_thread).bind(id))`
   for futures, or `callable_mp(this, &Svc::_handle_x_on_main_thread).call_deferred(id)` for listeners.
4. In `_handle_x_on_main_thread(int id)` (now on the main thread) pull the payload under the lock,
   build the Godot `Dictionary` / `String`, apply `Convertor::deepCopyVariant(...)`, then `emit_signal`.

**Allowed on the worker:** a bare scalar `String`/`int` passed by value through MessageQueue
(e.g. an error code). Prefer storing `std::string` and building the `String` in the handler.

**Copy-this gold standard → `database.cpp` / `database.h`:** `PendingFirebaseResult` +
`_pending_results_mutex` + `_queue_*_event` / `_handle_*_on_main_thread`. `firestore.cpp` and
`messaging.cpp` follow the identical shape — read any of the three before adding a new async
service and mirror it exactly.

```cpp
// ❌ FORBIDDEN — builds a Godot Dictionary on the Firebase worker thread (the SIGBUS class)
future.OnCompletion([this](const Future<Snapshot>& r) {
    Dictionary d = to_dict(r.result());            // CowData built off-main → null-_p
    MessageQueue::get_singleton()->push_callable(cb.bind(d));
});

// ✅ CORRECT — store raw C++, build the Dictionary in the main-thread handler
future.OnCompletion([this](const Future<Snapshot>& r) {
    PendingResult p; p.raw = r.result().GetData();  // raw C++ copy, owns itself
    { std::lock_guard<std::mutex> lk(_mutex); _pending[id] = std::move(p); }
    MessageQueue::get_singleton()->push_callable(
        callable_mp(this, &Svc::_handle_on_main_thread).bind(id));
});
void Svc::_handle_on_main_thread(int id) {           // NOW on the main thread
    Dictionary d = to_dict(_pending[id].raw);
    emit_signal("done", Convertor::deepCopyVariant(d));
}
```

**Separate, lower-frequency rule:** never *call* the Firebase SDK from a Godot worker thread —
drive futures from the main thread (`_process` / signals).

> Checked by review against this rule + the gold-standard pattern — there is no CI gate. (A brace-matching
> gate was prototyped in task-1078 and dropped 2026-06-25 — a heuristic that needed per-change
> reconciliation was judged heavier than the rule it guarded; the protection is keeping THIS section
> prominent and mirroring `database.cpp`.)

---

## 🚨 String UTF-8 Lifetime — `String::utf8().get_data()` is a dangling pointer

```cpp
// ❌ CRASHES - Dangling pointer!
// String::utf8() returns a temporary CharString.
// get_data() points into that temporary.
// When the temporary is destroyed, the pointer becomes invalid.
const char* cstr = string_name.utf8().get_data();
firebase::analytics::LogEvent(cstr);  // CRASH: pointer invalid

// ✅ CORRECT - Store CharString to extend lifetime
CharString cs = string_name.utf8();     // CharString lives in this scope
firebase::analytics::LogEvent(cs.get_data());  // Pointer valid through call
```

**Why This Matters**:
- **Android JNI**: Strict UTF-8 validation (`Modified UTF-8` format). Dangling pointers read garbage bytes that fail JNI validation.
- **Desktop**: More lenient — may work randomly but will crash eventually.
- **Firebase SDK**: Reads string data asynchronously — the pointer must remain valid.

When building a `std::vector<firebase::analytics::Parameter>`, the `Parameter`s hold *pointers* into
the CharStrings — so the CharStrings must outlive the vector. Keep them in a parallel
`std::vector<CharString>` in the same scope as the `LogEvent` call:

```cpp
std::vector<CharString> key_strings, value_strings;   // MUST outlive fb_params
std::vector<firebase::analytics::Parameter> fb_params;
for (const KeyValue<Variant, Variant>& kv : params) {
    key_strings.push_back(String(kv.key).utf8());
    value_strings.push_back(String(kv.value).utf8());
    fb_params.push_back({key_strings.back().get_data(), value_strings.back().get_data()});
}
firebase::analytics::LogEvent(event_cs.get_data(), fb_params.data(), fb_params.size());
```

**Reference implementation**: `analytics.cpp` — every `log_event*` / `set_user_property` /
`set_user_id` follows this (fixed in task-402, 2025-12-31). Mirror it in any new SDK call
that takes a `const char*`.

### Firebase Objects Lifetime

`firebase::App*` must outlive every service built from it (`Auth`, `Database`, …) — destroy in
reverse order. Deleting the app while a service still references it is a crash.

---

## Architecture context (read for non-trivial work)

- [data-and-firebase.md](../../../docs/technical/architecture/data-and-firebase.md) — three-tier data model, ARM64 safety via C++ main-thread `fromFirebaseVariant`+`deepCopyVariant` (task-1065 deleted the GDScript `_safe_copy_variant`), rate-limiter constants, FIREBASE_TIMEOUT_SEC=45.0
- [build-and-deploy.md](../../../docs/technical/architecture/build-and-deploy.md) — Firebase SDK build-from-source (`build-firebase-libs`), SDK-injection markers (`//ADD_FIREBASE_BUILDSCRIPT_HERE_`, etc.), per-platform pipelines

---

## 🔀 Type Conversion (`convertor.h/cpp`)

`Convertor` converts between GDScript `Variant` and `firebase::Variant`:
`fromFirebaseVariant` (FB → GD), three `toFirebaseVariant` overloads (GD → FB), and
`deepCopyVariant` (GDScript-safe memory).

Scalars map as expected (`String`→`std::string` UTF-8, `int`→`int64_t`, `float`→`double`);
`Dictionary`→`std::map`, `Array`→`std::vector` convert recursively; `null`→`Variant::Null()`.

**Critical**: deep-copy before handing data to GDScript — Firebase SDK memory may be freed while
GDScript still references it.

```cpp
// ✅ CORRECT - Deep copy ensures GDScript owns memory
Variant data = Convertor::fromFirebaseVariant(firebase_data);
return Convertor::deepCopyVariant(data);

// ❌ FORBIDDEN - Shallow copy causes crashes
return Convertor::fromFirebaseVariant(firebase_data);  // Firebase owns memory
```

---

## Platform Support

Build gating lives in `config.py` (`can_build`) — read it rather than trusting a copy here.
Current state: **Android, iOS, macOS, Windows** all build the module; **Linux is not supported**;
and **editor builds exclude it entirely** (`target == 'editor'` → `False`), which is why GDScript
guards every C++ class behind `ClassDB.class_exists(...)`.

| Platform | Arches | Init source |
|----------|--------|-------------|
| Android | arm32, arm64, x86_64 (must match the device) | `firebase_platform.mm` (JNIEnv + Activity) |
| iOS | arm64 device | `firebase_platform.mm` (Objective-C++, UIKit/NSRunLoop) |
| macOS | arm64, x86_64 Universal 2 | `firebase_platform.mm` |
| Windows | x86_64, **MSVC only** (MinGW ABI-incompatible with the SDK) | `firebase_windows.cpp` |

Everything else (`auth.cpp`, `database.cpp`, `firestore.cpp`, `analytics.cpp`, `messaging.cpp`,
`remote_config.cpp`, `convertor.cpp`, `firebase_common.cpp`) is pure C++, shared by all platforms.
Per-platform library lists + Windows system-lib LINKFLAGS live in `SCsub`.

---

## Service status

Bound method surfaces are derivable — read each service's `_bind_methods()` for the authoritative
list (they are `*_async(request_id, ...)` + signal pairs, not the synchronous shapes you might assume).

### Cloud Functions (`functions.h`) — NOT IMPLEMENTED

⚠️ **Stub only.** No `functions.cpp`; the `#include` and `register_class<FirebaseFunctions>()` are
commented out in `register_types.cpp`. Not compiled, not registered, not callable from GDScript.

**Decision (2026-06-16): keep this stub dormant — do NOT build it for parity.** This binding wraps the *callable* (`onCall`) client SDK, whose only value over a plain `HTTPRequest` is auto-attaching the caller's Auth + App Check context to a server RPC. GameTwo's planned server functions don't need that channel: Steam token-minting (task-559) is reached over plain `HTTPRequest` — no auth context exists yet at mint time (see `project/firebase/steam_auth_service.gd`) — and the RevenueCat receipt webhook (task-573) is server-to-server (the client never calls it). The deployed-functions backend itself lives in a separate `functions/` project (task-586), not in this C++ module. Finish this binding only when an already-signed-in client must invoke server-authoritative gameplay (e.g. server-side run scoring, validated opponent fetch) — the current design deliberately solves those client-side.

### Cloud Messaging (`messaging.h/cpp`) — PARTIAL

`FirebaseMessaging` is registered and initializes FCM with a listener, but the whole bound surface
is one method `get_token()` plus signals `token` and `message(message_data)`. **NOT implemented**
(despite earlier docs): `subscribe_to_topic` / `unsubscribe_from_topic`, no `message_received`
signal, and there is **no GDScript `MessagingService` wrapper** — so it is not usable from game
code yet. Finishing this is gated on task-557 (push-notification retention feature).

### Adding a new service

Copy `firestore.cpp` — it is the newest full implementation and already carries the worker→main
pattern above. Then: register the class in `register_types.cpp`, link the service lib per platform
in `SCsub`, and add the GDScript wrapper under `project/firebase/`.

---

## 🚨 Known Platform Limitation — Windows RTDB error strings (task-516)

Do NOT trust Windows Firebase RTDB error reporting: on a permission-denied the SDK returns
`error() == 0` with an empty `error_message()` (macOS/iOS correctly return `8` + the server text).
Investigate Firebase permission errors on macOS or mobile instead. Windows RTDB tests therefore
validate with `expected_result.type = "action_result_trust"` (action success/failure) rather than
log-pattern matching — see `tests/debug_configs/firebase-rtdb-layer.json`.

---

## 🔨 Build & Debug

```bash
# After ANY C++ change — MANDATORY before Android testing (Android runs cached templates)
just cpp-dev                      # build templates → install template → deploy-android
just deploy-ios                   # iOS equivalent

# Test
just test-android-target firebase-cpp-layer
just logs-pattern TEST_ID "cpp.firebase.*"

# Debug
just logs-android-device "Firebase"   # or "FATAL" for native crashes
just logs-ios TEST_ID                 # saved iOS test logs
just logs-ios-device "term"           # live iOS device logs
```

**See Also:**
- `project/firebase/CLAUDE.md` — GDScript service layer (3-layer architecture, async patterns)
- `tests/CLAUDE.md` — testing Firebase functionality
- `justfiles/CLAUDE.md` — build system commands

**Key Principles:**
- ✅ **Thread safety** — never build a Godot object on a Firebase worker thread (see top)
- ✅ **String lifetime** — store the `CharString`, never `utf8().get_data()` inline
- ✅ **Type safety** — use `Convertor` for all GDScript ↔ Firebase conversions
- ✅ **Memory safety** — `deepCopyVariant` before returning to GDScript; manage SDK object lifetimes
- ✅ **Error handling** — always check `Future::error()`
- ✅ **Platform gating** — GDScript guards every C++ class with `ClassDB.class_exists(...)` (editor builds have no module)

*This module is critical infrastructure — changes require thorough testing across platforms.*
