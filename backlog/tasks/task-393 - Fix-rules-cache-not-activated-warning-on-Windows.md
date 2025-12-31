---
id: task-393
title: Fix rules cache not activated warning on Windows
status: Consider
assignee: []
created_date: '2025-12-29 00:03'
updated_date: '2025-12-29 00:07'
labels:
  - windows
  - performance
  - cache
  - initialization
dependencies: []
priority: low
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Windows tests show warnings about rules being accessed before cache initialization:

```
Rules not found in cache - call activate_rules_cache() first
{ "collection": "rules", "cache_key": "1WTKwZ8aXSeQVEVT8qeNtwUZepVZh7wv5skRGn_zFUsY//rules_0" }
(rules_collection.gd:97)
```

**Root Cause**: Rules are being accessed before `activate_rules_cache()` is called during initialization.

**Impact**: Performance - requires fetch from source instead of cache hit on every access.

**Investigation needed**:
- Trace startup sequence to find where rules are accessed early
- Determine if cache activation timing can be moved earlier
- Check if this affects other platforms or is Windows-specific

**Source**: `rules_collection.gd:97`
<!-- SECTION:DESCRIPTION:END -->
