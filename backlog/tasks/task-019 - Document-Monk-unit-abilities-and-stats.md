---
id: task-019
title: Document Monk unit abilities and stats
status: Done
assignee: []
created_date: '2025-08-08 23:10'
updated_date: '2025-12-18 10:37'
labels:
  - creature
  - documentation
  - abilities
dependencies: []
ordinal: 233000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Document and validate the Monk unit (ID: 15) with Harmony ability that strengthens diverse tribal allies when recruited
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Monk unit has correct base stats (3/5, monk tribe)
- [ ] #2 Harmony ability affects specific tribes (soldier, forest, evil, magic)
- [ ] #3 Each tribe gets one random unit boosted +2/+2
- [ ] #4 Implementation for abilities_monk.gd tribal selection is accurate
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Complexity**: 🟡 Moderate
**Current System**: ✅ Good fit - similar to existing tribal abilities

### Technical Approach
Create `HarmonyAbility` that uses draft events to boost random units from specific tribes:

```gdscript
class_name HarmonyAbility extends Ability

func handle_draft_event(phase: core.Tempus, unit_position: int, unit: Block, draft_context: DraftContext, draft_event: core.CoreEvent) -> void:
    if phase == core.Tempus.POST and draft_event is core.LineupAddCardFromDraftEvent:
        var add_event: core.LineupAddCardFromDraftEvent = draft_event as core.LineupAddCardFromDraftEvent
        if add_event.card == unit:  # This monk was just recruited
            apply_harmony_bonuses(draft_context, unit)

func apply_harmony_bonuses(draft_context: DraftContext, monk_unit: Block) -> void:
    var target_tribes: Array[String] = ["soldier", "forest", "evil", "magic"]
    
    for tribe: String in target_tribes:
        var random_unit: Card = select_random_unit_with_tribe(draft_context.lineup, tribe, monk_unit)
        if random_unit:
            var stat_change: core.CardStatChangeEvent = core.CardStatChangeEvent.new(
                random_unit, 2, 2  # +2 attack, +2 health
            )
            draft_context.add_event(stat_change)
```

### Required Changes
1. **Random Selection Utility**: Create `select_random_unit_with_tribe()` function
2. **AbilitiesHandler Extension**: Add "harmony" case to parser
3. **Multi-tribe Processing**: Handle the 4 different target tribes efficiently

### Utility Functions Needed
```gdscript
# In utility system:
static func select_random_unit_with_tribe(lineup: Dictionary[int, Card], target_tribe: String, exclude_unit: Block = null) -> Card:
    var valid_units: Array[Card] = []
    
    for position: int in lineup:
        var card: Card = lineup[position]
        if card == exclude_unit:
            continue
        if card.card_info.tribe.match(target_tribe):
            valid_units.append(card)
    
    if valid_units.is_empty():
        return null
    
    return valid_units[randi() % valid_units.size()]
```

### Dependencies
- Existing draft event system (✅ Available)
- Card stat change events (✅ Available)
- Random selection utilities (📋 Need to create)
- Tribe matching system (✅ Available via `card_info.tribe.match()`)

### Technical Details
- **Trigger**: When the Monk unit itself is recruited (added to lineup)
- **Target Tribes**: Exactly 4 tribes - "soldier", "forest", "evil", "magic"
- **Selection**: One random unit per tribe (if available)
- **Bonus**: +2/+2 to each selected unit
- **Exclusion**: Monk itself is never a target (even if it had multiple tribes)
- **Empty Tribes**: If no units of a tribe exist, that bonus is skipped

### Edge Cases & Behavior
- **No Valid Targets**: If lineup has no units of a specific tribe, that tribe's bonus is simply not applied
- **Multiple Tribe Units**: Units with multiple tribes could be selected for multiple bonuses
- **Same Unit Multiple Times**: If a unit has multiple target tribes, it could receive multiple +2/+2 bonuses
- **Timing**: All stat changes are queued as events, so they apply simultaneously

### Testing Strategy
- Test with lineups containing all 4 target tribes (should get 4 bonuses)
- Test with lineups missing some tribes (should only boost available tribes)
- Test with multiple units per tribe (should randomly select one per tribe)
- Test with units having multiple tribes (verify bonus stacking behavior)
- Test with empty lineup except monk (should apply no bonuses)
- Test stat change application (+2/+2 per selected unit)
- Verify monk itself is never selected as target
<!-- SECTION:PLAN:END -->
