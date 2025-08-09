#!/usr/bin/env bash
set -euo pipefail

# Comment Analysis Script for Justfiles
# Analyzes all comments to identify cleanup candidates

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANALYSIS_FILE="$SCRIPT_DIR/justfile_comment_analysis.txt"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')

echo "📝 JUSTFILE COMMENT ANALYSIS" | tee "$ANALYSIS_FILE"
echo "=============================" | tee -a "$ANALYSIS_FILE"
echo "Timestamp: $TIMESTAMP" | tee -a "$ANALYSIS_FILE"
echo "" | tee -a "$ANALYSIS_FILE"

# Function to analyze comment patterns
analyze_comments() {
    local category="$1"
    local pattern="$2"
    local description="$3"
    
    echo "🔍 $category" | tee -a "$ANALYSIS_FILE"
    echo "$(printf '=%.0s' {1..50})" | tee -a "$ANALYSIS_FILE"
    echo "Pattern: $pattern" | tee -a "$ANALYSIS_FILE"
    echo "Description: $description" | tee -a "$ANALYSIS_FILE"
    echo "" | tee -a "$ANALYSIS_FILE"
    
    local count=$(rg "$pattern" justfiles/ --no-heading | wc -l | tr -d ' ')
    echo "Found $count matches:" | tee -a "$ANALYSIS_FILE"
    
    if [ "$count" -gt 0 ]; then
        rg "$pattern" justfiles/ --no-heading -n | head -20 | tee -a "$ANALYSIS_FILE"
        if [ "$count" -gt 20 ]; then
            echo "... and $((count - 20)) more matches" | tee -a "$ANALYSIS_FILE"
        fi
    fi
    echo "" | tee -a "$ANALYSIS_FILE"
}

# Analyze different types of potentially obsolete comments
echo "Starting comprehensive comment analysis..." | tee -a "$ANALYSIS_FILE"
echo "" | tee -a "$ANALYSIS_FILE"

# 1. TODO comments (often outdated)
analyze_comments "TODO COMMENTS" "# TODO|# FIXME|# HACK|# NOTE.*TODO" "TODO items that might be obsolete"

# 2. Temporary comments
analyze_comments "TEMPORARY COMMENTS" "# TEMP|# TEMPORARY|# Quick|# For now" "Temporary fixes that might be permanent now"

# 3. Debug comments
analyze_comments "DEBUG COMMENTS" "# DEBUG|# Testing|# Test this|# For debugging" "Debug comments that might not be needed"

# 4. Obvious comments (state the obvious)
analyze_comments "OBVIOUS COMMENTS" "# Set |# Get |# Check |# Run |# Call |# Execute " "Comments that just restate the code"

# 5. Outdated version references
analyze_comments "VERSION REFERENCES" "# v[0-9]|# version|# Godot [0-9]|# Android [0-9]" "Version-specific comments that might be outdated"

# 6. Implementation details that are now obvious
analyze_comments "IMPLEMENTATION DETAILS" "# This function|# This command|# This will|# We need to" "Comments explaining obvious implementation"

# 7. Long separator lines (could be shortened)
analyze_comments "LONG SEPARATORS" "#{10,}" "Long comment separator lines"

# 8. Duplicate header comments
analyze_comments "DUPLICATE HEADERS" "# [A-Z][A-Z ]{20,}" "Potentially duplicate section headers"

# Summary statistics
echo "📊 COMMENT STATISTICS" | tee -a "$ANALYSIS_FILE"
echo "=====================" | tee -a "$ANALYSIS_FILE"

total_comments=$(rg "^[[:space:]]*#" justfiles/ --no-heading | wc -l | tr -d ' ')
total_files=$(find justfiles -name "*.justfile" | wc -l | tr -d ' ')
total_lines=$(find justfiles -name "*.justfile" -exec cat {} \; | wc -l | tr -d ' ')

echo "Total comment lines: $total_comments" | tee -a "$ANALYSIS_FILE"
echo "Total justfiles: $total_files" | tee -a "$ANALYSIS_FILE"
echo "Total lines: $total_lines" | tee -a "$ANALYSIS_FILE"
echo "Comment density: $(echo "scale=1; $total_comments * 100 / $total_lines" | bc -l 2>/dev/null || echo "N/A")%" | tee -a "$ANALYSIS_FILE"

echo "" | tee -a "$ANALYSIS_FILE"
echo "🎉 ANALYSIS COMPLETED" | tee -a "$ANALYSIS_FILE"
echo "=====================" | tee -a "$ANALYSIS_FILE"
echo "Results saved to: $ANALYSIS_FILE" | tee -a "$ANALYSIS_FILE"
echo "Review the categories above to identify cleanup candidates." | tee -a "$ANALYSIS_FILE"