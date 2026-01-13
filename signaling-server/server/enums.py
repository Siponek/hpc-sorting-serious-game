# pyright: strict

"""
Enums for Signaling Server

StrEnum-based enums for type-safe message handling.
"""

from enum import StrEnum


class MessageType(StrEnum):
    """Client -> Server message types."""
    CREATE_LOBBY = "create_lobby"
    LIST_LOBBIES = "list_lobbies"
    JOIN_LOBBY = "join_lobby"
    LEAVE_LOBBY = "leave_lobby"
    PING = "ping"


class ResponseType(StrEnum):
    """Server -> Client response/event types."""
    # Responses to client commands
    WELCOME = "welcome"
    LOBBY_CREATED = "lobby_created"
    LOBBY_LIST = "lobby_list"
    LOBBY_JOINED = "lobby_joined"
    LOBBY_LEFT = "lobby_left"
    PONG = "pong"
    ERROR = "error"

    # Server-pushed events
    PEER_JOINED = "peer_joined"
    PEER_LEFT = "peer_left"
    LOBBY_CLOSED = "lobby_closed"
    SERVER_SHUTDOWN = "server_shutdown"


class ErrorCode(StrEnum):
    """Error codes for error responses."""
    LOBBY_NOT_FOUND = "LOBBY_NOT_FOUND"
    LOBBY_CLOSED = "LOBBY_CLOSED"
    LOBBY_FULL = "LOBBY_FULL"
    ALREADY_IN_LOBBY = "ALREADY_IN_LOBBY"
    NOT_IN_LOBBY = "NOT_IN_LOBBY"
    UNKNOWN_COMMAND = "UNKNOWN_COMMAND"
    INVALID_JSON = "INVALID_JSON"
    ROOM_NOT_FOUND = "ROOM_NOT_FOUND"
    PEER_NOT_FOUND = "PEER_NOT_FOUND"
    PEER_ID_IN_USE = "PEER_ID_IN_USE"


class SignalingDataType(StrEnum):
    """WebRTC signaling message types."""
    INITIALIZE = "initialize"
    NEW_CONNECTION = "new_connection"
    PEER_DISCONNECTED = "peer_disconnected"
    READY = "ready"
    OFFER = "offer"
    ANSWER = "answer"
    ICE = "ice"
    SERVER_SHUTDOWN = "server_shutdown"


class LobbyCloseReason(StrEnum):
    """Reasons for lobby closure."""
    HOST_LEFT = "host_left"
    HOST_DISCONNECTED = "host_disconnected"
    HOST_CLOSED = "host_closed"
    CLOSED = "closed"


class SSEEventType(StrEnum):
    """SSE event types (for event: field in SSE stream)."""
    WELCOME = "welcome"
    PEER_JOINED = "peer_joined"
    PEER_LEFT = "peer_left"
    LOBBY_JOINED = "lobby_joined"
    LOBBY_CLOSED = "lobby_closed"
    GAME_PACKET = "game_packet"
    ERROR = "error"
    HEARTBEAT = "heartbeat"
    SERVER_SHUTDOWN = "server_shutdown"
