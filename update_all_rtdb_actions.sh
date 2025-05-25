#!/bin/bash
# Comprehensive script to update all RTDB action files for Phase 1

echo "Updating all remaining RTDB action files..."

# Get all action files that haven't been updated yet
files=($(find project/debug/actions/rtdb -name "*_action.gd" -type f | grep -v rtdb_debug_action.gd))

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "Processing $file..."
        
        # Update execute method signature
        sed -i '' 's/func execute(target_node: Node = null) -> Array:/func execute() -> Array:/' "$file"
        
        # Update get_firebase_database_for_target calls
        sed -i '' 's/get_firebase_database_for_target(target_node)/get_firebase_database()/' "$file"
        sed -i '' 's/get_firebase_database_for_target(/get_firebase_database(/' "$file"
        
        # Update _update_status calls
        sed -i '' 's/_update_status(target_node,/_update_status(/g' "$file"
        
        # Update execute_simple_operation calls
        sed -i '' 's/execute_simple_operation(target_node,/execute_simple_operation(/g' "$file"
        
        # Update tree access calls (common pattern)
        sed -i '' 's/target_node\.get_tree()/Engine.get_main_loop()/g' "$file"
        
        echo "  Updated: $file"
    else
        echo "  File not found: $file"
    fi
done

echo "RTDB action file updates complete."
