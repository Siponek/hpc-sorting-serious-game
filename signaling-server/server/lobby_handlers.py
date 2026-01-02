# pyright: strict

"""
Lobby Protocol Handlers

Handles messages for the lobby system (WebSocket or HTTP+SSE):
- create_lobby
- list_lobbies
- join_lobby
- leave_lobby
- ping
- broadcast (game packets)
"""

from __future__ import annotations

from collections.abc import Awaitable, Callable
from typing import Any

from .enums import ErrorCode, LobbyCloseReason, MessageType, ResponseType, SSEEventType
from .models import Lobby, Peer
from .state import state

# Type alias for handler functions
HandlerFunc = Callable[[Peer, dict[str, Any]], Awaitable[dict[str, Any]]]


# =============================================================================
# Utility Functions
# =============================================================================

async def send_to_peer(peer: Peer, message: dict[str, Any]) -> bool:
    """Send a JSON message to a peer via WebSocket or SSE queue."""
    msg_type = message.get("t", "unknown")

    # Try WebSocket first
    if peer.ws and not peer.ws.closed:
        try:
            await peer.ws.send_json(message)
            print(f"[LOBBY] Sent {msg_type} to peer {peer.peer_id} via WS")
            return True
        except Exception as e:
            print(f"[LOBBY] Error sending WS to peer {peer.peer_id}: {e}")
            return False

    # Try SSE queue
    if peer.sse_queue:
        try:
            await peer.sse_queue.put(message)
            print(f"[LOBBY] Queued {msg_type} for peer {peer.peer_id} via SSE (queue_size={peer.sse_queue.qsize()})")
            return True
        except Exception as e:
            print(f"[LOBBY] Error queueing SSE for peer {peer.peer_id}: {e}")
            return False

    print(f"[LOBBY] No transport for peer {peer.peer_id} (ws={peer.ws is not None}, sse={peer.sse_queue is not None})")
    return False


async def broadcast_to_lobby(
    lobby: Lobby,
    message: dict[str, Any],
    exclude_peer_id: int | None = None
) -> None:
    """Broadcast a message to all peers in a lobby, optionally excluding one."""
    msg_type = message.get("t", "unknown")
    peer_ids = list(lobby.peers.keys())
    print(f"[LOBBY] Broadcasting {msg_type} to lobby {lobby.code} (peers={peer_ids}, exclude={exclude_peer_id})")

    for peer_id, peer in lobby.peers.items():
        if peer_id != exclude_peer_id:
            await send_to_peer(peer, message)


async def close_lobby(
    lobby: Lobby,
    reason: LobbyCloseReason = LobbyCloseReason.CLOSED
) -> None:
    """Close a lobby and notify all peers."""
    code = lobby.code
    print(f"[LOBBY] Closing {code} '{lobby.name}' (reason: {reason})")

    # Notify all remaining peers
    for peer in list(lobby.peers.values()):
        await send_to_peer(peer, {
            "t": ResponseType.LOBBY_CLOSED,
            "code": code,
            "reason": str(reason),
        })
        peer.lobby_code = None

    # Remove from state
    state.remove_lobby(code)


# =============================================================================
# Protocol Handlers
# =============================================================================

async def handle_create_lobby(peer: Peer, data: dict[str, Any]) -> dict[str, Any]:
    """Handle create_lobby command."""
    name: str = data.get("name", f"Lobby-{state.generate_code()}")
    public: bool = data.get("public", True)
    player_limit: int = data.get("player_limit", 0)
    player_data: dict[str, Any] = data.get("player", {"name": f"Player {peer.peer_id}"})

    # Update peer's player data
    peer.player_data = player_data

    # Create lobby
    lobby = state.create_lobby(name, peer, public, player_limit)

    print(f"[LOBBY] Created: {lobby.code} '{name}' by peer {peer.peer_id}")

    return {
        "t": ResponseType.LOBBY_CREATED,
        "code": lobby.code,
        "name": name,
        "host_id": peer.peer_id,
        "your_id": peer.peer_id,
    }


async def handle_list_lobbies(peer: Peer, data: dict[str, Any]) -> dict[str, Any]:
    """Handle list_lobbies command."""
    lobbies = state.get_public_lobbies()
    items = [lobby.to_list_item() for lobby in lobbies]

    return {
        "t": ResponseType.LOBBY_LIST,
        "items": items,
    }


async def handle_join_lobby(peer: Peer, data: dict[str, Any]) -> dict[str, Any]:
    """Handle join_lobby command."""
    code_or_name: str = data.get("code", "")
    player_data: dict[str, Any] = data.get("player", {"name": f"Player {peer.peer_id}"})

    # Find lobby
    lobby = state.find_lobby(code_or_name)
    if not lobby:
        return {
            "t": ResponseType.ERROR,
            "code": ErrorCode.LOBBY_NOT_FOUND,
            "message": "Lobby not found",
        }

    if not lobby.open:
        return {
            "t": ResponseType.ERROR,
            "code": ErrorCode.LOBBY_CLOSED,
            "message": "Lobby is closed",
        }

    if lobby.is_full():
        return {
            "t": ResponseType.ERROR,
            "code": ErrorCode.LOBBY_FULL,
            "message": "Lobby is full",
        }

    # Check if already in a lobby
    if peer.lobby_code:
        return {
            "t": ResponseType.ERROR,
            "code": ErrorCode.ALREADY_IN_LOBBY,
            "message": "You are already in a lobby",
        }

    # Update peer's player data
    peer.player_data = player_data

    # Add peer to lobby
    lobby.add_peer(peer)

    # Update room player count for backward compatibility
    room = state.get_room(lobby.code)
    if room:
        room.player_count = len(lobby.peers)

    print(f"[LOBBY] Peer {peer.peer_id} joined {lobby.code} '{lobby.name}' (now {len(lobby.peers)} players)")

    # Notify other peers in lobby (especially host)
    await broadcast_to_lobby(lobby, {
        "t": ResponseType.PEER_JOINED,
        "id": peer.peer_id,
        "player": peer.player_data,
    }, exclude_peer_id=peer.peer_id)

    # Send lobby_joined to the joining peer
    return {
        "t": ResponseType.LOBBY_JOINED,
        "code": lobby.code,
        "name": lobby.name,
        "host_id": lobby.host_id,
        "your_id": peer.peer_id,
        "players": lobby.get_players_list(),
    }


async def handle_leave_lobby(peer: Peer, data: dict[str, Any]) -> dict[str, Any]:
    """Handle leave_lobby command."""
    if not peer.lobby_code:
        return {
            "t": ResponseType.ERROR,
            "code": ErrorCode.NOT_IN_LOBBY,
            "message": "You are not in a lobby",
        }

    lobby = state.get_lobby(peer.lobby_code)
    if not lobby:
        peer.lobby_code = None
        return {
            "t": ResponseType.ERROR,
            "code": ErrorCode.LOBBY_NOT_FOUND,
            "message": "Lobby no longer exists",
        }

    was_host = lobby.is_host(peer.peer_id)
    lobby_code = lobby.code
    lobby.remove_peer(peer.peer_id)

    print(f"[LOBBY] Peer {peer.peer_id} left {lobby_code} (was_host={was_host})")

    if was_host:
        # Host left - close the lobby
        await close_lobby(lobby, LobbyCloseReason.HOST_LEFT)
    else:
        # Regular peer left - notify others
        await broadcast_to_lobby(lobby, {
            "t": ResponseType.PEER_LEFT,
            "id": peer.peer_id,
        })

        # Update room player count
        room = state.get_room(lobby_code)
        if room:
            room.player_count = len(lobby.peers)

    return {"t": ResponseType.LOBBY_LEFT, "code": lobby_code}


async def handle_ping(peer: Peer, data: dict[str, Any]) -> dict[str, Any]:
    """Handle ping/heartbeat."""
    return {"t": ResponseType.PONG}


# =============================================================================
# Disconnect Handler
# =============================================================================

async def handle_peer_disconnect(peer: Peer) -> None:
    """Handle when a peer's WebSocket disconnects."""
    if peer.lobby_code:
        lobby = state.get_lobby(peer.lobby_code)
        if lobby:
            was_host = lobby.is_host(peer.peer_id)
            lobby.remove_peer(peer.peer_id)

            print(f"[LOBBY] Peer {peer.peer_id} disconnected from {lobby.code} (was_host={was_host})")

            if was_host:
                # Host disconnected - close lobby
                await close_lobby(lobby, LobbyCloseReason.HOST_DISCONNECTED)
            else:
                # Regular peer disconnected - notify others
                await broadcast_to_lobby(lobby, {
                    "t": ResponseType.PEER_LEFT,
                    "id": peer.peer_id,
                })

                # Update room player count
                room = state.get_room(lobby.code)
                if room:
                    room.player_count = len(lobby.peers)

    # Remove from global peers
    state.remove_lobby_peer(peer.peer_id)


# =============================================================================
# Message Router
# =============================================================================

# Map of message types to handlers
MESSAGE_HANDLERS: dict[str, HandlerFunc] = {
    MessageType.CREATE_LOBBY: handle_create_lobby,
    MessageType.LIST_LOBBIES: handle_list_lobbies,
    MessageType.JOIN_LOBBY: handle_join_lobby,
    MessageType.LEAVE_LOBBY: handle_leave_lobby,
    MessageType.PING: handle_ping,
}


async def route_message(peer: Peer, data: dict[str, Any]) -> dict[str, Any]:
    """Route a message to the appropriate handler."""
    msg_type = data.get("t", "unknown")

    handler = MESSAGE_HANDLERS.get(msg_type)
    if handler:
        return await handler(peer, data)

    return {
        "t": ResponseType.ERROR,
        "code": ErrorCode.UNKNOWN_COMMAND,
        "message": f"Unknown command: {msg_type}",
    }
