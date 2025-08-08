#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Centralizing debug_configs and test-lists paths using ripgrep..."
echo ""

# Counter for tracking changes
total_replacements=0

# Function to perform replacement and count changes
replace_and_count() {
    local pattern="$1"
    local replacement="$2"
    local description="$3"
    
    echo "🔍 $description"
    
    # Find files that contain the pattern
    if files=$(rg -l "$pattern" justfiles/ justfile 2>/dev/null); then
        echo "   Files to update:"
        echo "$files" | sed 's/^/     /'
        
        # Count total matches before replacement
        local matches=$(echo "$files" | xargs rg "$pattern" | wc -l | tr -d ' ')
        
        # Perform the replacement
        echo "$files" | xargs sed -i '' "s|$pattern|$replacement|g"
        
        echo "   ✅ Replaced $matches instances"
        total_replacements=$((total_replacements + matches))
    else
        echo "   ✅ No matches found (already updated)"
    fi
    echo ""
}

# Function to remove duplicate variable declarations
remove_duplicate_vars() {
    local var_pattern="$1"
    local description="$2"
    
    echo "🧹 $description"
    
    if files=$(rg -l "$var_pattern" justfiles/ justfile 2>/dev/null); then
        echo "   Files with duplicate variables:"
        echo "$files" | sed 's/^/     /'
        
        # Count and remove duplicate variable declarations
        local matches=$(echo "$files" | xargs rg "$var_pattern" | wc -l | tr -d ' ')
        echo "$files" | xargs sed -i '' "/$var_pattern/d"
        
        echo "   ✅ Removed $matches duplicate variable declarations"
        total_replacements=$((total_replacements + matches))
    else
        echo "   ✅ No duplicate variables found"
    fi
    echo ""
}

echo "📋 Phase 1: Replace hardcoded path references"
echo "=============================================="

# Replace all variations of project/debug_configs
replace_and_count "project/debug_configs" "{{DEBUG_CONFIG_DIR}}" "Replacing 'project/debug_configs' references"
replace_and_count "./project/debug_configs" "{{DEBUG_CONFIG_DIR}}" "Replacing './project/debug_configs' references"
replace_and_count "\"project/debug_configs" "\"{{DEBUG_CONFIG_DIR}}" "Replacing quoted 'project/debug_configs' references"

# Replace all variations of project/test-lists  
replace_and_count "project/test-lists" "{{TEST_LIST_DIR}}" "Replacing 'project/test-lists' references"
replace_and_count "./project/test-lists" "{{TEST_LIST_DIR}}" "Replacing './project/test-lists' references"
replace_and_count "\"project/test-lists" "\"{{TEST_LIST_DIR}}" "Replacing quoted 'project/test-lists' references"

echo "📋 Phase 2: Remove duplicate variable declarations"
echo "================================================="

# Remove duplicate variable declarations
remove_duplicate_vars 'CONFIG_DIR=".*project/debug_configs.*"' "Removing duplicate CONFIG_DIR declarations"
remove_duplicate_vars 'CONFIGS_DIR=".*project/debug_configs.*"' "Removing duplicate CONFIGS_DIR declarations"  
remove_duplicate_vars 'TEST_LIST_DIR=".*project/test-lists.*"' "Removing duplicate TEST_LIST_DIR declarations"

echo "📊 SUMMARY"
echo "=========="
echo "✅ Total replacements made: $total_replacements"
echo ""

# Verify the changes
echo "🔍 Verification: Checking for remaining hardcoded references..."
remaining_debug=$(rg -c "project/debug_configs" justfiles/ justfile 2>/dev/null | grep -v ":0" || true)
remaining_test=$(rg -c "project/test-lists" justfiles/ justfile 2>/dev/null | grep -v ":0" || true)

if [[ -n "$remaining_debug" || -n "$remaining_test" ]]; then
    echo "⚠️  WARNING: Some hardcoded references may remain:"
    if [[ -n "$remaining_debug" ]]; then
        echo "   debug_configs references:"
        echo "$remaining_debug" | sed 's/^/     /'
    fi
    if [[ -n "$remaining_test" ]]; then
        echo "   test-lists references:"  
        echo "$remaining_test" | sed 's/^/     /'
    fi
    echo ""
    echo "💡 Manual review may be needed for complex cases"
else
    echo "✅ No remaining hardcoded references found!"
fi

echo ""
echo "🎯 Next steps:"
echo "1. Test critical commands: just config-list, just test-android development-workflow" 
echo "2. If tests pass, proceed with folder move (Phase 2)"
echo "3. Update centralized variables to new paths"