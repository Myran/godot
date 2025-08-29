---
id: task-092
title: bug axe man health is now permanent between battles
status: Done
assignee: []
created_date: '2025-08-22 12:51'
updated_date: '2025-08-29 19:16'
labels: []
dependencies: []
---

## Description

axe man in test line up now retains bonus between combat. why

## Root Cause Analysis (2025-08-29)

**Problem**: Axe man's death trigger health bonuses are persisting between battles instead of being combat-only.

**Root Cause Found**: The issue is in `project/rules/unit_data.gd` lines 571-587 in the `apply_permanent_changes_from` method. During the recent refactoring (likely around commit `536bacc8`), the reconciliation system was changed to incorrectly convert ALL `ACQUIRED` abilities to `ENHANCEMENT` (permanent) persistence type.

### Technical Details

**Problematic Code** (lines 571-587 in unit_data.gd):
```gdscript
for battle_ability: Ability in final_battle_state.abilities:
    if (
        battle_ability.persistence_type == Ability.PersistenceType.ACQUIRED
        and not battle_ability.get_class() in current_ability_classes
    ):
        var enhanced_ability: Ability = battle_ability.deep_duplicate()
        enhanced_ability.persistence_type = Ability.PersistenceType.ENHANCEMENT  # <-- BUG HERE
        self.add_ability(enhanced_ability)
```

**Expected Behavior**: 
- Axe man's death trigger health bonus should be `TEMPORARY` during battle only
- Should NOT be converted to `ENHANCEMENT` persistence type
- Should NOT carry over between battles

**Current Incorrect Behavior**:
- Death trigger health bonuses applied during combat (✅ correct)  
- Made permanent via `ENHANCEMENT` persistence type (❌ incorrect)
- Carried over to future battles (❌ incorrect)

**Affected Unit**: Axe man (card ID 2) with `DeathTriggerHealthAbility` scaffolding in unit_data.gd line 70

### Solution Required
Filter the persistence logic to exclude combat-only abilities like `DeathTriggerHealthAbility` from being made permanent in the reconciliation process.

## Fix Implementation (2025-08-29)

**Changes Made** in `project/rules/unit_data.gd`:

1. **Added filtering logic** (line 574): Added `and not _is_combat_only_ability(battle_ability)` condition to prevent combat-only abilities from being converted to permanent `ENHANCEMENT` type.

2. **Added helper method** `_is_combat_only_ability` (lines 110-117): Identifies abilities that should only apply during combat and not persist between battles:
   - `DeathTriggerHealthAbility` - Axe man's ondeath health bonus

3. **Added debug logging** (lines 589-598): Logs when combat-only abilities are correctly skipped from becoming permanent for better debugging.

**Validation**: 
- ✅ GDScript syntax validation passed
- ✅ Battle logic tests passed (4/4 actions successful)
- ✅ No regressions introduced

**Expected Result**: Axe man's death trigger health bonuses will now be combat-only and will NOT carry over between battles.
