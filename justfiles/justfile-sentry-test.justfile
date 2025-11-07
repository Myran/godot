# Sentry Android SDK Template Injection Testing Recipes

# Recipe to add Sentry placeholders to Godot Android source (one-time setup)
add-sentry-placeholders:
    @echo "🛡️ Adding Sentry placeholders to Godot Android source..."
    @echo "This is a one-time setup to enable Firebase-style template injection"
    @echo ""

    # Create backup directory
    BACKUP_DIR="backup/$(date +%Y%m%d_%H%M%S)_sentry_placeholders"
    mkdir -p "{{PROJECT_PATH}}/backup"
    mkdir -p "{{PROJECT_PATH}}/$BACKUP_DIR"
    @echo "📁 Created backup directory: $BACKUP_DIR"

    # Backup original files
    @echo "💾 Backing up original files..."
    cp "{{PROJECT_PATH}}/godot/platform/android/java/app/build.gradle" "{{PROJECT_PATH}}/$BACKUP_DIR/build.gradle.backup"
    cp "{{PROJECT_PATH}}/godot/platform/android/java/app/src/main/AndroidManifest.xml" "{{PROJECT_PATH}}/$BACKUP_DIR/AndroidManifest.xml.backup"

    # Add Sentry plugin placeholder to build.gradle
    @echo "🔧 Adding Sentry plugin placeholder to build.gradle..."
    if ! grep -q "//ADD_SENTRY_PLUGINS_HERE_" "{{PROJECT_PATH}}/godot/platform/android/java/app/build.gradle"; then
        sed -i.bak 's/}/    \/\/ADD_SENTRY_PLUGINS_HERE_\n}/' "{{PROJECT_PATH}}/godot/platform/android/java/app/build.gradle"
        @echo "✅ Added //ADD_SENTRY_PLUGINS_HERE_ placeholder"
    else
        @echo "⚠️  Sentry plugin placeholder already exists"
    fi

    # Add Sentry metadata placeholder to AndroidManifest.xml
    @echo "🔧 Adding Sentry metadata placeholder to AndroidManifest.xml..."
    if ! grep -q "<!--ADD_SENTRY_METADATA_HERE_-->" "{{PROJECT_PATH}}/godot/platform/android/java/app/src/main/AndroidManifest.xml"; then
        # Find the location after existing meta-data and before closing application tag
        sed -i.bak '/<\/application>/i\
\
        <!--ADD_SENTRY_METADATA_HERE_-->' "{{PROJECT_PATH}}/godot/platform/android/java/app/src/main/AndroidManifest.xml"
        @echo "✅ Added <!--ADD_SENTRY_METADATA_HERE_--> placeholder"
    else
        @echo "⚠️  Sentry metadata placeholder already exists"
    fi

    # Verify placeholders were added
    @echo ""
    @echo "🔍 Verifying placeholders in Godot source:"
    if grep -q "//ADD_SENTRY_PLUGINS_HERE_" "{{PROJECT_PATH}}/godot/platform/android/java/app/build.gradle"; then
        @echo "✅ Sentry plugin placeholder found in build.gradle"
    else
        @echo "❌ Sentry plugin placeholder NOT found in build.gradle"
    fi

    if grep -q "<!--ADD_SENTRY_METADATA_HERE_-->" "{{PROJECT_PATH}}/godot/platform/android/java/app/src/main/AndroidManifest.xml"; then
        @echo "✅ Sentry metadata placeholder found in AndroidManifest.xml"
    else
        @echo "❌ Sentry metadata placeholder NOT found in AndroidManifest.xml"
    fi

    @echo ""
    @echo "🎯 Sentry placeholders added successfully!"
    @echo "💾 Backups available in: $BACKUP_DIR"
    @echo "📝 Next step: Test with 'just test-sentry-injection'"

# Recipe to restore original files (if needed)
restore-sentry-placeholders backup_name:
    @#!/usr/bin/env bash
    @if [ -z "{{backup_name}}" ]; then
        @echo "❌ Please specify backup directory name"
        @echo "Usage: just restore-sentry-placeholders <backup_directory>"
        @echo "Available backups:"
        @ls -1 "{{PROJECT_PATH}}/backup" | grep sentry_placeholders
        exit 1
    fi
    @echo "🔄 Restoring from backup: {{backup_name}}"
    @echo ""

    BACKUP_PATH="{{PROJECT_PATH}}/backup/{{backup_name}}"
    if [ ! -d "$BACKUP_PATH" ]; then
        @echo "❌ Backup directory not found: $BACKUP_PATH"
        exit 1
    fi

    # Restore build.gradle
    if [ -f "$BACKUP_PATH/build.gradle.backup" ]; then
        cp "$BACKUP_PATH/build.gradle.backup" "{{PROJECT_PATH}}/godot/platform/android/java/app/build.gradle"
        @echo "✅ Restored build.gradle"
    else
        @echo "⚠️  build.gradle.backup not found in $BACKUP_PATH"
    fi

    # Restore AndroidManifest.xml
    if [ -f "$BACKUP_PATH/AndroidManifest.xml.backup" ]; then
        cp "$BACKUP_PATH/AndroidManifest.xml.backup" "{{PROJECT_PATH}}/godot/platform/android/java/app/src/main/AndroidManifest.xml"
        @echo "✅ Restored AndroidManifest.xml"
    else
        @echo "⚠️  AndroidManifest.xml.backup not found in $BACKUP_PATH"
    fi

    @echo ""
    @echo "🎯 Original files restored from: {{backup_name}}"

# Recipe to test the Sentry template injection process
test-sentry-injection:
    @echo "🧪 Testing Sentry Android SDK template injection..."
    @echo ""

    # Check if placeholders exist
    @echo "🔍 Checking for Sentry placeholders in Godot source..."
    if ! grep -q "//ADD_SENTRY_PLUGINS_HERE_" "{{PROJECT_PATH}}/godot/platform/android/java/app/build.gradle"; then
        @echo "❌ Sentry plugin placeholder not found in build.gradle"
        @echo "💡 Run 'just add-sentry-placeholders' first"
        exit 1
    fi

    if ! grep -q "<!--ADD_SENTRY_METADATA_HERE_-->" "{{PROJECT_PATH}}/godot/platform/android/java/app/src/main/AndroidManifest.xml"; then
        @echo "❌ Sentry metadata placeholder not found in AndroidManifest.xml"
        @echo "💡 Run 'just add-sentry-placeholders' first"
        exit 1
    fi

    @echo "✅ All Sentry placeholders found"
    @echo ""

    # Backup current exported files
    @echo "💾 Backing up current exported Android files..."
    TEST_BACKUP_DIR="backup/$(date +%Y%m%d_%H%M%S)_test_injection"
    mkdir -p "{{PROJECT_PATH}}/backup/$TEST_BACKUP_DIR"

    if [ -f "{{PROJECT_PATH}}/project/android/build/build.gradle" ]; then
        cp "{{PROJECT_PATH}}/project/android/build/build.gradle" "{{PROJECT_PATH}}/backup/$TEST_BACKUP_DIR/exported_build.gradle.backup"
        @echo "✅ Backed up exported build.gradle"
    fi

    if [ -f "{{PROJECT_PATH}}/project/android/build/AndroidManifest.xml" ]; then
        cp "{{PROJECT_PATH}}/project/android/build/AndroidManifest.xml" "{{PROJECT_PATH}}/backup/$TEST_BACKUP_DIR/exported_AndroidManifest.xml.backup"
        @echo "✅ Backed up exported AndroidManifest.xml"
    fi

    # Test the injection process
    @echo ""
    @echo "🔧 Testing Sentry template injection..."
    @echo ""

    # Check if export-apk-android exists (we'll simulate the export process)
    if ! grep -q "export-apk-android" justfiles/justfile-platform-android.justfile; then
        @echo "⚠️  export-apk-android recipe not found, creating minimal test environment..."
        mkdir -p "{{PROJECT_PATH}}/project/android/build/"
        # Copy current Godot source to project directory for testing
        cp "{{PROJECT_PATH}}/godot/platform/android/java/app/build.gradle" "{{PROJECT_PATH}}/project/android/build/" 2>/dev/null || echo "⚠️  Could not copy build.gradle"
        cp "{{PROJECT_PATH}}/godot/platform/android/java/app/src/main/AndroidManifest.xml" "{{PROJECT_PATH}}/project/android/build/" 2>/dev/null || echo "⚠️  Could not copy AndroidManifest.xml"
    fi

    # Run the Sentry injection
    @echo "🚀 Running Sentry injection..."
    just insert-sentry-dependencies-test

    # Verify injection results
    @echo ""
    @echo "🔍 Verifying injection results..."

    if [ -f "{{PROJECT_PATH}}/project/android/build/build.gradle" ]; then
        if grep -q "io.sentry.android.gradle" "{{PROJECT_PATH}}/project/android/build/build.gradle"; then
            @echo "✅ Sentry plugin found in exported build.gradle"
        else
            @echo "❌ Sentry plugin NOT found in exported build.gradle"
        fi
    else
        @echo "⚠️  Exported build.gradle not found"
    fi

    if [ -f "{{PROJECT_PATH}}/project/android/build/AndroidManifest.xml" ]; then
        if grep -q "io.sentry.dsn" "{{PROJECT_PATH}}/project/android/build/AndroidManifest.xml"; then
            @echo "✅ Sentry metadata found in exported AndroidManifest.xml"
        else
            @echo "❌ Sentry metadata NOT found in exported AndroidManifest.xml"
        fi
    else
        @echo "⚠️  Exported AndroidManifest.xml not found"
    fi

    @echo ""
    @echo "🎯 Sentry template injection test completed!"
    @echo "💾 Backups available in: $TEST_BACKUP_DIR"
    @echo "📝 Use 'just restore-test-injection $TEST_BACKUP_DIR' to restore"

# Test version of insert-sentry-dependencies (safe for testing)
insert-sentry-dependencies-test:
    @echo "🛡️ Testing Sentry Android SDK dependencies injection..."

    # Ensure project/android/build directory exists
    mkdir -p "{{PROJECT_PATH}}/project/android/build/"

    # Copy source files to export directory if they don't exist
    if [ ! -f "{{PROJECT_PATH}}/project/android/build/build.gradle" ]; then
        @echo "📁 Copying build.gradle template..."
        cp "{{PROJECT_PATH}}/godot/platform/android/java/app/build.gradle" "{{PROJECT_PATH}}/project/android/build/build.gradle"
    fi

    if [ ! -f "{{PROJECT_PATH}}/project/android/build/AndroidManifest.xml" ]; then
        @echo "📁 Copying AndroidManifest.xml template..."
        mkdir -p "{{PROJECT_PATH}}/project/android/build/"
        cp "{{PROJECT_PATH}}/godot/platform/android/java/app/src/main/AndroidManifest.xml" "{{PROJECT_PATH}}/project/android/build/AndroidManifest.xml"
    fi

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
    if [ -f "{{PROJECT_PATH}}/project/android/build/build.gradle" ]; then
        just replace project/android/build/build.gradle //ADD_SENTRY_PLUGINS_HERE_ temp_sentry_plugin.txt
        @echo "✅ Sentry plugin injected into build.gradle"
    else
        @echo "❌ project/android/build/build.gradle not found"
    fi

    # Insert manifest metadata
    if [ -f "{{PROJECT_PATH}}/project/android/build/AndroidManifest.xml" ]; then
        just replace project/android/build/AndroidManifest.xml <!--ADD_SENTRY_METADATA_HERE_--> temp_sentry_metadata.txt
        @echo "✅ Sentry metadata injected into AndroidManifest.xml"
    else
        @echo "❌ project/android/build/AndroidManifest.xml not found"
    fi

    @echo "Cleaning up temporary Sentry files..."
    rm temp_sentry_plugin.txt temp_sentry_metadata.txt

    @echo "✅ Sentry Android SDK test injection completed."

# Restore from test injection
restore-test-injection backup_name:
    @#!/usr/bin/env bash
    @if [ -z "{{backup_name}}" ]; then
        @echo "❌ Please specify test backup directory name"
        @echo "Usage: just restore-test-injection <test_backup_directory>"
        @echo "Available test backups:"
        @ls -1 "{{PROJECT_PATH}}/backup" | grep test_injection
        exit 1
    fi

    @echo "🔄 Restoring from test backup: {{backup_name}}"
    @echo ""

    BACKUP_PATH="{{PROJECT_PATH}}/backup/{{backup_name}}"
    if [ ! -d "$BACKUP_PATH" ]; then
        @echo "❌ Test backup directory not found: $BACKUP_PATH"
        exit 1
    fi

    # Restore exported files
    if [ -f "$BACKUP_PATH/exported_build.gradle.backup" ]; then
        cp "$BACKUP_PATH/exported_build.gradle.backup" "{{PROJECT_PATH}}/project/android/build/build.gradle"
        @echo "✅ Restored exported build.gradle"
    fi

    if [ -f "$BACKUP_PATH/exported_AndroidManifest.xml.backup" ]; then
        cp "$BACKUP_PATH/exported_AndroidManifest.xml.backup" "{{PROJECT_PATH}}/project/android/build/AndroidManifest.xml"
        @echo "✅ Restored exported AndroidManifest.xml"
    fi

    @echo ""
    @echo "🎯 Test injection restored from: {{backup_name}}"

# List all available backups
list-sentry-backups:
    @echo "📋 Available Sentry backups:"
    @echo ""
    @echo "🔧 Placeholder backups:"
    @ls -1 "{{PROJECT_PATH}}/backup" | grep sentry_placeholders | sed 's/^/  /' || echo "  (none found)"
    @echo ""
    @echo "🧪 Test injection backups:"
    @ls -1 "{{PROJECT_PATH}}/backup" | grep test_injection | sed 's/^/  /' || echo "  (none found)"
    @echo ""
    @echo "Usage examples:"
    @echo "  just restore-sentry-placeholders <placeholder_backup>"
    @echo "  just restore-test-injection <test_backup>"