# How to Test and Apply Logger Refactoring

This document explains how to test and apply the Logger refactoring changes outlined in Phase 4 of the Advanced Logger improvement plan.

## Overview of Changes

The Logger class has been refactored to:
1. Break down large methods into smaller, more focused ones
2. Remove duplicate code
3. Improve error handling
4. Enhance testability

## Testing Steps

### Method 1: Testing in the Editor

1. Open the Godot Editor by running `just edit` from the project root
2. In the FileSystem panel, navigate to:
   `res://addons/advanced_logger/tests/logger_refactoring_test.tscn`
3. Run this scene (F5 or the "Play" button)
4. Check the Output panel for test results
   - All tests should pass
   - If any tests fail, note the failures for debugging

### Method 2: Manual Testing

1. Temporarily replace the original logger.gd with the refactored version:
   ```bash
   mv project/addons/advanced_logger/core/logger.gd project/addons/advanced_logger/core/logger.gd.backup
   cp project/addons/advanced_logger/core/logger.gd.new project/addons/advanced_logger/core/logger.gd
   ```

2. Run the original test scenes to verify that existing functionality works:
   - `res://addons/advanced_logger/tests/unit/test_log_formatting.gd`
   - `res://addons/advanced_logger/tests/unit/test_tag_filtering.gd`
   - `res://addons/advanced_logger/tests/integration/test_tag_operations.gd`

3. Restore the original logger after testing:
   ```bash
   mv project/addons/advanced_logger/core/logger.gd.backup project/addons/advanced_logger/core/logger.gd
   ```

## Applying the Changes

Once testing confirms that the refactored code works correctly:

1. Backup the original logger:
   ```bash
   cp project/addons/advanced_logger/core/logger.gd project/addons/advanced_logger/core/logger.gd.backup
   ```

2. Replace with the refactored version:
   ```bash
   cp project/addons/advanced_logger/core/logger.gd.new project/addons/advanced_logger/core/logger.gd
   ```

3. Add the new test files to version control:
   ```bash
   git add project/addons/advanced_logger/tests/unit/test_logger_refactoring.gd
   git add project/addons/advanced_logger/tests/logger_refactoring_test.tscn
   git add project/addons/advanced_logger/refactoring_logger_methods.md
   ```

4. Commit the changes:
   ```bash
   git commit -m "Refactor: Reduce method size in Logger class (Priority 4)"
   ```

## Troubleshooting

If tests fail:

1. **Path Issues**: Make sure all imports reference the correct paths:
   - Logger should be imported from `res://addons/advanced_logger/core/logger.gd`
   - Other imports may need adjustment

2. **Method Signatures**: Ensure refactored methods maintain the same signatures

3. **Missing Methods**: If existing tests look for methods that were renamed,
   consider adding compatibility methods that delegate to the new methods

4. **Type Errors**: Check that type annotations are correct in the refactored code

## Documentation

For more details about the refactoring changes, see:
`project/addons/advanced_logger/refactoring_logger_methods.md`
