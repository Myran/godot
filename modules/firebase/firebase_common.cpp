// firebase_common.cpp - Shared Firebase implementation across all platforms
// Platform-specific createApplication() is implemented in:
// - firebase_platform.mm (Android/iOS/macOS)
// - firebase_windows.cpp (Windows)

#include "firebase.h"
#include "core/io/dir_access.h"   // task-1502: create the sink's directory
#include "core/object/callable_mp.h"
#include "core/object/class_db.h"
#include "core/object/message_queue.h"
#include "core/os/os.h"           // task-1502: resolve the user data dir
#include "firebase/log.h"     // task-1502: firebase::LogLevel
#include <cstdio>            // task-1502: synchronous stderr for fatal-adjacent lines
#include <mutex>
#include <string>
#include <utility>
#include <vector>
#include "database.h"        // For FirebaseDatabase::begin_shutdown()
#include "remote_config.h"   // For FirebaseRemoteConfig::begin_shutdown() (task-1081)
#include "auth.h"            // For FirebaseAuth::begin_shutdown() (task-1084)
#include "firestore.h"       // For FirebaseFirestore::begin_shutdown() (task-1084)
#include "analytics.h"       // For FirebaseAnalytics::begin_shutdown() (task-1084)
#include "messaging.h"       // For FirebaseMessaging::begin_shutdown() (task-1084 panel follow-up)

#if defined(__APPLE__)
#include <TargetConditionals.h>
#if TARGET_OS_IPHONE
#include "firebase/app.h"
#endif
#endif

// task-1502: bridge the Firebase SDK's own diagnostics into Godot's log sink.
//
// The SDK formats every message and hands it to ONE global callback
// (app/src/log.cc). The default callback printf()s to stdout, which Godot's
// logger never captures and the Windows test runner does not redirect — so
// SDK-side failures were silent. task-1481 spent three sessions recovering a
// diagnostic that repo.cc:503 had already written and nobody could see.
//
// LogSetCallback is exported by the prebuilt libraries (verified: darwin
// universal `T ...LogSetCallback...`, and the VS2019 x64 Debug+Release .lib)
// but it lives in an internal header the release zip does not ship, so it is
// declared here rather than included.
namespace firebase {
typedef void (*LogCallback)(LogLevel log_level, const char *log_message, void *callback_data);
void LogSetCallback(LogCallback callback, void *callback_data);
} // namespace firebase

namespace {

std::mutex g_sdk_log_mutex;
std::vector<std::pair<int, std::string>> g_sdk_log_pending;
bool g_sdk_log_drain_queued = false;
uint64_t g_sdk_log_dropped = 0;

// Bounded: a verbose log level must not grow without limit if the main loop
// stalls. Drops are counted and reported rather than silently swallowed.
constexpr size_t SDK_LOG_MAX_PENDING = 512;

// task-1502: the synchronous sink. Opened once on the main thread at install,
// written from whatever thread the SDK logs on. A FILE* rather than stderr
// because redirecting stderr on Windows costs the process exit code: any
// -RedirectStandard* on Start-Process returns a null ExitCode, so a 0xC0000005
// would report as a pass (measured 2026-08-13). Null when the open failed —
// every use is guarded and the queue path still runs.
FILE *g_sdk_log_file = nullptr;

// MAIN THREAD ONLY — builds the Godot Strings.
void _firebase_sdk_log_drain() {
	std::vector<std::pair<int, std::string>> batch;
	uint64_t dropped = 0;
	{
		std::lock_guard<std::mutex> lock(g_sdk_log_mutex);
		batch.swap(g_sdk_log_pending);
		dropped = g_sdk_log_dropped;
		g_sdk_log_dropped = 0;
		g_sdk_log_drain_queued = false;
	}
	for (const std::pair<int, std::string> &entry : batch) {
		const String line = String("[Firebase SDK] ") + String::utf8(entry.second.c_str());
		if (entry.first >= firebase::kLogLevelError) {
			print_error(line);
		} else {
			print_line(line);
		}
	}
	if (dropped > 0) {
		print_error(String("[Firebase SDK] ") + itos((int64_t)dropped) + " log line(s) dropped - buffer full");
	}
}

// ANY THREAD, and the SDK holds its own log mutex across this call, which
// serialises every invocation. Two consequences: build NOTHING Godot here, the
// ARM64 SIGBUS class this module's CLAUDE.md forbids; and never log from here.
// That mutex is RECURSIVE, so the hazard is not deadlock as this comment once
// claimed — p_message points into the SDK's shared static format buffer, so a
// nested log overwrites the string being read and recurses.
void _firebase_sdk_log_callback(firebase::LogLevel p_level, const char *p_message, void *) {
	// task-1502 AC#1: an error-level line must NOT depend on the queue below.
	// The drain runs on the main thread, so anything the SDK logs microseconds
	// before the process dies goes down with the buffer. That is exactly how
	// repo.cc's "Could not initialize persistence" stayed invisible through
	// three sessions of task-1481 while it was being hunted.
	//
	// Written here, synchronously, on the thread that emitted it. Raw C stdio
	// only: this runs on arbitrary threads and must construct no Godot object
	// (the ARM64 SIGBUS class this module's CLAUDE.md forbids). fflush is the
	// point of the exercise — stderr is block-buffered when redirected to a
	// file, so without it the line dies in libc's buffer exactly as it did in
	// the queue.
	// Threshold is WARNING, not ERROR, and that is deliberate. A sink that fires
	// only during an unreproducible crash is a sink nobody can prove works: the
	// one SDK LogError we know of (repo.cc's persistence failure) is now
	// unreachable, because database.cpp refuses the input that caused it. At
	// WARNING every run emits a few lines, so the whole chain — callback,
	// fflush, retrieval — is exercised continuously instead of being trusted.
	// Verbose and Debug stay out; the SDK is very chatty there and the queue
	// already carries them to the Godot log.
	//
	// fflush is the point: without it the line sits in libc's buffer and dies
	// with the process, exactly as it died in the queue.
	//
	// Two guarantees make the unlocked fprintf safe. The SDK serialises every
	// callback under its own log mutex, and stdio locks the stream implicitly
	// (C11 7.21.2p7). Do NOT log from inside here: p_message points into the
	// SDK's shared static format buffer, so a nested log overwrites the string
	// being read and recurses.
	if (g_sdk_log_file != nullptr && p_level >= firebase::kLogLevelWarning) {
		const char *tag = "WARNING";
		if (p_level >= firebase::kLogLevelAssert) {
			tag = "ASSERT";
		} else if (p_level >= firebase::kLogLevelError) {
			tag = "ERROR";
		}
		fprintf(g_sdk_log_file, "[Firebase SDK][%s] %s\n", tag, p_message ? p_message : "");
		fflush(g_sdk_log_file);
	}

	bool queue_drain = false;
	{
		std::lock_guard<std::mutex> lock(g_sdk_log_mutex);
		if (g_sdk_log_pending.size() >= SDK_LOG_MAX_PENDING) {
			g_sdk_log_dropped++;
			return;
		}
		// p_message points into the SDK's static format buffer — copy it now.
		g_sdk_log_pending.emplace_back((int)p_level, p_message ? p_message : "");
		queue_drain = !g_sdk_log_drain_queued;
		if (queue_drain) {
			g_sdk_log_drain_queued = true;
		}
	}
	if (!queue_drain) {
		return; // a drain is already scheduled; it will pick this line up.
	}
	if (MessageQueue::get_singleton() != nullptr) {
		MessageQueue::get_singleton()->push_callable(callable_mp_static(_firebase_sdk_log_drain));
	} else {
		// Before the queue exists (early startup) or after it is gone
		// (shutdown). Release the slot so the next message tries again,
		// instead of latching the flag and stranding the buffer forever.
		std::lock_guard<std::mutex> lock(g_sdk_log_mutex);
		g_sdk_log_drain_queued = false;
	}
}

} // namespace

void Firebase::install_sdk_log_bridge() {
	// task-1502: open the synchronous sink first, on the main thread, so it is
	// ready before anything can touch the SDK. It sits beside godot.log in the
	// user data dir because that is the directory every platform's harness
	// already retrieves from. "w" truncates once per process, so a previous
	// run's warnings cannot be read as this run's.
	if (g_sdk_log_file == nullptr && OS::get_singleton() != nullptr) {
		const String dir = OS::get_singleton()->get_user_data_dir().path_join("logs");
		if (DirAccess::make_dir_recursive_absolute(dir) == OK) {
			const CharString path = dir.path_join("firebase_sdk.txt").utf8();
			g_sdk_log_file = fopen(path.get_data(), "w");
		}
	}
	firebase::LogSetCallback(&_firebase_sdk_log_callback, nullptr);
}

firebase::App* Firebase::app_ptr = NULL;

Firebase::Firebase() {
    if (app_ptr == NULL) {
        createApplication();
    }
}

firebase::App* Firebase::AppId() {
    if (app_ptr == NULL) {
        createApplication();
    }
    return app_ptr;
}

void Firebase::cleanup_firebase() {
    print_line(String("[Firebase] Starting cleanup sequence..."));

    if (app_ptr != NULL) {
        print_line(String("[Firebase] Cleaning up Firebase resources..."));

        // CRITICAL FIX: Call begin_shutdown() on Firebase services that might be active
        // to prevent further callbacks during app shutdown, avoiding use-after-free crashes
        // Only Database is guaranteed to be used (card retrieval), others are optional
        FirebaseDatabase::begin_shutdown();

        // task-1081: RemoteConfig must ALSO begin_shutdown. The boot balance overlay
        // (BalanceOverlay.fetch_and_apply) fires a fetch_and_activate at startup; if that
        // SDK future is still pending at quit, its worker-thread completion lambda would
        // push_callable(callable_mp(this,...)) onto a torn-down MessageQueue -> 0xC0000005
        // (Windows shutdown crash). begin_shutdown() only flips an atomic flag + prints
        // (no SDK calls, no static-init-order hazard), so it is safe even if RemoteConfig
        // was never initialized. The flag makes both the worker-lambda guard and the
        // main-thread handler guards (remote_config.cpp) skip late callbacks.
        FirebaseRemoteConfig::begin_shutdown();

        // task-1084: teardown parity. Auth, Firestore, and Analytics each register
        // firebase::Future OnCompletion worker-thread lambdas that push_callable onto the
        // MessageQueue; the is_shutting_down guards already exist atop those lambdas (auth.cpp,
        // firestore.cpp, analytics.cpp) but stayed DORMANT because begin_shutdown() was never
        // called for them — so a still-pending future firing during teardown could push onto a
        // torn-down MessageQueue / dereference a freed `this` (the same 0xC0000005 class as
        // task-1081). Each begin_shutdown() only flips an atomic flag + prints (no SDK calls,
        // no static-init-order hazard), so it is safe even if the service was never initialized.
        FirebaseAuth::begin_shutdown();
        FirebaseFirestore::begin_shutdown();
        FirebaseAnalytics::begin_shutdown();
        // task-1084 (panel follow-up): FCM is Listener-based, not Future-based, so the
        // original Future-sweep missed it. setToken/setMessage call_deferred onto the
        // MessageQueue from an OS-driven push callback — guard it too.
        FirebaseMessaging::begin_shutdown();

        print_line(String("[Firebase] Firebase cleanup completed"));
        app_ptr = NULL;
    } else {
        print_line(String("[Firebase] No active Firebase app to clean up"));
    }
}

void Firebase::_bind_methods() {
    ClassDB::bind_method(D_METHOD("quit_app"), &Firebase::quit_app);
    ClassDB::bind_method(D_METHOD("cleanup_firebase"), &Firebase::cleanup_firebase);
    ClassDB::bind_method(D_METHOD("process_notifications"), &Firebase::process_notifications);
}

// Note: createApplication() and quit_app() are platform-specific
// and implemented in firebase_platform.mm or firebase_windows.cpp
