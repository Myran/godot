#!/usr/bin/env bash
set -euo pipefail

echo "🧹 COMPREHENSIVE GDSCRIPT CLEANUP - ALL FILES"
echo "=============================================="

# Get all GDScript files with comments
files_with_comments=($(find project -name "*.gd" -type f -exec grep -l "^[[:space:]]*#" {} \;))
total_files=${#files_with_comments[@]}

echo "📊 Found $total_files GDScript files with comments"

# Count comments before
before_count=$(find project -name "*.gd" -type f -exec grep -c "^[[:space:]]*#" {} \; | awk '{sum+=$1} END {print sum}')
echo "📊 Comments before cleanup: $before_count"
echo ""

files_modified=0

# Clean each file
for file in "${files_with_comments[@]}"; do
    echo "🔍 Processing: $file"
    
    # Create temporary file with aggressive comment removal
    awk '
    # Only keep absolutely critical comments
    /^[[:space:]]*# (CRITICAL|SECURITY|Copyright|License)/ { print; next; }
    
    # Remove ALL other comments (including ## documentation)
    /^[[:space:]]*#/ { next; }
    
    # Keep all non-comment lines
    { print; }
    ' "$file" > "${file}.tmp"
    
    # Check if changes were made
    if ! cmp -s "$file" "${file}.tmp"; then
        mv "${file}.tmp" "$file"
        echo "  ✅ Cleaned"
        ((files_modified++))
    else
        rm -f "${file}.tmp"
        echo "  ⏭️  No changes"
    fi
done

# Count comments after
after_count=$(find project -name "*.gd" -type f -exec grep -c "^[[:space:]]*#" {} \; | awk '{sum+=$1} END {print sum}')

echo ""
echo "📊 RESULTS:"
echo "Files processed: $total_files"
echo "Files modified: $files_modified" 
echo "Comments before: $before_count"
echo "Comments after: $after_count"
echo "Comments removed: $((before_count - after_count))"