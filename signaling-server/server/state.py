# pyright: strict

"""
Global State Management for Signaling Server
"""

from __future__ import annotations

import random

from aiohttp import web

from .config import CONFIG
from .models import Lobby, Peer, Room


class State:
    """
    Centralized state manager for the signaling server.

    Manages:
    - Lobbies (new WebSocket-based lobby system)
    - Rooms (WebRTC signaling rooms for backward compatibility)
    - Peer connections
    """

    def __init__(self):
        # Lobby system state
        self.lobbies: dict[str, Lobby] = {}
        self.lobby_name_to_code: dict[str, str] = {}
        self.lobby_peers: dict[int, Peer] = {}
        self._next_peer_id: int = 1

        # WebRTC signaling state (existing/backward compatible)
        self.rooms: dict[str, Room] = {}
        self.ws_connections: dict[str, dict[int, web.WebSocketResponse]] = {}

    # =========================================================================
    # Peer ID Management
    # =========================================================================

    def get_next_peer_id(self) -> int:
        """Get the next global peer ID."""
        peer_id = self._next_peer_id
        self._next_peer_id += 1
        return peer_id

    # =========================================================================
    # Code Generation
    # =========================================================================

    def generate_code(self) -> str:
        """Generate a random room/lobby code."""
        chars = CONFIG.room_code_chars
        length = CONFIG.room_code_length
        return ''.join(random.choice(chars) for _ in range(length))

    def generate_unique_code(self) -> str:
        """Generate a unique code not already in use."""
        code = self.generate_code()
        while code in self.lobbies or code in self.rooms:
            code = self.generate_code()
        return code

    # =========================================================================
    # Lobby Management
    # =========================================================================

    def create_lobby(self, name: str, host_peer: Peer, public: bool = True, player_limit: int = 0) -> Lobby:
        """Create a new lobby."""
        code = self.generate_unique_code()
        lobby = Lobby.create(code, name, host_peer, public, player_limit)

        self.lobbies[code] = lobby
        self.lobby_name_to_code[name.lower()] = code

        # Also create a corresponding room for WebRTC signaling
        room = Room(
            code=code,
            channel=CONFIG.default_channel,
            next_peer_id=2,  # Host is 1, next client is 2
            created_at=lobby.created_at,
            lobby_name=name,
            public=public,
            player_limit=player_limit,
            player_count=1,
        )
        self.rooms[code] = room
        self.ws_connections[code] = {}

        return lobby

    def get_lobby(self, code: str) -> Lobby | None:
        """Get a lobby by code."""
        return self.lobbies.get(code.upper())

    def get_lobby_by_name(self, name: str) -> Lobby | None:
        """Get a lobby by name."""
        code = self.lobby_name_to_code.get(name.lower())
        return self.lobbies.get(code) if code else None

    def find_lobby(self, code_or_name: str) -> Lobby | None:
        """Find a lobby by code or name."""
        # Try as code first
        lobby = self.get_lobby(code_or_name)
        if lobby:
            return lobby
        # Try as name
        return self.get_lobby_by_name(code_or_name)

    def remove_lobby(self, code: str) -> Lobby | None:
        """Remove a lobby and clean up associated resources."""
        lobby = self.lobbies.pop(code, None)
        if lobby:
            # Clean up name mapping
            if lobby.name.lower() in self.lobby_name_to_code:
                del self.lobby_name_to_code[lobby.name.lower()]

            # Clear peer lobby references
            for peer in lobby.peers.values():
                peer.lobby_code = None

            # Clean up corresponding room
            self.rooms.pop(code, None)
            self.ws_connections.pop(code, None)

        return lobby

    def get_public_lobbies(self) -> list[Lobby]:
        """Get all public, open lobbies."""
        return [
            lobby for lobby in self.lobbies.values()
            if lobby.public and lobby.open
        ]

    # =========================================================================
    # Peer Management
    # =========================================================================

    def add_lobby_peer(self, peer: Peer) -> None:
        """Register a peer in the lobby system."""
        self.lobby_peers[peer.peer_id] = peer

    def remove_lobby_peer(self, peer_id: int) -> Peer | None:
        """Remove a peer from the lobby system."""
        return self.lobby_peers.pop(peer_id, None)

    def get_lobby_peer(self, peer_id: int) -> Peer | None:
        """Get a peer by ID."""
        return self.lobby_peers.get(peer_id)

    # =========================================================================
    # Room Management (WebRTC Signaling)
    # =========================================================================

    def create_room(self, channel: str = "default", lobby_name: str = "",
                    public: bool = True, player_limit: int = 0, is_debug: bool = False) -> Room:
        """Create a new WebRTC signaling room."""
        code = "TEST" if is_debug else self.generate_unique_code()

        room = Room(
            code=code,
            channel=channel,
            lobby_name=lobby_name,
            public=public,
            player_limit=player_limit,
        )
        self.rooms[code] = room
        self.ws_connections[code] = {}

        if lobby_name:
            self.lobby_name_to_code[lobby_name.lower()] = code

        return room

    def get_room(self, code: str) -> Room | None:
        """Get a room by code."""
        return self.rooms.get(code.upper())

    def find_room(self, code_or_name: str) -> Room | None:
        """Find a room by code or name."""
        # Try as code first
        room = self.get_room(code_or_name)
        if room:
            return room
        # Try as name
        code = self.lobby_name_to_code.get(code_or_name.lower())
        return self.rooms.get(code) if code else None

    def remove_room(self, code: str) -> Room | None:
        """Remove a room."""
        room = self.rooms.pop(code, None)
        if room and room.lobby_name:
            self.lobby_name_to_code.pop(room.lobby_name.lower(), None)
        self.ws_connections.pop(code, None)
        return room

    def get_public_rooms(self) -> list[Room]:
        """Get all public rooms."""
        return [room for room in self.rooms.values() if room.public]

    # =========================================================================
    # WebSocket Connection Management
    # =========================================================================

    def add_signaling_connection(self, code: str, peer_id: int, ws: web.WebSocketResponse) -> None:
        """Add a WebSocket connection for signaling."""
        if code not in self.ws_connections:
            self.ws_connections[code] = {}
        self.ws_connections[code][peer_id] = ws

    def remove_signaling_connection(self, code: str, peer_id: int) -> None:
        """Remove a WebSocket connection for signaling."""
        if code in self.ws_connections:
            self.ws_connections[code].pop(peer_id, None)

    def get_signaling_connections(self, code: str) -> dict[int, web.WebSocketResponse]:
        """Get all signaling connections for a room."""
        return self.ws_connections.get(code, {})

    def get_signaling_peer_ids(self, code: str, exclude: int | None = None) -> list[int]:
        """Get all peer IDs in a signaling room."""
        connections = self.ws_connections.get(code, {})
        if exclude is not None:
            return [pid for pid in connections if pid != exclude]
        return list(connections.keys())

    # =========================================================================
    # Cleanup
    # =========================================================================

    def clear_all(self) -> None:
        """Clear all state."""
        self.lobbies.clear()
        self.lobby_name_to_code.clear()
        self.lobby_peers.clear()
        self.rooms.clear()
        self.ws_connections.clear()
        self._next_peer_id = 1


# Global state instance
state = State()
