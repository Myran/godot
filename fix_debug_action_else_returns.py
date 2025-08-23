#!/usr/bin/env python3
"""
Fix remaining else-return violations in debug_action.gd
This script identifies and fixes if-return-else-return patterns.
"""

import re

def fix_else_return_patterns(content):
    """Fix else-return patterns while preserving logic."""
    
    # Pattern 1: Simple if-return-else-return pattern
    # Matches: if condition:\n    return value\nelse:\n    return other_value
    pattern1 = re.compile(
        r'(\s+)if\s+([^:]+):\s*\n'  # if statement with condition
        r'(\s+)return\s+([^\n]+)\n'  # return statement
        r'(\s+)else:\s*\n'  # else statement
        r'(\s+)((?:.*\n)*?)'  # content inside else (can be multiline)
        r'(\s+)return\s+([^\n]+)',  # final return statement
        re.MULTILINE | re.DOTALL
    )
    
    def replace_pattern1(match):
        indent1 = match.group(1)
        condition = match.group(2)
        indent2 = match.group(3)
        return1 = match.group(4)
        else_content = match.group(6).strip()
        indent4 = match.group(8)
        return2 = match.group(9)
        
        result = f"{indent1}if {condition}:\n{indent2}return {return1}\n{indent1}\n"
        
        # Add the else content if any (properly indented)
        if else_content:
            for line in else_content.split('\n'):
                if line.strip():
                    result += f"{indent1}{line.strip()}\n"
        
        result += f"{indent1}return {return2}"
        return result
    
    # Apply the pattern fixes
    fixed_content = pattern1.sub(replace_pattern1, content)
    
    return fixed_content

def main():
    file_path = "project/debug/actions/debug_action.gd"
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    original_content = content
    fixed_content = fix_else_return_patterns(content)
    
    if fixed_content != original_content:
        with open(file_path, 'w') as f:
            f.write(fixed_content)
        print(f"Fixed else-return patterns in {file_path}")
        
        # Count changes made
        original_lines = original_content.count('\n')
        fixed_lines = fixed_content.count('\n')
        print(f"Line count change: {original_lines} -> {fixed_lines}")
    else:
        print("No changes needed")

if __name__ == "__main__":
    main()