#!/usr/bin/env python3
import re
import os

# List of files that need fixing
files_to_fix = [
    "./debug/actions/debug_action.gd",
    "./debug/actions/firebase_backend/backend_async_pattern_test_action.gd",
    "./debug/actions/firebase_backend/backend_error_handling_test_action.gd",
    "./debug/actions/firebase_backend/backend_firebase_debug_action.gd",
    "./debug/actions/firebase_backend/backend_lifecycle_test_action.gd",
    "./debug/actions/firebase_backend/backend_method_mapping_test_action.gd",
    "./debug/actions/firebase_backend/backend_request_tracking_test_action.gd",
    "./debug/actions/firebase_backend/backend_timer_manager_test_action.gd",
    "./debug/actions/firebase_cpp/cpp_error_handling_test_action.gd",
    "./debug/actions/firebase_cpp/cpp_firebase_debug_action.gd",
    "./debug/actions/firebase_cpp/cpp_large_data_test_action.gd",
    "./debug/actions/firebase_cpp/cpp_timeout_behavior_test_action.gd",
    "./debug/actions/registrations/game_actions.gd",
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
    "./debug/actions/system_recording_integrity_action.gd",
    "./debug/actions/system_replay_integrity_action.gd",
    "./debug/actions/test_semantic_comprehensive_action.gd",
    "./debug/actions/test_semantic_coverage_action.gd",
    "./debug/debug_menu_controller.gd"
]

os.chdir("project")

def fix_file(file_path):
    print(f"Fixing {file_path}...")
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        original_content = content
        
        # Fix pattern: return ... \n\t\telse:\n\t\t\treturn
        # Look for return followed by else: on next line
        pattern1 = re.compile(r'(\s+return[^\n]+)\n(\s+)else:\s*\n(\s+return)', re.MULTILINE)
        content = pattern1.sub(r'\1\n\2\n\3', content)
        
        # Fix pattern: return ... \n\t\telif
        pattern2 = re.compile(r'(\s+return[^\n]+)\n(\s+)elif(\s)', re.MULTILINE)
        content = pattern2.sub(r'\1\n\2if\3', content)
        
        if content != original_content:
            with open(file_path, 'w') as f:
                f.write(content)
            print(f"  ✅ Fixed {file_path}")
        else:
            print(f"  ⏭️  No changes needed in {file_path}")
            
    except Exception as e:
        print(f"  ❌ Error fixing {file_path}: {e}")

# Fix all files
for file_path in files_to_fix:
    if os.path.exists(file_path):
        fix_file(file_path)
    else:
        print(f"⚠️  File not found: {file_path}")

print("✅ Finished fixing else-return violations")