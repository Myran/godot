#!/bin/bash
# Script to update RTDB action files - Phase 1 refactoring

echo "Updating RTDB action files to remove target_node parameter..."

# List of files to update
files=(
    "project/debug/actions/rtdb/rtdb_set_nested_path_action.gd"
    "project/debug/actions/rtdb/rtdb_delete_value_action.gd"
    "project/debug/actions/rtdb/rtdb_update_value_action.gd"
    "project/debug/actions/rtdb/rtdb_get_nested_path_action.gd"
    "project/debug/actions/rtdb/rtdb_list_children_action.gd"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "Processing $file..."
        # Update execute method signature
        sed -i '' 's/func execute(target_node: Node = null) -> Array:/func execute() -> Array:/' "$file"
        # Update execute_simple_operation calls to remove target_node parameter
        sed -i '' 's/execute_simple_operation(target_node,/execute_simple_operation(/' "$file"
        echo "  Updated: $file"
    else
        echo "  File not found: $file"
    fi
done

echo "Basic action file updates complete."
