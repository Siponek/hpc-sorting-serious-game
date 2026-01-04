# pyright: strict

"""
HTTP Endpoint Handlers

REST API endpoints for backward compatibility with existing clients.
"""

from __future__ import annotations

from typing import Any

from aiohttp import web

from .config import PORT
from .enums import ErrorCode, LobbyCloseReason
from .lobby_handlers import close_lobby
from .state import state

# =============================================================================
# Session Endpoints (WebRTC signaling)
# =============================================================================


async def handle_host(request: web.Request) -> web.Response:
    """POST /session/host - Create a new room (HTTP fallback for WebRTC-only clients)"""
    try:
        body: dict[str, Any] = await request.json()
    except Exception:
        body = {}

    is_debug: bool = body.get("is_debug", False)
    channel: str = body.get("channel", "default")
    lobby_name: str = body.get("lobby_name", "")
    lobby_public: bool = body.get("public", True)
    player_limit: int = body.get("player_limit", 0)

    room = state.create_room(
        channel=channel,
        lobby_name=lobby_name,
        public=lobby_public,
        player_limit=player_limit,
        is_debug=is_debug,
    )

    print(f"[HOST] Room created: {room.code} (channel: {channel}, lobby: {lobby_name})")

    host = request.host.split(":")[0]
    ws_url = f"ws://{host}:{PORT}/ws/{room.code}"

    return web.json_response(
        {
            "success": True,
            "code": room.code,
            "ws_url": ws_url,
            "lobby_name": lobby_name,
        }
    )


async def handle_update(request: web.Request) -> web.Response:
    """POST /session/update/:code - Update room metadata"""
    code = request.match_info["code"].upper()

    room = state.get_room(code)
    if not room:
        return web.json_response({"success": False, "code": ErrorCode.ROOM_NOT_FOUND}, status=404)

    try:
        body: dict[str, Any] = await request.json()
    except Exception:
        body = {}

    # Update lobby name mapping
    old_lobby_name = room.lobby_name
    new_lobby_name: str = body.get("lobby_name", old_lobby_name)

    if old_lobby_name and old_lobby_name.lower() in state.lobby_name_to_code:
        del state.lobby_name_to_code[old_lobby_name.lower()]

    if new_lobby_name:
        state.lobby_name_to_code[new_lobby_name.lower()] = code
        room.lobby_name = new_lobby_name

    if "public" in body:
        room.public = body["public"]
    if "player_limit" in body:
        room.player_limit = body["player_limit"]

    print(f"[UPDATE] Room {code} updated: lobby={room.lobby_name}, public={room.public}")

    return web.json_response(
        {
            "success": True,
            "code": code,
            "lobby_name": room.lobby_name,
            "public": room.public,
            "player_limit": room.player_limit,
        }
    )


async def handle_player_count(request: web.Request) -> web.Response:
    """POST /session/players/:code - Update player count"""
    code = request.match_info["code"].upper()

    room = state.get_room(code)
    if not room:
        return web.json_response({"success": False, "code": ErrorCode.ROOM_NOT_FOUND}, status=404)

    try:
        body: dict[str, Any] = await request.json()
    except Exception:
        body = {}

    if "player_count" in body:
        room.player_count = int(body["player_count"])
        print(f"[PLAYERS] Room {code} player count: {room.player_count}")

    return web.json_response(
        {
            "success": True,
            "code": code,
            "player_count": room.player_count,
        }
    )


async def handle_close(request: web.Request) -> web.Response:
    """POST /session/close/:code - Close/delete a room"""
    code = request.match_info["code"].upper()

    room = state.get_room(code)
    if not room:
        return web.json_response({"success": False, "code": ErrorCode.ROOM_NOT_FOUND}, status=404)

    lobby_name = room.lobby_name

    # Close any remaining WebSocket connections
    connections = state.get_signaling_connections(code)
    for ws in connections.values():
        if not ws.closed:
            await ws.close()

    # Also close the lobby if it exists
    lobby = state.get_lobby(code)
    if lobby:
        await close_lobby(lobby, LobbyCloseReason.HOST_CLOSED)
    else:
        state.remove_room(code)

    print(f"[CLOSE] Room {code} closed by host (lobby: {lobby_name})")

    return web.json_response(
        {
            "success": True,
            "code": code,
        }
    )


async def handle_join(request: web.Request) -> web.Response:
    """POST /session/join/:code - Join a room (HTTP)"""
    code_or_name = request.match_info["code"]

    room = state.find_room(code_or_name)
    if not room:
        return web.json_response({"success": False, "code": ErrorCode.ROOM_NOT_FOUND}, status=404)

    print(f"[JOIN] Joining room: {room.code} (lobby: {room.lobby_name or 'N/A'})")

    host = request.host.split(":")[0]
    ws_url = f"ws://{host}:{PORT}/ws/{room.code}"

    return web.json_response(
        {
            "success": True,
            "ws_url": ws_url,
            "code": room.code,
            "lobby_name": room.lobby_name,
        }
    )


# =============================================================================
# Info Endpoints
# =============================================================================


async def handle_health(request: web.Request) -> web.Response:
    """GET /health - Health check"""
    return web.json_response(
        {
            "status": "ok",
            "rooms": len(state.rooms),
            "lobbies": len(state.lobbies),
            "lobby_peers": len(state.lobby_peers),
        }
    )


async def handle_rooms(request: web.Request) -> web.Response:
    """GET /rooms - List all rooms (debug)"""
    room_list: list[dict[str, Any]] = []
    for code, room in state.rooms.items():
        connections = state.get_signaling_connections(code)
        room_dict = room.to_dict()
        room_dict["signaling_peers"] = len(connections)
        room_list.append(room_dict)

    return web.json_response({"rooms": room_list})


async def handle_lobbies(request: web.Request) -> web.Response:
    """GET /lobbies - List public lobbies"""
    lobby_list: list[dict[str, Any]] = []

    # First try the lobby system
    for lobby in state.get_public_lobbies():
        lobby_list.append(lobby.to_gdsync_format())

    # Fallback to rooms for HTTP-only clients
    if not lobby_list:
        for room in state.get_public_rooms():
            lobby_list.append(
                {
                    "Name": room.lobby_name or room.code,
                    "Code": room.code,
                    "PlayerCount": room.player_count,
                    "PlayerLimit": room.player_limit,
                    "Public": True,
                    "Open": True,
                    "HasPassword": False,
                }
            )

    return web.json_response({"lobbies": lobby_list})


# =============================================================================
# Route Registration
# =============================================================================


def register_http_routes(app: web.Application) -> None:
    """Register all HTTP routes."""
    # Session endpoints
    app.router.add_post("/session/host", handle_host)
    app.router.add_post("/session/update/{code}", handle_update)
    app.router.add_post("/session/players/{code}", handle_player_count)
    app.router.add_post("/session/close/{code}", handle_close)
    app.router.add_post("/session/join/{code}", handle_join)

    # Info endpoints
    app.router.add_get("/health", handle_health)
    app.router.add_get("/rooms", handle_rooms)
    app.router.add_get("/lobbies", handle_lobbies)

    # OPTIONS handlers for CORS
    async def options_handler(_request: web.Request) -> web.Response:
        return web.Response()

    app.router.add_route("OPTIONS", "/session/host", options_handler)
    app.router.add_route("OPTIONS", "/session/update/{code}", options_handler)
    app.router.add_route("OPTIONS", "/session/players/{code}", options_handler)
    app.router.add_route("OPTIONS", "/session/close/{code}", options_handler)
    app.router.add_route("OPTIONS", "/session/join/{code}", options_handler)
    app.router.add_route("OPTIONS", "/lobbies", options_handler)
