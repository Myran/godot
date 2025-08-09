#!/usr/bin/env bash
set -euo pipefail

# Script to clean up obvious comments that just restate the code
# Removes comments that add no value like "# Check if..." before an if statement

echo "🧹 CLEANING OBVIOUS COMMENTS"
echo "============================"
echo ""

# Backup count
echo "📊 Before cleanup:"
echo "Total comments: $(rg "^[[:space:]]*#" justfiles/ --no-heading | wc -l | tr -d ' ')"
echo "Obvious comments: $(rg "# (Check |Get |Set |Call |Run |Execute )" justfiles/ --no-heading | wc -l | tr -d ' ')"
echo ""

files_modified=0

# Function to clean obvious comments from a file
clean_file() {
    local file="$1"
    local temp_file="${file}.cleaning_temp"
    local changes_made=false
    
    echo "🔍 Cleaning: $file"
    
    # Create a temporary file for processing
    cp "$file" "$temp_file"
    
    # Remove obvious "Check if" comments that are followed by if statements
    if sed -i.bak '/^[[:space:]]*# Check if.*$/N; /^[[:space:]]*# Check if.*\n[[:space:]]*if\|^[[:space:]]*# Check if.*\n[[:space:]]*elif/s/^[[:space:]]*# Check if.*\n//' "$temp_file" 2>/dev/null; then
        if ! cmp -s "$file" "$temp_file"; then
            changes_made=true
        fi
    fi
    
    # Remove obvious "Check [object]" comments before conditionals
    if sed -i.bak '/^[[:space:]]*# Check [a-z].*$/N; /^[[:space:]]*# Check [a-z].*\n[[:space:]]*if\|^[[:space:]]*# Check [a-z].*\n[[:space:]]*elif/s/^[[:space:]]*# Check [a-z].*\n//' "$temp_file" 2>/dev/null; then
        if ! cmp -s "$file" "$temp_file"; then
            changes_made=true
        fi
    fi
    
    # Remove obvious "Get/Set" comments before assignments
    if sed -i.bak '/^[[:space:]]*# Get .*$/N; /^[[:space:]]*# Get .*\n[[:space:]]*[A-Z_][A-Z_]*=/s/^[[:space:]]*# Get .*\n//' "$temp_file" 2>/dev/null; then
        if ! cmp -s "$file" "$temp_file"; then
            changes_made=true
        fi
    fi
    
    if sed -i.bak '/^[[:space:]]*# Set .*$/N; /^[[:space:]]*# Set .*\n[[:space:]]*[A-Z_][A-Z_]*=/s/^[[:space:]]*# Set .*\n//' "$temp_file" 2>/dev/null; then
        if ! cmp -s "$file" "$temp_file"; then
            changes_made=true
        fi
    fi
    
    # If changes were made, replace the original
    if [ "$changes_made" = true ]; then
        mv "$temp_file" "$file"
        echo "  ✅ Modified"
        ((files_modified++))
    else
        rm -f "$temp_file"
        echo "  ⏭️  No obvious comments found"
    fi
    
    # Clean up backup files
    rm -f "${temp_file}.bak"
}

# Process all justfiles
echo "Processing justfiles..."
echo ""

for file in justfiles/*.justfile; do
    if [[ -f "$file" ]]; then
        clean_file "$file"
    fi
done

echo ""
echo "📊 After cleanup:"
echo "Total comments: $(rg "^[[:space:]]*#" justfiles/ --no-heading | wc -l | tr -d ' ')"
echo "Obvious comments: $(rg "# (Check |Get |Set |Call |Run |Execute )" justfiles/ --no-heading | wc -l | tr -d ' ')"
echo ""
echo "✅ Files modified: $files_modified"
echo ""
echo "🧪 Testing functionality..."
if just --dry-run validate-all >/dev/null 2>&1; then
    echo "✅ Basic functionality test passed"
else
    echo "❌ Basic functionality test failed - please review changes"
fi