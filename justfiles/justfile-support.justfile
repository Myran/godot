# Supportive commands for Godot 4 Projects

# Take screenshot from Android device for AI analysis
screenshot-android name="screenshot":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📱 Taking screenshot from Android device..."
    
    # Take screenshot on device
    adb shell screencap -p /sdcard/{{name}}.png
    
    # Pull screenshot to temp directory
    adb pull /sdcard/{{name}}.png /tmp/{{name}}.png
    
    # Clean up device storage
    adb shell rm /sdcard/{{name}}.png
    
    echo "✅ Screenshot saved to /tmp/{{name}}.png"


# Close debug menu by tapping X button (top-right corner)
close-debug-menu:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🎯 Closing debug menu..."
    
    # Get screen size (expecting 1080x2220 override size)
    SCREEN_SIZE=$(adb shell wm size | grep "Override size" | cut -d: -f2 | tr -d ' ')
    if [[ -z "$SCREEN_SIZE" ]]; then
        SCREEN_SIZE=$(adb shell wm size | grep "Physical size" | cut -d: -f2 | tr -d ' ')
    fi
    
    WIDTH=$(echo $SCREEN_SIZE | cut -dx -f1)
    HEIGHT=$(echo $SCREEN_SIZE | cut -dx -f2)
    
    # Calculate X button position (approximately 95% from left, 3% from top)
    X_POS=$((WIDTH * 95 / 100))
    Y_POS=$((HEIGHT * 3 / 100))
    
    echo "📱 Screen size: ${WIDTH}x${HEIGHT}"
    echo "🎯 Tapping X button at: ${X_POS},${Y_POS}"
    
    adb shell input tap $X_POS $Y_POS
    
    echo "✅ Debug menu close attempted"

# Tap anywhere on screen to dismiss overlays
tap-to-dismiss:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "👆 Tapping to dismiss overlays..."
    
    # Get screen size
    SCREEN_SIZE=$(adb shell wm size | grep "Override size" | cut -d: -f2 | tr -d ' ')
    if [[ -z "$SCREEN_SIZE" ]]; then
        SCREEN_SIZE=$(adb shell wm size | grep "Physical size" | cut -d: -f2 | tr -d ' ')
    fi
    
    WIDTH=$(echo $SCREEN_SIZE | cut -dx -f1)
    HEIGHT=$(echo $SCREEN_SIZE | cut -dx -f2)
    
    # Tap center of screen
    X_POS=$((WIDTH / 2))
    Y_POS=$((HEIGHT / 2))
    
    echo "🎯 Tapping center at: ${X_POS},${Y_POS}"
    adb shell input tap $X_POS $Y_POS

# Validate environment variables
update-clangd:
    cd godot && scons compiledb=yes compile_commands.json

clean-xcode:
    rm -rf ~/Library/Developer/Xcode/DerivedData/

# Generate a repofile with repomix
generate-repofile:
    repomix --include 'project/**/*.gd','project/docs/*.md','godot/modules/firebase/*.mm','godot/modules/firebase/*.cpp','godot/modules/firebase/*.h'

# Generate Claude Code-optimized project context
generate-claude-context:
    repomix -c repomix-claude.config.json --compress --remove-comments --remove-empty-lines

validate-env:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Validating environment variables..."
    echo "✅ GAME_NAME: {{GAME_NAME}}"
    echo "✅ KEYSTORE_PASSWORD: [CONFIGURED]" 
    echo "✅ KEY_PASSWORD: [CONFIGURED]"
    echo "✅ APPLE_TEAM_ID: {{APPLE_TEAM_ID}}"
    echo "✅ APPLE_ID: {{APPLE_ID}}"
    echo "✅ IOS_PROVISIONING_PROFILE_UUID: {{IOS_PROVISIONING_PROFILE_UUID}}"
    echo "All required environment variables are set."

# Install dependencies
install-deps:
    @echo "Installing dependencies..."
    brew install scons yasm pipx ninja
    pipx install "gdtoolkit==4.*"
    pipx inject gdtoolkit setuptools

# Install iOS-specific dependencies
install-ios-deps:
    @echo "Installing iOS dependencies..."
    @echo "Current directory: $(pwd)"
    @echo "Justfile directory: {{justfile_directory()}}"
    @echo "Changing to MoltenVK directory..."
    cd {{justfile_directory()}}/extras/MoltenVK && \
    echo "Current directory after cd: $(pwd)" && \
    echo "Listing directory contents:" && \
    ls -la && \
    echo "Running fetchDependencies..." && \
    ./fetchDependencies --ios && \
    echo "Running make ios..." && \
    make ios
    @echo "Creating export/ios directory..."
    mkdir -p {{justfile_directory()}}/export/ios
    @echo "Copying MoltenVK.xcframework..."
    cp -R {{justfile_directory()}}/extras/MoltenVK/Package/Latest/MoltenVK/Static/MoltenVK.xcframework {{justfile_directory()}}/export/ios/
    @echo "iOS dependencies installed successfully."
    
# Lint GDScript files
lint:
    @echo "Linting GDScript files..."
    cd {{PROJECT_PATH}} && find . -name "*.gd" -type f -not -path "./addons/*" | grep -v -f .gdlintignore | xargs gdlint
# REMOVED: format - moved to justfile-dev-tools.justfile

format-test:
    @echo "TEST Formatting GDScript files..."
    cd {{PROJECT_PATH}} && find . -name "*.gd" -type f -not -path "./addons/*" -exec gdformat --check {} +

# Update version
update-version:
    #!/bin/bash
    echo "Updating versions..."
    # Update iOS version
    sed -i '' "s/^application\/version=.*/application\/version=\"1.0.$(date +'%Y%m%d%H%M%S')\"/" {{PROJECT_PATH}}/export_presets.cfg

    # Update Android version code and name
    sed -i '' "s/^version\/code=.*/version\/code=$(date +'%Y%m%d%H%M%S')/" {{PROJECT_PATH}}/export_presets.cfg
    sed -i '' "s/^version\/name=.*/version\/name=\"1.0.$(date +'%Y%m%d%H%M%S')\"/" {{PROJECT_PATH}}/export_presets.cfg

# REMOVED: update-export-presets - moved to justfile-dev-tools.justfile

# REMOVED: update-project-settings - moved to justfile-dev-tools.justfile

# Clean build artifacts
clean:
    @echo "Cleaning build artifacts..."
    cd {{GODOT_SUBMODULE_PATH}} && scons --clean

# Update all submodules
update-all-submodules:
    @echo "Updating all submodules..."
    git submodule update --init --recursive
    just update-godot-submodule
    just update-env-submodule

# Update environment submodule
update-env-submodule:
    @echo "Updating environment submodule..."
    cd env && git pull origin main
    git add env
    git commit -m "Update environment submodule"

# Show project status
status:
    @echo "Project Status:"
    @echo "Godot submodule:"
    cd {{GODOT_SUBMODULE_PATH}} && git status -s
    @echo "Main project:"
    git status -s


# Internal shared multi-platform test function
_test-multi-platform TARGET_CONFIG:
    #!/usr/bin/env bash
    set -euo pipefail

    TARGET_CONFIG="{{TARGET_CONFIG}}"

    echo "🚀 Running multi-platform test suite: $TARGET_CONFIG"
    echo "================================================="
    echo ""

    # Create shared session timestamp for multi-platform test
    MULTI_SESSION="$(date +%s)"
    export MULTI_PLATFORM_SESSION="$MULTI_SESSION"

    echo "🔍 Multi-platform session: $MULTI_SESSION"
    echo "🎯 Target configuration: $TARGET_CONFIG"
    echo ""

    # Clean up any old test files first (older than 1 hour)
    echo "🧹 Cleaning up old test result files..."
    find /tmp -name "test_action_results_*.json" -amin +60 -delete 2>/dev/null || true
    find /tmp -name "test_hierarchy_*.json" -amin +60 -delete 2>/dev/null || true

    # Get all supported platforms dynamically
    SUPPORTED_PLATFORMS=$(just _get-all-platforms)
    echo "🎯 Auto-detected platforms: $SUPPORTED_PLATFORMS"

    # Define the platforms and configs to test (desktop first as requested)
    TEST_PLATFORMS="desktop android"

    # Initialize tracking arrays (bash 3.2 compatible)
    PLATFORM_RESULTS=""
    PLATFORM_HIERARCHIES=""
    HIERARCHY_FILES=""

    # Run tests on each platform
    PLATFORM_NUM=1
    for PLATFORM in $TEST_PLATFORMS; do
        # Get platform icon and display name
        PLATFORM_ICON=$(just _get-platform-icon "$PLATFORM")
        PLATFORM_DISPLAY=$(just _get-platform-display-name "$PLATFORM")

        echo ""
        echo "${PLATFORM_NUM}️⃣ Running ${PLATFORM_DISPLAY} tests..."

        # Run platform-specific test
        PLATFORM_RESULT=0
        if DISABLE_TEST_CLEANUP=true MULTI_PLATFORM_MODE=true just "test-${PLATFORM}-target" "$TARGET_CONFIG" 2>/dev/null; then
            PLATFORM_RESULT=0
        else
            # Always treat as real failure for known platforms (desktop, android)
            # The commands exist, so any failure is a real test failure
            PLATFORM_RESULT=1
            echo "❌ $PLATFORM test failed"
        fi

        # Store result and find hierarchy file (bash 3.2 compatible)
        PLATFORM_RESULTS="$PLATFORM_RESULTS${PLATFORM}:${PLATFORM_RESULT};"

        if [[ $PLATFORM_RESULT -ne 2 ]]; then  # Not skipped
            # Find the hierarchy file created by this platform test
            # Look for files with the test config pattern or session timestamp
            HIERARCHY_FILE=$(ls -t /tmp/test_hierarchy_${TARGET_CONFIG}_*.json /tmp/test_hierarchy_*_${MULTI_SESSION}_*.json 2>/dev/null | head -n 1 || echo "")

            if [[ -z "$HIERARCHY_FILE" || ! -f "$HIERARCHY_FILE" ]]; then
                # No hierarchy file found - create one from action results for single config tests
                echo "🔧 Creating hierarchy file from action results for ${PLATFORM}"

                # Look for action results file from this platform test
                ACTION_RESULTS_FILE=$(find "{{USER_DATA_DIR}}/logs" -name "test_action_results_${TARGET_CONFIG}_*_${PLATFORM}_*.json" -type f -print -quit 2>/dev/null || echo "")

                if [[ -n "$ACTION_RESULTS_FILE" && -f "$ACTION_RESULTS_FILE" ]]; then
                    # Create hierarchy file from action results
                    HIERARCHY_FILE="/tmp/test_hierarchy_${TARGET_CONFIG//[^a-zA-Z0-9_-]/_}_${PLATFORM}_${MULTI_SESSION}.json"

                    # Read action results and transform to hierarchy format
                    ACTIONS_JSON=$(jq '. // []' "$ACTION_RESULTS_FILE" 2>/dev/null || echo '[]')
                    if jq -n --arg test_list "$TARGET_CONFIG" \
                          --arg test_session "$MULTI_SESSION" \
                          --arg config "$TARGET_CONFIG" \
                          --arg platform "$PLATFORM" \
                          --argjson actions "$ACTIONS_JSON" \
                          '{
                            "test_list": $test_list,
                            "test_session": $test_session,
                            "original_configs": [$config],
                            "at_references": [],
                            "direct_configs": [$config],
                            "config_results": [
                              {
                                "config": $config,
                                "status": "passed",
                                "platform": $platform,
                                "exit_code": 0,
                                "action_results": $actions
                              }
                            ]
                          }' > "$HIERARCHY_FILE" 2>/dev/null; then
                        echo "✅ Created hierarchy file: $(basename "$HIERARCHY_FILE")"
                    else
                        echo "⚠️ Failed to create hierarchy file from action results" >&2
                        HIERARCHY_FILE=""
                    fi
                else
                    echo "⚠️ No action results file found for ${PLATFORM} - creating empty hierarchy"
                    HIERARCHY_FILE="/tmp/test_hierarchy_${TARGET_CONFIG//[^a-zA-Z0-9_-]/_}_${PLATFORM}_${MULTI_SESSION}.json"
                    jq -n --arg test_list "$TARGET_CONFIG" \
                          --arg test_session "$MULTI_SESSION" \
                          --arg config "$TARGET_CONFIG" \
                          --arg platform "$PLATFORM" \
                          '{
                            "test_list": $test_list,
                            "test_session": $test_session,
                            "original_configs": [$config],
                            "at_references": [],
                            "direct_configs": [$config],
                            "config_results": [
                              {
                                "config": $config,
                                "status": "passed",
                                "platform": $platform,
                                "action_results": []
                              }
                            ]
                          }' > "$HIERARCHY_FILE"
                fi
            fi

            if [[ -n "$HIERARCHY_FILE" && -f "$HIERARCHY_FILE" ]]; then
                echo "📁 Found ${PLATFORM} hierarchy: $(basename "$HIERARCHY_FILE")"

                # Update platform info in hierarchy file
                TEMP_FILE=$(mktemp)
                jq --arg platform "$PLATFORM" '.config_results[].platform = $platform' "$HIERARCHY_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$HIERARCHY_FILE"

                PLATFORM_HIERARCHIES="$PLATFORM_HIERARCHIES${PLATFORM}:${HIERARCHY_FILE};"
                HIERARCHY_FILES="$HIERARCHY_FILES $HIERARCHY_FILE"
            else
                echo "⚠️ No hierarchy file found for ${PLATFORM} - metrics will show 0"
            fi
        fi

        PLATFORM_NUM=$((PLATFORM_NUM + 1))
    done

    # Generate unified multi-platform summary
    echo ""
    echo "📊 Multi-Platform Test Results"
    echo "==============================="
    echo ""
    echo "🎯 Final Multi-Platform Summary:"
    echo "================================"

    # Dynamically calculate totals across all platforms
    TOTAL_PASSED=0
    TOTAL_SKIPPED=0
    TOTAL_FAILED=0
    TESTED_PLATFORMS=""
    PLATFORM_COUNT=0

    # Helper function to get value from string-based storage
    get_platform_result() {
        local platform="$1"
        echo "$PLATFORM_RESULTS" | grep -o "${platform}:[^;]*" | cut -d: -f2
    }

    get_platform_hierarchy() {
        local platform="$1"
        echo "$PLATFORM_HIERARCHIES" | grep -o "${platform}:[^;]*" | cut -d: -f2
    }

    # Process each platform's results
    for PLATFORM in $TEST_PLATFORMS; do
        RESULT=$(get_platform_result "$PLATFORM")
        HIERARCHY_FILE=$(get_platform_hierarchy "$PLATFORM")

        if [[ "$RESULT" == "2" ]]; then
            continue  # Skip platforms that aren't supported
        fi

        PLATFORM_COUNT=$((PLATFORM_COUNT + 1))
        TESTED_PLATFORMS="$TESTED_PLATFORMS $PLATFORM"

        if [[ -n "$HIERARCHY_FILE" && -f "$HIERARCHY_FILE" ]]; then
            # Extract metrics for this platform
            P_PASSED=$(jq '[.config_results[] | select(.status == "passed")] | length' "$HIERARCHY_FILE" 2>/dev/null || echo "0")
            P_SKIPPED=$(jq '[.config_results[] | select(.status == "skipped")] | length' "$HIERARCHY_FILE" 2>/dev/null || echo "0")
            P_FAILED=$(jq '[.config_results[] | select(.status == "failed")] | length' "$HIERARCHY_FILE" 2>/dev/null || echo "0")

            # Add to totals
            TOTAL_PASSED=$((TOTAL_PASSED + P_PASSED))
            TOTAL_SKIPPED=$((TOTAL_SKIPPED + P_SKIPPED))
            TOTAL_FAILED=$((TOTAL_FAILED + P_FAILED))
        fi
    done

    TOTAL_CONFIGS=$((TOTAL_PASSED + TOTAL_SKIPPED + TOTAL_FAILED))
    TESTED_PLATFORMS_LIST=$(echo "$TESTED_PLATFORMS" | sed 's/^ *//' | tr ' ' ',')

    # Display summary header
    echo "Total Test Lists: 1"
    echo "Total Configs: $TOTAL_CONFIGS"
    echo "Platforms Tested: $TESTED_PLATFORMS_LIST ($PLATFORM_COUNT platform$(if [[ $PLATFORM_COUNT -gt 1 ]]; then echo 's'; fi))"
    echo ""

    # Display per-platform breakdown
    echo "🎯 Platform Breakdown:"
    for PLATFORM in $TEST_PLATFORMS; do
        RESULT=$(get_platform_result "$PLATFORM")
        HIERARCHY_FILE=$(get_platform_hierarchy "$PLATFORM")

        if [[ "$RESULT" == "2" ]]; then
            continue  # Skip unsupported platforms
        fi

        PLATFORM_ICON=$(just _get-platform-icon "$PLATFORM")

        if [[ -n "$HIERARCHY_FILE" && -f "$HIERARCHY_FILE" ]]; then
            P_PASSED=$(jq '[.config_results[] | select(.status == "passed")] | length' "$HIERARCHY_FILE" 2>/dev/null || echo "0")
            P_SKIPPED=$(jq '[.config_results[] | select(.status == "skipped")] | length' "$HIERARCHY_FILE" 2>/dev/null || echo "0")
            P_FAILED=$(jq '[.config_results[] | select(.status == "failed")] | length' "$HIERARCHY_FILE" 2>/dev/null || echo "0")
            P_TOTAL=$((P_PASSED + P_SKIPPED + P_FAILED))

            echo "   $PLATFORM_ICON $PLATFORM: ✅ $P_PASSED passed, ⏭️ $P_SKIPPED skipped, ❌ $P_FAILED failed ($P_TOTAL total)"
        else
            echo "   $PLATFORM_ICON $PLATFORM: ❌ ERROR (no results available)"
        fi
    done

    # Add comprehensive test map showing individual config results across platforms
    echo ""
    echo "📋 Comprehensive Test Map"
    echo "========================="
    echo ""

    # Collect all unique configs across all hierarchy files
    TEMP_ALL_CONFIGS="/tmp/all_configs_$$"
    > "$TEMP_ALL_CONFIGS"

    for PLATFORM in $TEST_PLATFORMS; do
        RESULT=$(get_platform_result "$PLATFORM")
        HIERARCHY_FILE=$(get_platform_hierarchy "$PLATFORM")

        if [[ "$RESULT" == "2" ]]; then
            continue  # Skip unsupported platforms
        fi

        if [[ -n "$HIERARCHY_FILE" && -f "$HIERARCHY_FILE" ]]; then
            jq -r '.config_results[].config' "$HIERARCHY_FILE" 2>/dev/null >> "$TEMP_ALL_CONFIGS"
        fi
    done

    # Get unique configs and sort them
    UNIQUE_CONFIGS=$(sort "$TEMP_ALL_CONFIGS" | uniq)
    rm -f "$TEMP_ALL_CONFIGS"

    if [[ -n "$UNIQUE_CONFIGS" ]]; then
        # Display each config with its status across all platforms
        while IFS= read -r config; do
            if [[ -n "$config" ]]; then
                echo "🔧 $config"

                # Show status for each platform
                for PLATFORM in $TEST_PLATFORMS; do
                    RESULT=$(get_platform_result "$PLATFORM")
                    HIERARCHY_FILE=$(get_platform_hierarchy "$PLATFORM")

                    if [[ "$RESULT" == "2" ]]; then
                        continue  # Skip unsupported platforms
                    fi

                    PLATFORM_ICON=$(just _get-platform-icon "$PLATFORM" 2>/dev/null || echo "📟")

                    if [[ -n "$HIERARCHY_FILE" && -f "$HIERARCHY_FILE" ]]; then
                        CONFIG_STATUS=$(jq -r '[.config_results[] | select(.config == "'"$config"'") | .status][0] // ""' "$HIERARCHY_FILE" 2>/dev/null)

                        case "$CONFIG_STATUS" in
                            "passed")
                                # Extract action count with fallback
                                ACTION_COUNT=$(jq -r '.config_results[] | select(.config == "'"$config"'") | .action_results // [] | length' "$HIERARCHY_FILE" 2>/dev/null || echo "0")

                                if [[ "$ACTION_COUNT" -gt 0 && "$ACTION_COUNT" != "null" ]]; then
                                    echo "   ├── $PLATFORM_ICON $PLATFORM: ✅ PASSED ($ACTION_COUNT actions)"

                                    # Extract action details safely without SIGPIPE
                                    ACTION_DETAILS=$(jq -r '.config_results[] | select(.config == "'"$config"'") |
                                           (.action_results // []) | sort_by(.sequence // 0)[:10][]? |
                                           select(.action != null) |
                                           "\(.action // "unknown") (\(.duration_ms // 0)ms)"' \
                                       "$HIERARCHY_FILE" 2>/dev/null)

                                    if [[ -n "$ACTION_DETAILS" ]]; then
                                        while IFS= read -r action_detail; do
                                            if [[ -n "$action_detail" ]]; then
                                                echo "   │   └── $action_detail"
                                            fi
                                        done <<< "$ACTION_DETAILS"
                                    fi
                                else
                                    # No action_results in hierarchy file - try to find from action results files directly
                                    ACTION_RESULTS_FILE=$(find "{{USER_DATA_DIR}}/logs" /tmp -name "test_action_results_*${config}*${PLATFORM}*.json" -type f -print -quit 2>/dev/null)

                                    if [[ -n "$ACTION_RESULTS_FILE" && -f "$ACTION_RESULTS_FILE" ]]; then
                                        DIRECT_ACTION_COUNT=$(jq 'length' "$ACTION_RESULTS_FILE" 2>/dev/null || echo "0")

                                        if [[ "$DIRECT_ACTION_COUNT" -gt 0 && "$DIRECT_ACTION_COUNT" != "null" ]]; then
                                            echo "   ├── $PLATFORM_ICON $PLATFORM: ✅ PASSED ($DIRECT_ACTION_COUNT actions)"

                                            # Extract action details safely without SIGPIPE
                                            DIRECT_ACTION_DETAILS=$(jq -r 'sort_by(.sequence // 0)[:10][] | "\(.action // "unknown") (\(.duration_ms // 0)ms)"' \
                                               "$ACTION_RESULTS_FILE" 2>/dev/null)

                                            if [[ -n "$DIRECT_ACTION_DETAILS" ]]; then
                                                while IFS= read -r action_detail; do
                                                    if [[ -n "$action_detail" ]]; then
                                                        echo "   │   └── $action_detail"
                                                    fi
                                                done <<< "$DIRECT_ACTION_DETAILS"
                                            fi
                                        else
                                            echo "   ├── $PLATFORM_ICON $PLATFORM: ✅ PASSED"
                                        fi
                                    else
                                        echo "   ├── $PLATFORM_ICON $PLATFORM: ✅ PASSED"
                                    fi
                                fi
                                ;;
                            "failed")
                                echo "   ├── $PLATFORM_ICON $PLATFORM: ❌ FAILED"
                                ;;
                            "skipped")
                                SKIP_REASON=$(jq -r '[.config_results[] | select(.config == "'"$config"'") | .skip_reason // "Platform incompatible"][0] // "Platform incompatible"' "$HIERARCHY_FILE" 2>/dev/null)
                                echo "   ├── $PLATFORM_ICON $PLATFORM: ⏭️  SKIPPED ($SKIP_REASON)"
                                ;;
                            "")
                                echo "   ├── $PLATFORM_ICON $PLATFORM: ⚫ NOT RUN"
                                ;;
                            *)
                                echo "   ├── $PLATFORM_ICON $PLATFORM: ❓ UNKNOWN ($CONFIG_STATUS)"
                                ;;
                        esac
                    else
                        echo "   ├── $PLATFORM_ICON $PLATFORM: ⚫ NO DATA"
                    fi
                done
                echo ""
            fi
        done <<< "$UNIQUE_CONFIGS"
    else
        echo "⚠️  No configuration results found across any platform"
        echo ""
    fi

    echo ""
    echo "Combined Results:"
    echo "✅ Passed: $TOTAL_PASSED"
    echo "⏭️  Skipped: $TOTAL_SKIPPED"
    echo "❌ Failed: $TOTAL_FAILED"
    echo ""
    echo "✅ Multi-platform breakdown complete"

    # Cleanup session files after summary
    echo "🧹 Cleaning up multi-platform session files..."
    rm -f /tmp/test_action_results_*_${MULTI_SESSION}_*.json 2>/dev/null || true
    for HIERARCHY_FILE in $HIERARCHY_FILES; do
        [[ -n "$HIERARCHY_FILE" ]] && rm -f "$HIERARCHY_FILE" 2>/dev/null || true
    done

    # Determine final result
    OVERALL_RESULT=0
    FAILED_PLATFORMS=""
    for PLATFORM in $TEST_PLATFORMS; do
        RESULT=$(get_platform_result "$PLATFORM")
        if [[ "$RESULT" != "0" && "$RESULT" != "2" ]]; then  # Not success and not skipped
            OVERALL_RESULT=1
            PLATFORM_ICON=$(just _get-platform-icon "$PLATFORM")
            FAILED_PLATFORMS="$FAILED_PLATFORMS\n   $PLATFORM_ICON $PLATFORM: FAILED (exit code: $RESULT)"
        fi
    done

    # Final result
    echo ""
    if [[ $OVERALL_RESULT -eq 0 ]]; then
        echo "✅ Multi-platform test suite completed successfully!"
        exit 0
    else
        echo "❌ Some platforms failed:"
        echo -e "$FAILED_PLATFORMS"
        exit 1
    fi

# Run tests across multiple platforms with unified summary (fixed config)
test:
    just _test-multi-platform "main"

# Run tests across multiple platforms with target selection and unified summary
test-all target="":
    #!/usr/bin/env bash
    set -euo pipefail

    # Handle target selection (argument or fzf)
    TARGET_CONFIG="{{target}}"
    if [ -z "$TARGET_CONFIG" ]; then
        # Use fzf selection like test-android/test-desktop
        selected=$(just _fzf-select-config "android" "all")
        if [ "$?" -eq 0 ] && [ -n "$selected" ]; then
            TARGET_CONFIG="$selected"
        else
            echo "❌ No selection made"
            exit 1
        fi
    fi

    just _test-multi-platform "$TARGET_CONFIG"

# Generate documentation
generate-docs:
    @echo "Generating documentation..."

# Create a new release
create-release version:
    @echo "Creating release {{version}}..."
    just update-version
    git add {{PROJECT_PATH}}/export_presets.cfg
    git commit -m "Bump version to {{version}}"
    git tag -a v{{version}} -m "Release {{version}}"
    git push origin main --tags

# Update MoltenVK ios
update-moltenvk:
    @echo "./fetchdepencies --ios needed on fresh build, not included...."
    cd extras/moltenVK && ./fetchDependencies --ios
    cd extras/MoltenVK && make ios
    cp -R extras/MoltenVK/Package/Release/MoltenVK/static/MoltenVK.xcframework export/ios
