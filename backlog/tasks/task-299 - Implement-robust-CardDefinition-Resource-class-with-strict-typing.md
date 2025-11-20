---
id: task-299
title: Implement robust CardDefinition Resource class with strict typing
status: To Do
assignee: []
created_date: '2025-11-20 09:11'
updated_date: '2025-11-20 09:16'
labels:
  - robustness
  - typing
  - resources
  - cards
  - strict-typing
  - editor-completion
dependencies: []
priority: medium
---

## Description

Replace the loose Dictionary usage for card_info with a strict Resource class to prevent runtime type errors and enable editor auto-completion. This refactoring improves code reliability, type safety, and developer experience by moving from dynamic dictionary access to strongly-typed Resource properties.

**Current Problem:**
```gdscript
# Loose typing prone to runtime errors
var card_info: Dictionary
var card_id = card_info.get("id", "unknown")  # No type safety
var attack = card_info.get("base_attack", 0)   # No validation
```

**Target Solution:**
```gdscript
# Strict typing with compile-time safety
var card_definition: CardDefinition
var card_id = card_definition.id               # Type-safe access
var attack = card_definition.base_attack       # Editor completion
```

**Benefits:**
- Compile-time type checking prevents runtime errors
- Editor auto-completion improves developer productivity
- Clear property definitions improve code documentation
- Better IDE support for refactoring and navigation

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] Create CardDefinition Resource class in project/data/resources/card_definition.gd
- [ ] Define @export typed variables for all standard card fields (id, card_name, base_health, base_attack, etc.)
- [ ] Add @export var tags: Array[String] for card tagging system
- [ ] Add @export var abilities_string: String for raw ability data from database
- [ ] Implement static from_dictionary(data: Dictionary) -> CardDefinition helper method
- [ ] Update UnitData class to use CardDefinition instead of Dictionary card_info
- [ ] Refactor init_with_info to convert Dictionary to CardDefinition immediately
- [ ] Update all card_info.id references to card_definition.id throughout codebase
- [ ] Update Block classes to work with CardDefinition resources
- [ ] Refactor UI refresh methods to use CardDefinition properties
- [ ] Add optional compatibility layer getter for card_info if needed for gradual migration
- [ ] Verify all card creation and loading workflows function correctly
- [ ] Test editor auto-completion and type safety improvements
- [ ] Update CoreEventResolver and other dependent systems to use CardDefinition
<!-- AC:END -->
