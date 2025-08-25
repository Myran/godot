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
    
    # Use debug mode to get runtime warnings (check-only doesn't show these)
    {{GODOT_EXECUTABLE}} --headless --debug --path . 2>&1 > "$temp_log" || true
    
    # Parse the log to extract warnings with better file attribution
    current_file="Unknown"
    > "$warnings_log"
    
    while IFS= read -r line; do
        if [[ $line =~ ^Loading\ resource:\ res:// ]]; then
            # Extract file path from loading message
            file_path=$(echo "$line" | sed 's/Loading resource: res:\/\///' | sed 's/[[:space:]]*$//')
            if [[ $file_path =~ \.gd$ ]]; then
                current_file="$file_path"
            fi
        elif [[ $line =~ ^ERROR: ]]; then
            # Try to extract file name from the error message itself
            if [[ $line =~ \"([^\"]*\.gd)\" ]]; then
                # Extract filename from error message (e.g., "defined in \"debug_action_result.gd\"")
                extracted_file="${BASH_REMATCH[1]}"
                echo "$extracted_file: $line" >> "$warnings_log"
            # Pattern matching for known error signatures
            elif [[ $line =~ (new_success|new_failure|new_timeout|new_performance_result|new_listener_result|new_batch_result|new_concurrent_result|new_restart_pending|get_error_category) ]]; then
                # These functions are from debug_action_result.gd
                echo "debug/debug_action_result.gd: $line" >> "$warnings_log"
            elif [[ $line =~ (\"seed\".*built-in function) ]]; then
                # Seed variable issues - likely from deterministic_rng or related files
                echo "Unknown (likely RNG-related): $line" >> "$warnings_log"
            else
                # Fall back to current file context (accurate for some cases)
                echo "$current_file: $line" >> "$warnings_log"
            fi
        fi
    done < "$temp_log"
    
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

# Show warnings in console (default)
show-warnings: (warnings "console")

# Save warnings to markdown file
save-warnings: (warnings "file") 

# Get warning count only
count-warnings: (warnings "count")