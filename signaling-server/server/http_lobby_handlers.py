# pyright: strict

"""
HTTP + SSE Lobby Handlers

REST API endpoints for lobby operations with SSE for real-time events.
This replaces WebSocket-based lobby handling for browser compatibility.

Endpoints:
- POST /api/lobby/connect       - Connect and get peer ID
- POST /api/lobby/create        - Create a new lobby
- POST /api/lobby/join          - Join an existing lobby
- POST /api/lobby/leave         - Leave current lobby
- GET  /api/lobby/list          - List public lobbies
- POST /api/lobby/broadcast     - Broadcast game packet to lobby
- GET  /api/lobby/events        - SSE stream for receiving events
"""

from __future__ import annotations

import asyncio
import json
from typing import Any

from aiohttp import web

from .config import CONFIG
from .enums import ErrorCode, LobbyCloseReason, ResponseType, SSEEventType
from .lobby_handlers import broadcast_to_lobby, close_lobby, send_to_peer
from .models import Lobby, Peer
from .state import state


# =============================================================================
# Helper Functions
# =============================================================================


def json_response(data: dict[str, Any], status: int = 200) -> web.Response:
    """Create a JSON response with proper content type."""
    return web.json_response(data, status=status)


def error_response(code: str, message: str, status: int = 400) -> web.Response:
    """Create an error JSON response."""
    return json_response(
        {
            "success": False,
            "error": code,
            "message": message,
        },
        status=status,
    )


# =============================================================================
# Connection Management
# =============================================================================


async def handle_connect(request: web.Request) -> web.Response:
    """
    POST /api/lobby/connect

    Connect to the server. Client can provide their own ID (from GDSync)
    or let the server generate one.

    Body (optional):
    {
        "client_id": 12345  // If provided, server uses this ID
    }

    Response:
    {
        "success": true,
        "peer_id": 12345
    }
    """
    try:
        body: dict[str, Any] = await request.json()
    except Exception:
        body = {}

    # Use client-provided ID if given, otherwise generate one
    client_id: int | None = body.get("client_id")
    if client_id is not None and client_id > 0:
        peer_id = client_id
        # Check for collision with existing peer
        if peer_id in state.lobby_peers:
            return error_response(
                ErrorCode.PEER_ID_IN_USE, f"Peer ID {peer_id} is already in use", status=409
            )
    else:
        peer_id = state.get_next_peer_id()

    # Create peer with SSE queue (no WebSocket)
    sse_queue: asyncio.Queue[dict[str, Any]] = asyncio.Queue()
    peer = Peer(peer_id=peer_id, sse_queue=sse_queue)
    state.add_lobby_peer(peer)

    print(
        f"[HTTP] Peer {peer_id} connected (client_provided={client_id is not None}, total: {len(state.lobby_peers)})"
    )

    return json_response(
        {
            "success": True,
            "peer_id": peer_id,
        }
    )


async def handle_disconnect(request: web.Request) -> web.Response:
    """
    POST /api/lobby/disconnect

    Disconnect from the server and clean up.

    Body:
    {
        "peer_id": 1
    }
    """
    try:
        body: dict[str, Any] = await request.json()
    except Exception:
        return error_response(ErrorCode.INVALID_JSON, "Invalid JSON body")

    peer_id: int = body.get("peer_id", -1)
    peer = state.get_lobby_peer(peer_id)

    if not peer:
        return error_response(ErrorCode.LOBBY_NOT_FOUND, "Peer not found", 404)

    # Handle lobby leave if in one
    if peer.lobby_code:
        lobby = state.get_lobby(peer.lobby_code)
        if lobby:
            was_host = lobby.is_host(peer_id)
            lobby.remove_peer(peer_id)

            if was_host:
                await close_lobby(lobby, LobbyCloseReason.HOST_DISCONNECTED)
            else:
                await broadcast_to_lobby(
                    lobby,
                    {
                        "t": ResponseType.PEER_LEFT,
                        "id": peer_id,
                    },
                )

    state.remove_lobby_peer(peer_id)
    print(f"[HTTP] Peer {peer_id} disconnected (remaining: {len(state.lobby_peers)})")

    return json_response({"success": True})


# =============================================================================
# Lobby Operations
# =============================================================================


async def handle_create_lobby(request: web.Request) -> web.Response:
    """
    POST /api/lobby/create

    Create a new lobby.

    Body:
    {
        "peer_id": 1,
        "name": "My Lobby",
        "public": true,
        "player_limit": 4,
        "player": {"name": "HostPlayer"}
    }

    Response:
    {
        "success": true,
        "code": "ABCD",
        "name": "My Lobby",
        "host_id": 1,
        "your_id": 1
    }
    """
    try:
        body: dict[str, Any] = await request.json()
    except Exception:
        return error_response(ErrorCode.INVALID_JSON, "Invalid JSON body")

    peer_id: int = body.get("peer_id", -1)
    peer = state.get_lobby_peer(peer_id)

    if not peer:
        return error_response(
            ErrorCode.LOBBY_NOT_FOUND, "Peer not found. Call /api/lobby/connect first.", 404
        )

    if peer.lobby_code:
        return error_response(ErrorCode.ALREADY_IN_LOBBY, "Already in a lobby")

    name: str = body.get("name", f"Lobby-{state.generate_code()}")
    public: bool = body.get("public", True)
    player_limit: int = body.get("player_limit", 0)
    player_data: dict[str, Any] = body.get("player", {"name": f"Player {peer_id}"})

    peer.player_data = player_data

    lobby = state.create_lobby(name, peer, public, player_limit)

    print(f"[HTTP] Lobby created: {lobby.code} '{name}' by peer {peer_id}")

    return json_response(
        {
            "success": True,
            "t": ResponseType.LOBBY_CREATED,
            "code": lobby.code,
            "name": name,
            "host_id": peer_id,
            "your_id": peer_id,
        }
    )


async def handle_join_lobby(request: web.Request) -> web.Response:
    """
    POST /api/lobby/join

    Join an existing lobby by code or name.

    Body:
    {
        "peer_id": 2,
        "code": "ABCD",
        "player": {"name": "JoiningPlayer"}
    }

    Response:
    {
        "success": true,
        "code": "ABCD",
        "name": "My Lobby",
        "host_id": 1,
        "your_id": 2,
        "players": [{"id": 1, "player": {"name": "Host"}}, ...]
    }
    """
    try:
        body: dict[str, Any] = await request.json()
    except Exception:
        return error_response(ErrorCode.INVALID_JSON, "Invalid JSON body")

    peer_id: int = body.get("peer_id", -1)
    peer = state.get_lobby_peer(peer_id)

    if not peer:
        return error_response(
            ErrorCode.LOBBY_NOT_FOUND, "Peer not found. Call /api/lobby/connect first.", 404
        )

    code_or_name: str = body.get("code", "")
    player_data: dict[str, Any] = body.get("player", {"name": f"Player {peer_id}"})

    lobby = state.find_lobby(code_or_name)
    if not lobby:
        return error_response(ErrorCode.LOBBY_NOT_FOUND, "Lobby not found", 404)

    # Check if peer is already in THIS lobby (host joining their own lobby)
    # This is allowed - just return success with current state
    if peer.lobby_code == lobby.code:
        print(f"[HTTP] Peer {peer_id} re-joining their own lobby {lobby.code} (host join)")
        return json_response(
            {
                "success": True,
                "t": ResponseType.LOBBY_JOINED,
                "code": lobby.code,
                "name": lobby.name,
                "host_id": lobby.host_id,
                "your_id": peer_id,
                "players": lobby.get_players_list(),
            }
        )

    # Check if peer is in a DIFFERENT lobby
    if peer.lobby_code:
        return error_response(ErrorCode.ALREADY_IN_LOBBY, "Already in a lobby")

    if not lobby.open:
        return error_response(ErrorCode.LOBBY_CLOSED, "Lobby is closed")

    if lobby.is_full():
        return error_response("LOBBY_FULL", "Lobby is full")

    peer.player_data = player_data
    lobby.add_peer(peer)

    # Update room player count for backward compatibility
    room = state.get_room(lobby.code)
    if room:
        room.player_count = len(lobby.peers)

    print(
        f"[HTTP] Peer {peer_id} joined {lobby.code} '{lobby.name}' (now {len(lobby.peers)} players)"
    )

    # Notify other peers (host and others) about new player
    await broadcast_to_lobby(
        lobby,
        {
            "t": ResponseType.PEER_JOINED,
            "id": peer_id,
            "player": peer.player_data,
        },
        exclude_peer_id=peer_id,
    )

    return json_response(
        {
            "success": True,
            "t": ResponseType.LOBBY_JOINED,
            "code": lobby.code,
            "name": lobby.name,
            "host_id": lobby.host_id,
            "your_id": peer_id,
            "players": lobby.get_players_list(),
        }
    )


async def handle_leave_lobby(request: web.Request) -> web.Response:
    """
    POST /api/lobby/leave

    Leave the current lobby.

    Body:
    {
        "peer_id": 2
    }

    Response:
    {
        "success": true,
        "code": "ABCD"
    }
    """
    try:
        body: dict[str, Any] = await request.json()
    except Exception:
        return error_response(ErrorCode.INVALID_JSON, "Invalid JSON body")

    peer_id: int = body.get("peer_id", -1)
    peer = state.get_lobby_peer(peer_id)

    if not peer:
        return error_response(ErrorCode.LOBBY_NOT_FOUND, "Peer not found", 404)

    if not peer.lobby_code:
        return error_response(ErrorCode.NOT_IN_LOBBY, "Not in a lobby")

    lobby = state.get_lobby(peer.lobby_code)
    if not lobby:
        peer.lobby_code = None
        return error_response(ErrorCode.LOBBY_NOT_FOUND, "Lobby no longer exists")

    was_host = lobby.is_host(peer_id)
    lobby_code = lobby.code
    lobby.remove_peer(peer_id)

    print(f"[HTTP] Peer {peer_id} left {lobby_code} (was_host={was_host})")

    if was_host:
        await close_lobby(lobby, LobbyCloseReason.HOST_LEFT)
    else:
        await broadcast_to_lobby(
            lobby,
            {
                "t": ResponseType.PEER_LEFT,
                "id": peer_id,
            },
        )

        room = state.get_room(lobby_code)
        if room:
            room.player_count = len(lobby.peers)

    return json_response(
        {
            "success": True,
            "t": ResponseType.LOBBY_LEFT,
            "code": lobby_code,
        }
    )


async def handle_list_lobbies(request: web.Request) -> web.Response:
    """
    GET /api/lobby/list

    List all public lobbies.

    Response:
    {
        "success": true,
        "lobbies": [
            {"code": "ABCD", "name": "My Lobby", "players": 2, "player_limit": 4, "public": true}
        ]
    }
    """
    lobbies = state.get_public_lobbies()
    items = [lobby.to_list_item() for lobby in lobbies]

    return json_response(
        {
            "success": True,
            "lobbies": items,
        }
    )


# =============================================================================
# Game Packet Broadcasting
# =============================================================================


async def handle_broadcast(request: web.Request) -> web.Response:
    """
    POST /api/lobby/broadcast

    Broadcast a game packet to all peers in the lobby.
    Used for GDSync.call_func and other game operations.

    Body:
    {
        "peer_id": 1,
        "packet": "base64_encoded_data",
        "target": -1  // -1 = all, or specific peer_id
    }

    Response:
    {
        "success": true,
        "delivered_to": [2, 3]
    }
    """
    try:
        body: dict[str, Any] = await request.json()
    except Exception:
        return error_response(ErrorCode.INVALID_JSON, "Invalid JSON body")

    peer_id: int = body.get("peer_id", -1)
    peer = state.get_lobby_peer(peer_id)

    if not peer:
        return error_response(ErrorCode.LOBBY_NOT_FOUND, "Peer not found", 404)

    if not peer.lobby_code:
        return error_response(ErrorCode.NOT_IN_LOBBY, "Not in a lobby")

    lobby = state.get_lobby(peer.lobby_code)
    if not lobby:
        return error_response(ErrorCode.LOBBY_NOT_FOUND, "Lobby not found")

    packet_data: str = body.get("packet", "")
    target_peer: int = body.get("target", -1)  # -1 = broadcast to all

    delivered_to: list[int] = []

    message = {
        "t": SSEEventType.GAME_PACKET,
        "from": peer_id,
        "packet": packet_data,
    }

    if target_peer == -1:
        # Broadcast to all except sender
        for target_id, target in lobby.peers.items():
            if target_id != peer_id:
                success = await send_to_peer(target, message)
                if success:
                    delivered_to.append(target_id)
    else:
        # Send to specific peer
        target = lobby.peers.get(target_peer)
        if target:
            success = await send_to_peer(target, message)
            if success:
                delivered_to.append(target_peer)

    return json_response(
        {
            "success": True,
            "delivered_to": delivered_to,
        }
    )


# =============================================================================
# SSE Event Stream
# =============================================================================


async def handle_events(request: web.Request) -> web.StreamResponse:
    """
    GET /api/lobby/events?peer_id=1

    Server-Sent Events stream for receiving real-time updates.

    Events sent:
    - welcome: Connection confirmed
    - peer_joined: A peer joined the lobby
    - peer_left: A peer left the lobby
    - lobby_closed: The lobby was closed
    - game_packet: Game data from another peer
    - heartbeat: Keep-alive (every 15s)
    """
    peer_id_str = request.query.get("peer_id", "")

    if not peer_id_str:
        return web.Response(status=400, text="Missing peer_id parameter")

    try:
        peer_id = int(peer_id_str)
    except ValueError:
        return web.Response(status=400, text="Invalid peer_id")

    peer = state.get_lobby_peer(peer_id)
    if not peer:
        return web.Response(status=404, text="Peer not found")

    if not peer.sse_queue:
        return web.Response(status=400, text="Peer not configured for SSE")

    # Create SSE response with CORS headers
    # Note: Must include CORS headers here since middleware can't modify StreamResponse after prepare()
    response = web.StreamResponse(
        status=200,
        reason="OK",
        headers={
            "Content-Type": "text/event-stream",
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",  # Disable nginx buffering
            "Access-Control-Allow-Origin": CONFIG.cors_origins,
            "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type, Accept, Cache-Control",
        },
    )
    await response.prepare(request)

    print(f"[SSE] Peer {peer_id} connected to event stream")

    # Send welcome event
    welcome_data = json.dumps({"peer_id": peer_id})
    await response.write(f"event: {SSEEventType.WELCOME}\ndata: {welcome_data}\n\n".encode())

    # Heartbeat interval (seconds)
    heartbeat_interval = 15.0

    try:
        while True:
            try:
                # Wait for message with timeout for heartbeat
                message = await asyncio.wait_for(peer.sse_queue.get(), timeout=heartbeat_interval)

                # Determine event type from message
                event_type = message.get("t", "message")
                data = json.dumps(message)

                await response.write(f"event: {event_type}\ndata: {data}\n\n".encode())

            except asyncio.TimeoutError:
                # Send heartbeat
                heartbeat_data = json.dumps({"ts": asyncio.get_event_loop().time()})
                await response.write(
                    f"event: {SSEEventType.HEARTBEAT}\ndata: {heartbeat_data}\n\n".encode()
                )

    except (ConnectionResetError, ConnectionAbortedError):
        print(f"[SSE] Peer {peer_id} connection lost")
    except asyncio.CancelledError:
        print(f"[SSE] Peer {peer_id} stream cancelled")
    finally:
        # Handle disconnect when SSE stream closes
        print(f"[SSE] Peer {peer_id} event stream closed")

        # Trigger disconnect handling
        if peer.lobby_code:
            lobby = state.get_lobby(peer.lobby_code)
            if lobby:
                was_host = lobby.is_host(peer_id)
                lobby.remove_peer(peer_id)

                if was_host:
                    await close_lobby(lobby, LobbyCloseReason.HOST_DISCONNECTED)
                else:
                    await broadcast_to_lobby(
                        lobby,
                        {
                            "t": ResponseType.PEER_LEFT,
                            "id": peer_id,
                        },
                    )

        state.remove_lobby_peer(peer_id)

    return response


# =============================================================================
# Route Registration
# =============================================================================


def register_http_lobby_routes(app: web.Application) -> None:
    """Register all HTTP lobby routes."""
    # Connection management
    app.router.add_post("/api/lobby/connect", handle_connect)
    app.router.add_post("/api/lobby/disconnect", handle_disconnect)

    # Lobby operations
    app.router.add_post("/api/lobby/create", handle_create_lobby)
    app.router.add_post("/api/lobby/join", handle_join_lobby)
    app.router.add_post("/api/lobby/leave", handle_leave_lobby)
    app.router.add_get("/api/lobby/list", handle_list_lobbies)

    # Game packet broadcasting
    app.router.add_post("/api/lobby/broadcast", handle_broadcast)

    # SSE event stream
    app.router.add_get("/api/lobby/events", handle_events)

    # OPTIONS handlers for CORS
    async def options_handler(_request: web.Request) -> web.Response:
        return web.Response()

    for path in [
        "/api/lobby/connect",
        "/api/lobby/disconnect",
        "/api/lobby/create",
        "/api/lobby/join",
        "/api/lobby/leave",
        "/api/lobby/list",
        "/api/lobby/broadcast",
        "/api/lobby/events",
    ]:
        app.router.add_route("OPTIONS", path, options_handler)
