#!/usr/bin/env bash
set -euo pipefail

# GDScript Comment Cleanup Script - Comprehensive Version
# Removes ALL comments unless they have very specific value:
# - Only keep CRITICAL warnings and license info
# - Remove ALL documentation comments (## comments)
# - Remove obvious comments that restate code
# - Remove commented out code
# - Remove debug/TODO/explanatory comments

echo "🧹 COMPREHENSIVE GDSCRIPT COMMENT CLEANUP"
echo "========================================="
echo ""

# Find all GDScript files
gdscript_files=$(find project -name "*.gd" -type f)
total_files=$(echo "$gdscript_files" | wc -l | tr -d ' ')

echo "📊 Found $total_files GDScript files to analyze"
echo ""

# Backup count
echo "📊 Before cleanup:"
gdscript_comment_count=$(find project -name "*.gd" -type f -exec grep -c "^[[:space:]]*#" {} + 2>/dev/null | awk '{sum+=$1} END {print sum}' || echo "0")
echo "Total GDScript comments: $gdscript_comment_count"
echo ""

files_modified=0

# Function to clean GDScript comments
clean_gdscript_file() {
    local file="$1"
    local temp_file="${file}.gdscript_temp"
    
    echo "🔍 Cleaning: $file"
    
    # Use awk to intelligently remove comments
    awk '
    BEGIN { in_function = 0; }
    
    # Remove ALL documentation comments (## comments) including function/class docs
    /^[[:space:]]*## / { next; }
    
    # Only keep very specific critical comments - be extremely selective
    /^[[:space:]]*# (CRITICAL|SECURITY|Copyright|License|@export|@tool)/ { print; next; }
    
    # Remove ALL other comments - be comprehensive
    /^[[:space:]]*#/ { next; }
    
    # Keep all non-comment lines and remaining comments
    { print; }
    ' "$file" > "$temp_file"
    
    # Check if changes were made
    if ! cmp -s "$file" "$temp_file"; then
        mv "$temp_file" "$file"
        echo "  ✅ Cleaned"
        ((files_modified++))
    else
        rm -f "$temp_file"
        echo "  ⏭️  No changes needed"
    fi
}

# Process GDScript files
echo "Processing GDScript files..."
echo ""

while IFS= read -r file; do
    if [[ -f "$file" && -n "$file" ]]; then
        clean_gdscript_file "$file"
    fi
done <<< "$gdscript_files"

echo ""
echo "📊 After cleanup:"
gdscript_comment_count_after=$(find project -name "*.gd" -type f -exec grep -c "^[[:space:]]*#" {} + 2>/dev/null | awk '{sum+=$1} END {print sum}' || echo "0")
echo "Total GDScript comments: $gdscript_comment_count_after"
echo ""
echo "✅ Files modified: $files_modified"
echo "📉 Comments removed: $((gdscript_comment_count - gdscript_comment_count_after))"
echo ""

# Test that we didn't break syntax
echo "🧪 Testing GDScript syntax..."
syntax_errors=0
while IFS= read -r file; do
    if [[ -f "$file" && -n "$file" ]]; then
        if ! gdparse "$file" >/dev/null 2>&1; then
            echo "❌ Syntax error in: $file"
            ((syntax_errors++))
        fi
    fi
done <<< "$gdscript_files"

if [ $syntax_errors -eq 0 ]; then
    echo "✅ All GDScript syntax checks passed"
else
    echo "❌ Found $syntax_errors syntax errors - please review"
fi