---
id: task-259
title: >-
  Implement Build-Time Sentry Android SDK Integration for Complete Error
  Coverage
status: To Do
assignee: []
created_date: '2025-11-06 10:54'
labels: []
dependencies: []
---

## Description

Implement build-time injection of Sentry Android SDK into Godot's Android export system to provide complete error coverage including GDScript, native C++, Java/Kotlin, ANR monitoring, profiling, and session replay.

## Current State Analysis

**Investigation completed** - Godot's Android build system uses SCons to generate `android_source.zip` from source templates. The build recipe `build-android-templates` creates templates that are used during Godot's export process.

**Key Discovery**: `android_source.zip` is built dynamically from `godot/platform/android/java/` source files, not a static template. This enables build-time injection of Sentry Android SDK into the generated templates.

## Implementation Plan

### **Phase 1: Firebase-Style Template Injection Integration**

#### **Key Insight: Use Proven Firebase Template Injection Pattern**

**Simplification Decision**: Use the same template injection pattern as Firebase instead of complex build-time source modification. This provides:
- ✅ **Proven pattern** - Already works reliably for Firebase
- ✅ **Simple implementation** - Just placeholder markers + content replacement
- ✅ **Easy maintenance** - Same workflow as existing Firebase integration
- ✅ **No SCons complexity** - Uses existing `tools/replace_content.py` infrastructure

#### **Required Files to Modify:**

1. **Add Sentry Placeholders to Godot Android Source**
   - `godot/platform/android/java/app/build.gradle` - Add Sentry placeholder markers
   - `godot/platform/android/java/app/src/main/AndroidManifest.xml` - Add Sentry meta-data placeholder

2. **Justfile Template Injection Recipe**
   - `justfiles/justfile-build-utils.justfile` - Add `insert-sentry-dependencies` recipe
   - `justfiles/justfile-platform-android.justfile` - Integrate Sentry injection into build recipes

#### **Implementation Steps with Template Injection:**

##### **Step 1: Add Sentry Plugin Placeholder to Godot Android build.gradle**
- **Location**: `godot/platform/android/java/app/build.gradle`
- **Add in plugins section** (after existing plugins):
  ```gradle
  plugins {
      id 'com.android.application'
      id 'org.jetbrains.kotlin.android'
      //ADD_SENTRY_PLUGINS_HERE_
  }
  ```

**Key Simplification**: Unlike Firebase, Sentry only needs the plugin placeholder - no buildscript or dependencies placeholders needed because:
- **Sentry plugin 5.12.2 automatically adds SDK 8.25.0**
- **No manual dependencies required** - plugin handles everything
- **No buildscript needed** - plugin works without additional classpath

##### **Step 2: Add Sentry Manifest Placeholder**
- **Location**: `godot/platform/android/java/app/src/main/AndroidManifest.xml`
- **Add in application section** (after existing meta-data):
  ```xml
  <application android:label="@string/godot_project_name_string"
      android:allowBackup="false"
      android:icon="@mipmap/icon"
      android:isGame="true"
      android:hasFragileUserData="false"
      android:requestLegacyExternalStorage="false"
      android:appCategory="game"
      tools:replace="android:allowBackup,android:appCategory,android:isGame,android:hasFragileUserData,android:requestLegacyExternalStorage"
      tools:ignore="GoogleAppIndexingWarning">

      <!-- Existing Firebase meta-data -->
      <meta-data android:name="com.google.firebase.messaging.default_notification_icon" android:resource="@mipmap/ic_notification" />

      <!--ADD_SENTRY_METADATA_HERE_-->

      <!-- Existing Godot configuration remains unchanged -->
      <meta-data tools:node="replace" android:name="org.godotengine.rendering.method" android:value="gl_compatibility" />
      <!-- ... rest of existing meta-data ... -->
  </application>
  ```

##### **Step 3: Create Sentry Template Injection Recipe**
- **Location**: `justfiles/justfile-build-utils.justfile`
- **Add after Firebase recipe**:
  ```bash
  insert-sentry-dependencies:
      @echo "Preparing Sentry Android SDK dependencies..."

      # Sentry buildscript content - Only needed if we want to control version manually
      # Note: Sentry plugin 5.12.2 automatically adds SDK 8.25.0, so we don't need explicit buildscript

      # Sentry plugin content (Latest version 5.12.2)
      echo 'id "io.sentry.android.gradle" version "5.12.2"' > temp_sentry_plugin.txt

      # Sentry manifest metadata content (Complete from official documentation)
      echo '        <!-- Required: set your sentry.io project identifier (DSN) -->' > temp_sentry_metadata.txt
      echo '        <meta-data android:name="io.sentry.dsn" android:value="${sentryDsn}" />' >> temp_sentry_metadata.txt
      echo '' >> temp_sentry_metadata.txt
      echo '        <!-- Add data like request headers, user ip address and device name -->' >> temp_sentry_metadata.txt
      echo '        <meta-data android:name="io.sentry.send-default-pii" android:value="true" />' >> temp_sentry_metadata.txt
      echo '' >> temp_sentry_metadata.txt
      echo '        <!-- enable automatic breadcrumbs for user interactions (clicks, swipes, scrolls) -->' >> temp_sentry_metadata.txt
      echo '        <meta-data android:name="io.sentry.traces.user-interaction.enable" android:value="true" />' >> temp_sentry_metadata.txt
      echo '        <!-- enable screenshot for crashes -->' >> temp_sentry_metadata.txt
      echo '        <meta-data android:name="io.sentry.attach-screenshot" android:value="true" />' >> temp_sentry_metadata.txt
      echo '        <!-- enable view hierarchy for crashes -->' >> temp_sentry_metadata.txt
      echo '        <meta-data android:name="io.sentry.attach-view-hierarchy" android:value="true" />' >> temp_sentry_metadata.txt
      echo '' >> temp_sentry_metadata.txt
      echo '        <!-- enable the performance API by setting a sample-rate, adjust in production env -->' >> temp_sentry_metadata.txt
      echo '        <meta-data android:name="io.sentry.traces.sample-rate" android:value="1.0" />' >> temp_sentry_metadata.txt
      echo '' >> temp_sentry_metadata.txt
      echo '        <!-- Enable UI profiling, adjust in production env. This is evaluated only once per session -->' >> temp_sentry_metadata.txt
      echo '        <meta-data android:name="io.sentry.traces.profiling.session-sample-rate" android:value="1.0" />' >> temp_sentry_metadata.txt
      echo '        <!-- Set profiling mode. For more info see https://docs.sentry.io/platforms/android/profiling/#enabling-ui-profiling -->' >> temp_sentry_metadata.txt
      echo '        <meta-data android:name="io.sentry.traces.profiling.lifecycle" android:value="trace" />' >> temp_sentry_metadata.txt
      echo '        <!-- Enable profiling on app start. The app start profile will be stopped automatically when the app start root span finishes -->' >> temp_sentry_metadata.txt
      echo '        <meta-data android:name="io.sentry.traces.profiling.start-on-app-start" android:value="true" />' >> temp_sentry_metadata.txt
      echo '' >> temp_sentry_metadata.txt
      echo '        <!-- record session replays for 100% of errors and 10% of sessions -->' >> temp_sentry_metadata.txt
      echo '        <meta-data android:name="io.sentry.session-replay.on-error-sample-rate" android:value="1.0" />' >> temp_sentry_metadata.txt
      echo '        <meta-data android:name="io.sentry.session-replay.session-sample-rate" android:value="0.1" />' >> temp_sentry_metadata.txt

      @echo "Inserting Sentry configurations..."

      # Insert plugin into plugins section (alongside Firebase plugin)
      just replace project/android/build/build.gradle  //ADD_SENTRY_PLUGINS_HERE_ temp_sentry_plugin.txt

      # Insert manifest metadata
      just replace project/android/build/AndroidManifest.xml  <!--ADD_SENTRY_METADATA_HERE_--> temp_sentry_metadata.txt

      @echo "Cleaning up temporary Sentry files..."
      rm temp_sentry_plugin.txt temp_sentry_metadata.txt

      @echo "✅ Sentry Android SDK dependencies inserted successfully."
  ```

##### **Step 4: Integrate into Android Build Recipes**
- **Location**: `justfiles/justfile-platform-android.justfile`
- **Modify existing recipes** to include Sentry injection:
  ```bash
  quick-build-android:
      @echo "⚡ Quick Android build (2-3 min)..."
      just insert-firebase-dependencies
      just insert-sentry-dependencies
      just export-apk-android
      just export-aab-android
      @echo "✅ Quick Android build complete!"

  build-all-android force="no": validate-env
      @echo "🤖 FULL BUILD - ANDROID ONLY"
      @echo "🤖 ANDROID BUILD STEPS"
      @echo "===================="
      @echo "📦 [1/4] Checking Android templates..."
      just _check-or-build-android-templates {{force}}
      @echo "🔥 [2/5] Setting up Firebase..."
      just insert-firebase-dependencies
      @echo "🛡️ [3/5] Setting up Sentry..."
      just insert-sentry-dependencies
      @echo "📱 [4/5] Exporting Android APK..."
      just export-apk-android
      @echo "📦 [5/5] Exporting Android AAB..."
      just export-aab-android
  ```

##### **Step 5: Configure Sentry gradle.properties
- **Location**: `project/android/build/gradle.properties`
- **Add Sentry configuration** (can be added by template injection or directly):
  ```properties
  # Sentry Android SDK Configuration
  sentry.autoProguardConfig=true
  sentry.autoUpload=true
  sentry.includeProguardSources=true
  sentry.includeSourceContext=true
  sentry.tracesSampleRate=1.0
  ```

#### **🔍 Validation: Complete Official Sentry Coverage**

**✅ All official Sentry Android setup requirements covered:**

1. **✅ Installation** - `id "io.sentry.android.gradle" version "5.12.2"`
2. **✅ Configuration via AndroidManifest.xml** - Complete meta-data from official docs:
   - **✅ DSN Configuration** - `io.sentry.dsn`
   - **✅ PII Data** - `io.sentry.send-default-pii`
   - **✅ User Interaction Breadcrumbs** - `io.sentry.traces.user-interaction.enable`
   - **✅ Screenshots** - `io.sentry.attach-screenshot`
   - **✅ View Hierarchy** - `io.sentry.attach-view-hierarchy`
   - **✅ Performance API** - `io.sentry.traces.sample-rate`
   - **✅ UI Profiling** - Complete profiling configuration:
     - `io.sentry.traces.profiling.session-sample-rate`
     - `io.sentry.traces.profiling.lifecycle`
     - `io.sentry.traces.profiling.start-on-app-start`
   - **✅ Session Replay** - Complete replay configuration:
     - `io.sentry.session-replay.on-error-sample-rate`
     - `io.sentry.session-replay.session-sample-rate`

3. **✅ SDK Integration** - Plugin 5.12.2 automatically adds SDK 8.25.0
4. **✅ ContentProvider Initialization** - Sentry uses built-in Android ContentProvider
5. **✅ App Start Coverage** - Captures crashes from app start automatically

**🚀 Advanced Features Included:**
- **ANR Monitoring** - Included in SDK 8.25.0
- **Session Replay** - 100% errors, 10% sessions (configurable)
- **UI Profiling** - Enabled with trace mode
- **Performance Monitoring** - 100% sample rate for development
- **Automatic Breadcrumbs** - User interactions captured
- **Rich Context** - Screenshots, view hierarchy, PII data

### **Phase 2: Advanced Features (Complete Error Coverage)**

#### **Additional Integration Points:**

##### **Step 8: ANR Monitoring Configuration**
- **Location**: `godot/platform/android/java/app/build.gradle`
- **Add to Sentry Configuration**:
  ```gradle
  sentry {
      autoProguardConfig true
      autoUpload true
      includeProguardSources true
      includeSourceContext true

      // ANR monitoring
      anrEnabled true

      // Session Replay
      sessionReplay {
          sessionSampleRate 1.0
          onErrorSampleRate 1.0
      }

      // Profiling
      profiles {
          sampleRate 1.0
      }
  }
  ```

##### **Step 9: Java/Kotlin Bridge Integration**
- **Location**: `godot/platform/android/java/src/org/godotengine/godot/GodotActivity.java`
- **Integration Point**: In `onCreate()` method before Godot initialization:
  ```java
  import io.sentry.Sentry;
  import io.sentry.android.core.SentryAndroid;

  @Override
  protected void onCreate(Bundle savedInstanceState) {
      super.onCreate(savedInstanceState);

      // Initialize Sentry Android SDK for Java/Kotlin error capture
      SentryAndroid.init(this, options -> {
          options.setDsn(System.getenv("SENTRY_DSN"));
          options.setDebug(BuildConfig.DEBUG);
          options.setTracesSampleRate(1.0);
          options.setSessionTracking(true);
          options.setAttachStacktrace(true);

          // ANR monitoring
          options.setAnrEnabled(true);

          // Session Replay
          options.getSessionReplay().setSessionSampleRate(1.0);
          options.getSessionReplay().setOnErrorSampleRate(1.0);

          // Profiling
          options.getProfiles().setSampleRate(1.0);
      });

      // Existing Godot initialization continues...
      mGodot = new Godot(this, appArgs);
  }
  ```

##### **Step 10: Native C++ Integration Enhancement**
- **Location**: `godot/platform/android/java/src/org/godotengine/godot/Godot.java`
- **Integration Point**: Add Sentry native bridge:
  ```java
  import io.sentry.Sentry;

  // Add native bridge initialization
  public static void initializeSentryNative() {
      // Configure Sentry native SDK for C++ error capture
      Sentry.configureScope(scope -> {
          scope.setTag("engine", "godot");
          scope.setTag("platform", "android");
          scope.setTag("architecture", System.getProperty("os.arch"));
      });
  }
  ```

#### **Testing Strategy:**

##### **Step 11: Create Comprehensive Test Configurations**
- **Test Configuration**: `tests/debug_configs/sentry-android-sdk-complete.json`
- **Actions**:
  ```json
  {
    "description": "TDD: Validate complete Sentry Android SDK integration",
    "actions": [
      "sentry.validate_gdextension_loading",
      "sentry.test_java_kotlin_errors",
      "sentry.test_native_crashes",
      "sentry.test_anr_monitoring",
      "sentry.test_session_replay",
      "sentry.test_profiling"
    ],
    "platforms": ["android"]
  }
  ```

##### **Step 12: Add Test Actions for Advanced Features**
- **Location**: `project/debug/actions/sentry/sentry_android_complete_testing_action.gd`
- **New Test Actions**:
  - `sentry.test_java_kotlin_errors` - Simulate Java/Kotlin exceptions
  - `sentry.test_anr_monitoring` - Test ANR detection
  - `sentry.test_session_replay` - Validate session replay capture
  - `sentry.test_profiling` - Test performance profiling

## Success Criteria

### **Phase 1 Success Metrics:**
- [ ] Sentry Gradle plugin integrated into build system
- [ ] Java/Kotlin errors automatically captured
- [ ] Build-time injection working without manual steps
- [ ] All existing functionality preserved
- [ ] No build failures or conflicts

### **Phase 2 Success Metrics:**
- [ ] ANR monitoring active and reporting
- [ ] Session replay capturing UI interactions
- [ ] Performance profiling data collection
- [ ] Complete error coverage (GDScript + C++ + Java/Kotlin)
- [ ] Advanced features configurable per build type

## Integration Dependencies

### **Prerequisites:**
1. **Sentry Android SDK version compatibility** with Godot 4.3
2. **Gradle plugin version alignment** with Android build tools
3. **Export plugin modifications** compatible with existing Godot export system
4. **Justfile recipe integration** without breaking existing workflows

### **Testing Requirements:**
1. **Unit tests** for each Sentry integration component
2. **Integration tests** for complete error capture pipeline
3. **Performance tests** ensuring no impact on game performance
4. **Cross-platform tests** ensuring Android functionality only

## Risk Assessment

### **High Risk Items:**
- **Build system integration complexity** - Unknown interaction with Godot's SCons build
- **Version compatibility** - Sentry SDK conflicts with Godot's Android dependencies
- **Export process modification** - Potential breaking changes to existing workflows

### **Medium Risk Items:**
- **Performance impact** - Sentry SDK overhead on mobile performance
- **ANR monitoring conflicts** - Potential interference with Godot's main thread
- **Memory usage increase** - Additional SDK memory footprint

### **Low Risk Items:**
- **Configuration management** - Sentry settings are well-documented
- **Testing framework integration** - Existing debug action infrastructure
- **Documentation requirements** - Standard integration documentation
