# Card Abilities

## Guard

**ID:** 1
**Attack:** 1
**Health:** 2
**Tribe:** soldier
**Description:** The humble guard is the backbone of any army. It gets stronger with every knight on the battlefield.
**Abilities:**
*   **Knight Bonus:** When recruited, gains +1/+1 for each friendly "knight" unit.
**Implementation:**
*   The `abilities_guard.gd` script extends `unit_abilites.gd`.
*   It overrides the `event_recruit` function.
*   In `event_recruit`, it iterates through all friendly units and checks if they have the "knight" trait.
*   For each knight found, it increases the guard's `attack` and `health` by `knight_bonus_attack` and `knight_bonus_health` (both 1).

## Old Man

**ID:** 2
**Attack:** 1
**Health:** 1
**Tribe:** villager
**Description:** A fragile old man that can be surprisingly resilient.
**Abilities:**
*   **Shield:** When the battle starts, when it's recruited, and when it spawns, it gains a shield.
*   **Merge Bonus:** When merged, it gains +1/+1.
**Implementation:**
*   The `abilities_oldman.gd` script extends `unit_abilites.gd`.
*   It overrides the `event_start_battle`, `event_pre_recruit`, and `event_spawned` functions to set the `is_shield_active` property of the unit to `true`.
*   It overrides the `event_merge` function to increase the unit's `attack` and `health` by `old_man_merge_bonus_attack` and `old_man_merge_bonus_health` (both 1) respectively.

## Mooseman

**ID:** 3
**Attack:** 2
**Health:** 3
**Tribe:** evil
**Description:** It's a moose, it's a man, it's a mooseman! It gains a shield when merged.
**Abilities:**
*   **Merge Shield:** Gains a shield when merged.
**Implementation:**
*   The `abilities_mooseman.gd` script extends `unit_abilites.gd`.
*   It overrides the `event_merge` function to set the `is_shield_active` property of the unit to `true`.

## Spearman

**ID:** 4
**Attack:** 1
**Health:** 3
**Tribe:** soldier
**Description:** Has a pointy stick. Its attack can break through enemy lines to hit the unit behind its target.
**Abilities:**
*   **Breakthrough:** Attacks the primary target and also the unit directly behind it in the other line, if one exists.
**Implementation:**
*   The `abilities_spearman.gd` script extends `unit_abilites.gd`.
*   It overrides the `select_action` function to return "breaktrough".
*   The `battle.gd` script contains the `breaktrough` function, which calls the `fight` function with `is_breaktrough = true`.
*   The `fight` function, when `is_breaktrough` is true, identifies the unit in the other line at the same position as the primary target and damages it as well, if such a unit exists.

## Archer

**ID:** 5
**Attack:** 1
**Health:** 2
**Tribe:** soldier
**Description:** Shoots arrows. Attacks before the enemy and can shoot arrows as a special attack.
**Abilities:**
*   **First Strike:** Attacks before the enemy.
*   **Arrows:** Fires a number of arrows equal to the number of other friendly "forest" units. Each arrow deals damage equal to the Archer's level to a random enemy unit.
**Implementation:**
*   The `abilities_archer.gd` script extends `unit_abilites.gd`.
*   In `_ready()`, it sets `has_first_strike` to `true`.
*   It overrides `select_pre_battle_action` and `select_action` to return "arrows".
*   The `battle.gd` script contains the `arrows` function, which is called when a unit's action is "arrows".
*   The `arrows` function counts the number of friendly units with the "forest" trait (excluding the Archer itself).
*   It then iterates that many times, and in each iteration, it selects a random enemy unit, plays a projectile animation, and deals damage equal to the Archer's `unit_level`.

## Rhino

**ID:** 6
**Attack:** 4
**Health:** 2
**Tribe:** animal
**Description:** It's a rhino. It has a special backstab attack that targets the enemy's back line.
**Abilities:**
*   **Backstab:** Prioritizes attacking the enemy's back line. If the back line is empty, it attacks the front line.
**Implementation:**
*   The `abilities_rhino.gd` script extends `unit_abilites.gd`.
*   It overrides the `select_action` function to return "backstab".
*   The `battle.gd` script contains the `backstab` function, which calls the `fight` function with `is_backstab = true`.
*   The `fight` function, when `is_backstab` is true, sets the target line to the enemy's back line if it's not empty; otherwise, it targets the front line.

## Knight Red

**ID:** 7
**Attack:** 4
**Health:** 4
**Tribe:** soldier
**Description:** A knight in red armor.
**Abilities:** 

## Knight Green

**ID:** 8
**Attack:** 4
**Health:** 4
**Tribe:** soldier
**Description:** A knight in green armor.
**Abilities:** 

## Knight Gold

**ID:** 8
**Attack:** 4
**Health:** 4
**Tribe:** soldier
**Description:** A knight in gold armor. It protects all other knights.
**Abilities:**
*   **Shield Aura:** At the start of battle, gives a shield to all friendly "knight" units.
**Implementation:**
*   The `abilities_knight_gold.gd` script extends `unit_abilites.gd`.
*   It overrides the `event_start_battle` function.
*   In `event_start_battle`, it iterates through all friendly units and if they have the "knight" trait, it sets their `is_shield_active` property to `true`.

## Dwarf

**ID:** 9
**Attack:** 2
**Health:** 2
**Tribe:** dwarf
**Description:** A stout fellow. He's a master smith and improves the gear of all soldiers.
**Abilities:**
*   **Smithing:** When recruited, gives +1/+1 to all friendly "soldier" units for each level of the dwarf.
**Implementation:**
*   The `abilities_dwarf.gd` script extends `unit_abilites.gd`.
*   It overrides the `event_recruit` function.
*   In `event_recruit`, it iterates through all friendly units and checks if they have the "soldier" trait.
*   For each soldier found, it increases their `attack` and `health` by `dwarf_upgrade_attack` and `dwarf_upgrade_health` (both 1) multiplied by the dwarf's `unit_level`.

## Wizard

**ID:** 10
**Attack:** 2
**Health:** 6
**Tribe:** magic
**Description:** Casts spells. Its special attack is a powerful zap that can eliminate multiple enemies.
**Abilities:**
*   **Zap:** For each level of the Wizard, it fires a projectile that instantly kills a random enemy unit.
**Implementation:**
*   The `abilities_wizard.gd` script extends `unit_abilites.gd`.
*   It overrides the `select_action` function to return "zap".
*   The `battle.gd` script contains the `zap` function, which is called when a unit's action is "zap".
*   The `zap` function iterates a number of times equal to the Wizard's `unit_level`.
*   In each iteration, it selects a random enemy unit, plays a projectile animation, and then sets the target's health to -1, effectively killing it.

## Lizard

**ID:** 11
**Attack:** 4
**Health:** 4
**Tribe:** animal
**Description:** A scaly creature. It spits acid and gets stronger when evil allies are recruited.
**Abilities:**
*   **Acid Spit:** Fires a projectile at a random enemy unit, dealing damage equal to the Lizard's `acid_damage` property.
*   **Acid Bonus:** Gains +2 acid damage when a friendly "evil" unit is recruited.
**Implementation:**
*   The `abilities_lizard.gd` script extends `unit_abilites.gd`.
*   It has an `acid_damage` property that is increased by `acid_damage_increase` (2) in the `event_recruit` function if the recruited unit has the "evil" trait.
*   It overrides `select_pre_battle_action` to return "lizard_spit".
*   The `battle.gd` script contains the `lizard_spit` function, which is called when a unit's pre-battle action is "lizard_spit".
*   The `lizard_spit` function selects a random enemy unit, plays a projectile animation, and then deals damage equal to the Lizard's `acid_damage`.

## Troll

**ID:** 12
**Attack:** 1
**Health:** 1
**Tribe:** evil
**Description:** A fearsome troll that draws power from its evil allies.
**Abilities:**
*   **Evil Synergy:** Gains +2/+2 for each other friendly "evil" unit in play when it enters the battlefield.
**Implementation:**
*   The `abilities_troll.gd` script extends `unit_abilites.gd`.
*   It overrides the `come_into_play` function.
*   In `come_into_play`, it iterates through all friendly units and checks if they have the "evil" trait.
*   For each evil unit found, it increases the troll's `attack` and `health` by `troll_bonus_attack` and `troll_bonus_health` (both 2).

## Barbarian

**ID:** 13
**Attack:** 7
**Health:** 5
**Tribe:** barbarian
**Description:** A fierce warrior. Her massive axe can cleave through multiple enemies.
**Abilities:**
*   **Cleave:** Attacks the primary target and also the units directly above and below it in the battle line.
**Implementation:**
*   The `abilities_barbarian.gd` script extends `unit_abilites.gd`.
*   It overrides the `select_action` function to return "cleave_fight".
*   The `battle.gd` script contains the `cleave_fight` function, which calls the `fight` function with `cleave = true`.
*   The `fight` function, when `cleave` is true, identifies the units adjacent to the primary target and applies damage to them as well.

## Axeman

**ID:** 14
**Attack:** 5
**Health:** 3
**Tribe:** soldier
**Description:** Wields a mighty axe. Has a chance to cleave through multiple enemies.
**Abilities:**
*   **Cleave:** 50% chance to attack the primary target and also the units directly above and below it in the battle line.
**Implementation:**
*   The `abilities_axeman.gd` script extends `unit_abilites.gd`.
*   It overrides the `select_action` function to randomly return either "cleave_fight" or "fight".
*   The `battle.gd` script contains the `cleave_fight` function, which calls the `fight` function with `cleave = true`.
*   The `fight` function, when `cleave` is true, identifies the units adjacent to the primary target and applies damage to them as well.

## Monk

**ID:** 15
**Attack:** 3
**Health:** 5
**Tribe:** monk
**Description:** A peaceful warrior. He brings harmony to the battlefield, strengthening a diverse group of allies.
**Abilities:**
*   **Harmony:** When recruited, gives +2/+2 to one random unit of each of the following tribes: "soldier", "forest", "evil", and "magic".
**Implementation:**
*   The `abilities_monk.gd` script extends `unit_abilites.gd`.
*   It overrides the `event_recruit` function.
*   In `event_recruit`, it iterates through a list of tribes ("soldier", "forest", "evil", "magic").
*   For each tribe, it finds one random friendly unit with that tribe and increases its `attack` and `health` by `monk_bonus_attack` and `monk_bonus_health` (both 2).

## Red Lizard

**ID:** 16
**Attack:** 4
**Health:** 4
**Tribe:** animal
**Description:** A red, scaly creature.
**Abilities:**