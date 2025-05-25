#!/bin/bash
# Fix listener callback methods

echo "Fixing listener callback methods..."

# Fix bind calls that pass target_node
sed -i '' 's/\.bind(target_node)/.bind()/' project/debug/actions/rtdb/*_listener_action.gd
sed -i '' 's/connect(_on_.*\.bind(target_node))/connect(_on_child_added)/g' project/debug/actions/rtdb/*_listener_action.gd

# Fix callback method signatures
sed -i '' 's/func _on_child_added(child_key: String, child_value: Variant, target_node: Node)/func _on_child_added(child_key: String, child_value: Variant)/g' project/debug/actions/rtdb/*_listener_action.gd
sed -i '' 's/func _on_child_changed(child_key: String, child_value: Variant, target_node: Node)/func _on_child_changed(child_key: String, child_value: Variant)/g' project/debug/actions/rtdb/*_listener_action.gd
sed -i '' 's/func _on_child_removed(child_key: String, child_value: Variant, target_node: Node)/func _on_child_removed(child_key: String, child_value: Variant)/g' project/debug/actions/rtdb/*_listener_action.gd

# Fix any remaining target_node parameter references in method calls
for file in project/debug/actions/rtdb/*_listener_action.gd; do
    if [ -f "$file" ]; then
        echo "Fixing callback bindings in $file..."
        # More specific fixes
        sed -i '' 's/connect(_on_child_added\.bind(target_node))/connect(_on_child_added)/' "$file"
        sed -i '' 's/connect(_on_child_changed\.bind(target_node))/connect(_on_child_changed)/' "$file"
        sed -i '' 's/connect(_on_child_removed\.bind(target_node))/connect(_on_child_removed)/' "$file"
    fi
done

echo "Listener callback method fixes complete."
