"""
Lobby Protocol Handlers

Handles WebSocket messages for the lobby system:
- create_lobby
- list_lobbies
- join_lobby
- leave_lobby
- ping
"""

from __future__ import annotations
from typing import TYPE_CHECKING

from .models import Peer, Lobby
from .state import state

if TYPE_CHECKING:
    pass


# =============================================================================
# Utility Functions
# =============================================================================

async def send_to_peer(peer: Peer, message: dict) -> bool:
    """Send a JSON message to a peer's WebSocket."""
    if peer.ws and not peer.ws.closed:
        try:
            await peer.ws.send_json(message)
            return True
        except Exception as e:
            print(f"[LOBBY] Error sending to peer {peer.peer_id}: {e}")
    return False


async def broadcast_to_lobby(lobby: Lobby, message: dict, exclude_peer_id: int = None) -> None:
    """Broadcast a message to all peers in a lobby, optionally excluding one."""
    for peer_id, peer in lobby.peers.items():
        if peer_id != exclude_peer_id:
            await send_to_peer(peer, message)


async def close_lobby(lobby: Lobby, reason: str = "closed") -> None:
    """Close a lobby and notify all peers."""
    code = lobby.code
    print(f"[LOBBY] Closing {code} '{lobby.name}' (reason: {reason})")

    # Notify all remaining peers
    for peer in list(lobby.peers.values()):
        await send_to_peer(peer, {
            "t": "lobby_closed",
            "code": code,
            "reason": reason,
        })
        peer.lobby_code = None

    # Remove from state
    state.remove_lobby(code)


# =============================================================================
# Protocol Handlers
# =============================================================================

async def handle_create_lobby(peer: Peer, data: dict) -> dict:
    """Handle create_lobby command."""
    name = data.get("name", f"Lobby-{state.generate_code()}")
    public = data.get("public", True)
    player_limit = data.get("player_limit", 0)
    player_data = data.get("player", {"name": f"Player {peer.peer_id}"})

    # Update peer's player data
    peer.player_data = player_data

    # Create lobby
    lobby = state.create_lobby(name, peer, public, player_limit)

    print(f"[LOBBY] Created: {lobby.code} '{name}' by peer {peer.peer_id}")

    return {
        "t": "lobby_created",
        "code": lobby.code,
        "name": name,
        "host_id": peer.peer_id,
        "your_id": peer.peer_id,
    }


async def handle_list_lobbies(peer: Peer, data: dict) -> dict:
    """Handle list_lobbies command."""
    lobbies = state.get_public_lobbies()
    items = [lobby.to_list_item() for lobby in lobbies]

    return {
        "t": "lobby_list",
        "items": items,
    }


async def handle_join_lobby(peer: Peer, data: dict) -> dict:
    """Handle join_lobby command."""
    code_or_name = data.get("code", "")
    player_data = data.get("player", {"name": f"Player {peer.peer_id}"})

    # Find lobby
    lobby = state.find_lobby(code_or_name)
    if not lobby:
        return {
            "t": "error",
            "code": "LOBBY_NOT_FOUND",
            "message": "Lobby not found",
        }

    if not lobby.open:
        return {
            "t": "error",
            "code": "LOBBY_CLOSED",
            "message": "Lobby is closed",
        }

    if lobby.is_full():
        return {
            "t": "error",
            "code": "LOBBY_FULL",
            "message": "Lobby is full",
        }

    # Check if already in a lobby
    if peer.lobby_code:
        return {
            "t": "error",
            "code": "ALREADY_IN_LOBBY",
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
        "t": "peer_joined",
        "id": peer.peer_id,
        "player": peer.player_data,
    }, exclude_peer_id=peer.peer_id)

    # Send lobby_joined to the joining peer
    return {
        "t": "lobby_joined",
        "code": lobby.code,
        "name": lobby.name,
        "host_id": lobby.host_id,
        "your_id": peer.peer_id,
        "players": lobby.get_players_list(),
    }


async def handle_leave_lobby(peer: Peer, data: dict) -> dict:
    """Handle leave_lobby command."""
    if not peer.lobby_code:
        return {
            "t": "error",
            "code": "NOT_IN_LOBBY",
            "message": "You are not in a lobby",
        }

    lobby = state.get_lobby(peer.lobby_code)
    if not lobby:
        peer.lobby_code = None
        return {
            "t": "error",
            "code": "LOBBY_NOT_FOUND",
            "message": "Lobby no longer exists",
        }

    was_host = lobby.is_host(peer.peer_id)
    lobby_code = lobby.code
    lobby.remove_peer(peer.peer_id)

    print(f"[LOBBY] Peer {peer.peer_id} left {lobby_code} (was_host={was_host})")

    if was_host:
        # Host left - close the lobby
        await close_lobby(lobby, "host_left")
    else:
        # Regular peer left - notify others
        await broadcast_to_lobby(lobby, {
            "t": "peer_left",
            "id": peer.peer_id,
        })

        # Update room player count
        room = state.get_room(lobby_code)
        if room:
            room.player_count = len(lobby.peers)

    return {"t": "lobby_left", "code": lobby_code}


async def handle_ping(peer: Peer, data: dict) -> dict:
    """Handle ping/heartbeat."""
    return {"t": "pong"}


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
                await close_lobby(lobby, "host_disconnected")
            else:
                # Regular peer disconnected - notify others
                await broadcast_to_lobby(lobby, {
                    "t": "peer_left",
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
MESSAGE_HANDLERS = {
    "create_lobby": handle_create_lobby,
    "list_lobbies": handle_list_lobbies,
    "join_lobby": handle_join_lobby,
    "leave_lobby": handle_leave_lobby,
    "ping": handle_ping,
}


async def route_message(peer: Peer, data: dict) -> dict:
    """Route a message to the appropriate handler."""
    msg_type = data.get("t", "unknown")

    handler = MESSAGE_HANDLERS.get(msg_type)
    if handler:
        return await handler(peer, data)

    return {
        "t": "error",
        "code": "UNKNOWN_COMMAND",
        "message": f"Unknown command: {msg_type}",
    }
