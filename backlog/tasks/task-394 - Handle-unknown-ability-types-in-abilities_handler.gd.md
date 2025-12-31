---
id: task-394
title: Handle unknown ability types in abilities_handler.gd
status: Consider
assignee: []
created_date: '2025-12-29 00:03'
updated_date: '2025-12-29 00:07'
labels:
  - gameplay
  - abilities
  - data-integrity
  - windows
dependencies: []
priority: medium
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Windows tests show warnings about unrecognized ability types in the ability parser:

```
Unknown ability type in create_ability_from_type
- { "ability_type": "attacktarget", "params": ["backrow"] }
- { "ability_type": "damage", "params": ["frontandbackrow"] }
- { "ability_type": "dwarf", "params": ["1", "1"] }
(abilities_handler.gd:52)
```

**Possible causes**:
1. Missing ability type implementations
2. Data/code mismatch - ability types exist in card data but not in code
3. Deprecated ability types that were removed but still referenced
4. Case sensitivity or naming convention issues

**Impact**: These abilities may not function correctly, affecting gameplay.

**Investigation needed**:
- Check if these ability types should exist and need implementation
- Search card data for references to these ability types
- Determine if this is a regression or expected behavior

**Source**: `abilities_handler.gd:52`
<!-- SECTION:DESCRIPTION:END -->
