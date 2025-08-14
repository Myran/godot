---
id: task-004
title: Document Guard unit abilities and stats
status: Done
assignee: []
created_date: '2025-08-08 23:09'
updated_date: '2025-08-14 12:07'
labels:
  - creature
  - documentation
  - abilities
dependencies: []
---

## Description

Document and validate the Guard unit (ID: 0) with Soldier Bonus ability that gains +1/+1 for each friendly soldier unit when recruited

## Acceptance Criteria

- [x] Guard unit has correct base stats (1/1, soldier tribe) - ID: 0
- [x] Soldier Bonus ability is properly documented
- [x] Implementation details for SoldierBonusAbility are accurate
- [x] Unit behavior is consistent with description

## Implementation Plan

**Complexity**: 🟢 Simple
**Current System**: ✅ Perfect fit for existing event-driven architecture

### Technical Approach
Create `SoldierBonusAbility` that extends the base `Ability` class and leverages the existing draft event system:

```gdscript
class_name SoldierBonusAbility extends Ability

func handle_draft_event(phase: core.Tempus, unit_position: int, unit: Block, draft_context: DraftContext, draft_event: core.CoreEvent) -> void:
    if phase == core.Tempus.POST and draft_event is core.LineupAddCardFromDraftEvent:
        var soldier_count = count_units_with_tags_in_lineup(draft_context.lineup, ["soldier"], unit)
        if soldier_count > 0:
            var stat_change = core.CardStatChangeEvent.new(unit, soldier_count, soldier_count)
            draft_context.add_event(stat_change)
```

### Required Changes
1. **AbilitiesHandler Extension**: Add "guard" case to parser mapping to SoldierBonusAbility
2. **Utility Function**: Use existing `AbilityHelper.count_units_with_tags_in_lineup()` helper
3. **Integration**: Works seamlessly with existing `core.LineupAddCardFromDraftEvent` system

### Dependencies
- Existing draft event system (✅ Available)
- Card stat change events (✅ Available)  
- Soldier counting utilities (✅ Available via AbilityHelper)

### Testing Strategy
- Test with lineups containing 0, 1, 2, 3+ soldiers
- Verify stat bonuses apply correctly on recruitment
- Ensure no bonuses when no soldiers present
- Validate behavior with mixed tribe/tag soldier combinations

## Implementation Notes

✅ **SYSTEM UPGRADE COMPLETED**: All implementation discrepancies have been resolved:

1. ✅ **Corrected Guard ID**: Guard unit properly identified as ID '0' (not '1')
2. ✅ **Fixed Ability Mapping**: 'guard:1;1' ability now correctly maps to SoldierBonusAbility
3. ✅ **Removed Incorrect Assignment**: Removed DamageShieldAbility from unit ID '1' (Archer)
4. ✅ **Created SoldierBonusAbility**: New class implemented in `project/rules/soldier_bonus_ability.gd`
5. ✅ **Updated AbilitiesHandler**: Parser now properly handles Guard's soldier synergy ability

## Actual Implementation

**Guard Unit Specifications** (from gameone-577cb-export.json):
- **ID**: "0"
- **Name**: "guard" 
- **Card Name**: "Brettonian Guard"
- **Base Stats**: 1 Attack / 1 Health
- **Tribe**: "soldier"
- **Ability String**: "guard:1;1"
- **Description**: "Gain +1/+1 for each unique soldier in play."

**SoldierBonusAbility Implementation**:
- **File**: `project/rules/soldier_bonus_ability.gd`
- **Extends**: `Ability` base class
- **Trigger**: Draft phase when unit is added to lineup
- **Effect**: Grants +1/+1 per soldier unit in lineup (both tribe and tag)
- **Integration**: Uses existing `AbilityHelper.count_units_with_tags_in_lineup()` utility

**Parser Integration**:
- **File**: `project/rules/abilities_handler.gd`
- **Case**: "guard" → `SoldierBonusAbility.new(health_bonus, attack_bonus)`
- **Parameters**: Both health and attack bonuses from ability string (1;1)

## Validation Status

✅ **Code Validation**: All GDScript files pass syntax validation
✅ **Runtime Validation**: Godot project loads without errors
✅ **System Integration**: Guard unit now properly gains soldier synergy bonuses

## Soldier Synergy Analysis

**Level 1 Soldiers (Immediate synergy)**: **3 units available**
- **guard** (tribe: soldier) - Self-synergy excluded 
- **dwarf** (tribe: soldier) - +1/+1 bonus to Guard
- **spearman** (tags: soldier) - +1/+1 bonus to Guard

**Level 2+ Soldiers (Scaling synergy)**: **5 additional units**
- **knight_blue, knight_green, knight_red** (tribe: soldier)
- **monk** (tags: soldier + others)
- **knight_gold** (Level 3, tribe: soldier)

**Game Balance Impact**: 
- ✅ **Early Game Viable**: Guard can gain +1/+1 or +2/+2 at Level 1
- ✅ **Scales Well**: Additional soldier options at higher levels
- ✅ **Strategic Value**: Encourages soldier-focused drafting strategies

## UPGRADE SYSTEM IMPROVEMENT PLAN - ✅ COMPLETED

**Issue RESOLVED**: Guard ability now properly triggers when upgraded in lineup.

### Problems Fixed:
1. **✅ Context Assignment Bug Fixed**: In `clicker.gd:261`, replaced hardcoded `DRAFT` context with source card context preservation
2. **✅ Event System Updated**: Migrated from synthetic `LineupAddCardFromDraftEvent` to natural `BlockEntersPlay` events
3. **✅ Triggering Logic Corrected**: Guard now properly triggers only when it enters lineup with proper context filtering

### Solution Implemented:

#### 1. ✅ Fixed Context Preservation in Merge Process
**File**: `/Users/mattiasmyhrman/repos/gametwo/project/core/clicker/clicker.gd:261`
```gdscript
# FIXED - Changed from:
# new_card.block_context = Cards.CONTEXT.DRAFT

# To:
# Preserve the original context from source cards (LINEUP vs DRAFT)
new_card.block_context = first_card.block_context
```

#### 2. ✅ Updated Guard Ability to Use BlockEntersPlay
**File**: `/Users/mattiasmyhrman/repos/gametwo/project/rules/soldier_bonus_ability.gd`
```gdscript
func handle_draft_event(event: DraftAbilityEvent) -> void:
    if event.phase != core.Tempus.POST:
        return

    # Trigger when this Guard enters lineup (from draft or from upgrade)
    if not event.event is core.BlockEntersPlay:
        return

    var enters_play_event: core.BlockEntersPlay = event.event
    var entering_block: Block = enters_play_event.block
    
    # Only trigger if this Guard is entering and it's going to lineup context
    if entering_block != event.unit:
        return
    if not entering_block is Card:
        return
    var entering_card: Card = entering_block as Card
    if entering_card.block_context != Cards.CONTEXT.LINEUP:
        return

    # Count soldiers and apply bonuses
    var soldier_unit_count: int = AbilityHelper.count_units_with_tags_in_lineup(
        event.draft_context.lineup, [GameConstants.UnitTags.SOLDIER], event.unit
    )
    
    if soldier_unit_count > 0:
        var total_health_bonus: int = health_per_soldier * soldier_unit_count
        var total_attack_bonus: int = attack_per_soldier * soldier_unit_count
        AbilityHelper.apply_permanent_stat_bonus(event, total_health_bonus, total_attack_bonus)
```

#### 3. ✅ Removed Synthetic Event System
**File**: `/Users/mattiasmyhrman/repos/gametwo/project/core/clicker/clicker.gd`
- Removed synthetic `LineupAddCardFromDraftEvent` generation in upgrade process
- Now relies on natural `BlockEntersPlay` events that fire automatically

#### 4. ✅ Guard Triggering Rules (Verified):
- ✅ **Guard drafted to lineup**: Triggers once with proper soldier bonuses
- ✅ **Guard upgraded in lineup**: Triggers once (context preserved, treated as new entry)  
- ✅ **Guard upgraded on board**: No trigger (correct - not in lineup context)
- ✅ **Other units changing**: No trigger (correct - not this Guard)

### ✅ Testing Results:
- **Test Config**: `ability-guard-01` - Comprehensive soldier synergy scenario
- **Status**: ✅ PASSED with 100% checksum validation
- **Validation**: All 9 semantic action checksums matched expected baseline
- **Functionality**: Guard ability properly triggers for both draft and upgrade scenarios

### ✅ Benefits Achieved:
- ✅ Universal upgrade system that works across all contexts
- ✅ Clean Guard ability logic using natural game events  
- ✅ Proper context preservation for all merged units
- ✅ Solid foundation for other synergy abilities
