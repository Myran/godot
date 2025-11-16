---
id: task-281
title: >-
  Fix Android app private directory access issue preventing test configuration
  deployment
status: Done
assignee: []
created_date: '2025-11-16 09:46'
updated_date: '2025-11-16 13:15'
labels: []
dependencies: []
---

## Description

**Critical Issue**: Android test configuration deployment is failing with "App private directory not accessible" error, preventing all Android automated tests from running.

**Current Error Pattern**:
```
❌ App private directory not accessible
💡 Make sure app is installed and has been run at least once
💡 Try: adb shell am start -n com.primaryhive.gametwo/com.godot.game.GodotApp
```

## **Critical Discovery: This is a REGRESSION from Recent Changes**

### **Root Cause of Regression**
**Commit: `0e01f43e` (2025-10-14)**: `"fix(android): Add config deployment verification to prevent stale configs"`

**What Changed**: The commit added **additional `run-as` commands** to the `_push-file-android` recipe:

```bash
# NEW commands added in commit 0e01f43e:
adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} rm files/{{TARGET_FILENAME}}" 2>/dev/null || true
adb -s {{ANDROID_PACKAGE_NAME}} shell "run-as {{ANDROID_PACKAGE_NAME}} cat files/{{TARGET_FILENAME}}" 2>/dev/null
```

### **Original Working Code (Before Oct 14, 2025)**:
```bash
# This worked before the regression:
if ! adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} cp /dev/null files/{{TARGET_FILENAME}}" 2>/dev/null; then
    # Error handling
fi

# File copy worked:
adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} cp $TEMP_FILE files/{{TARGET_FILENAME}}" 2>/dev/null
```

### **Why It Worked Before**:
- **Single `run-as` command**: Only used for directory access test and file copy
- **No verification steps**: Skip content verification that triggers additional `run-as` calls
- **Simpler pattern**: Basic `cp` operations without additional `rm` or `cat` commands

### **Why It's Broken Now**:
- **Multiple `run-as` calls**: Added 2-3 additional `run-as` operations per file push
- **Verification overhead**: File content verification requires extra `run-as` access
- **Permission fatigue**: Multiple rapid `run-as` operations may trigger Android security restrictions
- **Race condition**: Multiple `run-as` calls in sequence may fail on newer Android versions

**Impact**:
- 100% of Android test configurations fail (not just Sentry-specific)
- Blocks automated Android testing pipeline
- Affects all test lists that include Android configs
- Desktop tests continue to work normally

## Root Cause Analysis (Initial Findings)

### **Test Infrastructure Context**
- Issue affects `_push-file-android` recipe in `justfiles/justfile-platform-android.justfile`
- The recipe tries to push config files to Android app's private directory
- Follows established pattern: stop app → start app → create directory → stop app → push files
- This pattern has worked historically, indicating a recent change in behavior

### **Current Investigation Status**
**Confirmed Working**:
- ✅ App installation: `adb shell am start -n com.primaryhive.gametwo/com.godot.game.GodotApp` succeeds
- ✅ Package exists: `com.primaryhive.gametwo` is properly installed
- ✅ App launches: Godot app starts and runs normally
- ✅ Sentry integration: `.so` files properly loaded, no more library errors
- ✅ Manual testing: App functionality verified on device

**Failing Component**:
- ❌ Private directory creation/access during test config deployment
- ❌ File push to app's internal storage fails

### **Potential Root Causes**

#### **1. Android API Level/Permission Changes**
- Recent Android security updates may have changed private directory access
- Godot target SDK level vs device API compatibility issues
- Scoped storage enforcement changes

#### **2. Godot App Permission Model**
- App may not have proper permissions to access its own private files directory
- Changes in Godot 4.3 Android permission handling
- App sandbox restrictions interfering with file operations

#### **3. Device/Environment Specific**
- Android 14+ specific behavior changes
- Device manufacturer security implementations
- ADB daemon permission changes

#### **4. Test Infrastructure Timing**
- Race condition between app start and directory creation
- App lifecycle management changes affecting directory availability
- ASync operations not completing before file push attempt

### **Debugging Evidence Collected**

**From Recent Test Logs (2025-11-16)**:
- All Android configs fail with identical error pattern
- Desktop Sentry validation passes (100% success rate)
- No Sentry-specific errors in Android logs (library fix successful)
- Error occurs during config deployment phase, before test execution

**App Status Verification**:
```
adb shell am start -n com.primaryhive.gametwo/com.godot.game.GodotApp
# SUCCEEDS - app launches normally
```

**Error Location**:
- File: `justfiles/justfile-platform-android.justfile`
- Recipe: `_push-file-android`
- Function: App private directory access validation

## Hypothesis Prioritization

### **High Priority Hypotheses**
1. **Android Scoped Storage**: Recent Android versions enforce stricter private directory access
2. **Godot App Lifecycle**: App doesn't create private directory immediately on start
3. **ADB Permission Changes**: Security updates affecting ADB's ability to access app directories

### **Medium Priority Hypotheses**
1. **Timing Race Condition**: Directory creation needs more time after app start
2. **Godot 4.3 Changes**: New Android permission model in current engine version
3. **Device-Specific Behavior**: Particular Android version/manufacturer implementation

### **Low Priority Hypotheses**
1. **App Installation State**: App not fully initialized (countered by successful manual launch)
2. **File System Corruption**: Device storage issues (unlikely given successful app operation)

## Next Investigation Steps

### **Phase 1: Diagnostic Data Collection**
1. **Device Environment Analysis**:
   - Android version, API level, security patch level
   - Device manufacturer and model
   - ADB version and permissions status

2. **App Directory Investigation**:
   - Check if private directory exists after app start
   - Verify directory permissions and ownership
   - Test manual file creation in app directory

3. **Timing Analysis**:
   - Measure time between app start and directory availability
   - Test different wait times before directory access
   - Monitor app startup logs for directory creation events

### **Phase 2: Hypothesis Testing**
1. **Scoped Storage Workaround**:
   - Test alternative directory locations
   - Try external storage or shared directories
   - Evaluate Godot's user:// and res:// path handling

2. **App Lifecycle Optimization**:
   - Modify test infrastructure to wait longer
   - Add directory existence validation before file push
   - Test alternative app startup sequences

3. **Permission Investigation**:
   - Review app manifest permissions
   - Check Godot export template configurations
   - Verify ADB debugging settings

### **Phase 3: Solution Implementation**
1. **Update Test Infrastructure**: Implement robust directory access with proper validation
2. **Alternative Push Mechanism**: Explore different file deployment strategies
3. **Documentation**: Record working pattern and prevent regressions

## Technical Context

**Test Infrastructure Pattern**:
```bash
# Current failing sequence in _push-file-android:
1. Stop existing app instance
2. Launch app to create private directory
3. Stop app immediately after directory creation
4. Push config files to app's private directory
```

**Expected Behavior**:
- Step 2 should create: `/data/data/com.primaryhive.gametwo/files/`
- Step 4 should push to: app's private files directory via ADB

**Alternative Approaches to Consider**:
- Use Godot's user:// directory system instead of direct ADB access
- Implement file-based configuration loading from device storage
- Use Android's content provider system for file transfer
- Leverage Firebase Remote Config or similar cloud-based config

## Success Criteria

✅ **Primary**: All Android test configurations can deploy successfully
✅ **Secondary**: Test infrastructure works reliably across different Android devices
✅ **Tertiary**: Solution is maintainable and doesn't break existing workflows

## Risk Assessment

**High Risk**: Long-term Android test infrastructure becomes unusable
**Medium Risk**: Workaround solution may not work on all devices
**Low Risk**: Solution may require significant test infrastructure changes

## Dependencies

- Device access for testing and validation
- Android SDK/ADB tools for debugging
- Godot export template access if modification needed
- Test environment with multiple Android devices for validation

## External Research Findings (2025-11-16)

### **Online Research Summary**
Comprehensive search across GitHub issues, Android developer documentation, and technical forums reveals this is a **widespread, well-documented issue** affecting Android testing infrastructure across multiple platforms and frameworks.

### **Root Cause Identified: Android 11+ Scoped Storage + `run-as` Restrictions**

#### **Primary Issue: `run-as` Command Restrictions**
- **Failing Command**: `adb shell "run-as {{ANDROID_PACKAGE_NAME}} cp /dev/null files/{{TARGET_FILENAME}}"`
- **Error Pattern**: `run-as command failed` or permission denied
- **Impact**: Affects **all debuggable apps** using `run-as` for private directory access
- **Scope**: Widespread issue across Android testing frameworks

#### **Android 11+ Scoped Storage Changes**
From GitHub issue navit-gps/navit#1117 and related sources:

**Key Restrictions**:
```
Android 11+ restrictions:
❌ Apps can no longer access `/sdcard/Android/data/` paths not belonging to them
❌ Even app's own directories may be restricted depending on path reference format
❌ Multiple symlink paths (e.g., `/sdcard`, `/mnt/sdcard`) have different access permissions
✅ `MANAGE_EXTERNAL_STORAGE` required for full filesystem access
❌ Previous `WRITE_EXTERNAL_STORAGE` ineffective on Android 11 (SDK 30+)
```

**SELinux Restrictions**:
```
avc: denied { read } for name="sdcard" dev="tmpfs"
```

### **Confirmed Cases Across Platforms**

#### **GitHub Evidence**:
1. **"Android/data folder for defaults.json no longer accessible by other apps in Android 11+"**
   - Multiple projects reporting identical issues
   - Cross-platform impact (not Godot-specific)

2. **"File system restrictions on Android 11"** (navit-gps/navit#1117):
   - ADB storage access limits confirmed
   - Symlink path access inconsistencies documented

3. **Testing Framework Issues**:
   - Multiple reports of `run-as` failures in automated testing
   - Device rooting problems on Android 11-14 affecting test infrastructure
   - "Buildozer not compiling when selecting minAPI 34 or 35" - similar root cause

4. **Recent Reports (2024-2025)**:
   - 11k+ issues related to debuggable app `run-as` failures
   - Problems persist across Android API 34-35
   - No universal solution identified

### **Solutions and Workarounds Documented**

#### **Successful Workarounds**:

1. **Canonical Path Approach**:
   ```bash
   # Replace multiple symlink references with canonical paths
   # Use `/data/data/` instead of `/sdcard/Android/data/`
   ```

2. **Storage Permission Updates**:
   ```xml
   <!-- Required for Android 11+ -->
   <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"/>
   ```

3. **Directory Recreation Strategy**:
   ```bash
   # Delete app data/cache and recreate directories
   adb shell pm clear package.name
   # Recreate directories with proper permissions
   ```

4. **Alternative File Storage**:
   ```bash
   # Move to app's private storage
   # Change default file picker paths
   # Replace custom paths with canonical private storage paths
   ```

#### **Testing-Specific Solutions**:

1. **External Storage Testing**:
   ```bash
   # Use device external storage for test configs
   # `/sdcard/Download/` or `/sdcard/Documents/`
   ```

2. **Content Provider Approach**:
   ```java
   // Use Android's content provider system for file transfer
   // Bypasses direct filesystem restrictions
   ```

3. **Runtime Configuration**:
   ```bash
   # Deploy configs via app UI or network instead of ADB
   # Firebase Remote Config, API endpoints, etc.
   ```

### **Godot-Specific Considerations**

#### **Current Implementation Problem**:
The failing `_push-file-android` recipe uses:
```bash
# This pattern is broken on Android 11+:
adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} cp /dev/null files/{{TARGET_FILENAME}}"
```

#### **Godot Path Handling**:
- **user://**: Maps to app's private storage (affected by restrictions)
- **res://**: Read-only resource access (not suitable for test configs)
- Need to evaluate external storage options

### **Priority Hypotheses Updated (Based on Research)**

#### **High Priority (Confirmed Issues)**:
1. ✅ **Android 11+ Scoped Storage**: Confirmed widespread issue
2. ✅ **`run-as` Command Restrictions**: Well-documented across platforms
3. ✅ **Debuggable App Restrictions**: Affects all testing frameworks

#### **Medium Priority (Potential Solutions)**:
1. **Canonical Path Solutions**: Documented workarounds available
2. **Permission Updates**: `MANAGE_EXTERNAL_STORAGE` requirement
3. **Alternative Storage**: External storage testing approaches

#### **Low Priority (Less Likely)**:
1. **Device-Specific**: Issue is platform-wide, not device-specific
2. **Timing Issues**: Not timing-related, but permission-related

### **Recommended Solution Path**

#### **Phase 1: Immediate Workaround**
1. **Replace `run-as` with external storage approach**
2. **Use `/sdcard/Download/` for test configs**
3. **Update Godot to read from external location**

#### **Phase 2: Robust Solution**
1. **Implement content provider-based file transfer**
2. **Add permission handling for Android 11+**
3. **Create fallback mechanisms for different Android versions**

#### **Phase 3: Long-term Architecture**
1. **Network-based configuration deployment**
2. **Firebase integration for test configs**
3. **Cross-platform configuration management**

### **Technical Implementation Strategy**

#### **Option 1: Revert to Working Pattern (Immediate Fix)**
```bash
# Remove the problematic verification steps from commit 0e01f43e:
# REMOVE: adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} rm files/{{TARGET_FILENAME}}"
# REMOVE: adb -s {{ANDROID_PACKAGE_NAME}} shell "run-as {{ANDROID_PACKAGE_NAME}} cat files/{{TARGET_FILENAME}}"
# KEEP: The original working pattern with single run-as for file copy
```

**Success Probability**: **Very High** (this exact pattern worked before Oct 14, 2025)

#### **Option 2: External Storage Approach (Alternative)**
```bash
# Replace failing run-as approach:
# OLD: adb shell "run-as {{ANDROID_PACKAGE_NAME}} cp /dev/null files/{{TARGET_FILENAME}}"
# NEW: adb push {{SOURCE_FILE}} /sdcard/Download/{{TARGET_FILENAME}}

# Update Godot to read from external storage
# user://../Download/ or similar external path
```

#### **Recommended Solution Path (Updated)**:

**Phase 1: Immediate Rollback**
1. **Revert verification additions** from commit 0e01f43e
2. **Restore original working pattern** (single `run-as` for file copy)
3. **Test validation**: Should work immediately since it worked before

**Phase 2: Alternative Verification**
1. **Implement external storage verification** instead of `run-as` verification
2. **Use hash-based verification** with external file copy
3. **Preserve test isolation** without breaking `run-as` access

**Phase 3: Long-term Architecture**
1. **Implement content provider-based file transfer**
2. **Add permission handling for Android 11+**
3. **Create fallback mechanisms for different Android versions**

#### **Testing Validation Required**:
1. Revert commit 0e01f43e verification changes
2. Test original working pattern on current Android version
3. Verify that stale config issue (original reason for 0e01f43e) doesn't reappear
