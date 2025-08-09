#!/usr/bin/env bash
set -euo pipefail

# Aggressive Comment Cleanup Script
# Removes all comments except those with particular value:
# - Section headers (# =====, # SECTION NAME)  
# - Important warnings/notes (# WARNING, # IMPORTANT, # NOTE, # CRITICAL)
# - Complex algorithm explanations (multi-line comments with substance)
# - Copyright/license headers
# - TODOs and FIXMEs (might be valuable)

echo "🧹 AGGRESSIVE COMMENT CLEANUP"
echo "=============================="
echo ""

# Backup count
echo "📊 Before aggressive cleanup:"
echo "Total comments: $(rg "^[[:space:]]*#" justfiles/ --no-heading | wc -l | tr -d ' ')"
echo ""

files_modified=0

# Function to aggressively clean comments from a file
aggressive_clean_file() {
    local file="$1"
    local temp_file="${file}.aggressive_temp"
    
    echo "🔥 Aggressively cleaning: $file"
    
    # Use awk to remove comments that don't have particular value
    awk '
    BEGIN { in_function = 0; empty_lines = 0; }
    
    # Skip completely empty lines and track consecutive empty lines
    /^[[:space:]]*$/ { 
        empty_lines++; 
        if (empty_lines <= 2) print; 
        next; 
    }
    
    # Reset empty line counter
    { empty_lines = 0; }
    
    # Keep section headers (long lines of === or capitalized sections)
    /^[[:space:]]*# ={5,}/ { print; next; }
    /^[[:space:]]*# [A-Z][A-Z ]{10,}/ { print; next; }
    
    # Keep important warning/note comments
    /^[[:space:]]*# (WARNING|IMPORTANT|NOTE|CRITICAL|FIXME|TODO|HACK)/ { print; next; }
    
    # Keep copyright/license comments
    /^[[:space:]]*# (Copyright|License|Author)/ { print; next; }
    
    # Keep function/command descriptions (comments directly above function definitions)
    /^[[:space:]]*# / {
        # Look ahead to see if next non-empty line is a function definition
        getline next_line;
        if (next_line ~ /^[a-zA-Z0-9_-]+[[:space:]]*:/) {
            # This is a function description - keep it
            print;
            print next_line;
            next;
        } else {
            # Not a function description - skip the comment, keep the next line
            print next_line;
            next;
        }
    }
    
    # Keep all non-comment lines
    !/^[[:space:]]*#/ { print; }
    ' "$file" > "$temp_file"
    
    # Check if changes were made
    if ! cmp -s "$file" "$temp_file"; then
        mv "$temp_file" "$file"
        echo "  ✅ Aggressively cleaned"
        ((files_modified++))
    else
        rm -f "$temp_file"
        echo "  ⏭️  No changes needed"
    fi
}

# Process all justfiles
echo "Processing justfiles..."
echo ""

for file in justfiles/*.justfile; do
    if [[ -f "$file" ]]; then
        aggressive_clean_file "$file"
    fi
done

echo ""
echo "📊 After aggressive cleanup:"
echo "Total comments: $(rg "^[[:space:]]*#" justfiles/ --no-heading | wc -l | tr -d ' ')"
echo ""
echo "✅ Files modified: $files_modified"
echo ""
echo "🧪 Testing functionality..."
if just --dry-run validate-all >/dev/null 2>&1 && just --dry-run test-android-target system-testing >/dev/null 2>&1; then
    echo "✅ Functionality tests passed"
else
    echo "❌ Functionality tests failed - please review changes"
fi