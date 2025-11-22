---
id: task-290
title: add ios quit mechanic in tests
status: Done
assignee: []
created_date: '2025-11-17 22:49'
updated_date: '2025-11-22 10:55'
labels: []
dependencies: []
---

## Description
Q: How do I programmatically quit my iOS application?
There is no API provided for gracefully terminating an iOS application.

In iOS, the user presses the Home button to close applications. Should your application have conditions in which it cannot provide its intended function, the recommended approach is to display an alert for the user that indicates the nature of the problem and possible actions the user could take — turning on WiFi, enabling Location Services, etc. Allow the user to terminate the application at their own discretion.

WARNING: Do not call the exit function. Applications calling exit will appear to the user to have crashed, rather than performing a graceful termination and animating back to the Home screen.

Additionally, data may not be saved, because -applicationWillTerminate: and similar UIApplicationDelegate methods will not be invoked if you call exit.

If during development or testing it is necessary to terminate your application, the abort function, or assert macro is recommended

## Testing & CI Termination Methods

### 1. Via XCUITest (The UI Test Layer)

When writing UI tests with XCUITest, you can terminate the app programmatically.

**Use Case:** Your test needs to relaunch the app to verify some state persistence or initialization logic.

**Command:**
```swift
let app = XCUIApplication()
app.launch()

// ... do test steps ...

app.terminate()
```

**Note:** This is safe and intended for UI testing scenarios. It simulates a user force-quitting the app.

### 2. Via simctl (The Pipeline / Shell Layer)

If you need to kill the app from a CI script (e.g., Bash, Jenkins, GitHub Actions) without interacting with the UI code, you should use Xcode's command-line tools.

**Use Case:** You are running a script that installs the app, launches it, waits for a generic log, and needs to clean up the simulator afterwards.

**Command:**
```bash
xcrun simctl terminate <device_id> <bundle_identifier>
```

**Example:** Targeting the currently booted simulator:
```bash
xcrun simctl terminate booted com.yourcompany.yourapp
```

### 3. Via Application Code (The "Debug Hook" Layer)

Sometimes you need the app to self-terminate based on a specific logic flow or after performing a "headless" task in the simulator. Since `exit(0)` is forbidden in the App Store, you must wrap it in conditional compilation flags or logic checks.

**Use Case:** The app performs a data migration or a smoke test on launch and should close immediately upon success so the CI job can finish.

**Step A: Pass a Launch Argument**

Configure your CI to launch the app with a specific argument (e.g., `-CITesting`).

In XCUITest:
```swift
let app = XCUIApplication()
app.launchArguments.append("-CITesting")
app.launch()
```

Or via Scheme / Command Line:
```bash
xcodebuild test ... -destination ... -scheme YourScheme -launchArgument "-CITesting"
```

**Step B: Handle it in AppDelegate or SceneDelegate**

```swift
import UIKit

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    // Check for the CI flag
    if CommandLine.arguments.contains("-CITesting") {

        // Perform your CI specific setup/checks here
        print("CI Environment detected.")

        // ... do work ...

        // Quit the app programmatically
        // IMPORTANT: Only do this in DEBUG or specific CI configurations
        #if DEBUG
        exit(0)
        #endif
    }

    return true
}
```

## Summary Recommendation

| Scenario | Best Method |
|----------|-------------|
| Writing UI Tests | `XCUIApplication().terminate()` |
| Cleanup via Shell Script | `xcrun simctl terminate booted <bundle_id>` |
| App needs to close itself | `exit(0)` wrapped in `#if DEBUG` and triggered by `CommandLine.arguments` |

⚠️ **Important:** Ensure that any code using `exit(0)` is strictly stripped out of your Release/AppStore builds using Preprocessor Macros (e.g., `#if DEBUG`), otherwise your app will be rejected by Apple review.

## Implementation Solution (Task-290)

### Final Implementation: `_exit(0)` in Firebase Module

We implemented iOS quit functionality using `_exit(0)` instead of `exit(0)` in the Firebase C++ module.

**Key Discovery:** `exit(0)` allows cleanup handlers to run, which delays termination by ~0.86 seconds and triggers Firebase SDK errors. Using `_exit(0)` bypasses cleanup handlers and terminates immediately.

**Files Modified:**

1. **godot/modules/firebase/firebase.h**
   - Added `quit_app()` instance method declaration

2. **godot/modules/firebase/firebase.mm**
   ```cpp
   void Firebase::quit_app() {
   #if defined(__APPLE__)
       // iOS quit for testing/CI only
       // Use _exit() instead of exit() to bypass cleanup handlers and terminate immediately
       // This is necessary because exit() allows cleanup code to run, which can delay termination
       _exit(0);
   #else
       // Android/other platforms: no-op (they use Engine.get_main_loop().quit())
   #endif
   }
   ```

3. **project/core/events/quit_application_event.gd**
   - Modified `_handle_ios_quit()` to use `ClassDB.instantiate("Firebase")` and call `quit_app()`

**Why `_exit(0)` vs `exit(0)`:**
- `exit(0)`: Runs atexit handlers, flushes buffers, cleanup code → 0.86s delay + Firebase errors
- `_exit(0)`: Immediate termination, no cleanup → instant quit, test framework detects completion

**Platform Guard:**
- Uses `#if defined(__APPLE__)` to ensure iOS-only execution
- Android and other platforms use standard `Engine.get_main_loop().quit()`

**Testing Results:**
- ✅ Immediate termination confirmed via logs
- ✅ No Firebase SDK errors after termination
- ✅ Test framework detects app completion correctly
