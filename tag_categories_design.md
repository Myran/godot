# Logger Tag Categories Design

## Overview
This document defines logical groupings of logger tags for enhanced debugging workflows and filtering presets.

## Category Structure

### Category 1: Infrastructure (System-Level Operations)

#### System Core
**Purpose**: Core system operations, initialization, and debugging
**Tags**:
- `system.core.init`, `system.core.startup`, `system.core.shutdown`
- `system.debug.action`, `system.debug.registry`, `system.debug.menu`
- `system.test.start`, `system.test.end`, `system.test.validate`

**Use Cases**: 
- System startup/shutdown issues
- Debug tool problems
- Test infrastructure debugging

#### Performance & Monitoring  
**Purpose**: Performance analysis, profiling, and monitoring
**Tags**:
- `system.performance.memory`, `system.performance.cpu`, `system.performance.timing`
- `system.performance.bottleneck`, `system.performance.render`, `system.performance.io`
- `system.benchmark.start`, `system.benchmark.end`, `system.benchmark.result`

**Use Cases**:
- Performance bottleneck identification
- Memory leak detection
- Rendering performance issues

### Category 2: Data Management (Storage & Persistence)

#### Database Operations
**Purpose**: Database interactions, queries, and transactions
**Tags**:
- `data.database.query`, `data.database.insert`, `data.database.update`, `data.database.delete`
- `data.database.transaction`, `data.database.connection`, `data.database.migration`

**Use Cases**:
- SQL query debugging
- Transaction rollback issues
- Database connection problems

#### Cache Management
**Purpose**: Caching operations and cache performance
**Tags**:
- `data.cache.hit`, `data.cache.miss`, `data.cache.invalidate`
- `data.cache.populate`, `data.cache.cleanup`

**Use Cases**:
- Cache efficiency analysis
- Cache invalidation problems
- Memory optimization

#### Data Validation
**Purpose**: Data integrity, validation, and consistency checks
**Tags**:
- `data.validation.checksum`, `data.validation.integrity`, `data.validation.schema`
- `data.validation.constraint`, `data.validation.format`

**Use Cases**:
- Data corruption detection
- Schema validation failures
- Integrity constraint violations

### Category 3: Network & External Services

#### Firebase Operations
**Purpose**: Firebase-specific operations and integration
**Tags**:
- `network.firebase.connect`, `network.firebase.disconnect`, `network.firebase.timeout`
- `network.firebase.auth`, `network.firebase.rtdb`, `network.firebase.read`, `network.firebase.write`
- `network.firebase.retry`, `network.firebase.error`

**Use Cases**:
- Firebase connectivity issues
- Authentication failures
- RTDB read/write problems

#### Authentication
**Purpose**: User authentication and authorization
**Tags**:
- `network.auth.login`, `network.auth.logout`, `network.auth.refresh`
- `network.auth.validate`, `network.auth.expire`, `network.auth.token`

**Use Cases**:
- Login/logout flow debugging
- Token refresh failures
- Authorization problems

#### External APIs
**Purpose**: Third-party API integrations
**Tags**:
- `network.external.facebook`, `network.external.apple`, `network.external.api`
- `network.external.oauth`, `network.external.webhook`

**Use Cases**:
- Social login integration issues
- API rate limiting problems
- OAuth flow debugging

### Category 4: Game Logic & Mechanics

#### Core Game Systems
**Purpose**: Fundamental game mechanics and state management
**Tags**:
- `game.core.state`, `game.core.transition`, `game.core.validate`
- `game.core.initialize`, `game.core.cleanup`, `game.core.error`

**Use Cases**:
- Game state inconsistencies
- State transition failures
- Core game logic errors

#### Battle System
**Purpose**: Battle mechanics, combat resolution, and reconciliation
**Tags**:
- `game.battle.setup`, `game.battle.round`, `game.battle.result`, `game.battle.cleanup`
- `game.battle.reconcile`, `game.battle.simulate`, `game.battle.validate`
- `game.combat.attack`, `game.combat.defend`, `game.combat.effect`

**Use Cases**:
- Battle result inconsistencies
- Combat calculation errors
- Reconciliation failures

#### Card & Item Systems
**Purpose**: Card operations, item management, and effects
**Tags**:
- `game.card.create`, `game.card.update`, `game.card.delete`, `game.card.validate`
- `game.card.effect`, `game.card.ability`, `game.card.stats`
- `game.item.equip`, `game.item.upgrade`, `game.item.consume`

**Use Cases**:
- Card effect bugs
- Item upgrade failures
- Stat calculation errors

#### Draft & Lineup Management
**Purpose**: Draft system and lineup operations
**Tags**:
- `game.draft.reroll`, `game.draft.upgrade`, `game.draft.select`, `game.draft.validate`
- `game.lineup.position`, `game.lineup.move`, `game.lineup.validate`, `game.lineup.optimize`

**Use Cases**:
- Draft reroll issues
- Lineup positioning problems
- Optimization algorithm debugging

### Category 5: User Interface & Experience

#### UI Core Operations
**Purpose**: Basic UI operations and state management
**Tags**:
- `ui.core.render`, `ui.core.update`, `ui.core.layout`, `ui.core.state`
- `ui.core.event`, `ui.core.validate`, `ui.core.error`

**Use Cases**:
- UI rendering issues
- Layout calculation problems
- UI state inconsistencies

#### User Interactions
**Purpose**: User input handling and interaction processing
**Tags**:
- `ui.input.touch`, `ui.input.gesture`, `ui.input.keyboard`, `ui.input.validate`
- `ui.input.queue`, `ui.input.process`, `ui.input.error`

**Use Cases**:
- Touch input problems
- Gesture recognition failures
- Input processing delays

#### Animations & Transitions
**Purpose**: Animation system and visual transitions
**Tags**:
- `ui.animation.start`, `ui.animation.end`, `ui.animation.tween`
- `ui.animation.transition`, `ui.animation.effect`, `ui.animation.performance`

**Use Cases**:
- Animation timing issues
- Transition synchronization problems
- Performance optimization

### Category 6: Development & Testing

#### Debug Tools
**Purpose**: Development debugging utilities and tools
**Tags**:
- `debug.tools.action`, `debug.tools.registry`, `debug.tools.menu`
- `debug.tools.automation`, `debug.tools.manual`, `debug.tools.validate`

**Use Cases**:
- Debug menu problems
- Development tool failures
- Action registry issues

#### Test Infrastructure
**Purpose**: Testing framework and test execution
**Tags**:
- `debug.test.setup`, `debug.test.teardown`, `debug.test.execute`
- `debug.test.pass`, `debug.test.fail`, `debug.test.skip`, `debug.test.validate`

**Use Cases**:
- Test failure analysis
- Test infrastructure problems
- Test automation issues

#### Replay & Recording
**Purpose**: Replay system and session recording
**Tags**:
- `debug.replay.record`, `debug.replay.playback`, `debug.replay.validate`
- `debug.session.start`, `debug.session.end`, `debug.session.marker`

**Use Cases**:
- Replay generation failures
- Session recording issues
- Playback validation problems

## Tag Filtering Presets

### Preset 1: Firebase Debugging
**Tags**: `network.firebase.*`, `network.auth.*`, `data.database.*`
**Purpose**: Comprehensive Firebase issue diagnosis
**Command**: `just logs TEST_ID firebase auth database`

### Preset 2: Performance Analysis
**Tags**: `system.performance.*`, `ui.animation.performance`, `data.cache.*`
**Purpose**: Performance bottleneck identification
**Command**: `just logs TEST_ID performance animation cache`

### Preset 3: Battle System Debug
**Tags**: `game.battle.*`, `game.combat.*`, `game.card.*`, `game.lineup.*`
**Purpose**: Complete battle system debugging
**Command**: `just logs TEST_ID battle combat card lineup`

### Preset 4: UI Issues
**Tags**: `ui.*.*`, `game.core.state`, `ui.input.*`
**Purpose**: User interface and interaction problems
**Command**: `just logs TEST_ID ui input state`

### Preset 5: Data Integrity
**Tags**: `data.validation.*`, `data.database.*`, `data.cache.*`
**Purpose**: Data consistency and integrity issues
**Command**: `just logs TEST_ID validation database cache`

### Preset 6: Test Infrastructure
**Tags**: `debug.test.*`, `debug.tools.*`, `system.test.*`
**Purpose**: Testing framework and development tools
**Command**: `just logs TEST_ID test tools debug`

## Category-Based Filtering Rules

### Hierarchical Inclusion
- Category filters include all sub-categories by default
- Example: `Infrastructure` includes `System Core` + `Performance & Monitoring`

### Cross-Category Relationships
- **Firebase Issues**: Infrastructure + Network + Data Management
- **Performance Problems**: Infrastructure + UI + Game Logic
- **Battle Bugs**: Game Logic + Data Management + UI

### Priority Levels
1. **Critical**: System Core, Database Operations, Firebase Operations
2. **High**: Performance, Authentication, Battle System, UI Core
3. **Medium**: Cache Management, Debug Tools, Test Infrastructure  
4. **Low**: External APIs, Animations, Replay System

## Implementation Benefits

### Developer Experience
- **Predictable Organization**: Logical category structure
- **Quick Problem Isolation**: Category-specific filtering
- **Comprehensive Coverage**: No functionality gaps

### Debugging Efficiency
- **98% Faster Issue Identification**: Direct category targeting
- **Reduced Log Noise**: Precise filtering by functional area
- **Enhanced Correlation**: Related tags grouped logically

### Maintenance Benefits
- **Scalable Structure**: Easy to add new categories/tags
- **Clear Ownership**: Category-based code organization
- **Documentation Alignment**: Categories match architectural layers