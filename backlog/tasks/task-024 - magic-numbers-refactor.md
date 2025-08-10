# task-024 - magic-numbers-refactor

## Overview
Refactor scattered magic numbers throughout the GDScript codebase into a centralized GameConstants class for better maintainability and consistency.

## Analysis Summary
✅ **COMPLETED**: Created GameConstants class at `project/core/game_constants.gd`
Found 160+ magic numbers across the core game files (excluding advanced_logger as requested).

## Key Categories Identified:

### **Game Logic Constants:**
- **Card Defaults**: health=1, attack=1, level=1 (used in ~15 locations)
- **Player Defaults**: level=1, lives=3
- **Grid System**: GRID_WIDTH=5, GRID_HEIGHT=5
- **Battle System**: Zero thresholds for health/attack/stat values

### **Random Number Generation:**
- **Seeds**: 12345 (default fallback), 54321 (hard reset)
- **Roll Ranges**: %99 for unit level selection
- **ID Generation**: %10000 for session IDs, 1<<30 for websocket IDs

### **UI/Animation Constants:**
- **Rotation**: 360 degrees for full rotation
- **Layout**: +20 padding, height=30 for panels
- **Performance**: 5 second warning threshold

### **Network/Data Constants:**
- **HTTP Codes**: 200-299 success range, 404 not found
- **API Limits**: 3000 for Facebook API calls
- **Timeouts**: Various millisecond conversions (*1000)

### **Technical/Utility Constants:**
- **Array Operations**: -1/+1 indexing patterns
- **String Operations**: -3 for truncation suffixes
- **Test Data**: health=10, attack=5, price=10*(i+1)

## Implementation Status

### ✅ Phase 1: COMPLETED
- Created GameConstants class with categorized constants
- Documented all major magic number patterns
- Organized by logical groupings (Card System, Battle, UI, Network, etc.)

### 🔄 Phase 2: IN PROGRESS  
**Files needing refactor (ordered by priority):**

1. **project/rules/unit_data.gd** - current_health=1, current_attack=1
2. **project/core/clicker/level_rules.gd** - GRID_WIDTH=5 already defined
3. **project/rules/battle.gd** - Zero thresholds and stat checks
4. **project/core/card/*.gd files** - Default card values (health=1, attack=1, level=1)
5. **project/data/collections/*.gd** - Test data constants and default values
6. **project/core/game.gd** - RNG seeds and game logic constants

### 📋 Phase 3: Validation
- Comprehensive test suite to ensure no behavioral changes
- Performance impact assessment 
- Documentation updates

## Key Benefits
- **Maintainability**: Single source of truth for game balance values
- **Consistency**: Eliminates duplicate magic numbers across files  
- **Debugging**: Easier to track where values come from
- **Tuning**: Centralized location for game balance adjustments
- **Testing**: Easy A/B testing by modifying constants

## Files Requiring Updates (Focus List)
- project/rules/unit_data.gd (health/attack defaults)
- project/core/card/card*.gd (card system defaults) 
- project/rules/battle*.gd (battle thresholds)
- project/core/clicker/level_*.gd (grid and level constants)
- project/data/collections/*.gd (test data and defaults)

## Next Steps
1. Replace magic numbers in unit_data.gd and card system
2. Update battle system constants
3. Validate with test suite
4. Update remaining files incrementally