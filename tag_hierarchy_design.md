# Logger Tag Hierarchy Design Document

## Overview
This document defines a new 3-level hierarchical tag system: `layer.domain.operation`

## Current State Analysis

### Existing Tag Constants (47 total)
#### Infrastructure Layer
- `database`, `cache`, `firebase`, `local_data`, `network`, `auth`, `facebook`, `apple`
- `system`, `debug`, `data`, `initialization`, `performance`, `validation`
- `error`, `test`

#### Game Logic Layer  
- `card`, `level`, `item`, `battle`, `combat`, `game`, `game_state`, `rng`
- `rule`, `rules`, `event`, `player`, `draft`, `lineup`, `animation`
- `state_transition`, `win_condition`, `stat`, `grid`, `clicker`
- `reconciliation`, `ability`, `effect`, `deep_copy`

#### UI Layer
- `ui`, `ui_input`, `ui_animation`, `input`

### String Literals Found (40+ unique)
- **Debug/System**: `debug_ui`, `abortion`, `run_all`, `registry`, `stats`, `rtdb`, `status`
- **Semantic**: `semantic`, `action`, `semantic_action`, `gamestate`, `marker`, `session`  
- **Game**: `gameplay`, `board`, `reset`, `memory`, `final_state`, `checksum`
- **Workflow**: `workflow`, `replay`, `recording`, `validation`, `regression`

## Proposed 3-Level Hierarchy

### Level 1: Layer (Technical Architecture)
- `system` - Core system operations, initialization, debug, registry
- `data` - Data operations, storage, backends, validation  
- `network` - Network operations, Firebase, authentication, external APIs
- `game` - Game logic, rules, mechanics, state management
- `ui` - User interface, input handling, animations, rendering
- `debug` - Development tools, testing, debugging utilities

### Level 2: Domain (Functional Area)
#### System Domains
- `system.core` - System initialization, debug, registry
- `system.performance` - Performance monitoring, profiling
- `system.test` - Test execution, automation, validation

#### Data Domains  
- `data.storage` - Database, cache, local storage
- `data.validation` - Data integrity, checksums, validation
- `data.collection` - Collections (cards, items, players, etc.)

#### Network Domains
- `network.firebase` - Firebase operations (auth, RTDB, etc.)
- `network.auth` - Authentication (Facebook, Apple, etc.)
- `network.external` - External API calls

#### Game Domains
- `game.core` - Core game mechanics, state management
- `game.battle` - Battle system, combat, reconciliation  
- `game.draft` - Draft system, card selection
- `game.lineup` - Lineup management, positioning
- `game.card` - Card operations, effects, abilities
- `game.rules` - Rule engine, validation, win conditions

#### UI Domains
- `ui.core` - Basic UI operations, state management
- `ui.input` - Input handling, touch events
- `ui.animation` - Animations, transitions, effects
- `ui.navigation` - Navigation, state transitions

#### Debug Domains
- `debug.tools` - Debug utilities, dev tools
- `debug.replay` - Replay system, recording, playback
- `debug.semantic` - Semantic action logging
- `debug.test` - Test utilities, automation

### Level 3: Operation (Specific Action)
#### Common Operations (Cross-domain)
- `create`, `read`, `update`, `delete` (CRUD operations)
- `start`, `complete`, `abort`, `reset`
- `validate`, `process`, `transform`
- `load`, `save`, `cache`, `sync`  
- `connect`, `disconnect`, `timeout`, `retry`
- `error`, `warning`, `info`, `debug`

#### Domain-Specific Operations
- **Battle**: `reconcile`, `simulate`, `resolve`
- **Draft**: `reroll`, `upgrade`, `select`
- **Network**: `authenticate`, `authorize`, `fetch`, `post`
- **UI**: `render`, `animate`, `transition`, `interact`

## Migration Strategy

### Phase 1: Maintain Backward Compatibility
- Keep existing flat tags as aliases to hierarchical tags
- Example: `TAG_FIREBASE` = `"firebase"` (legacy) = `"network.firebase.general"` (new)

### Phase 2: Gradual Migration  
- Add hierarchical constants alongside existing ones
- Update logging calls to use hierarchical tags where appropriate
- Provide migration guide for developers

### Phase 3: Full Hierarchy
- All new logging uses hierarchical tags
- Legacy flat tags deprecated but still functional
- Enhanced filtering supports both flat and hierarchical patterns

## Enhanced Filtering Examples

### Wildcard Support
- `system.*` - All system layer operations
- `*.firebase.*` - All Firebase operations across layers
- `*.*.error` - All error operations across all domains
- `game.battle.*` - All battle domain operations
- `debug.*.complete` - All completion operations in debug layer

### Common Debug Scenarios
- **Firebase Issues**: `network.firebase.*` + `*.*.error`
- **Performance Problems**: `system.performance.*` + `game.*.process`
- **UI Events**: `ui.*.*` + `game.*.transition`
- **Battle Debugging**: `game.battle.*` + `game.rules.*`

## Implementation Considerations

### Tag Constant Naming
- Hierarchical: `TAG_SYSTEM_CORE_START = "system.core.start"`
- Legacy: `TAG_SYSTEM = "system"` (maintained for compatibility)
- Alias: `TAG_FIREBASE = "network.firebase.general"` (maps legacy to hierarchy)

### Performance Impact
- Hierarchical tags are still single strings
- No performance impact on logging
- Enhanced filtering capabilities with minimal overhead

### Developer Experience
- Predictable tag structure for any operation
- Auto-completion friendly constant names
- Clear debugging workflow with logical grouping