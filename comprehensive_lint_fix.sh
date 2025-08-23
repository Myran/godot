#!/bin/bash
set -euo pipefail

cd project

echo "🔧 Fixing GDScript linting issues comprehensively..."

# Get list of files with no-else-return violations from gdlint output
files_with_else_return=$(find . -name "*.gd" -type f -not -path "./addons/*" | grep -v -f .gdlintignore | xargs gdlint 2>&1 | grep "no-else-return\|no-elif-return" | cut -d: -f1 | sort -u)

if [ -z "$files_with_else_return" ]; then
    echo "No files with else-return violations found"
else
    echo "Files with else-return violations:"
    echo "$files_with_else_return"
    
    # Fix each file individually
    for file in $files_with_else_return; do
        echo "Fixing $file..."
        
        # Create a Python script to fix the issues properly
        python3 << EOF
import re

file_path = "$file"
with open(file_path, 'r') as f:
    content = f.read()

# Pattern to match: return statement followed by else: return
# This regex handles indentation properly
pattern1 = re.compile(r'(\s+)return ([^\n]+)\n(\s+)else:\s*\n(\s+)return', re.MULTILINE)
content = pattern1.sub(r'\1return \2\n\3\n\4return', content)

# Pattern to match: return statement followed by elif
pattern2 = re.compile(r'(\s+)return ([^\n]+)\n(\s+)elif', re.MULTILINE)
content = pattern2.sub(r'\1return \2\n\3if', content)

with open(file_path, 'w') as f:
    f.write(content)
EOF
    done
fi

echo "✅ Fixed else-return violations"