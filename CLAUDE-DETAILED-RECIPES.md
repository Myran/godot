# Justfile Recipe Deep Dive - Complete Call Chains & Usage Guide

**CRITICAL REFERENCE** - Complete recipe hierarchy, call chains, and decision criteria for all 21,358 lines of justfile infrastructure.

---

## 📊 Complete Build Hierarchy: `just build`

### **Full Call Chain (46 min)**

```
just build [force="no"]
    │
    └─→ just build-artifacts [force]
            │
            ├─→ just build-toolchain [force]                    [~40 min]
            │       │
            │       ├─→ just build-sentry-all [force]           [varies]
            │       │       ├─→ Sentry GDScript builds
            │       │       ├─→ Sentry native iOS builds
            │       │       ├─→ Sentry native Android builds
            │       │       └─→ Sentry native Windows builds
            │       │
            │       ├─→ just build-editor [force]               [~20 min]
            │       │       ├─→ SCons compile Godot source
            │       │       └─→ mv bin/ → editor/
            │       │
            │       └─→ just templates-all [force]              [~20 min]
            │               │
            │               ├─→ just build-moltenvk [force]
            │               │
            │               ├─→ just templates-ios [force]
            │               │       ├─→ just ios-build-template [force]
            │               │       │       ├─→ SCons iOS arm64 debug
            │               │       │       ├─→ SCons iOS arm64 release
            │               │       │       └─→ Copy to xcframework/
            │               │       │
            │               │       └─→ just package-ios-template [force]
            │               │               └─→ zip xcframework → templates/ios.zip
            │               │
            │               ├─→ just templates-android [force]
            │               │       ├─→ just build-android-templates [force]
            │               │       │       ├─→ just build-swappy [force]
            │               │       │       │       ├─→ Build Swappy Frame Pacing
            │               │       │       │       └─→ Copy libs to thirdparty/
            │               │       │       │
            │               │       │       ├─→ SCons compile C++ modules → .so files
            │               │       │       │       (Firebase, custom modules, all architectures)
            │               │       │       │
            │               │       │       └─→ Gradle generateGodotTemplates
            │               │       │               ├─→ Package .so → godot-lib.debug.aar
            │               │       │               └─→ Create templates/android_source.zip
            │               │       │
            │               │       └─→ just setup-android
            │               │               └─→ Validate Android SDK environment
            │               │
            │               └─→ just build-windows-templates [force]
            │                       └─→ Windows template compilation
            │
            ├─→ just setup-android-templates [force]            [~2 min]
            │       └─→ just install-android-template
            │               └─→ Unzip templates/android_source.zip → project/android/build/
            │
            ├─→ just export-all-android [force]                  [~3 min]
            │       ├─→ just insert-firebase-dependencies
            │       ├─→ just export-apk-android
            │       │       └─→ Godot --export-debug (calls Gradle internally)
            │       │               └─→ Output: export/android/gametwo_debug.apk
            │       │
            │       └─→ just export-aab-android
            │               └─→ Godot --export-release (AAB for Play Store)
            │
            └─→ just build-ios-all [force]                       [~5 min]
                    ├─→ just build-ios-app-debug
                    └─→ iOS xcframework integration

Total: ~46 minutes (first-time build)
```

### **When to Use Each Level**

| Command | Time | When to Use | What It Skips |
|---------|------|-------------|---------------|
| `just build` | 46 min | First-time setup, complete rebuild | Nothing - full rebuild |
| `just build force=yes` | 46 min | Force rebuild everything from scratch | Nothing - forces all |
| `just rebuild` | 46 min | Alias for `build force=yes` | Nothing |
| `just build-artifacts` | 45 min | Build all deployable files | Device installation |
| `just build-toolchain` | 40 min | Build editor + templates only | Export artifacts |
| `just build-editor` | 20 min | Custom Godot editor only | Templates, exports |

---

## 🤖 Android Build Pathways - Complete Breakdown

### **Pathway 1: Template Building (C++ Changes)**

```
just build-android-templates [force="no"]                [3-15 min]
    │
    ├─→ Check if templates exist (skip if force=no)
    │       ├─→ templates/android_debug.apk
    │       ├─→ templates/android_release.apk
    │       └─→ templates/android_source.zip
    │
    ├─→ just build-swappy [force]                        [varies]
    │       ├─→ Check if libswappy_static.a exists
    │       ├─→ Run extras/godot-swappy/build.bash
    │       ├─→ Extract gamesdk.zip
    │       ├─→ Extract games-frame-pacing-release.aar
    │       └─→ Copy libs to godot/thirdparty/swappy-frame-pacing/
    │
    ├─→ SCons compile C++ modules                        [10-15 min]
    │       ├─→ platform=android target=template_debug
    │       ├─→ platform=android target=template_release
    │       ├─→ All architectures: arm64-v8a, armeabi-v7a, x86, x86_64
    │       └─→ Output: godot/bin/*.so files
    │
    └─→ Gradle generateGodotTemplates                    [3-5 min]
            ├─→ cd godot/platform/android/java/
            ├─→ ./gradlew generateGodotTemplates
            ├─→ Package .so → godot-lib.debug.aar
            ├─→ Package .so → godot-lib.release.aar
            └─→ Create templates/android_source.zip

THEN: just install-android-template                      [30 sec]
    └─→ Unzip templates/android_source.zip → project/android/build/

THEN: just fastbuild-android (REQUIRED for testing)      [30-60 sec]
    └─→ Package + deploy (see Pathway 4)
```

**When to Use:**
- C++ module changes (Firebase SDK modifications)
- Custom native modules
- First-time template setup
- After updating Godot version

**Critical:** `install-android-template` + `fastbuild-android` REQUIRED after template building

---

### **Pathway 2: Full Pipeline (Complete Build)**

```
just build-all-android [force="no"]                      [3-25 min]
    │
    ├─→ just _build-common [force]                       [20+ min]
    │       ├─→ just install-deps
    │       ├─→ just build-editor [force]
    │       └─→ just update-version
    │
    └─→ just _build-android-full [force]                 [3-25 min]
            │
            ├─→ just templates-android [force]            [3-15 min]
            │       └─→ just build-android-templates [force]
            │
            ├─→ just setup-android-templates [force]      [30 sec]
            │       └─→ just install-android-template
            │
            └─→ just export-all-android [force]           [3 min]
                    ├─→ just insert-firebase-dependencies
                    ├─→ just export-apk-android
                    │       └─→ Godot --export-debug Android
                    │               (Gradle runs internally)
                    │               Output: export/android/gametwo_debug.apk
                    │
                    └─→ just export-aab-android
                            └─→ Godot --export-release Android
                                    Output: export/android/gametwo.aab
```

**When to Use:**
- Release builds
- First-time Android setup
- After Godot version updates
- When templates need rebuild

**Note:** Builds APK to `export/android/` but does NOT install to device

---

### **Pathway 3: Quick Build (Skip Template Check)**

```
just quick-build-android                                 [2-3 min]
    │
    ├─→ just insert-firebase-dependencies                [30 sec]
    │       └─→ Copy Firebase SDK files to project/android/build/
    │
    └─→ just export-apk-android                          [2 min]
            └─→ Godot --export-debug Android
                    ├─→ Uses templates/android_source.zip directly
                    ├─→ Godot extracts internally
                    ├─→ Gradle runs internally
                    └─→ Output: export/android/gametwo_debug.apk
```

**When to Use:**
- GDScript/asset changes
- Templates already built
- Don't need to rebuild templates

**Limitation:** Output to `export/android/`, not installed to device

---

### **Pathway 4: Fast Build (Dev Iteration) ⚡ CRITICAL**

```
just fastbuild-android                                   [30-60 sec]
    │
    │ (Alias to: just export-install-launch-debug)
    │
    ├─→ just export-apk-debug                            [15-20 sec]
    │       └─→ Godot --export-debug to /tmp/
    │               (Skips final packaging optimization)
    │
    ├─→ just install-apk-debug                           [10-15 sec]
    │       ├─→ just insert-firebase-dependencies
    │       │       └─→ Copy Firebase SDK to project/android/build/
    │       │
    │       └─→ Gradle assembleStandardDebug             [explicit control]
    │               ├─→ cd project/android/build/
    │               ├─→ ./gradlew assembleStandardDebug
    │               ├─→ Combines .aar templates + game assets + Firebase
    │               └─→ Output: project/android/build/build/outputs/apk/
    │
    └─→ just restart-android-app                         [5 sec]
            ├─→ adb install APK
            └─→ adb am start (launch app)
```

**When to Use:**
- **REQUIRED** after ANY GDScript/C++ changes before Android testing
- Rapid development iteration
- After `install-android-template` completes

**Requirements:**
- `install-android-template` must be run first
- Pre-extracted templates in `project/android/build/`

**Why It's Required:**
- Android uses compiled/cached code
- Code changes don't auto-update without rebuild
- Gradle combines new code with templates
- Installs directly to device for immediate testing

**Critical Business Rule:** 🚨 **ALWAYS run `fastbuild-android` after code changes before Android testing**

---

### **Pathway 5: Export Only (No Firebase)**

```
just export-apk-android                                  [1-2 min]
    │
    └─→ Godot --export-debug Android
            ├─→ Uses templates/android_source.zip directly
            ├─→ No Firebase dependency injection
            └─→ Output: export/android/gametwo_debug.apk
```

**When to Use:**
- Creating export artifacts
- Testing without Firebase
- CI/CD export validation

---

### **🎯 C++ Development Workflow (Recommended)**

```
just cpp-dev                                             [3-16 min]
    │
    ├─→ just build-android-templates                     [3-15 min]
    │       └─→ (See Pathway 1)
    │
    ├─→ just install-android-template                    [30 sec]
    │       └─→ Unzip to project/android/build/
    │
    └─→ just fastbuild-android                           [30-60 sec]
            └─→ (See Pathway 4) Package + deploy + launch
```

**When to Use:**
- ⭐ **ONE-COMMAND** C++ workflow (recommended)
- Firebase SDK modifications
- Custom C++ module development
- Native library integration

**Benefits:**
- Single command handles entire C++ workflow
- Automatic template build → install → deploy
- Ready for immediate testing

---

## 🍎 iOS Build & Deploy - Complete Breakdown

### **iOS Template Building**

```
just templates-ios [force="no"]                          [varies]
    │
    ├─→ just build-moltenvk [force]
    │       └─→ MoltenVK library for Vulkan support
    │
    ├─→ just ios-build-template [force]                  [~15 min]
    │       ├─→ Check if templates exist (skip if force=no)
    │       │       ├─→ bin/libgodot.ios.template_release.arm64.a
    │       │       └─→ bin/libgodot.ios.template_debug.arm64.a
    │       │
    │       ├─→ SCons compile iOS templates
    │       │       ├─→ platform=ios target=template_debug arch=arm64
    │       │       └─→ platform=ios target=template_release arch=arm64
    │       │
    │       └─→ Copy to xcframework
    │               ├─→ misc/dist/ios_xcode/...template_release.xcframework/
    │               ├─→ misc/dist/ios_xcode/...template_debug.xcframework/
    │               └─→ export/ios/gametwo.xcframework/
    │
    └─→ just package-ios-template [force]                [30 sec]
            ├─→ Check if templates/ios.zip exists
            └─→ zip xcframework → templates/ios.zip
```

---

### **iOS Deployment Levels**

#### **LEVEL 1: Launch Existing App (1-2 sec)**

```
just run-ios-iphone                                      [1-2 sec]
    │
    └─→ just install-ios-iphone-debug
            └─→ just _ios-launch-app "iphone" "debug"
                    ├─→ Validate device
                    ├─→ Select device: IOS_IPHONE_DEVICE_ID
                    ├─→ Validate app exists
                    ├─→ xcrun devicectl device process launch
                    └─→ No rebuild, no install - just launch

just run-ios-ipad                                        [1-2 sec]
    └─→ (Same flow, uses IOS_IPAD_DEVICE_ID)
```

**When to Use:**
- App already installed
- No code changes
- Quick restart
- Testing different configs

---

#### **LEVEL 2: Hot Reload (5-10 sec) ⚡**

```
just hotreload-ios-iphone                                [5-10 sec]
    │
    └─→ just _ios-hotreload "iphone" "debug"
            │
            ├─→ just ios-update-pck                      [3-5 sec]
            │       ├─→ just pre-build (pre-build hook)
            │       ├─→ Godot --export-pack iOS
            │       │       └─→ Creates .pck file with game content
            │       │
            │       └─→ xcrun devicectl device copy to
            │               └─→ Copy .pck to existing app bundle
            │
            └─→ just _ios-launch-app "iphone" "debug"    [1-2 sec]
                    └─→ Launch app with new content

just hotreload-ios-ipad                                  [5-10 sec]
    └─→ (Same flow, uses iPad device)
```

**When to Use:**
- GDScript changes
- Asset updates (scenes, textures, etc.)
- Rapid iteration cycles
- App already installed with correct binary

**What Changes:**
- Game content (.pck file)
- GDScript code
- Scenes, resources, assets

**What Doesn't Change:**
- Native binary (.app)
- C++ modules
- iOS frameworks

**Limitation:** Cannot update C++ code, native modules, or binary structure

---

#### **LEVEL 3: Full Install (2-5 min)**

```
just install-ios-iphone                                  [2-5 min]
    │
    └─→ just install-ios-iphone-debug
            └─→ just _ios-launch-app "iphone" "debug"
                    │
                    ├─→ Validate iOS workflow
                    ├─→ just pre-build (pre-build hook)
                    │
                    ├─→ Select device & build path
                    │       Device: IOS_IPHONE_DEVICE_ID
                    │       Build: export/ios/build/products/Debug-iphoneos/gametwo.app
                    │
                    ├─→ Validate .app exists
                    │
                    ├─→ xcrun devicectl device install app
                    │       └─→ Install complete .app bundle to device
                    │
                    └─→ xcrun devicectl device process launch
                            └─→ Launch installed app

just install-ios-ipad                                    [2-5 min]
    └─→ (Same flow, uses iPad device)

Variants:
    just install-ios-iphone-release                      [2-5 min]
    just install-ios-ipad-release                        [2-5 min]
        └─→ Uses Release build configuration
```

**When to Use:**
- C++ module changes
- iOS framework updates
- First-time installation
- After template rebuild
- Binary structure changes

**What Changes:**
- Complete .app bundle
- Native binary
- C++ modules
- Game content
- Everything

---

#### **LEVEL 4: Complete iOS Build + Install**

```
just build-install-ios                                   [varies]
    │
    ├─→ just build-ios-all [force]                       [varies]
    │       ├─→ Build iOS templates if needed
    │       ├─→ Build iOS app (Xcode)
    │       └─→ Package .app bundle
    │
    └─→ just install-ios-ipad                            [2-5 min]
            └─→ Install + launch on iPad
```

**When to Use:**
- Complete iOS rebuild
- Template updates
- Xcode project changes
- Major iOS updates

---

### **iOS Recipe Comparison**

| Recipe | Time | Rebuilds Binary | Updates Content | Reinstalls | Use Case |
|--------|------|-----------------|-----------------|------------|----------|
| `run-ios-*` | 1-2s | ❌ | ❌ | ❌ | Quick restart |
| `hotreload-ios-*` | 5-10s | ❌ | ✅ | ❌ | GDScript iteration |
| `install-ios-*` | 2-5m | ❌ | ✅ | ✅ | Full reinstall |
| `build-install-ios` | varies | ✅ | ✅ | ✅ | Complete rebuild |

---

## 🔄 Android Recipe Comparison

### **Android Deployment Levels**

#### **LEVEL 1: Launch Existing App (1-2 sec)**

```
just run-android                                         [1-2 sec]
    │
    ├─→ Clear persistent config
    │       └─→ just config-clear-android
    │
    └─→ Launch existing app
            └─→ adb am start -n com.primaryhive.gametwo/com.godot.game.GodotApp
```

**When to Use:**
- App already installed
- No code changes
- Quick restart
- Testing different configs

---

#### **LEVEL 2a: Install Existing APK (30 sec)**

```
just install-android                                     [30 sec]
    │
    └─→ just install-apk-android-debug
            └─→ just _android-install-apk "debug"
                    │
                    ├─→ Validate APK exists: export/android/gametwo_debug.apk
                    ├─→ Uninstall existing app
                    │       └─→ adb uninstall com.primaryhive.gametwo
                    │
                    └─→ Install + launch APK
                            ├─→ adb install gametwo_debug.apk
                            └─→ adb am start (launch)

Variants:
    just install-apk-android-debug                       [30 sec]
    just install-apk-android-release                     [30 sec]
```

**When to Use:**
- Pre-built APK exists
- No rebuild needed
- Testing specific APK artifact

**Requirement:** APK must exist in `export/android/`

---

#### **LEVEL 2b: Fast Build + Install (30-60 sec) ⚡ CRITICAL**

```
just fastbuild-android                                   [30-60 sec]
    │
    └─→ just export-install-launch-debug
            │
            ├─→ just export-apk-debug                    [15-20 sec]
            │       └─→ Godot --export-debug to /tmp/
            │
            ├─→ just install-apk-debug                   [10-15 sec]
            │       ├─→ just insert-firebase-dependencies
            │       └─→ Gradle assembleStandardDebug
            │               └─→ Build from project/android/build/
            │
            └─→ just restart-android-app                 [5 sec]
                    ├─→ adb install
                    └─→ adb am start
```

**When to Use:**
- 🚨 **REQUIRED** after ANY code changes
- Rapid development iteration
- After `install-android-template`

**Critical:** This is the **fastest way** to test code changes on Android

---

#### **LEVEL 3: Quick Build (2-3 min)**

```
just quick-build-android                                 [2-3 min]
    │
    ├─→ just insert-firebase-dependencies
    └─→ just export-apk-android
            └─→ Godot --export-debug (Gradle internal)
                    Output: export/android/gametwo_debug.apk
```

**When to Use:**
- Templates already exist
- GDScript/asset changes
- Create export artifact
- No device installation needed

---

#### **LEVEL 4: Full Android Build (3-25 min)**

```
just build-all-android [force="no"]                      [3-25 min]
    │
    └─→ (See Pathway 2 - Complete hierarchy)
```

**When to Use:**
- Release builds
- Template rebuild needed
- First-time setup
- Complete Android rebuild

---

### **Android Recipe Comparison**

| Recipe | Time | Rebuilds Templates | Rebuilds APK | Installs | Use Case |
|--------|------|-------------------|--------------|----------|----------|
| `run-android` | 1-2s | ❌ | ❌ | ❌ | Quick restart |
| `install-android` | 30s | ❌ | ❌ | ✅ | Install existing APK |
| `fastbuild-android` ⚡ | 30-60s | ❌ | ✅ | ✅ | **Dev iteration** |
| `quick-build-android` | 2-3m | ❌ | ✅ | ❌ | Export artifact |
| `build-all-android` | 3-25m | ✅ | ✅ | ❌ | Complete rebuild |

---

## 🎯 Testing Recipe Hierarchy

### **Multi-Platform Testing**

```
just test-all [CONFIG]                                   [varies]
    │
    ├─→ just test-desktop-target CONFIG                  [desktop time]
    │       └─→ (See Desktop Testing below)
    │
    └─→ just test-android-target CONFIG                  [android time]
            └─→ (See Android Testing below)
```

**When to Use:**
- Cross-platform validation
- Unified test reporting
- Pre-commit testing
- Regression testing

---

### **Android Automated Testing**

```
just test-android-target CONFIG                          [varies]
    │
    ├─→ just _test-setup-android CONFIG "enhanced"
    │       └─→ Display test header
    │
    ├─→ just _test-prepare-android CONFIG
    │       ├─→ just clear-android-test-cache
    │       └─→ just _validate-config-exists CONFIG
    │
    ├─→ just _test-check-android-device
    │       └─→ just _android-check-device-detailed
    │
    ├─→ Config resolution & wildcard expansion
    │       ├─→ Check if CONFIG is wildcard pattern
    │       ├─→ Expand @ symbols
    │       └─→ Generate temp configs if needed
    │
    ├─→ just _execute-android-test-target CONFIG
    │       │
    │       ├─→ Run test with config
    │       │       ├─→ just fastbuild-android (if needed)
    │       │       ├─→ Deploy config to device
    │       │       ├─→ Launch app with debug coordinator
    │       │       └─→ Wait for completion
    │       │
    │       ├─→ Extract logs
    │       │       └─→ just _extract-android-logs TEST_ID
    │       │
    │       ├─→ Checksum validation (if configured)
    │       │       ├─→ Extract checksums from logs
    │       │       ├─→ Compare with baseline
    │       │       └─→ Update baseline if needed
    │       │
    │       └─→ Error analysis
    │               └─→ just logs-errors TEST_ID
    │
    └─→ Display test summary
            ├─→ Test result (PASS/FAIL)
            ├─→ Checksum validation status
            └─→ Error count

Variants:
    just test-android-manual CONFIG                      [manual]
        └─→ Stays open for manual inspection

    just test-android-trace CONFIG                       [debug]
        └─→ Shows validation/config steps
```

**When to Use:**
- Automated testing with validation
- Checksum verification
- CI/CD integration
- Regression detection

**Features:**
- Automatic error analysis (98% token savings)
- Built-in checksum validation
- Baseline management
- Progressive failure detection

---

### **Desktop Automated Testing**

```
just test-desktop-target CONFIG                          [varies]
    │
    ├─→ just _test-setup-desktop CONFIG "automated"
    │       └─→ Display test header
    │
    ├─→ just _test-prepare-desktop CONFIG
    │       └─→ just _validate-config-exists CONFIG
    │
    ├─→ just _test-check-desktop-godot
    │       └─→ Validate Godot editor exists
    │
    ├─→ Config resolution & wildcard expansion
    │
    ├─→ just _execute-desktop-test-target CONFIG
    │       │
    │       ├─→ Run test with config
    │       │       ├─→ Deploy config
    │       │       ├─→ Launch Godot with debug coordinator
    │       │       └─→ Wait for completion
    │       │
    │       ├─→ Extract logs
    │       │       └─→ just _get-desktop-log-file
    │       │
    │       ├─→ Checksum validation (if configured)
    │       │
    │       └─→ Error analysis
    │               └─→ just logs-errors TEST_ID
    │
    └─→ Display test summary

Variants:
    just test-desktop-manual CONFIG                      [manual]
        └─→ Stays open for manual inspection
```

**When to Use:**
- Desktop platform testing
- Faster iteration than Android
- Cross-platform validation
- Development testing

---

### **Quick Testing**

```
just config-restart-android CONFIG                       [5 sec]
    │
    ├─→ just config-push-android CONFIG                  [2 sec]
    │       ├─→ just _validate-config-exists CONFIG
    │       ├─→ just _push-file-android config.json
    │       │       ├─→ Stop existing app
    │       │       ├─→ Launch to create directory
    │       │       ├─→ Stop immediately
    │       │       ├─→ Clear logcat buffer
    │       │       └─→ Push config file
    │       │
    │       └─→ Display success message
    │
    └─→ just run-android                                 [1-2 sec]
            └─→ Launch app with new config
```

**When to Use:**
- ⚡ **5-second iteration cycles**
- Config testing
- Action validation
- Rapid experimentation

**Limitation:** Only updates config, not code

---

## 🐛 Debug & Log Analysis Recipes

### **Token-Efficient Log Analysis (Progressive)**

#### **PHASE 1: Quick Error Scan (98% savings)**

```
just logs-errors TEST_ID                                 [<1 sec, <10 tokens]
    │
    └─→ Extract only errors and failures from logs
            ├─→ Filter for "ERROR", "FAIL", "TIMEOUT"
            └─→ Return minimal context
```

**When to Use:**
- First debugging step
- Quick pass/fail check
- Comprehensive test analysis
- CI/CD validation

---

#### **PHASE 2: Text Search (99% savings)**

```
just logs-text TEST_ID "search_term"                     [<1 sec, <5 tokens]
    │
    └─→ Simple case-insensitive text search
            ├─→ Find any occurrence of search term
            └─→ Return matching lines with context
```

**When to Use:**
- Find specific error messages
- Search for keywords
- Simple pattern matching
- Quick log inspection

---

#### **PHASE 3: Component Analysis (87-95% savings)**

```
just logs-android TEST_ID [TAGS...]                      [<2 sec, 50-200 tokens]
    │
    ├─→ Extract Android logs for TEST_ID
    ├─→ Filter by tags (optional)
    │       └─→ Examples: firebase, checksum, battle
    │
    └─→ Return filtered logs

just logs-desktop TEST_ID [TAGS...]                      [<2 sec, 50-200 tokens]
    └─→ (Same for desktop logs)
```

**When to Use:**
- Component-specific debugging
- Domain analysis
- Focused investigation

---

#### **PHASE 4: Pattern Matching (Wildcard System)**

```
just logs-pattern TEST_ID "pattern"                      [<2 sec, varies]
    │
    └─→ Wildcard pattern matching
            ├─→ Examples:
            │       "firebase.*" - All Firebase operations
            │       "*.error" - All error operations
            │       "game.battle.*" - All battle events
            │
            └─→ Return matching tagged logs

just logs-multi TEST_ID PATTERN1 PATTERN2                [<2 sec, varies]
    └─→ Multiple patterns with OR logic

just logs-exclude TEST_ID PATTERN EXCLUDE                [<2 sec, varies]
    └─→ Include pattern, exclude specific tags
```

**When to Use:**
- Cross-layer analysis
- Pattern discovery
- Advanced filtering
- Noise reduction

---

#### **PHASE 5: Structure Exploration**

```
just logs-tree TEST_ID                                   [<1 sec, minimal]
    │
    └─→ Hierarchical tag structure
            ├─→ Show tag hierarchy
            ├─→ Count operations per layer
            └─→ Discover available tags

just logs-discover TEST_ID PREFIX                        [<1 sec, minimal]
    └─→ Find tags starting with prefix
            └─→ Example: "firebase" → "firebase.auth", "firebase.rtdb"
```

**When to Use:**
- Understanding log structure
- Tag discovery
- System exploration
- Before targeted analysis

---

#### **PHASE 6: Precision Debugging (<200 tokens)**

```
just logs-tags TEST_ID TAG1 TAG2 ...                     [<2 sec, <200 tokens]
    │
    └─→ Exact tag filtering
            └─→ Only logs with specified tags
```

**When to Use:**
- Precise debugging
- Known issue investigation
- Minimal token usage

---

### **Full Android Device Logs**

```
just android-logs-search "SEARCH_TERM"                   [varies, complete]
    │
    └─→ Search complete device logs
            ├─→ adb logcat -d (full buffer)
            ├─→ Case-insensitive search
            └─→ Includes startup, initialization, everything
```

**When to Use:**
- ⚡ Missing logs in test results
- Startup/initialization debugging
- Fastbuild validation
- Complete log view needed

**Critical:** Use when test result logs are incomplete or missing

---

### **Android Device Log Monitoring**

```
just android-logs-live [DURATION] [FILTER] [COUNT]       [live]
    │
    └─→ Live log monitoring
            ├─→ Real-time logcat streaming
            ├─→ Optional filter level
            └─→ Optional line count limit

just android-logs-errors [DURATION]                      [live]
    └─→ Monitor only errors

just android-logs-tagged "TAG" [DURATION] [COUNT]        [live]
    └─→ Monitor specific tag

just android-logs-status                                 [instant]
    └─→ Device & app status

just android-logs-clear                                  [instant]
    └─→ Clear logcat buffer
```

**When to Use:**
- Live debugging
- Real-time monitoring
- Error detection
- Device diagnostics

---

## 🔧 Validation & CI/CD Recipes

### **Complete Validation**

```
just validate                                            [varies]
    │
    ├─→ just format                                      [<30 sec]
    │       └─→ Auto-format all GDScript files
    │
    ├─→ just validate-gdscript                           [<30 sec]
    │       └─→ Syntax validation
    │
    └─→ just validate-godot                              [1-2 min]
            └─→ Runtime validation (headless mode)
```

**When to Use:**
- During development
- Before testing
- Local validation

---

### **CI Validation (MANDATORY Before Commit)**

```
just ci-validate                                         [3-5 min]
    │
    ├─→ just ci-validate-desktop                         [2-3 min]
    │       │
    │       ├─→ just format                              [<30 sec]
    │       ├─→ just godot-import                        [<30 sec]
    │       │       └─→ Reimport project assets
    │       ├─→ just lint                                [<30 sec]
    │       ├─→ just validate-godot                      [1-2 min]
    │       └─→ just show-warnings                       [<30 sec]
    │
    └─→ just ci-validate-android                         [2-3 min]
            │
            ├─→ just format                              [<30 sec]
            ├─→ just godot-import                        [<30 sec]
            ├─→ just lint                                [<30 sec]
            ├─→ just validate-godot                      [1-2 min]
            └─→ just show-warnings-android               [<30 sec]
```

**When to Use:**
- 🚨 **MANDATORY** before every commit
- Pre-commit hook
- CI/CD pipeline
- Release validation

**Critical:** Ensures code quality, formatting, and platform compatibility

---

## 🎮 Gamestate & Replay Recipes

### **Gamestate Capture Workflow**

```
1. Play game → Debug menu → "Save State" → Exit

2. just capture-gamestate-desktop "scenario_name"        [<5 sec]
    │
    ├─→ Extract latest desktop log
    │       └─→ just _get-desktop-log-file
    │
    ├─→ Search for "GAMESTATE_SAVE_DATA"
    ├─→ Extract JSON gamestate data
    ├─→ Save to project/debug/saved_states/scenario_name.json
    └─→ Display success message

3. just capture-gamestate-android "scenario_name"        [<5 sec]
    └─→ (Same flow, uses Android logs)

4. just list-saved-states                                [instant]
    └─→ Show all saved states

5. Load in game: Debug menu → "Saved States" → Select scenario
```

**When to Use:**
- Scenario reproduction
- Bug investigation
- Regression testing
- Cross-platform testing (capture Android, load desktop - 90% faster)

---

### **Replay Generation Workflow**

```
1. Play game → Record session → Note SESSION_ID

2. just replay-generate-desktop SESSION_ID "config-name" [<5 sec]
    │
    ├─→ Extract desktop log for SESSION_ID
    ├─→ Parse battle actions
    ├─→ Generate debug config JSON
    │       └─→ tests/debug_configs/config-name.json
    │
    └─→ Display success message

3. just test-android-target config-name                  [automated]
    └─→ Replay battle with automated testing
```

**When to Use:**
- Battle replay testing
- Determinism validation
- Regression detection
- Automated testing generation

---

## 📊 Recipe Decision Matrix

### **"I need to build..."**

| Scenario | Use This | Time | Why |
|----------|----------|------|-----|
| First-time setup | `just build` | 46m | Complete toolchain |
| C++ changes | `just cpp-dev` ⭐ | 3-16m | One-command workflow |
| GDScript changes (Android) | `just fastbuild-android` ⚡ | 30-60s | **REQUIRED** before testing |
| iOS rebuild | `just build-install-ios` | 2-5m | Complete iOS flow |
| Release build | `just build-all-android` | 3-25m | Full pipeline |
| Templates only | `just build-android-templates` | 3-15m | C++ without full build |

### **"I need to test..."**

| Scenario | Use This | Time | Why |
|----------|----------|------|-----|
| Quick iteration | `just config-restart-android CONFIG` ⚡ | 5s | Fastest testing |
| Automated testing | `just test-android-target CONFIG` | varies | Validation included |
| Cross-platform | `just test-all [CONFIG]` | varies | Unified reporting |
| Manual inspection | `just test-android-manual CONFIG` | varies | Stays open |
| Comprehensive | `just test-android test-all` | varies | 15 configs |

### **"I need to debug..."**

| Scenario | Use This | Savings | Why |
|----------|----------|---------|-----|
| Quick error scan | `just logs-errors TEST_ID` ⚡ | 98% | Start here |
| Text search | `just logs-text TEST_ID "term"` ⚡ | 99% | Simple search |
| Pattern matching | `just logs-pattern TEST_ID "firebase.*"` | 90-95% | Wildcards |
| Component focus | `just logs-android TEST_ID firebase` | 87-95% | Domain analysis |
| Missing logs | `just android-logs-search "term"` | complete | Full device view |
| Structure | `just logs-tree TEST_ID` | minimal | Discover tags |

### **"I need to deploy..."**

| Scenario | Use This | Time | Why |
|----------|----------|------|-----|
| Quick restart (iOS) | `just run-ios-iphone` | 1-2s | No rebuild |
| GDScript changes (iOS) | `just hotreload-ios-iphone` ⚡ | 5-10s | Content only |
| Full install (iOS) | `just install-ios-iphone` | 2-5m | Complete binary |
| Quick restart (Android) | `just run-android` | 1-2s | No rebuild |
| Code changes (Android) | `just fastbuild-android` ⚡ | 30-60s | **REQUIRED** |
| Existing APK (Android) | `just install-android` | 30s | Pre-built APK |

---

## 🚨 Critical Business Rules

### **Build Requirements**

1. **After ANY GDScript/C++ changes before Android testing:**
   ```bash
   just fastbuild-android  # ⚡ MANDATORY
   ```

2. **Before every commit:**
   ```bash
   just ci-validate  # 🚨 MANDATORY
   ```

3. **After C++ changes (recommended):**
   ```bash
   just cpp-dev  # ⭐ One command: build → install → deploy
   ```

4. **After template building:**
   ```bash
   just install-android-template  # Required before fastbuild
   just fastbuild-android          # Required for testing
   ```

### **Testing Requirements**

1. **Use `test-*` commands, NOT `run-*` for debug actions:**
   - ✅ `just test-android-target CONFIG` (enables debug coordinator)
   - ❌ `just run-android` (debug actions won't execute)

2. **Progressive debugging workflow:**
   ```bash
   just logs-errors TEST_ID              # 1. Quick scan
   just logs-text TEST_ID "term"         # 2. Simple search
   just logs-pattern TEST_ID "pattern"   # 3. Wildcards
   just logs-android TEST_ID component   # 4. Deep dive
   ```

3. **Missing logs? Use full device logs:**
   ```bash
   just android-logs-search "term"  # Complete view including startup
   ```

### **Workflow Patterns**

#### **Daily Development (OODA Loop)**
```bash
just ci-validate           # OBSERVE: Code quality
just fastbuild-android     # ORIENT: Deploy changes
just test-android-target CONFIG  # DECIDE: Automated testing
just logs-errors TEST_ID   # ACT: Quick analysis
```

#### **C++ Development**
```bash
just cpp-dev  # ⭐ ONE COMMAND: template → install → deploy
```

#### **Pre-Commit**
```bash
just ci-validate           # 🚨 MANDATORY
just test-android test-all # Comprehensive
just logs-errors TEST_ID   # Verify
```

---

## 📖 Summary

This document provides:
- ✅ **Complete recipe call chains** showing every subrecipe
- ✅ **Decision criteria** for choosing the right recipe
- ✅ **Time estimates** for planning workflows
- ✅ **When to use** guidance for every major recipe
- ✅ **Critical differences** between similar recipes (hotreload vs install)
- ✅ **Business rules** ensuring correct usage

**Key Principles:**
1. **Start efficient** - Use token-saving log commands first
2. **Use the right tool** - Match recipe to task (hotreload for content, install for binary)
3. **Follow requirements** - `fastbuild-android` after code changes, `ci-validate` before commits
4. **One command when possible** - Use `cpp-dev` for C++ workflow
5. **Progressive debugging** - errors → text → pattern → component → precision

This is **critical business infrastructure** - using the right recipe at the right time ensures:
- ⚡ Faster iteration
- ✅ Correct builds
- 🎯 Efficient debugging
- 🚨 Quality validation
- 💰 Cost efficiency (token savings)
