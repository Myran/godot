# System validation and verification commands
# Self-contained utilities for validating development environment and tools
# NOTE: Core validation functions moved to justfile-validation-shared.justfile

# Strict Android device validation (requires actual device connection)
_require-android-device:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! adb -s {{ANDROID_DEVICE_ID}} shell echo "Connected" >/dev/null 2>&1; then
        echo "❌ Android device not connected: {{ANDROID_DEVICE_ID}}"
        echo "💡 Check device connection and run: adb devices"
        exit 1
    fi
    echo "✅ Android device connected"

# NOTE: _validate-ios-device and _validate-path-exists moved to justfile-validation-shared.justfile

# Ensure directory exists, create if missing
_ensure-directory-exists DIR:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -d "{{DIR}}" ]; then
        mkdir -p "{{DIR}}"
        echo "📁 Created directory: {{DIR}}"
    fi

# Combined validation for Android workflow requirements
# NOTE: _validate-android-workflow and _validate-ios-workflow moved to justfile-validation-shared.justfile

# Validate GDScript code by checking for syntax errors using gdparse
check OUTPUT="console":
    #!/usr/bin/env bash
    set -euo pipefail
    
    if [[ "{{OUTPUT}}" == "log" ]]; then
        echo "Validating GDScript code and saving errors to log file..."
        rm -f validation_errors.log
    else
        echo "Validating GDScript code..."
    fi
    
    cd {{PROJECT_PATH}}
    
    # Find all .gd files excluding addons
    gdscript_files=$(find . -name "*.gd" -type f -not -path "./addons/*")
    total_files=$(echo "$gdscript_files" | wc -l)
    
    echo "Checking $total_files GDScript files..."
    
    error_count=0
    current_file=0
    
    for file in $gdscript_files; do
        current_file=$((current_file + 1))
        
        if [[ "{{OUTPUT}}" == "log" ]]; then
            if ! gdparse "$file" >> validation_errors.log 2>&1; then
                echo "ERROR in $file" >> validation_errors.log
                error_count=$((error_count + 1))
            fi
        else
            if ! gdparse "$file" 2>/dev/null; then
                echo "❌ $file"
                error_count=$((error_count + 1))
            fi
        fi
        
        # Show progress every 25 files
        if [[ "{{OUTPUT}}" != "log" && $((current_file % 25)) -eq 0 ]]; then
            echo "Progress: $current_file/$total_files files checked..."
        fi
    done
    
    if [[ $error_count -eq 0 ]]; then
        echo "✅ All $total_files GDScript files passed validation"
        if [[ "{{OUTPUT}}" == "log" ]]; then
            echo "No errors found" > validation_errors.log
        fi
        exit 0
    else
        echo "❌ Found $error_count files with syntax errors"
        if [[ "{{OUTPUT}}" == "log" ]]; then
            echo "Validation complete. Errors saved to validation_errors.log"
        fi
        exit 1
    fi

# Validate GDScript code by checking for syntax errors
validate-gdscript OUTPUT="console": (check OUTPUT)

# Check Android debug connection and app status
check-android-debug-status:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📱 Checking Android debug status..."
    
    # Check if device is connected
    if ! adb -s {{ANDROID_DEVICE_ID}} shell echo "Connected" >/dev/null 2>&1; then
        echo "❌ Android device not connected: {{ANDROID_DEVICE_ID}}"
        exit 1
    fi
    
    # Check if app is installed
    if ! adb -s {{ANDROID_DEVICE_ID}} shell pm list packages | grep -q "{{ANDROID_PACKAGE_NAME}}" 2>/dev/null; then
        echo "❌ App not installed: {{ANDROID_PACKAGE_NAME}}"
        exit 1
    fi
    
    # Check if app is running
    if adb -s {{ANDROID_DEVICE_ID}} shell pgrep "{{ANDROID_PACKAGE_NAME}}" >/dev/null 2>&1; then
        echo "✅ App is running"
    else
        echo "⚠️  App is not running"
    fi
    
    # Check debug bridge status
    echo "📋 Debug bridge status:"
    adb -s {{ANDROID_DEVICE_ID}} shell getprop ro.debuggable 2>/dev/null || echo "  Debug property not accessible"
    
    echo "✅ Android debug status check complete"

# Extract all Godot engine warnings by running project and capturing output
warnings OUTPUT="console":
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Extracting Godot Engine Warnings..."
    echo "======================================"
    
    cd {{PROJECT_PATH}}
    
    echo "Running Godot project to capture warnings..."
    echo "This will take 10-15 seconds..."
    
    # Run Godot and capture full output, then extract warnings with context
    temp_log="/tmp/godot_full_output.log"
    warnings_log="/tmp/godot_warnings.log"
    
    # Use verbose debug mode with warning-mode all to get comprehensive warnings with detailed file loading info
    {{GODOT_EXECUTABLE}} --headless --verbose --debug --warning-mode all --path . 2>&1 > "$temp_log" || true
    
    # Parse warnings and attribute them to files using ripgrep for better precision
    # Extract warnings with improved pattern matching and file attribution
    > "$warnings_log"
    
    # Use ripgrep to extract ERROR lines with better context matching
    rg "^ERROR:" "$temp_log" --line-number --no-heading > /tmp/errors_with_lines.txt 2>/dev/null || true
    
    # Also extract file loading context for attribution
    rg "^Loading resource: res://(.+\.gd)$" "$temp_log" --line-number --only-matching --replace '$1' > /tmp/file_loading.txt 2>/dev/null || true
    
    # Correlate errors with most recently loaded .gd files
    current_file=""
    while IFS= read -r line; do
        line_num=$(echo "$line" | cut -d: -f1)
        content=$(echo "$line" | cut -d: -f2-)
        
        # Find the most recent .gd file loaded before this error
        recent_file=$(awk -v target="$line_num" '$1 < target {file=$2} END {print file}' FS=':' /tmp/file_loading.txt)
        
        if [[ -n "$recent_file" ]]; then
            echo "$recent_file: $content" >> "$warnings_log"
        else
            echo "Unknown: $content" >> "$warnings_log"
        fi
    done < /tmp/errors_with_lines.txt
    
    # Count warnings
    warning_count=$(wc -l < "$warnings_log" 2>/dev/null || echo "0")
    
    if [[ "{{OUTPUT}}" == "console" ]]; then
        echo ""
        echo "Found $warning_count Godot engine warnings:"
        echo "=============================================="
        
        if [[ $warning_count -gt 0 ]]; then
            cat "$warnings_log" | nl
            
            echo ""
            echo "Most problematic files:"
            cut -d: -f1 "$warnings_log" | sort | uniq -c | sort -nr | head -5
        else
            echo "No warnings found!"
        fi
        
        echo ""
        echo "Warning Summary: $warning_count total warnings"
        echo ""
        echo "Note: File attribution is approximate, based on loading context. Some warnings may"
        echo "belong to dependencies loaded during the attributed file's processing. For precise"
        echo "attribution, use the Godot editor's script analyzer."
        
    elif [[ "{{OUTPUT}}" == "file" ]]; then
        timestamp=$(date +%Y%m%d_%H%M%S)
        output_file="godot_warnings_$timestamp.md"
        
        echo "# Godot Engine Warnings" > "$output_file"
        echo "" >> "$output_file"
        echo "Total warnings found: $warning_count" >> "$output_file"
        echo "" >> "$output_file"
        echo "## All Warnings:" >> "$output_file"
        echo "" >> "$output_file"
        cat "$warnings_log" | nl >> "$output_file"
        
        echo "Warnings saved to: $output_file"
        
    elif [[ "{{OUTPUT}}" == "count" ]]; then
        echo "$warning_count"
    fi
    
    # Clean up temp files
    rm -f "$temp_log" "$warnings_log"

# Show GDScript warnings with file:line attribution
show-warnings:
    #!/usr/bin/env bash
    set -euo pipefail
    
    cd {{PROJECT_PATH}}
    
    # Show GDScript warnings only - minimal parameters for maximum efficiency
    {{GODOT_EXECUTABLE}} --headless --debug --quit --path . project/project.godot 2>&1 | rg "ERROR: '(.*)'" -o --replace '$1' || true

# Show Android-specific GDScript warnings with compilation errors
show-warnings-android:
    #!/usr/bin/env bash
    set -euo pipefail
    
    cd {{PROJECT_PATH}}
    
    echo "🔍 Validating GDScript for Android platform..."
    echo "⚠️  This performs Android export validation to catch platform-specific issues"
    echo ""
    
    # Perform Android export validation to catch platform-specific warnings/errors
    temp_export="/tmp/android_warnings_export.apk"
    
    echo "🚨 Android Platform Warnings & Errors:"
    echo "=============================="
    
    {{GODOT_EXECUTABLE}} --headless --export-debug "Android apk" "$temp_export" --path . project/project.godot 2>&1 | \
    rg -i "(WARNING|ERROR|SCRIPT ERROR|Parse Error|Failed to|deprecated|experimental).*" || echo "✅ No Android-specific warnings found"
    
    # Clean up
    rm -f "$temp_export"
    
    echo ""
    echo "💡 Use 'just show-warnings' for desktop-only warnings"

# Save warnings to markdown file
save-warnings: (warnings "file") 

