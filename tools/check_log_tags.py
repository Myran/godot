#!/usr/bin/env python3
import os
import re
import sys

def check_log_tags(file_path):
    """Check if a file contains logging calls with string literal tags instead of Log.TAG_ constants"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except UnicodeDecodeError:
        # Skip binary files or files with encoding issues
        return []
    
    # Find all Log calls with their tags
    log_calls = re.findall(r'Log\.(debug|info|warning|error|critical)\s*\(\s*[^,]+,\s*[^,]*,\s*\[(.*?)\]', content)
    
    issues = []
    for log_level, tags in log_calls:
        # Extract tags, which could be either string literals or Log.TAG_ constants
        tag_matches = re.findall(r'(["\']([^"\']+)["\']|Log\.TAG_\w+)', tags)
        for full_tag, string_content in tag_matches:
            # If the second group has content, it means this was a string literal
            if string_content:
                issues.append({
                    "level": log_level,
                    "tag": string_content,
                    "full_match": full_tag
                })
    
    return issues

def main():
    """Main function to check all GDScript files in the project"""
    issues_found = 0
    project_root = '/Users/mattiasmyhrman/repos/gametwo'
    
    print("Scanning for string literal tags in logging calls...")
    print("=" * 70)
    
    for root, _, files in os.walk(project_root):
        for file in files:
            if file.endswith('.gd'):
                file_path = os.path.join(root, file)
                file_issues = check_log_tags(file_path)
                
                if file_issues:
                    # Calculate relative path for cleaner output
                    rel_path = os.path.relpath(file_path, project_root)
                    print(f"\n{rel_path}:")
                    
                    for issue in file_issues:
                        print(f"  - String literal tag '{issue['tag']}' in Log.{issue['level']} call")
                        print(f"    Suggestion: Replace '{issue['full_match']}' with 'Log.TAG_{issue['tag'].upper()}'")
                        issues_found += 1
    
    print("\n" + "=" * 70)
    print(f"Total issues found: {issues_found}")
    
    if issues_found > 0:
        print("\nRecommendation: Update the string literals with Log.TAG_ constants.")
        print("The appropriate tag constants should already be defined in logger.gd")
        return 1
    else:
        print("\nAll logging calls are using proper Log.TAG_ constants. Good job!")
        return 0

if __name__ == "__main__":
    sys.exit(main())
