# HPC Sorting Serious Game: A Mobile-First Educational Approach to Teaching Parallel Computing

**Master's Thesis in Software Engineering**  
**University of Genova, Italy**  
**2025**

---

## Abstract

High-Performance Computing (HPC) and parallel programming remain challenging topics in computer science education, often requiring students to grasp abstract concepts without tangible, interactive experiences. This thesis presents the design, implementation, and evaluation of an innovative educational serious game that teaches fundamental parallel computing paradigms—OpenMP and MPI—through an interactive card sorting mechanic on mobile devices.

The game transforms abstract parallel computing concepts into concrete, manipulable interactions: players sort cards collaboratively in multiplayer mode (simulating MPI message passing) or individually with private buffer zones (simulating OpenMP shared memory with thread-local storage). By implementing this game using the Godot Engine and GDScript, with a focus on mobile-first design, this work addresses both pedagogical and technical challenges inherent in creating educational multiplayer games for resource-constrained devices.

Key contributions include: (1) a novel pedagogical mapping between card sorting mechanics and HPC paradigms, (2) implementation of robust multiplayer state synchronization for educational purposes using the GDSync framework, (3) solutions to mobile UI/UX challenges for displaying and manipulating numerous interactive elements on small screens, and (4) an open-source, extensible platform for future HPC education research.

**Keywords:** Serious Games, High-Performance Computing, Parallel Computing Education, OpenMP, MPI, Mobile Game Development, Multiplayer Synchronization, Godot Engine

---

# Chapter 1: Introduction

## 1.1 Context and Motivation

### 1.1.1 The Challenge of Teaching HPC

High-Performance Computing (HPC) has become an indispensable tool in modern computational science, powering everything from weather forecasting and molecular dynamics simulations to machine learning and big data analytics. As computational problems grow in scale and complexity, the ability to write efficient parallel programs has transitioned from a specialized skill to a fundamental competency for software engineers and computational scientists.

However, teaching parallel computing concepts presents unique pedagogical challenges:

1. **Abstraction Gap**: Parallel computing involves concepts like threads, processes, synchronization, and message passing that are inherently abstract. Students often struggle to visualize how multiple execution units interact, communicate, and coordinate.

2. **Cognitive Load**: Understanding parallel algorithms requires simultaneous consideration of multiple execution flows, shared resources, race conditions, and synchronization primitives—a significant cognitive burden for learners.

3. **Limited Immediate Feedback**: Traditional programming assignments in HPC courses often involve writing code, submitting to a cluster, waiting for results, and debugging—a slow feedback loop that impedes learning.

4. **Lack of Intuitive Mental Models**: Unlike sequential programming, where the execution model maps naturally to step-by-step thinking, parallel programming requires different mental models that are harder to internalize.

### 1.1.2 Traditional Teaching Methods vs. Serious Games

Traditional HPC education typically relies on:

- **Lecture-based instruction**: Professors explain concepts using slides, diagrams, and pseudocode
- **Textbook exercises**: Students work through theoretical problems
- **Programming assignments**: Implementation tasks on academic clusters or multicore machines
- **Performance profiling**: Analysis of speedup, efficiency, and scalability

While these methods provide theoretical foundations, they often fail to engage students emotionally or provide immediate, intuitive understanding of parallel execution dynamics.

**Serious games**—games designed with a primary purpose beyond entertainment—offer an alternative pedagogical approach. Educational games can:

- **Provide immediate feedback**: Players see the consequences of their actions instantly
- **Create engaging experiences**: Game mechanics tap into intrinsic motivation
- **Enable active learning**: Players learn by doing, not just reading or watching
- **Visualize abstract concepts**: Game representations make invisible processes visible
- **Support experimentation**: Safe environments for trial and error

In the context of HPC education, serious games can transform abstract parallelization strategies into tangible, manipulable activities. Instead of imagining threads operating on shared data, students can physically (or virtually) manipulate game elements that represent computation and data.

### 1.1.3 Physical Teaching Experiments as Inspiration

The pedagogical approach underlying this thesis stems from real-world classroom experiments conducted to teach parallel computing:

**OpenMP Simulation (Shared Memory Parallelism):**  
In one experiment, approximately 50 numbered cards were placed on a desk, and three students were asked to sort them collaboratively in an "OpenMP fashion"—meaning no verbal communication, simulating independent threads operating on shared data. Each student could:
- View all cards (shared memory)
- Move cards in the main workspace
- Use a private area for local reordering (thread-local storage)
- Merge their locally sorted subarrays back into the main array

This exercise demonstrated:
- How threads can work independently without explicit communication
- The challenges of coordinating work without synchronization primitives
- The concept of private vs. shared data
- The merge phase in parallel sorting algorithms

**MPI Simulation (Distributed Memory Parallelism):**  
In another experiment, students were positioned at different desks in the classroom (simulating distributed nodes), each receiving a subset of cards. They sorted their local subsets independently, then physically walked to a "master" student's desk to deliver their lowest card—simulating MPI message passing. The master student collected cards from all processes and merged them into a globally sorted order.

This exercise illustrated:
- Distributed data ownership (each process has its own memory)
- Explicit message passing for communication
- The master-worker pattern
- Network communication overhead (walking takes time, like network latency)

These physical activities were highly effective at conveying parallel computing concepts in a tangible way. Students reported better intuitive understanding and found the exercises memorable. This thesis aims to capture that pedagogical effectiveness in a scalable, digital format accessible on mobile devices.

### 1.1.4 The Gap Between Theory and Practice

Despite the availability of parallel programming frameworks like OpenMP and MPI, students often complete courses without developing strong intuition for:

- When to use shared memory vs. distributed memory approaches
- How to decompose problems for parallel execution
- The performance implications of different synchronization strategies
- The trade-offs between communication overhead and parallel speedup

Educational games can bridge this gap by providing:
- **Low-stakes experimentation**: Students can try different strategies without breaking expensive clusters
- **Visual representations**: Seeing cards move between buffers makes data movement concrete
- **Performance feedback**: Timing and move counting provide immediate metrics
- **Collaborative learning**: Multiplayer mode enables peer learning and discussion

## 1.2 Research Problem

This thesis addresses the following research questions:

### Primary Research Question:
**How can serious games effectively teach fundamental HPC concepts (OpenMP and MPI paradigms) in an engaging, intuitive manner on mobile platforms?**

### Secondary Research Questions:
1. **Pedagogical Mapping**: How can card sorting mechanics accurately represent parallel computing concepts without oversimplification or misleading abstractions?

2. **Technical Feasibility**: What are the technical challenges in implementing a multiplayer educational game on mobile devices, and how can they be overcome?

3. **UI/UX for Mobile**: How can a game display and allow manipulation of many interactive elements (50+ cards) on small smartphone screens while maintaining usability?

4. **Multiplayer Synchronization**: How can real-time multiplayer state synchronization be achieved for educational purposes, ensuring all players see consistent game state despite network latency?

5. **Engagement vs. Education**: How can game mechanics be designed to be both educationally sound and engaging enough to maintain student interest?

## 1.3 Objectives

### 1.3.1 Primary Objective
Develop a fully functional, mobile-first serious game that teaches parallel computing fundamentals through interactive card sorting, accurately representing OpenMP (shared memory) and MPI (distributed memory) paradigms.

### 1.3.2 Secondary Objectives

**Educational Objectives:**
- Create game mechanics that map directly to OpenMP and MPI programming patterns
- Implement single-player mode to simulate OpenMP-style parallelism (shared workspace, private buffers, no communication)
- Implement multiplayer mode to simulate MPI-style parallelism (distributed data, explicit message passing)
- Provide performance metrics (time, number of moves) to encourage optimization thinking

**Technical Objectives:**
- Develop a robust multiplayer architecture with reliable state synchronization
- Ensure smooth performance on Android devices (target 60 FPS)
- Implement intuitive touch-based drag-and-drop for card manipulation
- Create responsive UI that adapts to various screen sizes and orientations
- Utilize open-source technologies to enable future research and extensions

**Design Objectives:**
- Design engaging game mechanics that motivate repeated play
- Provide clear visual feedback for all game actions
- Implement progressive difficulty (varying numbers of cards)
- Support 2-4 players in multiplayer mode

### 1.3.3 Tertiary Objectives
- Evaluate technical feasibility and performance on real Android devices
- Gather preliminary feedback on educational effectiveness (if time permits)
- Document design patterns and lessons learned for future educational game developers
- Prepare materials for publication at a conference or in a journal

## 1.4 Proposed Solution

### 1.4.1 Overview of the HPC Sorting Serious Game

The **HPC Sorting Serious Game** is a mobile-first educational game implemented using the Godot Engine and GDScript. The game presents players with a set of numbered cards in random order and challenges them to sort the cards in ascending order as quickly as possible using the fewest moves.

**Core Mechanics:**
- **Card Container**: A scrollable horizontal container displaying all cards (10-100+ cards supported)
- **Drag-and-Drop**: Players drag cards to reorder them within the container
- **Buffer Zones**: Private slots where players can temporarily store cards for local sorting
- **Timer**: Tracks time from first move to successful sorting
- **Move Counter**: Counts each card placement to encourage algorithmic thinking
- **Validation**: Real-time feedback when cards are correctly sorted

### 1.4.2 Game Modes

**Single-Player Mode (Synchronous Simulation):**
In single-player mode, the player sees:

- The full set of cards in a shared container (simulating shared memory)
- A set of private buffer slots (simulating thread-local storage)
- The ability to move cards freely without restrictions

This mode simulates synchronous work where single thread controls all operations. The player must:

1. Strategically use buffer zones to sort subsequences (due to limited space on the screen)
2. Merge sorted subsequences back into the main container
3. Minimize moves and time (simulating algorithmic efficiency)

The lack of artificial restrictions (like forced turn-taking) represents the non-communicating, independent nature of synchronous execution.

**Multiplayer Mode (OpenMP Simulation):**

In multiplayer mode (2-4 players), the game simulates distributed memory parallelism:

- Each player sees the shared card container (simulating globally accessible data that must be explicitly communicated)
- Each player has private buffer zones visible only to them (simulating local process memory)
- Cards moved to a player's buffer disappear from other players' views (simulating data distribution)
- Players must coordinate to sort the full set

This mode represents MPI programming where:

- Data is distributed across processes
- Communication is explicit (moving cards represents message passing)
- Each process has its own local memory (private buffers)
- A coordinated protocol is needed to achieve a global goal

### 1.4.3 Pedagogical Mapping

| HPC Concept | Game Mechanic |
|-------------|---------------|
| **OpenMP Parallel Region** | Single-player game session |
| **Shared Memory** | Main card container visible to all |
| **Thread-Local Storage** | Private buffer zones |
| **Thread Independence** | No forced turn-taking, free card movement |
| **Work Distribution** | Choosing which cards to work on |
| **Parallel Sorting (e.g., Merge Sort)** | Sorting in buffers, then merging |
| **MPI Process** | Individual player in multiplayer mode |
| **Distributed Memory** | Each player's private buffers |
| **Message Passing** | Moving cards between container and buffers |
| **Master-Worker Pattern** | One player coordinates final merging |
| **Communication Overhead** | Time spent moving cards vs. sorting |
| **Synchronization** | Coordinating who works on which cards |

### 1.4.4 Technology Stack

**Engine**: Godot 4.x
- Open-source, lightweight, excellent for 2D games
- Cross-platform (Android, iOS, Web, Desktop)
- Built-in scene system and signal-based architecture
- Active community and plugin ecosystem

**Language**: GDScript
- Python-like syntax (easy for students to understand if they see the code)
- Tight integration with Godot
- Simpler export process than C# (no additional runtimes required for Android)

**Key Plugins/Frameworks**:
- **GDSync**: Multiplayer state synchronization framework for Godot
- **WebRTC/NodeWebSockets**: Real-time peer-to-peer communication
- **ToastParty**: User notification system
- **Logger**: Debugging and development tool
- **VarTree**: Runtime variable inspection

**Target Platform**: Android (primary), with support for desktop and potential web deployment

## 1.5 Thesis Contributions

This thesis makes the following contributions to the fields of computer science education and serious game development:

### 1.5.1 Pedagogical Contributions

**1. Novel Educational Approach to Parallel Computing:**
- A concrete, interactive representation of abstract HPC concepts
- Validated mapping between game mechanics and OpenMP/MPI patterns
- A scalable alternative to physical classroom exercises

**2. Design Patterns for Educational Multiplayer Games:**
- Reusable patterns for state synchronization in educational contexts
- Strategies for balancing educational fidelity with gameplay engagement
- Mobile-first design principles for educational games

### 1.5.2 Technical Contributions

**3. Multiplayer Synchronization for Educational Games:**
- Implementation of host-authoritative state management
- Solutions for synchronizing complex game state (100+ dynamic objects)
- Handling of distributed private state (player buffers) in multiplayer

**4. Mobile UI/UX Solutions:**
- Responsive layout for displaying many interactive elements on small screens
- Touch-optimized drag-and-drop for educational manipulation tasks
- ScrollContainer patterns for large numbers of game objects

**5. Open-Source Educational Platform:**
- Fully documented, extensible codebase on GitHub
- Reusable components for future educational game projects
- Plugin-based architecture for adding new HPC concepts

### 1.5.3 Research Contributions

**6. Evaluation Framework:**
- Methodology for assessing educational game effectiveness
- Performance metrics relevant to HPC education
- Technical performance benchmarks for mobile educational games

**7. Documentation of Challenges and Solutions:**
- Comprehensive analysis of GDSync framework limitations and workarounds
- Lessons learned in mobile multiplayer game development
- Recommendations for educators and game developers

## 1.6 Thesis Organization

This thesis is organized into eight chapters:

**Chapter 1: Introduction** (current chapter) establishes the context, motivation, research problems, objectives, and contributions of this work.

**Chapter 2: Background and Literature Review** surveys related work in HPC education, serious games for computer science, mobile game development, and multiplayer architecture patterns. It establishes the theoretical foundations and identifies gaps in existing research.

**Chapter 3: Methodology** describes the research approach, requirements analysis, technology selection rationale, game design methodology, and development process.

**Chapter 4: System Design and Architecture** presents the high-level architecture, component design, multiplayer synchronization strategy, and UI/UX considerations.

**Chapter 5: Implementation** details the actual implementation, including algorithms, code structure, mobile-specific optimizations, and key technical decisions.

**Chapter 6: Problems and Challenges** analyzes the difficulties encountered during development, solutions attempted, and lessons learned—particularly regarding GDSync issues and multiplayer synchronization challenges.

**Chapter 7: Results and Evaluation** presents the completed system, performance metrics, and preliminary evaluation of educational effectiveness (if conducted).

**Chapter 8: Conclusion and Future Work** summarizes contributions, answers research questions, discusses implications, and outlines directions for future research and development.

**Appendices** provide supplementary materials including user manuals, code listings, API documentation, and study materials.

---

# Chapter 4: System Design and Architecture

## 4.1 High-Level Architecture

### 4.1.1 Architectural Overview

The HPC Sorting Serious Game follows a **layered architecture** with clear separation of concerns, organized as shown in Figure 4.1.

```
┌─────────────────────────────────────────────────────────────┐
│                     Presentation Layer                       │
│  (Scenes, UI Components, Visual Feedback, Animations)       │
└───────────────────┬─────────────────────────────────────────┘
                    │
┌───────────────────┴─────────────────────────────────────────┐
│                    Game Logic Layer                          │
│  (Card Manager, State Validation, Sorting Algorithms)       │
└───────────────────┬─────────────────────────────────────────┘
                    │
┌───────────────────┴─────────────────────────────────────────┐
│                 Multiplayer Sync Layer                       │
│         (GDSync, State Broadcasting, RPC Calls)             │
└───────────────────┬─────────────────────────────────────────┘
                    │
┌───────────────────┴─────────────────────────────────────────┐
│                  Network Transport Layer                     │
│              (WebRTC, WebSockets, Signaling)                │
└─────────────────────────────────────────────────────────────┘
```
*Figure 4.1: High-level architectural layers*

**Key Architectural Principles:**

1. **Scene-Based Organization**: Godot's scene system naturally separates concerns into reusable, composable units (Main Menu, Lobby, Game Scene, etc.)

2. **Signal-Driven Communication**: Components communicate via Godot's signal system, enabling loose coupling and clear event flow

3. **Inheritance Hierarchy**: `MultiplayerCardManager` extends `CardManager`, adding multiplayer logic while reusing single-player code

4. **Singleton Pattern**: Global managers (`Settings`, `ConnectionManager`, `SceneManager`) provide shared state and functionality

5. **Host-Authoritative Model**: The host maintains the authoritative game state; clients render local views but respect host decisions

### 4.1.2 Component Diagram

```
┌──────────────┐         ┌──────────────┐
│  MainMenu    │────────▶│   Lobby      │
│   Scene      │         │   Scene      │
└──────────────┘         └──────┬───────┘
                                │
                                ▼
                         ┌─────────────┐
                         │ Multiplayer │
                         │ Game Scene  │
                         └──────┬──────┘
                                │
                 ┌──────────────┼──────────────┐
                 ▼              ▼              ▼
         ┌──────────────┐ ┌──────────┐ ┌────────────┐
         │ Multiplayer  │ │  Card    │ │  Timer     │
         │ CardManager  │ │Component │ │ Controller │
         └──────┬───────┘ └────┬─────┘ └────────────┘
                │              │
                │         ┌────▼─────┐
                │         │  Card    │
                │         │  Buffer  │
                │         │  (Slot)  │
                │         └──────────┘
                ▼
         ┌──────────────┐
         │ Connection   │
         │  Manager     │
         └──────┬───────┘
                │
                ▼
         ┌──────────────┐
         │   GDSync     │
         │  Framework   │
         └──────────────┘
```
*Figure 4.2: Major component relationships*

### 4.1.3 Client-Server Architecture

Despite being a peer-to-peer game (no dedicated server), the system uses a **host-authoritative client-server logical model**:

- **Host** (one player): Acts as the authoritative server
  - Generates initial game state (card values, order)
  - Validates all game actions
  - Broadcasts state updates to clients
  - Handles game completion logic

- **Clients** (other players): 
  - Render local view of game state
  - Send action requests to host (implicit in GDSync model)
  - Apply state updates received from host
  - Maintain local buffer state (private to each player)

This architecture ensures consistency: even if network conditions cause temporary desynchronization, the host's view is considered canonical.

### 4.1.4 State Machine: Game Flow

```
     [Start]
        │
        ▼
   ┌─────────┐
   │Main Menu│
   └────┬────┘
        │
        ├─────────Single Player────────┐
        │                              │
        ▼                              ▼
   ┌─────────┐                  ┌───────────┐
   │Multiplayer│                │Single-Player│
   │ Options  │                │ Game Scene │
   └────┬────┘                  └─────┬─────┘
        │                              │
        ▼                              │
   ┌─────────┐                        │
   │  Lobby  │                        │
   └────┬────┘                        │
        │                              │
        │ (Host: Start Game)           │
        ▼                              │
   ┌──────────────┐                   │
   │Multiplayer   │◀──────────────────┘
   │ Game Scene   │
   └──────┬───────┘
          │
          │ (Finish Game)
          ▼
   ┌──────────────┐
   │Finish Game   │
   │   Window     │
   └──────┬───────┘
          │
          ├─── Main Menu
          └─── Restart
```
*Figure 4.3: Game flow state machine*

## 4.2 Scene Structure

Godot's scene system organizes the game into modular, reusable units. Each scene is a tree of nodes with attached scripts.

### 4.2.1 Main Menu Scene

**Purpose**: Entry point for the application; navigation hub

**Structure**:
```
MenuScene (Control)
├── BackgroundTheme (Node)
├── MarginContainer
│   └── VBoxContainer
│       ├── TitleLabel
│       ├── SinglePlayerButton
│       ├── MultiplayerButton
│       └── OptionsButton
```

**Key Script**: `main_menu_options.gd`
- Handles button presses
- Navigates to single-player game scene or multiplayer options
- Opens settings dialog

**Signals**:
- Button `pressed` signals connected to navigation methods

### 4.2.2 Single-Player Game Scene

**Purpose**: Core gameplay for OpenMP simulation (single-player mode)

**Structure**:
```
SingleplayerScene (Control)
├── CardManager (Control) [card_manager.gd]
│   ├── ScrollContainer [scroll_container.gd]
│   │   └── CardContainer (HBoxContainer)
│   │       ├── Card instances...
│   ├── BufferZoneContainer (HBoxContainer)
│   │   ├── CardBuffer (VBoxContainer) ×N
│   │   │   └── Panel (Card slot)
│   ├── SortedCardsPanel (Panel)
│   │   └── SortedCardsContainer (HBoxContainer)
│   │       ├── Reference sorted cards...
│   ├── TimerDisplay (Label)
│   ├── MoveCounterLabel (Label)
│   └── FinishGameButton (Button)
```

**Key Components**:

1. **CardManager Script** (`card_manager.gd`):
   - Generates random card values
   - Instantiates Card nodes
   - Handles card placement signals
   - Validates sorting order
   - Manages timer and move counter

2. **ScrollContainer** (`scroll_container.gd`):
   - Enables horizontal scrolling for many cards
   - Handles drag-and-drop within card container
   - Calculates drop positions
   - Emits `card_dropped_card_container` signal

3. **Card Component** (`card.gd`):
   - Draggable panel with a label showing value
   - Drag preview generation
   - Visual feedback (hover, drag states)
   - Manages current container/slot parent

4. **CardBuffer** (`card_buffer.gd`):
   - Represents a private buffer slot
   - Accepts card drops
   - Enforces single-card occupancy
   - Visual feedback when occupied

**Data Flow (Single-Player)**:
1. User drags card from CardContainer
2. ScrollContainer detects drop, reorders cards
3. ScrollContainer emits signal: `card_dropped_card_container(card, was_in_buffer, slot)`
4. CardManager receives signal
5. CardManager increments move counter, starts timer (if first move)
6. CardManager checks if cards are sorted
7. If sorted, CardManager shows completion dialog

### 4.2.3 Multiplayer Lobby Scene

**Purpose**: Pre-game lobby where players gather before starting a multiplayer session

**Structure**:
```
MultiplayerLobbyScene (Window)
├── ConnectionManager (AutoLoad Singleton)
├── VBoxContainer
│   ├── LobbyInfoLabel (Label)
│   ├── PlayerListContainer (VBoxContainer)
│   │   ├── PlayerInLobby instances... [spawned dynamically]
│   └── StartGameButton (Button) [host only]
```

**Key Components**:

1. **MultiplayerLobby Script** (`multiplayer_lobby.gd`):
   - Displays lobby name/code
   - Lists connected players
   - Host can start the game (button visible only for host)
   - Listens for `player_joined`, `player_left`, `player_list_updated` signals from ConnectionManager

2. **PlayerInLobby** (`player_in_lobby.gd`):
   - Displays player name and client ID
   - Color-coded (host in different color)
   - Host can kick players (optional feature)

**Multiplayer Synchronization**:
- When a player joins, host creates a `PlayerInLobby` UI instance
- GDSync synchronizes player list updates
- Each client sees all players in the lobby

### 4.2.4 Multiplayer Game Scene

**Purpose**: Core gameplay for MPI simulation (multiplayer mode)

**Structure** (similar to single-player, with extensions):
```
MultiplayerGameScene (Control)
├── MultiplayerCardManager (Control) [multiplayer_card_manager.gd]
│   ├── ScrollContainer
│   │   └── CardContainer (HBoxContainer)
│   │       ├── Card instances... [host generates, clients receive]
│   ├── MyBufferZoneContainer (HBoxContainer)
│   │   ├── CardBuffer ×N (my private buffers)
│   ├── SortedCardsPanel
│   ├── TimerDisplay
│   ├── MoveCounterLabel
│   └── FinishGameButton
```

**Key Differences from Single-Player**:

1. **MultiplayerCardManager Script** (`multiplayer_card_manager.gd`):
   - Extends `CardManager`
   - Host generates cards; clients receive state
   - Exposes sync functions via GDSync
   - Tracks cards in other players' buffers (hidden from view)
   - Broadcasts card movements to all clients

2. **Private Buffer Visibility**:
   - Each player sees only their own buffer zone
   - Cards in other players' buffers are hidden from view
   - Dictionary `cards_in_other_buffers` tracks which cards are unavailable

3. **State Synchronization Functions**:
   - `sync_complete_game_state()`: Full state sync (for late joiners or initial load)
   - `sync_card_moved()`: Sync card reordering in main container
   - `sync_card_entered_buffer()`: Notify others when a card enters a player's buffer (hide it)
   - `sync_card_left_buffer()`: Notify others when a card leaves a player's buffer (show it)
   - `sync_timer_state()`: Sync timer start/stop

**Data Flow (Multiplayer - Card Moved in Container)**:
1. Player A drags card in CardContainer
2. ScrollContainer on Player A's device emits signal
3. MultiplayerCardManager on Player A's device calls `GDSync.call_func(sync_card_moved, [...])`
4. GDSync broadcasts to all clients (Player B, Player C, etc.)
5. MultiplayerCardManager on Player B receives `sync_card_moved()`
6. Player B's UI updates to reflect the new card order

**Data Flow (Multiplayer - Card Moved to Buffer)**:
1. Player A drags card to their private buffer
2. Card placement signal triggers `_on_card_placed_in_slot()`
3. MultiplayerCardManager calls `GDSync.call_func(sync_card_entered_buffer, [card_value, my_client_id])`
4. Player B and C receive `sync_card_entered_buffer()`
5. They remove the card from their view of CardContainer
6. They add card_value to `cards_in_other_buffers` dictionary
7. Player A still sees the card in their buffer

## 4.3 Core Game Components

### 4.3.1 Card Manager

**Responsibility**: Central controller for game logic

**Key Attributes**:
```gdscript
var cards_array: Array[Card] = []          # Active game cards
var sorted_cards_array: Array[Card] = []   # Reference sorted cards
var values: Array[int] = []                 # Card values
var sorted_all: Array[int] = []            # Sorted reference values
var num_cards: int = 64                     # Number of cards
var card_colors: Array[Color] = [...]      # Color palette
var slots: Array = []                       # Buffer slots
var move_count: int = 0                    # Total moves made
var timer_node: TimerController            # Timer reference
```

**Key Methods**:

1. `_ready()`:
   - Generates random card values
   - Creates card instances
   - Sets up buffer slots
   - Connects signals
   - Initializes timer

2. `generate_random_values() -> Array[int]`:
   - Generates random integers within specified range
   - Returns array of unique or non-unique values

3. `generate_completed_card_array(values: Array[int], prefix: String) -> Array[Card]`:
   - Creates Card nodes with given values
   - Applies styling and names
   - Returns array of Card instances

4. `check_sorting_order() -> bool`:
   - Iterates through cards in CardContainer
   - Checks if each card value <= next card value
   - Returns true if fully sorted

5. `_on_card_placed_in_container(card: Card, was_in_buffer: bool, slot: Variant)`:
   - Increments move counter
   - Starts timer if not already started
   - Checks if sorting is complete
   - Shows completion message if sorted

6. `_on_card_placed_in_slot(card: Card, slot: CardBuffer)`:
   - Increments move counter
   - Starts timer if needed
   - Sets slot occupancy
   - Checks sorting status

**State Management**:
- Maintains arrays of card references for efficient access
- Tracks original indices for swap logic
- Validates game state after each move

### 4.3.2 Card Component

**Responsibility**: Individual draggable card

**Structure**:
```gdscript
class_name Card
extends Panel

var value: int = 0                    # Card's numeric value
var original_index: int = -1          # Original position in container
var current_slot: CardBuffer = null   # Slot if in buffer zone
var can_drag: bool = true             # Whether card is draggable
var container_reference: Node = null  # Reference to CardContainer
```

**Key Methods**:

1. `_get_drag_data(at_position: Vector2) -> Variant`:
   - Godot's drag-and-drop entry point
   - Creates drag preview (semi-transparent copy)
   - Sets DragState.currently_dragged_card
   - Returns self as drag data

2. `_can_drop_data(at_position: Vector2, data: Variant) -> bool`:
   - Checks if data is a valid Card
   - Determines if drop is allowed at this position
   - Used for visual feedback during drag

3. `set_card_value(val: int)`:
   - Sets the card's value
   - Updates label text
   - Triggers visual refresh

4. `set_can_drag(draggable: bool)`:
   - Enables/disables drag interaction
   - Used to lock cards in other players' buffers

5. `place_in_slot(slot: CardBuffer)`:
   - Marks this card as occupying a slot
   - Stores slot reference
   - Changes visual style (optional)

6. `remove_from_slot()`:
   - Clears slot reference
   - Resets visual style
   - Re-enables dragging

**Visual States**:
- **Default**: Base color from card_colors palette
- **Hover**: Slightly lighter/highlighted
- **Dragging**: Semi-transparent preview
- **In Slot**: Darker or bordered to show buffer placement

### 4.3.3 Buffer System (Card Slots)

**Responsibility**: Private storage slots for local sorting

**Structure**:
```gdscript
class_name CardBuffer
extends VBoxContainer

@export var slot_text: String = "Slot"   # Label for this slot
@onready var panel: Panel = $Panel       # Visual container
@onready var label: Label = $Panel/CenterContainer/Label

var occupied_by: Card = null              # Card currently in slot
```

**Key Methods**:

1. `_can_drop_data(at_position: Vector2, data: Variant) -> bool`:
   - Accepts Card instances
   - Rejects if slot already occupied
   - Returns true if drop is valid

2. `_drop_data(at_position: Vector2, data: Variant)`:
   - Removes card from previous parent
   - Adds card to this slot's Panel
   - Calls `card.place_in_slot(self)`
   - Sets `occupied_by = card`
   - Emits signal `card_placed_in_slot`

3. `set_occupied_by(card: Card)`:
   - Updates occupancy state
   - Shows/hides empty slot visual
   - Called by CardManager during sync

4. `_update_panel_visibility()`:
   - Shows panel if slot is empty
   - Hides panel if slot is occupied (card is visible instead)

**Validation**:
- Enforces single-card-per-slot rule
- Provides visual feedback for valid drop zones

### 4.3.4 Timer and Scoring

**TimerController Responsibility**: Track elapsed time from first move to completion

**Structure**:
```gdscript
class_name TimerController
extends Node

var timer_started: bool = false
var elapsed_time: float = 0.0

signal timer_updated(time_string: String)
```

**Key Methods**:

1. `start_timer()`:
   - Sets `timer_started = true`
   - Begins accumulating `elapsed_time` in `_process(delta)`

2. `stop_timer()`:
   - Sets `timer_started = false`
   - Freezes elapsed time

3. `reset_timer()`:
   - Stops timer
   - Resets `elapsed_time = 0.0`

4. `getCurrentTime() -> int`:
   - Returns elapsed time in seconds

5. `getCurrentTimeAsString() -> String`:
   - Formats time as "MM:SS"
   - Returns formatted string

**Scoring Metrics**:
- **Time**: Lower is better (encourages efficient algorithms)
- **Moves**: Fewer moves indicate better algorithm (students learn to minimize swaps)

In educational context:
- Students can compare their times/moves across attempts
- Competitive leaderboards (future feature)
- Teaches algorithm analysis: time complexity vs. move complexity

## 4.4 Multiplayer Architecture

### 4.4.1 Connection Manager

**Responsibility**: Manage multiplayer connections, lobby state, and player tracking

**Structure** (Singleton/AutoLoad):
```gdscript
extends Node

signal player_joined(client_id: int, player_data: Dictionary)
signal player_left(client_id: int)
signal player_list_updated(players: Dictionary)

var players: Dictionary = {}  # client_id: {name: String, ...}
var my_client_id: int = -1
var lobby_host_id: int = -1
```

**Key Methods**:

1. `create_lobby() -> String`:
   - Initializes WebRTC signaling
   - Generates lobby code
   - Sets self as host
   - Returns lobby code/ID

2. `join_lobby(lobby_code: String) -> bool`:
   - Connects to signaling server
   - Attempts to join specified lobby
   - Returns success/failure

3. `am_i_host() -> bool`:
   - Returns true if my_client_id == lobby_host_id

4. `get_lobby_host_id() -> int`:
   - Returns client ID of the lobby host

5. `get_player_list() -> Dictionary`:
   - Returns dictionary of all connected players

6. `get_my_client_id() -> int`:
   - Returns this player's unique client ID

**Signal Emission**:
- When a peer connects: `emit_signal("player_joined", client_id, player_data)`
- When a peer disconnects: `emit_signal("player_left", client_id)`
- When player list changes: `emit_signal("player_list_updated", players)`

**Integration with GDSync**:
- GDSync uses ConnectionManager to identify clients
- Client IDs used as keys for state synchronization

### 4.4.2 State Synchronization Strategy

**Host-Authoritative Model**:

In this architecture:
- **Host is the source of truth** for all game state
- Clients send actions (implicitly via GDSync function calls)
- Host validates and broadcasts state updates
- Clients render based on received updates

**Synchronization Patterns**:

1. **Initial State Broadcast** (Game Start):
   ```
   Host:
     1. Generate card values
     2. Create card instances
     3. Wait for all nodes ready
     4. Call GDSync.call_func(sync_complete_game_state, [...])
   
   Clients:
     1. Receive sync_complete_game_state()
     2. Create cards with received values
     3. Position cards according to received state
     4. Set game_state_synced = true
   ```

2. **Incremental Updates** (Card Movement):
   ```
   Player A moves card:
     1. Player A: Card dropped in container
     2. Player A: Emit local signal
     3. Player A: Call GDSync.call_func(sync_card_moved, [card_val, from, to, my_id])
     4. GDSync broadcasts to all clients
     5. Player B, C: Receive sync_card_moved()
     6. Player B, C: Move card to new position in their view
   ```

3. **Private State** (Buffer Zones):
   ```
   Player A moves card to their buffer:
     1. Player A: Card dropped in slot
     2. Player A: Call GDSync.call_func(sync_card_entered_buffer, [card_val, my_id])
     3. Player B, C: Receive sync_card_entered_buffer()
     4. Player B, C: Remove card from their CardContainer view
     5. Player B, C: Track card in cards_in_other_buffers dictionary
   
   Player A returns card to container:
     1. Player A: Card dropped in container
     2. Player A: Call GDSync.call_func(sync_card_left_buffer, [card_val, my_id, index])
     3. Player B, C: Receive sync_card_left_buffer()
     4. Player B, C: Re-add card to CardContainer at specified index
     5. Player B, C: Remove from cards_in_other_buffers
   ```

**Conflict Resolution**:
- No explicit conflict resolution needed for this game (turn-free gameplay)
- Host's view is canonical if discrepancies arise
- Late-joining clients request full state sync from host

**Data Structures for Sync**:

```gdscript
# Initial state sync payload
{
  "card_states": [
    {"value": 42, "index": 0, "original_index": 0, "in_container": true, "in_buffer": false, "buffer_owner": -1},
    {"value": 17, "index": 1, "original_index": 1, "in_container": true, "in_buffer": false, "buffer_owner": -1},
    ...
  ],
  "values": [42, 17, ...],
  "sorted_all": [1, 2, 3, ...],
  "num_cards": 64,
  "buffer_size": 5
}

# Card movement sync payload
{
  "card_value": 42,
  "from_index": 3,
  "to_index": 7,
  "moving_client_id": 12345
}

# Buffer entry sync payload
{
  "card_value": 42,
  "entering_player_id": 12345
}

# Buffer exit sync payload
{
  "card_value": 42,
  "leaving_player_id": 12345,
  "to_index": 5
}
```

### 4.4.3 GDSync Integration

**GDSync Framework**: A third-party multiplayer synchronization addon for Godot

**Key Concepts**:

1. **Exposed Functions**:
   - Functions marked for remote invocation
   - Called via `GDSync.call_func(function_reference, [args])`
   - Automatically routed to all connected clients

2. **Function Exposure**:
   ```gdscript
   func setup_multiplayer_sync():
       GDSync.expose_func(self.sync_complete_game_state)
       GDSync.expose_func(self.sync_card_moved)
       GDSync.expose_func(self.sync_card_entered_buffer)
       GDSync.expose_func(self.sync_card_left_buffer)
       GDSync.expose_func(self.sync_timer_state)
   ```

3. **Remote Call Patterns**:
   - `GDSync.call_func(func_ref, [args])`: Call on all clients
   - `GDSync.call_func_on(client_id, func_ref, [args])`: Call on specific client
   - `GDSync.set_gdsync_owner(node, client_id)`: Set node ownership

**Protected Mode Issue**:
- GDSync has a "protected mode" that blocks cross-node communication by default
- Solution: Disable protected mode in Project Settings → Tools → GDSync
- Documented in README with screenshot

**Timing Considerations**:
- `await get_tree().process_frame` used to ensure nodes are ready before sync calls
- State requests triggered after a short delay (0.5s) to allow node instantiation

**RPC Pattern Usage**:
While Godot has built-in RPC (Remote Procedure Call), GDSync provides higher-level abstractions:
- Automatic serialization of arguments
- State ownership tracking
- Node instantiation replication (though we chose manual instantiation for control)

## 4.5 UI/UX Design

### 4.5.1 Mobile-First Interface Considerations

**Design Philosophy**: Optimize for small screens first, scale up to larger screens

**Key Principles**:

1. **Touch-Friendly Targets**:
   - Minimum touch target size: 44×44 points (Apple) / 48×48 dp (Android)
   - Cards sized to be easily tappable: default 80×120 pixels

2. **Horizontal Scrolling**:
   - Primary interaction is horizontal drag-and-drop
   - ScrollContainer enables viewing 50+ cards on small screens
   - Momentum scrolling for smooth navigation

3. **Minimal UI Clutter**:
   - Critical info only: timer, move counter, finish button
   - No complex menus during gameplay
   - Full-screen game area

4. **Responsive Layout**:
   - UI elements resize based on screen width
   - Card spacing calculated dynamically
   - Text scales with screen resolution

### 4.5.2 Touch Interaction Patterns

**Drag-and-Drop Implementation**:

1. **Drag Initiation**:
   - `_get_drag_data()` called on touch-down + movement
   - Creates semi-transparent drag preview
   - Original card remains visible (but dimmed)

2. **Drag Feedback**:
   - Preview follows touch point
   - Drop zones highlight when preview is over them
   - Invalid drop zones show visual rejection cue

3. **Drop Handling**:
   - `_can_drop_data()` called continuously during drag
   - `_drop_data()` called on touch-up in valid zone
   - Smooth animation to final position

**Scroll vs. Drag Disambiguation**:
- Challenge: How to distinguish scrolling from card dragging?
- Solution: 
  - Short touch-and-hold initiates drag
  - Quick swipe is interpreted as scroll
  - Once drag starts, scroll is disabled
  - ScrollContainer's `is_dragging_card_over_self` flag

### 4.5.3 Visual Feedback Mechanisms

**Real-Time Feedback**:

1. **Card State Visualization**:
   - **Default**: Card's assigned color from palette
   - **Hover**: Slightly lighter shade
   - **Dragging**: 50% opacity preview
   - **In Buffer**: Darker border or background

2. **Sorting Progress**:
   - Timer updates every frame (or every 0.1s for performance)
   - Move counter increments instantly
   - Toast notifications for milestones (50 moves, 100 moves, etc.)

3. **Completion Feedback**:
   - Confetti particles (CPUParticles2D)
   - Window with time/moves statistics
   - Celebratory color animation
   - Optional sound effect

4. **Error Feedback**:
   - Toast message: "Cards not sorted correctly"
   - Briefly flash incorrectly positioned cards (future feature)

**Multiplayer Feedback**:
- Toast notifications when players join/leave
- Player avatars or colored indicators (future feature)
- Visual cue when other players move cards (subtle highlight)

### 4.5.4 Responsive Layout for Different Screen Sizes

**Breakpoints**:
- Small phones (< 360dp width): Minimum card size, 3-4 cards visible
- Medium phones (360-600dp): Standard card size, 5-7 cards visible
- Tablets (600-900dp): Larger cards, 10+ cards visible
- Large tablets/desktop (> 900dp): Full spread, scrolling may not be needed

**Dynamic Spacing**:
```gdscript
func adjust_container_spacing():
    var available_width = get_viewport_rect().size.x
    var total_card_width = num_cards * Constants.CARD_WIDTH
    var remaining_space = available_width - total_card_width
    
    if remaining_space > 0:
        var spacing = remaining_space / (num_cards - 1)
        card_container.add_theme_constant_override("separation", spacing)
    else:
        # Enable scrolling
        card_container.add_theme_constant_override("separation", 10)
```

**Orientation Support**:
- Landscape: Wider card container, more cards visible
- Portrait: Vertical stacking of UI elements (timer above, buttons below)

## 4.6 Data Flow Diagrams

### 4.6.1 Single-Player Game Flow

```
[Game Start]
     │
     ▼
[Generate Random Values]
     │
     ▼
[Create Card Instances]
     │
     ▼
[Populate CardContainer]
     │
     ▼
[Create Buffer Slots]
     │
     ▼
[Wait for User Input]
     │
     ▼
[User Drags Card] ──────────┐
     │                      │
     ▼                      │
[Drop in Container?]        │
     │                      │
   Yes│   No               │
     │    │                │
     │    ▼                │
     │  [Drop in Buffer]   │
     │    │                │
     │    └────────┐       │
     ▼             ▼       │
[Increment Moves]          │
     │                     │
     ▼                     │
[Start Timer (if first)]   │
     │                     │
     ▼                     │
[Check Sorting Order]      │
     │                     │
   Sorted?                │
     │                     │
   Yes│   No              │
     │    │               │
     │    └───────────────┘
     ▼
[Stop Timer]
     │
     ▼
[Show Completion Window]
     │
     ▼
[Display Stats: Time, Moves]
     │
     ▼
[User Choice: Main Menu or Restart]
```

### 4.6.2 Multiplayer Game Initialization

```
[Lobby: Host Presses Start]
     │
     ▼
[Host: Call prepare_for_game_transition()]
     │
     ├─────────────────────────┐
     │                         │
     ▼                         ▼
[Host: Wait 1s]          [Clients: Receive signal]
     │                         │
     │                         ▼
     │                    [Clients: Show "Preparing..." toast]
     │                         │
     ▼                         ▼
[Host: Call transition_to_game()]
     │                         │
     ├─────────────────────────┘
     │
     ▼
[All: SceneManager.goto_scene("multiplayer_game_scene")]
     │
     ▼
[All: _ready() in MultiplayerCardManager]
     │
     ├─── Host Branch ─────────┐
     │                          │
     ▼                          ▼
[Host: Generate Cards]    [Clients: Initialize Empty]
     │                          │
     ▼                          ▼
[Host: Broadcast State]   [Clients: Request State]
     │                          │
     └─────────┬────────────────┘
               │
               ▼
     [Clients: Receive State]
               │
               ▼
     [Clients: Create Cards]
               │
               ▼
     [Clients: Position Cards]
               │
               ▼
     [All: game_state_synced = true]
               │
               ▼
     [All: Ready to Play]
```

### 4.6.3 Card Movement Synchronization Flow

```
[Player A: Drag Card in Container]
     │
     ▼
[Player A: Drop Card at New Position]
     │
     ▼
[Player A: ScrollContainer._drop_data()]
     │
     ▼
[Player A: Emit card_dropped_card_container(card, was_in_buffer, slot)]
     │
     ▼
[Player A: MultiplayerCardManager._on_card_placed_in_container()]
     │
     ▼
[Player A: Check if card was in buffer]
     │
     ├─── Was in Buffer ───┐
     │                     │
     │                     ▼
     │              [Call sync_card_left_buffer()]
     │                     │
     ├─── Not in Buffer ───┤
     │                     │
     ▼                     │
[Call sync_card_moved()]  │
     │                     │
     └─────────┬───────────┘
               │
               ▼
     [GDSync Broadcasts to All Clients]
               │
               ├─────────────┬─────────────┐
               ▼             ▼             ▼
         [Player B]     [Player C]     [Player D]
               │             │             │
               ▼             ▼             ▼
     [Receive sync_card_moved() or sync_card_left_buffer()]
               │             │             │
               ▼             ▼             ▼
     [Find Card by Value]
               │             │             │
               ▼             ▼             ▼
     [Update Card Position in CardContainer]
               │             │             │
               ▼             ▼             ▼
     [UI Updates Instantly]
```

### 4.6.4 Private Buffer Synchronization Flow

```
[Player A: Drag Card to Their Buffer Slot]
     │
     ▼
[Player A: CardBuffer._drop_data()]
     │
     ▼
[Player A: Emit card_placed_in_slot(card, slot)]
     │
     ▼
[Player A: MultiplayerCardManager._on_card_placed_in_slot()]
     │
     ▼
[Player A: Call GDSync.call_func(sync_card_entered_buffer, [card_value, my_id])]
     │
     ▼
[GDSync Broadcasts to All Clients]
     │
     ├─────────────┬─────────────┐
     ▼             ▼             ▼
[Player B]    [Player C]    [Player D]
     │             │             │
     ▼             ▼             ▼
[Receive sync_card_entered_buffer(card_value, player_A_id)]
     │             │             │
     ▼             ▼             ▼
[Find Card by Value]
     │             │             │
     ▼             ▼             ▼
[Remove Card from CardContainer]
     │             │             │
     ▼             ▼             ▼
[Add to cards_in_other_buffers dictionary]
     │             │             │
     ▼             ▼             ▼
[Card Hidden from View]

───────────────────────────────────────

[Player A: Drag Card from Buffer to Container]
     │
     ▼
[Player A: ScrollContainer._drop_data()]
     │
     ▼
[Player A: Emit card_dropped_card_container(card, was_in_buffer=true, slot)]
     │
     ▼
[Player A: Call GDSync.call_func(sync_card_left_buffer, [card_value, my_id, new_index])]
     │
     ▼
[GDSync Broadcasts to All Clients]
     │
     ├─────────────┬─────────────┐
     ▼             ▼             ▼
[Player B]    [Player C]    [Player D]
     │             │             │
     ▼             ▼             ▼
[Receive sync_card_left_buffer(card_value, player_A_id, new_index)]
     │             │             │
     ▼             ▼             ▼
[Find Card by Value]
     │             │             │
     ▼             ▼             ▼
[Re-add Card to CardContainer at new_index]
     │             │             │
     ▼             ▼             ▼
[Remove from cards_in_other_buffers]
     │             │             │
     ▼             ▼             ▼
[Card Visible Again]
```

---

## 4.7 Security and Data Privacy

While this is an educational game without sensitive data, basic security considerations include:

1. **No Login Required**: Aligns with design goal of frictionless access
2. **No Data Collection**: No personal information collected or transmitted
3. **Local Processing**: All game logic runs on devices, minimal server reliance
4. **Peer-to-Peer Architecture**: WebRTC enables direct connections, reducing server exposure
5. **Open Source**: Code is auditable on GitHub

**Future Considerations**:
- If leaderboards are added: Implement basic anti-cheat (server-side validation)
- If user accounts are added: Follow GDPR compliance for EU users

---

## 4.8 Performance Considerations

### 4.8.1 Target Performance Metrics

- **Frame Rate**: 60 FPS on mid-range Android devices (e.g., Snapdragon 660 or equivalent)
- **Network Latency Tolerance**: Playable with up to 200ms latency
- **Memory Footprint**: < 200 MB RAM
- **Battery Usage**: Comparable to other 2D casual games

### 4.8.2 Optimization Strategies

1. **Object Pooling** (Future):
   - Reuse Card instances instead of creating/destroying
   - Particularly important for games with many cards

2. **Efficient Rendering**:
   - Use CanvasItems (2D nodes) instead of 3D
   - Minimize draw calls by batching similar visual elements
   - Cull off-screen cards (though ScrollContainer handles this)

3. **Network Optimization**:
   - Send only necessary data (card value + indices, not full card state)
   - Throttle non-critical updates (e.g., timer sync every 1s, not every frame)
   - Use delta compression for state updates (future enhancement)

4. **Mobile-Specific**:
   - Reduce particle counts on low-end devices
   - Offer "Performance Mode" toggle (disable animations)
   - Profile with Godot's built-in profiler on actual devices

---

**End of Chapter 4**

---

# Summary

This thesis draft provides a comprehensive foundation for your Master's thesis, covering:

**Chapter 1: Introduction** establishes the educational problem (difficulty teaching HPC), motivates the serious game approach, defines research questions, outlines objectives, and describes the proposed solution.

**Chapter 4: System Design and Architecture** details the technical implementation, including:
- High-level architecture and component diagrams
- Scene structure for single-player and multiplayer modes
- Core components (CardManager, Card, Buffer, Timer)
- Multiplayer synchronization strategy and GDSync integration
- UI/UX design for mobile devices
- Data flow diagrams for various game scenarios

## Next Steps

To complete your thesis, you should:

1. **Write Chapter 2 (Background and Literature Review)**: Survey related work in serious games, HPC education, and mobile game development
2. **Write Chapter 3 (Methodology)**: Describe requirements analysis, technology selection rationale, and development process
3. **Write Chapter 5 (Implementation)**: Detail algorithms, code structure, and mobile-specific optimizations
4. **Write Chapter 6 (Problems and Challenges)**: Document GDSync issues, synchronization challenges, and solutions
5. **Write Chapter 7 (Results and Evaluation)**: Present performance metrics and any user studies conducted
6. **Write Chapter 8 (Conclusion)**: Summarize contributions and propose future work

Would you like me to:
- Expand any section with more detail?
- Draft additional chapters (3, 5, 6, 7, 8)?
- Add diagrams, pseudocode, or code listings?
- Refine the existing content?
