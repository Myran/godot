---
id: task-040
title: Optimize event filtering performance
status: To Do
assignee: []
created_date: '2025-08-12 12:20'
updated_date: '2025-08-12 13:29'
labels:
  - performance
  - optimization
  - events
dependencies:
  - task-039
priority: medium
---

## Description

Optimize the event filtering system using the new architecture's get_handled_event_classes() method with class reference optimization for enum-based event type checking. This implements the performance expert's recommendation for type-safe event filtering while maintaining the architecture's class reference approach instead of StringNames.
## Acceptance Criteria

- [ ] Event filtering performance under 0.1ms per event using class references
- [ ] get_handled_event_classes() method implemented in AbilityHelper for optimal filtering
- [ ] Class reference optimization replaces StringNames for better performance
- [ ] is_instance_of() validation implemented for type-safe event checking
- [ ] Memory usage for event queues remains stable with optimized filtering
- [ ] No performance degradation during complex multi-ability battles
- [ ] Event filtering scales linearly with ability count using class reference lookup
- [ ] Profiler shows no bottlenecks in optimized event system
- [ ] Battle performance remains within target 60 FPS with new filtering
- [ ] Enum-based event type checking validated for mobile performance
