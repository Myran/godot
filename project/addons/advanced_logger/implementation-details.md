# Advanced Logger - Tag Setup Implementation

This document outlines the implementation of the Tag Setup feature for the Advanced Logger addon.

## Files Modified

1. `logger_dock.tscn` - Updated with a new section for Tag Setups
2. `logger_dock.gd` - Added Tag Setup functionality

## Implementation Overview

The Tag Setup feature allows users to save, load, rename, and delete different tag configurations for the Advanced Logger. This enables quick switching between different logging setups for different development scenarios.

### Key Components

1. **Tag Setup Storage**: Uses a Dictionary to store named setups
2. **Config Integration**: Saves setups to the existing settings.cfg file
3. **UI Integration**: Adds a new section in the Tags tab for managing setups
4. **Context Menu**: Right-click functionality for loading, renaming, and deleting setups

### Usage

1. Configure active and ignored tags as desired
2. Click "Save Current Setup" and provide a name
3. Select a setup from the list and:
   - Double-click to load it
   - Right-click for additional options (Load, Rename, Delete)

### Default Setups

The system comes with two default setups:
- `default`: Empty configuration (no active or ignored tags)
- `debug_network`: Configuration focused on network debugging (active tag: "network")

## Manual Update Instructions

Due to the challenges with editing project files directly, these changes must be made manually:

1. **Right-click Menu Positioning Fix**:
   Update the `_on_setups_list_item_clicked` function to ensure the context menu is properly positioned.

2. **Rename Dialog Label Overlap Fix**:
   Implement the provided `_show_rename_dialog` function that clears the dialog text to avoid overlap.

3. **UI Path References**:
   Update all UI element references to reflect the new tabbed UI structure, particularly:
   - Update `SaveSetupButton` reference to: `$VBoxContainer/TabContainer/Tags/TagsContainer/SetupsSection/HBoxContainer/SaveSetupButton`
   - Update `SetupsList` reference to: `$VBoxContainer/TabContainer/Tags/TagsContainer/SetupsSection/ScrollContainer/SetupsList`

## Implementation Details

See `setup-implementation.txt` for the detailed implementation code.
