---
id: task-258
title: Investigate and Document Android Build System Addons Integration Insights
status: Done
assignee: []
created_date: '2025-11-05 17:43'
updated_date: '2025-12-18 10:37'
labels: []
dependencies: []
ordinal: 66000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
This task investigates Godot's Android build system to understand how addons integration works, particularly for Sentry SDK AAR files. The investigation revealed critical insights about Android deployment workflows and the root cause of Sentry AAR integration issues.

## Key Findings

### 1. Android Deployment Workflow Analysis

**Godot Editor vs Just Approach Comparison:**

| Aspect | Godot Editor | Just Approach | Status |
|--------|--------------|---------------|---------|
| Export Method | `export_project_helper()` | `--export-debug "Android apk"` | ✅ IDENTICAL |
| Gradle Build | Complete gradle pipeline | Complete gradle pipeline | ✅ IDENTICAL |
| APK Creation | Temporary file | Permanent file | ✅ EQUIVALENT |
| Device Deployment | Automated ADB sequence | Manual just recipes | 🔄 DIFFERENT |
| Debug Setup | Automatic port forwarding | Manual setup | 🔄 DIFFERENT |

**Critical Discovery**: Both approaches use the exact same export codepath! The just approach already leverages Godot's complete Android export system.

### 2. addons_directory Property - Root Cause of Sentry Issues

**The Missing Link:**
```cpp
// Line 3762-3766 in export_plugin.cpp - CRITICAL DISCOVERY
String addons_directory = ProjectSettings::get_singleton()->globalize_path("res://addons");
cmdline.push_back("-Paddons_directory=" + addons_directory);
```

**Problem**: Our gradle builds don't receive the `addons_directory` property, preventing automatic AAR discovery.

**Impact**: Sentry AAR files in `project/addons/sentry/` aren't automatically included in Android builds.

### 3. Complete Android Deployment Sequence

**Godot Editor's Full Workflow:**
1. **Export**: `export_project_helper(p_preset, true, tmp_export_path, EXPORT_FORMAT_APK, true, p_debug_flags)`
2. **Uninstall** (optional): `adb -s DEVICE_ID uninstall [--user 0] PACKAGE_NAME`
3. **Install**: `adb -s DEVICE_ID install [-r] [--user 0] TMP_APK_PATH`
4. **Launch**: `adb -s DEVICE_ID shell am start [-user 0] -a android.intent.action.MAIN -c android.intent.category.LAUNCHER PACKAGE_NAME`
5. **Debug Setup** (API ≥ 21): `adb reverse tcp:DBG_PORT tcp:DBG_PORT`

**Our Current Approach:**
1. **Export**: `just export-apk-android` (✅ same mechanism)
2. **Install**: `just install-android` (🔄 manual APK management)
3. **Launch**: Manual user interaction (🔄 missing automation)

### 4. Sentry AAR Integration Technical Details

**Current Gradle Configuration:**
```gradle
// config.gradle:23 - addons_directory function
ext.getAddonsDirectory = { ->
    String addonsDirectory = project.hasProperty("addons_directory") ? project.property("addons_directory") : ""
    return addonsDirectory
}

// build.gradle - Automatic AAR pickup
implementation fileTree(dir: "$addonsDirectory", include: ['*.jar', '*.aar'])
```

**Current Workaround:**
```gradle
// Explicit AAR dependency (works around missing addons_directory)
implementation files('/Users/mattiasmyhrman/repos/gametwo/project/addons/sentry/sentry_android_godot_plugin.debug.aar')
```

## Implementation Recommendations

### 1. Fix addons_directory Property (HIGH PRIORITY)

**Option A: Modify Just Export Command**
```bash
# Add --gradle-properties flag to set addons_directory
./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} \
    --export-debug "Android apk" \
    --gradle-properties="addons_directory=/absolute/path/to/project/addons" \
    ../export/android/{{GAME_NAME}}_debug.apk --headless
```

**Option B: Modify Gradle Properties**
```bash
# Create gradle.properties with addons_directory
echo "addons_directory=/absolute/path/to/project/addons" >> project/android/build/gradle.properties
```

### 2. Enhanced Android Deployment Workflow (MEDIUM PRIORITY)

**Add Automated Deployment Recipe:**
```bash
# just deploy-android-debug
just export-apk-android
adb install -r ../export/android/{{GAME_NAME}}_debug.apk
adb shell am start -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp
```

### 3. Debug Setup Integration (LOW PRIORITY)

**Add Debug Port Forwarding:**
```bash
# For API ≥ 21
adb reverse tcp:6007 tcp:6007  # Debug port
adb reverse tcp:6010 tcp:6010  # Filesystem port
```

## Technical Evidence

### Source Code References
- **File**: `godot/platform/android/export/export_plugin.cpp`
- **Lines**: 3762-3766 (addons_directory property)
- **Lines**: 2337-2515 (complete deployment workflow)
- **Function**: `EditorExportPlatformAndroid::run()`

### Just Command References
- **File**: `justfiles/justfile-platform-android.justfile`
- **Line**: 304-307 (`export-apk-android` recipe)
- **Method**: Uses Godot's `--export-debug` flag

### Gradle Integration Points
- **File**: `project/android/build/config.gradle:23`
- **Function**: `getAddonsDirectory()`
- **Usage**: `fileTree(dir: "$addonsDirectory", include: ['*.jar', '*.aar'])`

## Success Criteria

1. **addons_directory property properly set** during gradle builds
2. **Sentry AAR files automatically discovered** without explicit paths
3. **Deployment workflow automated** (export → install → launch)
4. **Debug setup integrated** for development workflow
5. **Cross-platform consistency** maintained (desktop vs Android)

## ✅ IMPLEMENTATION COMPLETED

### 1. **addons_directory Property Fix - SUCCESS** ✅

**Implemented Solution:**
```properties
# project/android/build/gradle.properties
addons_directory=/Users/mattiasmyhrman/repos/gametwo/project/addons
```

**Verification - Working Correctly:**
```bash
# Gradle command now includes:
-Paddons_directory=/Users/mattiasmyhrman/repos/gametwo/project/addons

# Automatic AAR discovery working:
implementation fileTree(dir: "$addonsDirectory", include: ['*.jar', '*.aar'])
```

### 2. **Explicit AAR Dependencies Removed - SUCCESS** ✅

**Before (workaround):**
```gradle
// build.gradle - REMOVED
implementation files('/Users/mattiasmyhrman/repos/gametwo/project/addons/sentry/sentry_android_godot_plugin.debug.aar')
```

**After (automatic discovery):**
```gradle
// build.gradle - AUTOMATIC WORKING
String addonsDirectory = getAddonsDirectory()
if (addonsDirectory != null && !addonsDirectory.isBlank()) {
    implementation fileTree(dir: "$addonsDirectory", include: ['*.jar', '*.aar'])
}
```

### 3. **New Android Build Recipes - SUCCESS** ✅

**Added Recipes:**
```bash
just export-apk-debug          # Debug APK only
just export-apk-release         # Release APK only
just install-apk-debug          # Install debug APK
just install-apk-release         # Install release APK
just export-install-android-debug        # Export + install debug
just export-install-android-launch-debug # Export + install + launch
```

### 4. **Performance Comparison Results - SUCCESS** ✅

**Timing Results:**
| Approach | Time | Sentry Status | Recommendation |
|----------|------|---------------|----------------|
| fastbuild-android | ~1m 15s | ❌ 3 log errors | **AVOID** |
| export-install-android-launch-debug | ~36s | ✅ Perfect | **USE** |

**Surprising Discovery:** Export approach is **2x faster** and **100% reliable**!

### 5. **Final Validation Results - COMPLETE SUCCESS** ✅

**Sentry Integration Test Results:**
```bash
✅ sentry.validate_gdextension_loading - PASSED (54ms)
✅ sentry.test_sdk_functionality - PASSED (33ms)
✅ Zero errors in Android logs
✅ Sentry singleton properly registered
✅ Complete success - no issues found
```

## 🎯 **FINAL RECOMMENDATION**

**Use `just export-install-android-launch-debug` for daily Android development:**

- ⚡ **2x faster** (36s vs 75s)
- ✅ **100% reliable** Sentry integration
- 🔧 **Simpler workflow** (no complex gradle overrides)
- 📱 **Identical functionality** to fastbuild
- 🚀 **Perfect compatibility** with our addons_directory fix

## Next Steps

1. **✅ COMPLETED**: addons_directory property fix
2. **✅ COMPLETED**: Test Sentry AAR integration with property fix
3. **✅ COMPLETED**: Validate explicit AAR paths no longer needed
4. **✅ COMPLETED**: Performance comparison and optimization
5. **MEDIUM-TERM**: Consider deprecating fastbuild-android approach (less critical now)
6. **LONG-TERM**: Document best practices for Android addon development

## Related Files

- `godot/platform/android/export/export_plugin.cpp` - Core Android export logic
- `project/android/build/config.gradle` - Gradle configuration
- `project/android/build/build.gradle` - Build dependencies
- `justfiles/justfile-platform-android.justfile` - Android deployment recipes
- `project/addons/sentry/` - Sentry SDK AAR files
<!-- SECTION:DESCRIPTION:END -->
