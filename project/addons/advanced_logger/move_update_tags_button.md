# Moving the "Update Tags" Button to the Settings Tab

These instructions explain how to move the "Update Tags" button from the Tags tab to the Settings tab in the Advanced Logger plugin.

## Changes Required

1. Open the Godot Editor
2. Locate and open the `logger_dock.tscn` file in the `project/addons/advanced_logger/` directory
3. Make the following changes to the scene:

### Step 1: Remove the button from its current location

1. Select the `UpdateTagsButton` node in the scene tree:
   `VBoxContainer/TabContainer/Tags/TagsContainer/AvailableTagsSection/UpdateTagsButton`
2. Right-click on the node and select "Cut" (or press Ctrl+X)

### Step 2: Add the button to the Settings tab

1. Select the `ButtonsSection` node in the scene tree:
   `VBoxContainer/TabContainer/Settings/ButtonsSection`
2. Right-click on this node and select "Paste" (or press Ctrl+V)
3. The button should now appear as a child of the ButtonsSection
4. Rename the node to "UpdateTagsButton" if necessary

### Step 3: Configure the button properties

1. Make sure the button has the following properties:
   - **Layout**: Set layout mode to 2
   - **Size Flags Horizontal**: Set to 3 (Expand)
   - **Text**: "Update Tags"

### Step 4: Verify the changes

1. Save the scene
2. The script has already been updated to reference the new location
3. Test the plugin to make sure the button works correctly in its new location

## Alternative Method

Alternatively, you can use the provided `logger_dock_modified.tscn` file as a reference for how the scene should be structured after moving the button.

## Code Changes Already Made

The code reference to the button has already been updated in `logger_dock.gd`:

```gdscript
# Changed from:
@onready var _update_tags_button: Button = $VBoxContainer/TabContainer/Tags/TagsContainer/AvailableTagsSection/UpdateTagsButton

# To:
@onready var _update_tags_button: Button = $VBoxContainer/TabContainer/Settings/ButtonsSection/UpdateTagsButton
```

No further code changes are required.
