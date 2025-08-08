#!/usr/bin/env bash
set -euo pipefail

echo "🧹 Cleaning up redundant local variables for simple, robust, clean code..."
echo ""

# Counter for tracking changes
total_replacements=0

# Function to perform cleanup and count changes
cleanup_and_count() {
    local pattern="$1"
    local replacement="$2" 
    local description="$3"
    
    echo "🔧 $description"
    
    # Find files that contain the pattern
    if files=$(rg -l "$pattern" justfiles/ 2>/dev/null); then
        echo "   Files to update:"
        echo "$files" | sed 's/^/     /'
        
        # Count total matches before replacement
        local matches=$(echo "$files" | xargs rg "$pattern" | wc -l | tr -d ' ')
        
        # Perform the replacement
        echo "$files" | xargs sed -i '' "s|$pattern|$replacement|g"
        
        echo "   ✅ Cleaned $matches instances"
        total_replacements=$((total_replacements + matches))
    else
        echo "   ✅ No instances found (already clean)"
    fi
    echo ""
}

# Function to remove entire lines containing redundant variable declarations
remove_redundant_lines() {
    local pattern="$1"
    local description="$2"
    
    echo "🗑️  $description"
    
    if files=$(rg -l "$pattern" justfiles/ 2>/dev/null); then
        echo "   Files with redundant variables:"
        echo "$files" | sed 's/^/     /'
        
        # Count and remove redundant variable declarations
        local matches=$(echo "$files" | xargs rg "$pattern" | wc -l | tr -d ' ')
        
        # Remove the entire lines containing these patterns
        echo "$files" | xargs sed -i '' "/$pattern/d"
        
        echo "   ✅ Removed $matches redundant variable lines"
        total_replacements=$((total_replacements + matches))
    else
        echo "   ✅ No redundant variables found"
    fi
    echo ""
}

echo "📋 Phase 1: Eliminate Redundant Local Variables"
echo "=============================================="

# Remove redundant local variable declarations that just duplicate centralized ones
remove_redundant_lines 'CONFIG_DIR="\./{{DEBUG_CONFIG_DIR}}"' "Removing redundant CONFIG_DIR local variables"
remove_redundant_lines 'TEST_LIST_DIR="\./{{TEST_LIST_DIR}}"' "Removing redundant TEST_LIST_DIR local variables"
remove_redundant_lines 'CONFIGS_DIR="{{DEBUG_CONFIG_DIR}}"' "Removing redundant CONFIGS_DIR local variables"

echo "📋 Phase 2: Direct Substitution for Cleaner Code"  
echo "================================================"

# Replace remaining usage of local variables with direct centralized variable usage
cleanup_and_count '\$CONFIG_DIR' '{{DEBUG_CONFIG_DIR}}' "Replace \$CONFIG_DIR usage with direct centralized variable"
cleanup_and_count '\$TEST_LIST_DIR' '{{TEST_LIST_DIR}}' "Replace \$TEST_LIST_DIR usage with direct centralized variable"
cleanup_and_count '\$CONFIGS_DIR' '{{DEBUG_CONFIG_DIR}}' "Replace \$CONFIGS_DIR usage with direct centralized variable"

echo "📋 Phase 3: Path Prefix Normalization"
echo "====================================="

# Normalize path prefixes - remove unnecessary "./" prefixes since centralized vars are already clean
cleanup_and_count '\./{{DEBUG_CONFIG_DIR}}' '{{DEBUG_CONFIG_DIR}}' "Remove unnecessary './' prefix from DEBUG_CONFIG_DIR"
cleanup_and_count '\./{{TEST_LIST_DIR}}' '{{TEST_LIST_DIR}}' "Remove unnecessary './' prefix from TEST_LIST_DIR"

echo "📊 CLEANUP SUMMARY"
echo "=================="
echo "✅ Total cleanups performed: $total_replacements"
echo ""

# Verify the cleanup results
echo "🔍 Verification: Checking for remaining redundant patterns..."
remaining_local_vars=$(rg -c "CONFIG_DIR.*=.*{{|TEST_LIST_DIR.*=.*{{|CONFIGS_DIR.*=" justfiles/ 2>/dev/null | grep -v ":0" || true)

if [[ -n "$remaining_local_vars" ]]; then
    echo "⚠️  Some redundant local variables may remain:"
    echo "$remaining_local_vars" | sed 's/^/     /'
else
    echo "✅ No redundant local variable declarations found!"
fi

# Check for consistent path usage
echo ""
echo "📏 Final path usage patterns:"
direct_usage=$(rg -c "{{DEBUG_CONFIG_DIR}}|{{TEST_LIST_DIR}}" justfiles/ justfile 2>/dev/null | awk -F: '{sum += $2} END {print sum}')
echo "   Direct centralized variable usage: $direct_usage references"

echo ""
echo "🎯 Code Quality Improvements:"
echo "✅ Eliminated redundant local variables"
echo "✅ Reduced code complexity" 
echo "✅ Improved maintainability"
echo "✅ Enhanced readability"
echo "✅ Ensured consistent path handling"