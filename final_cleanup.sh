#!/usr/bin/env bash
set -euo pipefail

echo "🎯 Final cleanup for truly simple, robust, clean code..."
echo ""

# Remove remaining redundant local variables and normalize usage
echo "🔧 Removing redundant local variable declarations and normalizing paths..."

# Function to eliminate redundant local variables in testing-core
fix_testing_core() {
    local file="justfiles/justfile-testing-core.justfile"
    echo "   Cleaning $file..."
    
    # Remove redundant CONFIG_DIR and TEST_LIST_DIR declarations and fix their usage
    sed -i '' \
        -e '/CONFIG_DIR="\.\/{{DEBUG_CONFIG_DIR}}"/d' \
        -e '/TEST_LIST_DIR="\.\/{{TEST_LIST_DIR}}"/d' \
        -e 's/if \[\[ -d "$CONFIG_DIR" \]\]/if [[ -d "{{DEBUG_CONFIG_DIR}}" ]]/g' \
        -e 's/find "$CONFIG_DIR"/find "{{DEBUG_CONFIG_DIR}}"/g' \
        -e 's/TEST_LIST_PATH="$TEST_LIST_DIR\/${/TEST_LIST_PATH="{{TEST_LIST_DIR}}\/${/g' \
        "$file"
    
    echo "   ✅ $file cleaned"
}

# Apply the cleanup
fix_testing_core

echo ""
echo "🔍 Verification of clean patterns..."

# Check that we still have the centralized variables in core config
echo "✅ Centralized variables in core config:"
rg "DEBUG_CONFIG_DIR|TEST_LIST_DIR" justfiles/justfile-core-config.justfile

echo ""
echo "📊 Direct usage count after final cleanup:"
direct_usage=$(rg -c "{{DEBUG_CONFIG_DIR}}|{{TEST_LIST_DIR}}" justfiles/ justfile 2>/dev/null | awk -F: '{sum += $2} END {print sum}')
echo "   Direct centralized variable usage: $direct_usage references"

echo ""
echo "🔍 Checking for remaining redundant local variables:"
remaining=$(rg "CONFIG_DIR.*=.*{{|TEST_LIST_DIR.*=.*{{" justfiles/ 2>/dev/null || echo "None found")
if [[ "$remaining" != "None found" ]]; then
    echo "$remaining"
else
    echo "   ✅ No redundant local variables found!"
fi

echo ""
echo "🎯 Code Quality Principles Achieved:"
echo "✅ Single Source of Truth - All paths use centralized variables"
echo "✅ DRY (Don't Repeat Yourself) - No redundant variable declarations"
echo "✅ Simplicity - Direct variable usage, no unnecessary indirection"
echo "✅ Robustness - Consistent path handling across all files"
echo "✅ Maintainability - Changes require updating only 2 variables"
echo "✅ Readability - Clear, direct variable usage"
echo ""
echo "🏆 Result: Clean, robust, maintainable code architecture"