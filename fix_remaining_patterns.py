#!/usr/bin/env python3
import re
import os

# List of files that still have violations
files_to_fix = [
    "./debug/actions/debug_action.gd",
    "./debug/actions/firebase_cpp/cpp_large_data_test_action.gd",
    "./debug/actions/firebase_cpp/cpp_timeout_behavior_test_action.gd", 
    "./debug/actions/firebase_cpp/cpp_firebase_debug_action.gd",
    "./debug/actions/firebase_cpp/cpp_error_handling_test_action.gd",
    "./debug/actions/firebase_backend/backend_async_pattern_test_action.gd",
    "./debug/actions/firebase_backend/backend_error_handling_test_action.gd",
    "./debug/actions/firebase_backend/backend_firebase_debug_action.gd",
    "./debug/actions/firebase_backend/backend_lifecycle_test_action.gd",
    "./debug/actions/firebase_backend/backend_method_mapping_test_action.gd",
    "./debug/actions/firebase_backend/backend_request_tracking_test_action.gd",
    "./debug/actions/firebase_backend/backend_timer_manager_test_action.gd",
    "./debug/actions/registrations/system_actions.gd",
    "./debug/actions/rtdb/firebase_operation_manager.gd",
    "./debug/actions/rtdb/rtdb_child_added_listener_action.gd",
    "./debug/actions/rtdb/rtdb_child_changed_listener_action.gd",
    "./debug/actions/rtdb/rtdb_child_removed_listener_action.gd",
    "./debug/actions/rtdb/rtdb_debug_action.gd",
    "./debug/actions/rtdb/rtdb_delete_value_action.gd",
    "./debug/actions/rtdb/rtdb_error_handling_test_action.gd",
    "./debug/actions/rtdb/rtdb_get_nested_path_action.gd",
    "./debug/actions/rtdb/rtdb_set_simple_value_action.gd",
    "./debug/actions/rtdb/rtdb_update_value_action.gd",
    "./debug/debug_menu_controller.gd"
]

os.chdir("project")

def fix_file_comprehensive(file_path):
    print(f"Fixing {file_path}...")
    
    try:
        with open(file_path, 'r') as f:
            lines = f.readlines()
        
        original_lines = lines[:]
        changes_made = 0
        
        i = 0
        while i < len(lines):
            line = lines[i]
            
            # Check for return statements (including return await)
            if 'return ' in line:
                # Look ahead for else: on next line(s)
                j = i + 1
                while j < len(lines) and lines[j].strip() == '':
                    j += 1  # Skip empty lines
                
                if j < len(lines):
                    next_line = lines[j]
                    
                    # Pattern 1: else: directly after return
                    if next_line.strip() == 'else:':
                        # Remove 'else:' and adjust indentation of following lines
                        del lines[j]  # Remove the 'else:' line
                        changes_made += 1
                        print(f"  Removed else: at line {j+1}")
                        continue
                    
                    # Pattern 2: elif after return - change to if
                    elif next_line.strip().startswith('elif '):
                        lines[j] = next_line.replace('elif ', 'if ', 1)
                        changes_made += 1
                        print(f"  Changed elif to if at line {j+1}")
            
            i += 1
        
        if changes_made > 0:
            with open(file_path, 'w') as f:
                f.writelines(lines)
            print(f"  ✅ Fixed {changes_made} patterns in {file_path}")
        else:
            print(f"  ⏭️  No changes needed in {file_path}")
            
    except Exception as e:
        print(f"  ❌ Error fixing {file_path}: {e}")

# Fix all files
for file_path in files_to_fix:
    if os.path.exists(file_path):
        fix_file_comprehensive(file_path)
    else:
        print(f"⚠️  File not found: {file_path}")

print("✅ Finished fixing remaining else-return violations")