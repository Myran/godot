# Gemini Project Overview: GameTwo

This document provides a high-level overview of the GameTwo project architecture, key systems, and established patterns. It is intended to be a living document, updated with new insights as work progresses.

## Core Architectural Principles

The GameTwo codebase is well-structured and follows several key architectural principles:

*   **Event-Driven Architecture:** The core of the game is built around a robust event bus (`core.gd`). Systems are decoupled and communicate by dispatching and listening for `CoreEvent`s. This is a powerful and flexible pattern that should be leveraged for all new features.
*   **Singletons for Global Systems:** The project makes extensive use of Godot's autoload feature to provide global access to key systems like `core`, `data_source`, `DebugManager`, and `ActionRecorder`. This is a clean and efficient way to manage global state.
*   **Clear Separation of Concerns:** The project is organized into logical directories (`core`, `data`, `debug`, `rules`, etc.), each with a clear responsibility. This makes the codebase easy to navigate and understand.
*   **Strong Typing:** The codebase consistently uses GDScript's static typing features. This is crucial for catching errors early and improving code maintainability. All new code should adhere to this standard.
*   **Comprehensive Debugging and Testing:** The project has a sophisticated debugging and testing infrastructure, including a `DebugStartupCoordinator`, a rich set of debug actions, and a robust test automation system using `just`. This is a major strength of the project and should be used and extended.

## Key Systems Overview

### 1. Event Bus (`core.gd`)

*   **Purpose:** The central nervous system of the game. All significant game events are dispatched through this autoload.
*   **Key Concepts:**
    *   `CoreEvent`: The base class for all game events.
    *   `core.action(event)`: The function to dispatch a new event.
    *   `EventSource`: An enum that classifies the origin of an event (e.g., `PLAYER`, `SYSTEM_CASCADE`). This is critical for the action recording system.

### 2. Data Source (`data_source.gd`)

*   **Purpose:** A facade that provides a unified interface for accessing game data, whether from a local JSON file or a Firebase backend.
*   **Key Concepts:**
    *   `BackendFactory`: A factory class that determines which backend to use based on the environment (editor, mobile) and internet connectivity.
    *   `DataBackend`: The base class for all data backends (`FirebaseBackend`, `LocalJSONBackend`).
    *   `CardCollection`, `LevelCollection`, etc.: A set of collection classes that provide a clean, high-level API for accessing specific types of data.

### 3. Debug System (`debug/`)

*   **Purpose:** A powerful and flexible system for debugging and testing the game.
*   **Key Concepts:**
    *   `DebugActionRegistry`: An autoload that manages a registry of all available debug actions.
    *   `DebugStartupCoordinator`: An autoload that can execute a sequence of debug actions at startup, driven by a JSON configuration file.
    *   `SystemIdleActionEvent`: A special event that is used to queue actions to be executed only when the game is in an idle state. This is the key to handling asynchronous operations and event cascades correctly.

### 4. Game Logic (`core/`)

*   **Purpose:** Contains the core gameplay logic, including the main game loop, state management, and various handlers for different game systems.
*   **Key Concepts:**
    *   `game.gd`: The main game scene script. It is responsible for initializing all the core systems and handling the main game loop.
    *   `GameHandler`: Manages the main game state machine (e.g., `DRAFT`, `PREPARE`, `BATTLE`).
    *   `LevelController`, `CardHandler`, `BattleHandler`, etc.: A set of handler classes that encapsulate the logic for specific game systems.

### 5. Action Recording & Replay (`debug/singletons/action_recorder.gd`)

*   **Purpose:** A system for recording player actions and replaying them for debugging and testing.
*   **Key Concepts:**
    *   `ActionRecorder`: An autoload that listens for `CoreEvent`s with `EventSource.PLAYER` and records them.
    *   `var_to_str()` and `str_to_var()`: The core serialization mechanism. This is a simple and powerful way to capture the complete state of an event.
    *   `EventFactory`: A planned class that will be responsible for deserializing recorded actions back into `CoreEvent` objects.

## Gemini's Insights & Future Directions

Based on my analysis, here are some key insights and recommendations for future work:

*   **Leverage the Idle Queue:** The `SystemIdleActionEvent` and the idle action queue in `game.gd` are the cornerstone of the game's asynchronous architecture. All new debug actions and complex game logic should be designed to work with this system. Avoid using `await` in the `DebugStartupCoordinator` or other high-level controllers.
*   **Embrace the Event Bus:** When adding new features, favor an event-driven approach. Instead of having systems call each other directly, have them dispatch events and listen for the events they care about. This will keep the codebase decoupled and maintainable.
*   **Maintain Strong Typing:** Continue to use GDScript's static typing features rigorously. This is one of the project's greatest strengths.
*   **Extend the Debug System:** The existing debug system is very powerful. As new features are added, be sure to add corresponding debug actions to make them easy to test and validate.
*   **Complete the Replay System:** The plan for the action replay system is excellent. Completing Phase 2 (Deserialization) and Phase 3 (Replay Engine) will provide a massive boost to the project's testing and debugging capabilities.

This document will serve as a valuable reference for all future tasks. I will continue to update it as I learn more about the project.
