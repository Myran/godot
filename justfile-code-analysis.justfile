# Code analysis and validation commands
# Self-contained utilities for analyzing GDScript code patterns

# Analyze dictionary iteration patterns in the codebase
analyze-dict-patterns:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔍 Analyzing dictionary iteration patterns in GDScript files..."
    echo ""
    
    # Find direct dictionary key iteration patterns
    echo "📋 Direct dictionary key iteration (should use DictUtils):"
    find project -name "*.gd" -exec grep -Hn "for .* in .*\.keys()" {} \; | grep -v "DictUtils" || echo "  ✅ No problematic patterns found"
    echo ""
    
    # Find direct dictionary iteration
    echo "📋 Direct dictionary iteration (may need deterministic ordering):"
    grep -rn "for .* in [a-zA-Z_][a-zA-Z0-9_]*:" project/**/*.gd | head -10 || echo "  ✅ No patterns found"
    echo ""
    
    # Find Array.map() usage that might have typing issues
    echo "📋 Array.map() usage (check for type safety):"
    grep -rn "\.map(" project/**/*.gd || echo "  ✅ No .map() usage found"
    echo ""
    
    # Check current DictUtils usage
    echo "📋 Current DictUtils usage:"
    grep -rn "DictUtils\." project/**/*.gd | wc -l | awk '{print "  Found " $1 " usages"}'
    echo ""
    
    echo "💡 Run 'just validate-dict-patterns' to check compliance"

# Validate dictionary patterns comply with DictUtils standards
validate-dict-patterns:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔍 Validating dictionary pattern compliance..."
    
    VIOLATIONS=0
    
    # Check for direct dictionary key iteration
    if find project -name "*.gd" -exec grep -l "for .* in .*\.keys()" {} \; | grep -v "DictUtils" >/dev/null 2>&1; then
        echo "❌ Found direct dictionary key iteration patterns:"
        find project -name "*.gd" -exec grep -Hn "for .* in .*\.keys()" {} \; | grep -v "DictUtils" || true
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
    
    # Check for direct dictionary iteration (excluding Array iterations)
    # Look for dictionary-specific patterns that might be problematic
    DICT_ITERATION_PATTERNS=$(find project -name "*.gd" -exec grep -l "for .* in .*\.values()\|for .* in .*:" {} \; 2>/dev/null | wc -l || echo "0")
    if [ "$DICT_ITERATION_PATTERNS" -gt 0 ]; then
        echo "ℹ️  Found $DICT_ITERATION_PATTERNS files with dictionary-like iteration patterns"
        echo "   (This is informational - manual review recommended for battle-critical code)"
        # Don't count this as a violation for now
    fi
    
    if [ $VIOLATIONS -eq 0 ]; then
        echo "✅ Dictionary patterns validation passed"
        exit 0
    else
        echo "⚠️  Found $VIOLATIONS dictionary pattern violations"
        echo "💡 Use DictUtils.deterministic_iterate() for consistent ordering"
        exit 1
    fi