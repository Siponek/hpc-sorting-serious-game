# GD-Sync Web Export Fix - Implementation Plan

## Problem Summary

GD-Sync fails on web exports because it uses networking APIs that are **not available in web browsers**:
- `PacketPeerUDP.bind()` - UDP sockets blocked by browsers
- `ENetMultiplayerPeer.create_server()` / `create_client()` - ENet not available in WASM

**Error:** `CONNECTION_FAILED.LOCAL_PORT_ERROR` (error code 2)

---

## Architecture Analysis

### GD-Sync Networking Flow (Current - Desktop Only)

```
┌─────────────────────────────────────────────────────────────────┐
│                    GD-Sync Architecture                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  MultiplayerClient.gd                                           │
│       │                                                         │
│       ├── _local_server (LocalServer.gd)     ← FAILS ON WEB     │
│       │       ├── PacketPeerUDP (lobby discovery)               │
│       │       └── ENetMultiplayerPeer (game server)             │
│       │                                                         │
│       └── _connection_controller (ConnectionController.gd)      │
│               └── ENetMultiplayerPeer (client)  ← FAILS ON WEB  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Web-Incompatible Code Locations

| File | Line | Code | Issue |
|------|------|------|-------|
| `LocalServer.gd` | 47 | `var local_peer : PacketPeerUDP = PacketPeerUDP.new()` | UDP not available |
| `LocalServer.gd` | 46 | `var local_server : ENetMultiplayerPeer = ENetMultiplayerPeer.new()` | ENet not available |
| `LocalServer.gd` | 119 | `local_peer.bind(port)` | Fails on web |
| `LocalServer.gd` | 134 | `local_server.create_server(8080)` | Fails on web |
| `ConnectionController.gd` | 317-318 | `client = ENetMultiplayerPeer.new()` + `client.create_client()` | Fails on web |

---

## Available Solutions

### Option A: Script Override Patch (Recommended)

**Strategy:** Create a patched version of `LocalServer.gd` that uses WebRTC via PackRTC, then swap it at runtime for web builds.

**Pros:**
- No modifications to GD-Sync submodule
- Can update GD-Sync independently
- Clean separation of concerns

**Cons:**
- Requires maintaining parallel implementation
- Need to keep patch in sync with GD-Sync updates

### Option B: Fork GD-Sync and Modify

**Strategy:** Fork GD-Sync repo, add web support directly with platform checks.

**Pros:**
- Single codebase
- Can submit PR upstream

**Cons:**
- Harder to receive upstream updates
- More invasive changes

### Option C: Bypass GD-Sync for Web, Use PackRTC Directly

**Strategy:** On web, completely skip GD-Sync and use PackRTC's multiplayer system.

**Pros:**
- Simpler implementation
- PackRTC already works on web

**Cons:**
- Two different multiplayer systems to maintain
- ConnectionManager needs significant changes
- Different lobby/session semantics

---

## Recommended Implementation: Option A (Script Override Patch)

### Phase 1: Create WebRTC-based LocalServer Replacement

Create `scenes/Multiplayer/LocalServerWebPatch.gd` that:
1. Extends or replaces `LocalServer.gd` functionality
2. Uses PackRTC's WebRTC signaling instead of UDP broadcast
3. Uses `WebRTCMultiplayerPeer` instead of `ENetMultiplayerPeer`
4. Maintains the same public API so GD-Sync internals work unchanged

### Phase 2: Create Platform-Aware Loader

Modify how GD-Sync loads `_local_server`:

```gdscript
# In a patch/autoload that runs before GDSync
func _ready():
    if OS.has_feature("web"):
        # Replace LocalServer with web-compatible version
        var gdsync = get_node("/root/GDSync")
        var old_local_server = gdsync._local_server
        old_local_server.queue_free()

        var web_local_server = preload("res://scenes/Multiplayer/LocalServerWebPatch.gd").new()
        gdsync._local_server = web_local_server
        gdsync.add_child(web_local_server)
```

### Phase 3: Implement WebRTC LocalServer

The patched LocalServer needs to implement these key functions:

| Original Function | Web Replacement |
|-------------------|-----------------|
| `start_local_peer()` | Connect to PackRTC signaling server |
| `create_local_lobby()` | Call `PackRTC.host()` to create room |
| `join_lobby()` | Call `PackRTC.join(code)` |
| `get_public_lobbies()` | Query PackRTC API for available rooms |
| `perform_local_scan()` | Not needed - PackRTC handles discovery |

---

## Detailed Implementation Steps

### Step 1: Create the Web LocalServer Patch

**File:** `scenes/Multiplayer/LocalServerWebPatch.gd`

```gdscript
extends Node

# Mirrors LocalServer.gd interface but uses WebRTC

var GDSync
var connection_controller
var request_processor
var session_controller
var logger

# Lobby state (same as original)
var local_lobby_name : String = ""
var local_lobby_password : String = ""
var local_lobby_public : bool = false
var local_lobby_open : bool = true
var local_lobby_player_limit : int = 0
var local_lobby_data : Dictionary = {}
var local_lobby_tags : Dictionary = {}
var found_lobbies : Dictionary = {}

# WebRTC specific
var rtc_session: PRSession = null
var is_host: bool = false

func _ready() -> void:
    GDSync = get_node("/root/GDSync")
    name = "LocalServer"
    # ... initialize references

func start_local_peer() -> bool:
    # For web, we don't need to bind UDP - just return success
    # Actual connection happens when creating/joining lobby
    logger.write_log("Web platform: Using WebRTC instead of UDP.", "[LocalServer-Web]")
    return true

func create_local_lobby(name: String, password: String = "", public: bool = true, ...) -> void:
    # Use PackRTC to create a room
    PackRTC.game_channel = "gdsync-" + name
    var session = await PackRTC.host()

    if session is PRSession:
        rtc_session = session
        is_host = true
        local_lobby_name = name
        # ... set other state

        # Wait for peer to be ready
        await session.peer_ready

        # Emit success
        GDSync.lobby_created.emit.call_deferred(name)
    else:
        GDSync.lobby_creation_failed.emit.call_deferred(name, ENUMS.LOBBY_CREATION_ERROR.LOCAL_PORT_ERROR)

func join_lobby(name: String, password: String) -> void:
    # Use PackRTC to join a room by code
    var session = await PackRTC.join(name)

    if session is PRSession:
        rtc_session = session
        is_host = false
        local_lobby_name = name

        await session.peer_ready

        # Connect signals and emit success
        GDSync.lobby_joined.emit.call_deferred(name)
    else:
        GDSync.lobby_join_failed.emit.call_deferred(name, ENUMS.LOBBY_JOIN_ERROR.LOBBY_DOES_NOT_EXIST)

# ... implement remaining functions
```

### Step 2: Create the Patch Loader Autoload

**File:** `scenes/Multiplayer/GDSyncWebPatch.gd`

```gdscript
extends Node

# This autoload should be loaded AFTER GDSync in project.godot

func _ready():
    if not OS.has_feature("web"):
        return  # Only patch on web

    # Wait for GDSync to be ready
    await get_tree().process_frame

    _apply_web_patch()

func _apply_web_patch():
    var gdsync = get_node_or_null("/root/GDSync")
    if not gdsync:
        push_error("GDSyncWebPatch: GDSync not found!")
        return

    # Get the original LocalServer
    var original = gdsync.get_node_or_null("LocalServer")
    if original:
        original.name = "LocalServer_Original"
        original.set_process(false)

    # Add web-compatible LocalServer
    var web_server = preload("res://scenes/Multiplayer/LocalServerWebPatch.gd").new()
    web_server.name = "LocalServer"
    gdsync.add_child(web_server)
    gdsync._local_server = web_server

    print("GDSync Web Patch applied successfully!")
```

### Step 3: Register Autoload

Add to `project.godot` (after GDSync):

```ini
[autoload]
# ... existing autoloads ...
GDSync="*res://addons/GD-Sync/MultiplayerClient.gd"
GDSyncWebPatch="*res://scenes/Multiplayer/GDSyncWebPatch.gd"  # Add this
ConnectionManager="*res://scenes/Multiplayer/connection_manager.gd"
```

### Step 4: Update ConnectionManager

Remove the web platform skip in `connection_manager.gd`:

```gdscript
func ensure_multiplayer_started():
    # Remove the OS.has_feature("web") check since we now support web
    if not GDSync.is_active():
        GDSync.start_local_multiplayer()
        logger.log_info("Started local multiplayer.")
    else:
        logger.log_info("Local multiplayer already started or connected.")
```

---

## Key Differences: Desktop vs Web

| Feature | Desktop (ENet/UDP) | Web (WebRTC/PackRTC) |
|---------|-------------------|---------------------|
| Lobby Discovery | UDP broadcast on LAN | PackRTC signaling server |
| Lobby ID | Lobby name string | Room code (4-6 chars) |
| Connection | Direct IP + Port | WebRTC via STUN/TURN |
| Hosting | Binds to port 8080 | Creates room on signaling server |
| Joining | Connects to IP:8080 | Joins room by code |

---

## Testing Checklist

- [ ] Web export loads without errors
- [ ] Can create lobby on web
- [ ] Can join lobby on web
- [ ] Desktop-to-web cross-play works
- [ ] Web-to-web multiplayer works
- [ ] Player data syncs correctly
- [ ] Disconnect/reconnect handling works

---

## Alternative: Minimal Fix (Disable with Clear Message)

If full WebRTC implementation is not feasible now, implement a cleaner disable:

```gdscript
# In connection_manager.gd
func ensure_multiplayer_started():
    if OS.has_feature("web"):
        # Show user-friendly message
        ToastParty.show({
            "text": "Multiplayer is not yet supported in the web version. Please use the desktop version for multiplayer.",
            "bgcolor": Color.ORANGE_RED,
        })
        emit_signal("connection_to_multiplayer_failed", -1)
        return

    # ... rest of function
```

---

## Files to Create/Modify

### New Files:
1. `scenes/Multiplayer/LocalServerWebPatch.gd` - WebRTC replacement for LocalServer
2. `scenes/Multiplayer/GDSyncWebPatch.gd` - Autoload that applies the patch

### Modified Files:
1. `project.godot` - Add GDSyncWebPatch autoload
2. `scenes/Multiplayer/connection_manager.gd` - Remove web disable check

---

## Dependencies

- **PackRTC** (already installed) - Provides WebRTC signaling
- **AwaitableHTTPRequest** (already installed) - Used by PackRTC
- **WebSocketClient** (already installed via nodewebsockets) - Used by PackRTC

---

## Estimated Effort

| Task | Complexity | Time Estimate |
|------|------------|---------------|
| LocalServerWebPatch.gd | High | 4-6 hours |
| GDSyncWebPatch.gd | Low | 30 min |
| Testing & Debug | Medium | 2-3 hours |
| **Total** | | **6-10 hours** |

---

## Next Steps

1. Decide on implementation approach (full WebRTC vs minimal disable)
2. If full WebRTC: Start with `LocalServerWebPatch.gd`
3. Test incrementally - start with `start_local_peer()` returning true
4. Implement lobby creation/joining
5. Test cross-platform multiplayer
