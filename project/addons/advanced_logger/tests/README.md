# Advanced Logger Tests

This directory contains tests for the Advanced Logger plugin. These tests serve two purposes:

1. **Validation**: Ensure that existing functionality works as expected
2. **Refactoring Confidence**: Provide assurance that refactoring doesn't break behavior

## Test Structure

The tests are organized into two categories:

### Unit Tests

Located in `tests/unit/`, these tests focus on individual components and functions:

- `test_tag_validation.gd`: Tests tag name validation logic
- `test_tag_filtering.gd`: Tests tag filtering rules (show/hide based on active/ignored tags)
- `test_config_handling.gd`: Tests configuration loading, saving, and defaults
- `test_log_formatting.gd`: Tests log message formatting options

### Integration Tests

Located in `tests/integration/`, these tests focus on interactions between components:

- `test_tag_operations.gd`: Tests tag operations across Logger and LoggerDock

## Running the Tests

There are two ways to run the tests:

### Method 1: Using the Test Runner Scene

1. Open the Godot Editor
2. Open the `tests/test_runner.tscn` scene
3. Click the "Play" button to run the scene
4. Check the output in the Debug Console

### Method 2: Running Individual Tests

Each test file can be run individually by:

1. Opening the specific test script
2. Selecting "Run Current Scene" from the "Run" menu
3. Viewing the results in the Debug Console

## Test Output

Tests produce colorful, descriptive output:
- Green checkmarks (✓) for passed tests
- Red X marks (✗) for failed tests
- Test case descriptions for easy identification of issues

## Extending the Tests

When adding new features or making changes:

1. Add or update tests to cover the new functionality
2. Run the test suite to ensure nothing breaks
3. Follow the same pattern of using descriptive test names and clear output

## Notes for Refactoring

These tests were specifically created to support the refactoring of:

- Tag Management
- Configuration System
- Logger Formatting
- UI Component Structure

Use them as a guide to ensure that your refactoring preserves the existing functionality while improving the code structure.
