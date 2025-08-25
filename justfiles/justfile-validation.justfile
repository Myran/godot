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

# Show warnings - combines Godot engine warnings + static analysis
show-warnings:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🔍 Comprehensive GDScript Analysis"
    echo "=================================="
    echo ""
    
    cd {{PROJECT_PATH}}
    
    # Part 1: Static analysis using ripgrep (fast)
    echo "📊 STATIC ANALYSIS (ripgrep-powered)"
    echo "-----------------------------------"
    
    # Ensure ripgrep can find gdscript type
    export RIPGREP_CONFIG_PATH=~/.ripgreprc
    
    # TODO/FIXME comments
    todo_count=$(rg -t gdscript -i "(TODO|FIXME|HACK|XXX)" --count 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
    echo "🔧 TODO/FIXME items: $todo_count"
    if [[ $todo_count -gt 0 ]]; then
        rg -t gdscript -i "(TODO|FIXME|HACK|XXX)" --line-number --no-heading | head -5
        [[ $todo_count -gt 5 ]] && echo "   ... and $((todo_count - 5)) more"
        echo ""
    fi
    
    # Missing type annotations - count from actual Godot warnings for accuracy
    temp_godot_log="/tmp/temp_godot_analysis.log"
    timeout 10s {{GODOT_EXECUTABLE}} --headless --verbose --debug --warning-mode all --path . > "$temp_godot_log" 2>&1 || true
    untyped_vars=$(rg "has no static type" "$temp_godot_log" --count 2>/dev/null || echo "0")
    echo "⚠️  Untyped variables: $untyped_vars"
    
    # Missing return types  
    all_funcs=$(rg -t gdscript "^func\s+\w+" --count 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
    typed_funcs=$(rg -t gdscript "^func\s+\w+.*->" --count 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
    untyped_funcs=$((all_funcs - typed_funcs))
    echo "⚠️  Functions missing return types: $untyped_funcs"
    
    echo ""
    
    # Part 2: Godot engine warnings (comprehensive)
    echo "🎮 GODOT ENGINE WARNINGS"  
    echo "------------------------"
    echo "NOTE: GDScript static analysis warnings (INCOMPATIBLE_TERNARY, UNSAFE_CAST, etc.)"
    echo "      are primarily shown in the editor interface, not console output."
    echo "Running project analysis to capture available warnings..."  
    echo "This will take 10-15 seconds..."
    
    temp_log="/tmp/godot_project_output.log"
    warnings_log="/tmp/godot_warnings.log"
    
    # Clear any previous logs to avoid confusion
    rm -f /tmp/godot*.log 2>/dev/null || true
    
    # Use our enhanced Godot engine with built-in file:line attribution
    
    # Run project using our enhanced engine that provides clean ERROR: 'file:line: message' format  
    # Use the EXACT command that successfully captured 24+ warnings, with proper timing
    timeout 25 {{GODOT_EXECUTABLE}} --headless --verbose --debug --path . project/project.godot 2>"$temp_log" 1>/dev/null || true
    
    echo "Analysis completed, extracting GDScript warnings..."
    
    # Initialize warnings log
    > "$warnings_log"
    
    # Extract warnings using our enhanced Godot engine - much simpler now!
    echo "=== GDScript Static Analysis Warnings ===" >> "$warnings_log"
    echo "Enhanced with file paths and line numbers from modified Godot engine" >> "$warnings_log"
    echo "" >> "$warnings_log"
    
    # Our enhanced engine provides clean ERROR: 'file.gd:123: message' format
    rg "ERROR: '([^']+)'" "$temp_log" -o --replace '$1' | \
    while IFS= read -r warning; do
        if [[ $warning =~ ^([^:]+):([0-9]+):\ (.+)$ ]]; then
            echo "${BASH_REMATCH[1]}:${BASH_REMATCH[2]}: ${BASH_REMATCH[3]}" >> "$warnings_log"
        else
            echo "• $warning" >> "$warnings_log"  
        fi
    done
    
    # Add runtime warnings if any exist
    if rg -q 'WARNING.*\([^)]*\.gd:[0-9]+\)' "$temp_log"; then
        echo "" >> "$warnings_log"
        echo "=== Runtime Warnings ===" >> "$warnings_log"
        rg 'WARNING.*\([^)]*\.gd:[0-9]+\)' "$temp_log" | \
        sed 's/\x1B\[[0-9;]*[a-zA-Z]//g' | \
        rg -o '\([^)]*\.gd:[0-9]+\).*' | \
        sed 's/^(//' | sed 's/):/: /' >> "$warnings_log"
    fi
    
    # Add XR messages if any exist  
    if rg -q '^XR:' "$temp_log"; then
        echo "" >> "$warnings_log"
        echo "=== XR Messages ===" >> "$warnings_log" 
        rg '^XR:' "$temp_log" >> "$warnings_log"
    fi
    
    # Count warnings
    warning_count=$(wc -l < "$warnings_log" 2>/dev/null || echo "0")
    
    echo ""
    echo "Found $warning_count Godot engine warnings:"
    echo "=============================================="
    
    if [[ $warning_count -gt 0 ]]; then
        cat "$warnings_log" | head -50  # Limit output for readability
        [[ $warning_count -gt 50 ]] && echo "... ($((warning_count - 50)) more warnings truncated)"
        echo ""
        echo "📁 File References:"
        echo "   All warnings now include precise file:line locations"
        echo "   Use your editor to navigate directly to warning locations"
    else
        echo "✅ No Godot engine warnings found!"
    fi
    
    echo ""
    echo "📊 SUMMARY"
    echo "=========="
    echo "🔧 TODO/FIXME items: $todo_count"
    echo "⚠️  Untyped variables: $untyped_vars" 
    echo "⚠️  Functions missing return types: $untyped_funcs"
    echo "🎮 Godot console warnings: $warning_count"
    echo ""
    echo "ℹ️  ABOUT GDSCRIPT STATIC ANALYSIS WARNINGS:"
    echo "   Warnings like INCOMPATIBLE_TERNARY, UNSAFE_CAST, UNTYPED_DECLARATION,"
    echo "   SHADOWED_VARIABLE, etc. are generated by Godot's static analyzer but"
    echo "   are primarily displayed in the editor's script interface, not in"
    echo "   console/headless output. To see these warnings:"
    echo "   • Open scripts in Godot editor"
    echo "   • Check the 'Script' tab warnings panel" 
    echo "   • Use editor-based validation for full static analysis"
    echo ""
    
    # Clean up temp files
    rm -f "$temp_log" "$warnings_log"

# Save warnings to markdown file
save-warnings: (warnings "file") 

# Get warning count only
count-warnings: (warnings "count")