"""
Data Models for Signaling Server
"""

from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional, TYPE_CHECKING

if TYPE_CHECKING:
    from aiohttp import web


@dataclass
class Peer:
    """Represents a connected peer/player in the lobby system."""
    peer_id: int
    ws: web.WebSocketResponse
    player_data: dict = field(default_factory=lambda: {})
    lobby_code: Optional[str] = None

    def __post_init__(self):
        if not self.player_data:
            self.player_data = {"name": f"Player {self.peer_id}"}

    def to_dict(self) -> dict:
        """Convert to dictionary for JSON serialization."""
        return {
            "id": self.peer_id,
            "player": self.player_data
        }


@dataclass
class Lobby:
    """Represents a game lobby."""
    code: str
    name: str
    host_id: int
    public: bool = True
    player_limit: int = 0
    open: bool = True
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    peers: dict[int, Peer] = field(default_factory=dict)

    @classmethod
    def create(cls, code: str, name: str, host_peer: Peer, public: bool = True, player_limit: int = 0) -> Lobby:
        """Factory method to create a lobby with a host peer."""
        lobby = cls(
            code=code,
            name=name,
            host_id=host_peer.peer_id,
            public=public,
            player_limit=player_limit,
        )
        lobby.add_peer(host_peer)
        return lobby

    def add_peer(self, peer: Peer) -> None:
        """Add a peer to the lobby."""
        self.peers[peer.peer_id] = peer
        peer.lobby_code = self.code

    def remove_peer(self, peer_id: int) -> Optional[Peer]:
        """Remove a peer from the lobby."""
        peer = self.peers.pop(peer_id, None)
        if peer:
            peer.lobby_code = None
        return peer

    def get_players_list(self) -> list[dict]:
        """Get list of all players in the lobby."""
        return [p.to_dict() for p in self.peers.values()]

    def is_host(self, peer_id: int) -> bool:
        """Check if a peer is the host."""
        return peer_id == self.host_id

    def is_full(self) -> bool:
        """Check if the lobby is full."""
        return self.player_limit > 0 and len(self.peers) >= self.player_limit

    def to_dict(self) -> dict:
        """Convert to dictionary for JSON serialization."""
        return {
            "code": self.code,
            "name": self.name,
            "host_id": self.host_id,
            "public": self.public,
            "player_count": len(self.peers),
            "player_limit": self.player_limit,
            "open": self.open,
        }

    def to_list_item(self) -> dict:
        """Format for lobby list response."""
        return {
            "code": self.code,
            "name": self.name,
            "players": len(self.peers),
            "public": self.public,
            "player_limit": self.player_limit,
        }

    def to_gdsync_format(self) -> dict:
        """Format for GDSync/HTTP lobby list compatibility."""
        return {
            "Name": self.name,
            "Code": self.code,
            "PlayerCount": len(self.peers),
            "PlayerLimit": self.player_limit,
            "Public": self.public,
            "Open": self.open,
            "HasPassword": False,
        }


@dataclass
class Room:
    """Represents a WebRTC signaling room (for backward compatibility)."""
    code: str
    channel: str
    next_peer_id: int = 1
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    lobby_name: str = ""
    public: bool = True
    player_limit: int = 0
    player_count: int = 1

    def to_dict(self) -> dict:
        """Convert to dictionary for JSON serialization."""
        return {
            "code": self.code,
            "channel": self.channel,
            "next_peer_id": self.next_peer_id,
            "created_at": self.created_at,
            "lobby_name": self.lobby_name,
            "public": self.public,
            "player_limit": self.player_limit,
            "player_count": self.player_count,
        }
