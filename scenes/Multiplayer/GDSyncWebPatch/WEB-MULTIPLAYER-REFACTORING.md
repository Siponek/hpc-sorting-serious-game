# Web Multiplayer Implementation - Code Review & Refactoring Plan

**Date:** 2025-12-18
**Status:** Proposal
**Files Under Review:**
- `scenes/Multiplayer/LocalServerSignaling.gd` (1091 lines)
- `scenes/Multiplayer/SignalingClient.gd` (536 lines)
- `scenes/Multiplayer/GDSyncWebPatch.gd` (67 lines)

---

## Executive Summary

The current web multiplayer implementation works but has accumulated significant technical debt. The main issues are:

1. **God Class anti-pattern** - LocalServerSignaling.gd does too much
2. **No type safety** - Heavy use of raw arrays and dictionaries
3. **Duplicated code patterns** - Similar functions repeated with minor variations
4. **Fragile communication** - Magic index access, no standardized protocol
5. **Missing error handling** - Silent failures, no reconnection logic

**Estimated effort:** 2-3 days of focused refactoring
**Risk level:** Medium (requires careful testing of multiplayer flows)

---

## Part 1: Identified Problems

### 1.1 LocalServerSignaling.gd — God Class (1091 lines)

#### Problem: Single Responsibility Violation

This file handles:
- Host-side packet processing
- Client-side packet processing
- Lobby state management (name, password, tags, data)
- Message formatting and sending
- Ownership tracking and caching
- Signaling event handling
- Peer/client table management

**Impact:** Difficult to test, modify, or understand individual components.

#### Problem: The `_send_message` Signature

```gdscript
func _send_message(
    message: int, client: Client, value=null, value2=null, value3=null
) -> void:
```

This pattern indicates missing message abstraction. The nullable positional parameters are error-prone and don't convey meaning.

#### Problem: Magic Index Access

Throughout the code, request data is accessed via enum indices:

```gdscript
var node_path = request[ENUMS.DATA.NAME]      # Index 1
var owner_id = request[ENUMS.DATA.VALUE]      # Index 2
var target = request[ENUMS.DATA.TARGET_CLIENT] # Index 3
```

**Issues:**
- No compile-time type checking
- Easy to use wrong index
- Requires knowledge of GDSync's internal array format
- If GDSync changes indices, code silently breaks

#### Problem: Duplicated Client Inner Class

```gdscript
class Client:
    extends RefCounted
    var valid: bool = false
    var client_id: int = -1
    var peer_id: int = -1
    # ...
```

This duplicates what could be a shared model in `MultiplayerTypes.gd`.

#### Problem: Copy-Paste Request Handlers

The following functions follow identical patterns:

| Function | Lines | Pattern |
|----------|-------|---------|
| `_set_lobby_tag_request` | 10 | Extract key/value → Store → Broadcast LOBBY_DATA_RECEIVED + TAGS_CHANGED |
| `_erase_lobby_tag_request` | 10 | Check exists → Erase → Broadcast LOBBY_DATA_RECEIVED + TAGS_CHANGED |
| `_set_lobby_data_request` | 10 | Extract key/value → Store → Broadcast LOBBY_DATA_RECEIVED + DATA_CHANGED |
| `_erase_lobby_data_request` | 10 | Check exists → Erase → Broadcast LOBBY_DATA_RECEIVED + DATA_CHANGED |
| `_set_player_data_request` | 10 | Extract key/value → Store → Broadcast PLAYER_DATA_RECEIVED + CHANGED |
| `_erase_player_data_request` | 12 | Check exists → Erase → Broadcast PLAYER_DATA_RECEIVED + CHANGED |

**Total:** ~62 lines that could be ~20 lines with generalization.

---

### 1.2 SignalingClient.gd — Fragile Implementation (536 lines)

#### Problem: Manual URL Parsing

```gdscript
if url.begins_with("https://"):
    use_ssl = true
    port = 443
    url = url.substr(8)
elif url.begins_with("http://"):
    url = url.substr(7)

var port_idx = url.find(":")
if port_idx != -1:
    host = url.substr(0, port_idx)
    port = int(url.substr(port_idx + 1))
```

**Issues:**
- Doesn't handle edge cases (paths, query strings, IPv6)
- Duplicates logic that should be utility function
- Error-prone string manipulation

#### Problem: Hand-Rolled SSE Parsing

```gdscript
func _process_sse_buffer() -> void:
    while true:
        var event_end = _sse_buffer.find("\n\n")
        if event_end == -1:
            break
        var event_block = _sse_buffer.substr(0, event_end)
        _sse_buffer = _sse_buffer.substr(event_end + 2)
        _parse_sse_event(event_block)
```

**Issues:**
- No handling of malformed SSE data
- No handling of SSE comments (lines starting with `:`)
- No handling of multi-line `data:` fields
- Buffer can grow unbounded on malformed input

#### Problem: Event Types as String Constants

```gdscript
const EVT_WELCOME = "welcome"
const EVT_PEER_JOINED = "peer_joined"
const EVT_PEER_LEFT = "peer_left"
# ...
```

Should be an enum with bidirectional string mapping for type safety.

#### Problem: No Reconnection Logic

```gdscript
func _on_disconnected() -> void:
    _cleanup()
    disconnected.emit()  # That's it - connection is dead
```

If SSE stream drops (network hiccup, server restart), user must manually reconnect.

#### Problem: No Request Timeouts

```gdscript
var response = await http.request_completed  # Waits forever
```

HTTP requests have no timeout. A hung request blocks the entire flow.

#### Problem: No Request Deduplication

Multiple rapid calls to `broadcast_packet` create many parallel HTTP requests. No queuing or batching.

---

### 1.3 GDSyncWebPatch.gd — Fragile Monkey Patching

#### Problem: Runtime Reference Replacement

```gdscript
gdsync._local_server = web_local_server
```

**Issues:**
- GDSync may cache `_local_server` reference elsewhere
- No way to know if other code already grabbed old reference
- Update order matters (autoload order in project.godot)

#### Problem: No Verification

The patch doesn't verify it actually worked:

```gdscript
_patch_applied = true  # Just assumes success
```

Should verify `gdsync._local_server == web_local_server` and that the signaling connection works.

---

### 1.4 Cross-Cutting Issues

#### No Shared Protocol Definition

The Python server and GDScript client both define:
- API endpoints
- Request/response field names
- SSE event types
- Error codes

These are defined independently, leading to potential drift.

#### Inconsistent Error Handling

| Location | Error Handling |
|----------|----------------|
| `_process_incoming_packet_as_client` | Silent return on bad packet |
| `_http_post` | Returns empty dict, caller may not check |
| `_set_owner_request` | Silent return if `from.valid` is false |
| SSE parsing | Logs error but continues |

#### Verbose Debug Logging

```gdscript
logger.log_info("HOST sending RELIABLE to %d: bytes=%d, base64_len=%d, requests=%d" % [...])
```

Debug logging is mixed with production code. Should be conditional or use log levels.

---

## Part 2: Proposed Solutions

### 2.1 Architecture: Split LocalServerSignaling

**Current:**
```
LocalServerSignaling.gd (1091 lines - does everything)
```

**Proposed:**
```
scenes/Multiplayer/
├── LocalServerSignaling.gd          # Coordinator (~250 lines)
├── signaling/
│   ├── HostProcessor.gd             # Host packet handling (~150 lines)
│   ├── ClientProcessor.gd           # Client packet handling (~80 lines)
│   ├── MessageBuilder.gd            # Message construction (~60 lines)
│   └── LobbyDataHandler.gd          # Tag/data/player requests (~80 lines)
├── models/
│   └── SignalingModels.gd           # Data classes (~100 lines)
└── SignalingClient.gd               # HTTP+SSE (refactored, ~400 lines)
```

**Benefits:**
- Single responsibility per file
- Testable components
- Easier to understand and modify

---

### 2.2 Data Models: Type-Safe Structures

**New file: `scenes/Multiplayer/models/SignalingModels.gd`**

```gdscript
class_name SignalingModels

## Peer in the lobby (replaces inner Client class)
class Peer extends RefCounted:
    var id: int = -1
    var username: String = ""
    var is_valid: bool = false
    var player_data: Dictionary = {}

    var _reliable_queue: Array = []
    var _unreliable_queue: Array = []
    var _lobby_targets: Array = []  # Other peers

    func queue_reliable(request: Array) -> void:
        _reliable_queue.append(request)

    func queue_unreliable(request: Array) -> void:
        _unreliable_queue.append(request)

    func drain_reliable() -> Array:
        var result = _reliable_queue.duplicate()
        _reliable_queue.clear()
        return result

    func drain_unreliable() -> Array:
        var result = _unreliable_queue.duplicate()
        _unreliable_queue.clear()
        return result


## Lobby state container
class LobbyState extends RefCounted:
    var name: String = ""
    var code: String = ""
    var password: String = ""
    var is_public: bool = true
    var is_open: bool = true
    var player_limit: int = 0
    var tags: Dictionary = {}
    var data: Dictionary = {}
    var ownership_cache: Dictionary = {}  # node_path -> owner_id

    func clear() -> void:
        name = ""
        code = ""
        password = ""
        is_public = true
        is_open = true
        player_limit = 0
        tags.clear()
        data.clear()
        ownership_cache.clear()

    func to_dict(include_data: bool = false) -> Dictionary:
        var result = {
            "Name": name,
            "Code": code,
            "Public": is_public,
            "Open": is_open,
            "PlayerLimit": player_limit,
            "Tags": tags,
            "HasPassword": password != ""
        }
        if include_data:
            result["Data"] = data
        return result


## Standardized GDSync message wrapper
class Message extends RefCounted:
    var type: int
    var values: Array

    func _init(p_type: int, p_values: Array = []) -> void:
        type = p_type
        values = p_values

    func to_request() -> Array:
        var request = [ENUMS.REQUEST_TYPE.MESSAGE, type]
        request.append_array(values)
        return request

    # Factory methods for common messages
    static func set_owner(path: String, owner_id: int) -> Message:
        return Message.new(ENUMS.MESSAGE_TYPE.SET_GDSYNC_OWNER, [path, owner_id])

    static func client_joined(client_id: int) -> Message:
        return Message.new(ENUMS.MESSAGE_TYPE.CLIENT_JOINED, [client_id])

    static func client_left(client_id: int) -> Message:
        return Message.new(ENUMS.MESSAGE_TYPE.CLIENT_LEFT, [client_id])

    static func lobby_joined(code: String) -> Message:
        return Message.new(ENUMS.MESSAGE_TYPE.LOBBY_JOINED, [code])

    static func host_changed(host_id: int) -> Message:
        return Message.new(ENUMS.MESSAGE_TYPE.HOST_CHANGED, [host_id])

    static func kicked() -> Message:
        return Message.new(ENUMS.MESSAGE_TYPE.KICKED, [])
```

---

### 2.3 Message Building: Replace `_send_message`

**New file: `scenes/Multiplayer/signaling/MessageBuilder.gd`**

```gdscript
class_name MessageBuilder extends RefCounted

## Queue a message to a peer's reliable queue
static func send(peer: SignalingModels.Peer, message: SignalingModels.Message) -> void:
    if peer == null or not peer.is_valid:
        return
    peer.queue_reliable(message.to_request())


## Queue a message to multiple peers
static func broadcast(
    peers: Dictionary,  # id -> Peer
    message: SignalingModels.Message,
    exclude_id: int = -1
) -> void:
    for peer in peers.values():
        if peer.id != exclude_id:
            send(peer, message)


## Queue ownership message
static func send_ownership(peer: SignalingModels.Peer, path: String, owner_id: int) -> void:
    send(peer, SignalingModels.Message.set_owner(path, owner_id))


## Queue lobby data update to all peers
static func broadcast_lobby_data(
    peers: Dictionary,
    lobby: SignalingModels.LobbyState,
    change_type: int,
    changed_key: String
) -> void:
    var data_msg = SignalingModels.Message.new(
        ENUMS.MESSAGE_TYPE.LOBBY_DATA_RECEIVED,
        [lobby.to_dict(true)]
    )
    var change_msg = SignalingModels.Message.new(change_type, [changed_key])

    for peer in peers.values():
        send(peer, data_msg)
        send(peer, change_msg)
```

---

### 2.4 Generalized Data Handlers

**New file: `scenes/Multiplayer/signaling/LobbyDataHandler.gd`**

```gdscript
class_name LobbyDataHandler extends RefCounted

var _peers: Dictionary  # Reference to peer table
var _lobby: SignalingModels.LobbyState  # Reference to lobby state


func _init(peers: Dictionary, lobby: SignalingModels.LobbyState) -> void:
    _peers = peers
    _lobby = lobby


## Generic handler for set/erase operations on key-value storage
func handle_kv_operation(
    storage: Dictionary,
    request: Array,
    change_message_type: int,
    is_erase: bool = false
) -> void:
    var key = request[ENUMS.LOBBY_DATA.NAME]

    if is_erase:
        if not storage.has(key):
            return
        storage.erase(key)
    else:
        var value = request[ENUMS.LOBBY_DATA.VALUE]
        storage[key] = value

    MessageBuilder.broadcast_lobby_data(_peers, _lobby, change_message_type, key)


# Convenience methods
func set_lobby_tag(request: Array) -> void:
    handle_kv_operation(_lobby.tags, request, ENUMS.MESSAGE_TYPE.LOBBY_TAGS_CHANGED)

func erase_lobby_tag(request: Array) -> void:
    handle_kv_operation(_lobby.tags, request, ENUMS.MESSAGE_TYPE.LOBBY_TAGS_CHANGED, true)

func set_lobby_data(request: Array) -> void:
    handle_kv_operation(_lobby.data, request, ENUMS.MESSAGE_TYPE.LOBBY_DATA_CHANGED)

func erase_lobby_data(request: Array) -> void:
    handle_kv_operation(_lobby.data, request, ENUMS.MESSAGE_TYPE.LOBBY_DATA_CHANGED, true)
```

---

### 2.5 SignalingClient Improvements

#### Add SSE Event Enum

```gdscript
enum SSEEventType {
    UNKNOWN = -1,
    WELCOME = 0,
    PEER_JOINED = 1,
    PEER_LEFT = 2,
    LOBBY_CLOSED = 3,
    GAME_PACKET = 4,
    ERROR = 5,
    HEARTBEAT = 6
}

const _SSE_EVENT_MAP: Dictionary = {
    "welcome": SSEEventType.WELCOME,
    "peer_joined": SSEEventType.PEER_JOINED,
    "peer_left": SSEEventType.PEER_LEFT,
    "lobby_closed": SSEEventType.LOBBY_CLOSED,
    "game_packet": SSEEventType.GAME_PACKET,
    "error": SSEEventType.ERROR,
    "heartbeat": SSEEventType.HEARTBEAT
}

static func parse_event_type(event_str: String) -> SSEEventType:
    return _SSE_EVENT_MAP.get(event_str, SSEEventType.UNKNOWN)
```

#### Add Reconnection with Exponential Backoff

```gdscript
var _reconnect_attempts: int = 0
var _max_reconnect_attempts: int = 5
var _base_reconnect_delay: float = 1.0
var _should_reconnect: bool = true

func _on_sse_disconnected() -> void:
    if not _should_reconnect:
        _cleanup()
        disconnected.emit()
        return

    if _reconnect_attempts >= _max_reconnect_attempts:
        push_error("SignalingClient: Max reconnection attempts reached")
        _cleanup()
        disconnected.emit()
        return

    var delay = _base_reconnect_delay * pow(2, _reconnect_attempts)
    _reconnect_attempts += 1

    print("SignalingClient: Reconnecting in %.1f seconds (attempt %d/%d)" % [
        delay, _reconnect_attempts, _max_reconnect_attempts
    ])

    await get_tree().create_timer(delay).timeout

    if _should_reconnect:
        _start_sse_connection()

func _on_sse_connected() -> void:
    _reconnect_attempts = 0  # Reset on successful connection
```

#### Add Request Timeout

```gdscript
const DEFAULT_TIMEOUT_SEC: float = 10.0

func _http_post(path: String, body: Dictionary, timeout: float = DEFAULT_TIMEOUT_SEC) -> Dictionary:
    var http = HTTPRequest.new()
    http.timeout = timeout
    add_child(http)
    # ... rest of implementation
```

---

### 2.6 Shared Protocol Definition

**New file: `scenes/Multiplayer/SignalingProtocol.gd`**

```gdscript
class_name SignalingProtocol

## API Endpoints (must match Python server)
const API_CONNECT = "/api/lobby/connect"
const API_CREATE = "/api/lobby/create"
const API_JOIN = "/api/lobby/join"
const API_LEAVE = "/api/lobby/leave"
const API_BROADCAST = "/api/lobby/broadcast"
const API_LIST = "/api/lobby/list"
const API_EVENTS = "/api/lobby/events"

## Request/Response Keys
const KEY_PEER_ID = "peer_id"
const KEY_CLIENT_ID = "client_id"
const KEY_CODE = "code"
const KEY_NAME = "name"
const KEY_HOST_ID = "host_id"
const KEY_YOUR_ID = "your_id"
const KEY_PLAYERS = "players"
const KEY_PACKET = "packet"
const KEY_TARGET = "target"
const KEY_SUCCESS = "success"
const KEY_ERROR = "error"
const KEY_MESSAGE = "message"
const KEY_PUBLIC = "public"
const KEY_PLAYER_LIMIT = "player_limit"
const KEY_PLAYER = "player"

## Error Codes (must match Python server)
const ERR_LOBBY_NOT_FOUND = "LOBBY_NOT_FOUND"
const ERR_LOBBY_FULL = "LOBBY_FULL"
const ERR_LOBBY_CLOSED = "LOBBY_CLOSED"
const ERR_PEER_NOT_FOUND = "PEER_NOT_FOUND"
const ERR_NOT_IN_LOBBY = "NOT_IN_LOBBY"

## Request Builders
static func connect_request(client_id: int) -> Dictionary:
    return {KEY_CLIENT_ID: client_id}

static func create_request(
    peer_id: int,
    name: String,
    is_public: bool,
    player_limit: int,
    player_data: Dictionary
) -> Dictionary:
    return {
        KEY_PEER_ID: peer_id,
        KEY_NAME: name,
        KEY_PUBLIC: is_public,
        KEY_PLAYER_LIMIT: player_limit,
        KEY_PLAYER: player_data
    }

static func join_request(peer_id: int, code: String, player_data: Dictionary) -> Dictionary:
    return {
        KEY_PEER_ID: peer_id,
        KEY_CODE: code,
        KEY_PLAYER: player_data
    }

static func broadcast_request(peer_id: int, packet: String, target: int = -1) -> Dictionary:
    return {
        KEY_PEER_ID: peer_id,
        KEY_PACKET: packet,
        KEY_TARGET: target
    }

## Response Parsing
static func is_success(response: Dictionary) -> bool:
    return response.get(KEY_SUCCESS, false)

static func get_error(response: Dictionary) -> String:
    return response.get(KEY_ERROR, "UNKNOWN")

static func get_message(response: Dictionary) -> String:
    return response.get(KEY_MESSAGE, "Unknown error")
```

---

## Part 3: Implementation Plan

### Phase 1: Data Models (Low Risk)
1. Create `SignalingModels.gd` with Peer, LobbyState, Message classes
2. Create `SignalingProtocol.gd` with constants and helpers
3. No changes to existing code yet

### Phase 2: Extract Utilities (Low Risk)
1. Create `MessageBuilder.gd`
2. Create `LobbyDataHandler.gd`
3. Update LocalServerSignaling to use new utilities
4. Test multiplayer flows

### Phase 3: Split Processors (Medium Risk)
1. Extract `HostProcessor.gd` from LocalServerSignaling
2. Extract `ClientProcessor.gd` from LocalServerSignaling
3. Refactor LocalServerSignaling to coordinator role
4. Extensive testing

### Phase 4: SignalingClient Improvements (Medium Risk)
1. Add SSE event enum
2. Add reconnection logic
3. Add request timeouts
4. Test connection edge cases

### Phase 5: Cleanup (Low Risk)
1. Remove dead code
2. Standardize logging
3. Update documentation

---

## Part 4: Estimated Impact

### Line Count Comparison

| File | Current | After Refactor | Change |
|------|---------|----------------|--------|
| LocalServerSignaling.gd | 1091 | ~250 | -77% |
| SignalingClient.gd | 536 | ~400 | -25% |
| GDSyncWebPatch.gd | 67 | ~70 | +4% |
| **New Files:** | | | |
| SignalingModels.gd | - | ~100 | new |
| SignalingProtocol.gd | - | ~80 | new |
| MessageBuilder.gd | - | ~60 | new |
| LobbyDataHandler.gd | - | ~50 | new |
| HostProcessor.gd | - | ~150 | new |
| ClientProcessor.gd | - | ~80 | new |
| **Total** | **1694** | **~1240** | **-27%** |

### Quality Improvements

| Metric | Before | After |
|--------|--------|-------|
| Max file length | 1091 lines | ~250 lines |
| Type safety | Low (raw arrays) | Medium (typed classes) |
| Test coverage potential | Low | High |
| Code duplication | High | Low |
| Error handling | Inconsistent | Standardized |

---

## Appendix: Files to Create

```
scenes/Multiplayer/
├── LocalServerSignaling.gd          # MODIFY - reduce to coordinator
├── SignalingClient.gd               # MODIFY - add reconnection, timeouts
├── GDSyncWebPatch.gd                # KEEP - minor updates
├── SignalingProtocol.gd             # NEW - shared constants
├── models/
│   └── SignalingModels.gd           # NEW - Peer, LobbyState, Message
└── signaling/
    ├── HostProcessor.gd             # NEW - host-side logic
    ├── ClientProcessor.gd           # NEW - client-side logic
    ├── MessageBuilder.gd            # NEW - message construction
    └── LobbyDataHandler.gd          # NEW - tag/data handlers
```
