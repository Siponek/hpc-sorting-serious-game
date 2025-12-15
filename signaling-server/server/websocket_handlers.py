"""
WebSocket Endpoint Handlers

Two WebSocket endpoints:
1. /lobby - Lobby events (create/join/leave, peer events)
2. /ws/{code} - WebRTC signaling (ICE/SDP exchange)
"""

from __future__ import annotations
import json
from aiohttp import web, WSMsgType

from .models import Peer
from .state import state
from .lobby_handlers import route_message, handle_peer_disconnect


# =============================================================================
# Lobby WebSocket Handler
# =============================================================================

async def handle_lobby_websocket(request: web.Request) -> web.WebSocketResponse:
    """WebSocket handler for lobby events (separate from WebRTC signaling)."""
    ws = web.WebSocketResponse()
    await ws.prepare(request)

    peer_id = state.get_next_peer_id()
    peer = Peer(peer_id=peer_id, ws=ws)
    state.add_lobby_peer(peer)

    print(f"[LOBBY] Peer {peer_id} connected (total lobby peers: {len(state.lobby_peers)})")

    # Send welcome message with assigned ID
    await ws.send_json({
        "t": "welcome",
        "your_id": peer_id,
    })

    try:
        async for msg in ws:
            if msg.type == WSMsgType.TEXT:
                try:
                    data = json.loads(msg.data)
                    response = await route_message(peer, data)
                    if response:
                        await ws.send_json(response)

                except json.JSONDecodeError:
                    await ws.send_json({
                        "t": "error",
                        "code": "INVALID_JSON",
                        "message": "Invalid JSON",
                    })
            elif msg.type == WSMsgType.ERROR:
                print(f"[LOBBY] WebSocket error for peer {peer_id}: {ws.exception()}")

    finally:
        # Handle disconnect
        await handle_peer_disconnect(peer)
        print(f"[LOBBY] Peer {peer_id} disconnected (remaining: {len(state.lobby_peers)})")

    return ws


# =============================================================================
# WebRTC Signaling WebSocket Handler
# =============================================================================

async def handle_signaling_websocket(request: web.Request) -> web.WebSocketResponse:
    """WebSocket handler for WebRTC signaling (ICE/SDP exchange)."""
    code = request.match_info['code'].upper()

    room = state.get_room(code)
    if not room:
        return web.Response(status=404, text='Room not found')

    ws = web.WebSocketResponse()
    await ws.prepare(request)

    # Assign peer ID from room's sequence
    peer_id = room.next_peer_id
    room.next_peer_id += 1

    state.add_signaling_connection(code, peer_id, ws)

    connections = state.get_signaling_connections(code)
    print(f"[WS] Peer {peer_id} connected to room {code} (total: {len(connections)})")

    try:
        # Send initialization with existing peers
        existing_peers = state.get_signaling_peer_ids(code, exclude=peer_id)
        await ws.send_json({
            'data_type': 'initialize',
            'id': peer_id,
            'peers': existing_peers,
        })

        # Notify others about new peer
        for pid, other_ws in connections.items():
            if pid != peer_id and not other_ws.closed:
                await other_ws.send_json({
                    'data_type': 'new_connection',
                    'peer_id': peer_id,
                })

        # Message loop
        async for msg in ws:
            if msg.type == WSMsgType.TEXT:
                try:
                    data = json.loads(msg.data)
                    data_type = data.get('data_type', 'unknown')

                    # Skip ready messages
                    if data_type == 'ready':
                        continue

                    # Log signaling messages
                    if data_type in ('offer', 'answer', 'ice'):
                        target_id = data.get('to', '?')
                        print(f"[SIGNAL] {data_type.upper()} from peer {peer_id} to peer {target_id}")

                    # Forward to target peer
                    if 'to' in data:
                        target_id = data['to']
                        target_connections = state.get_signaling_connections(code)
                        if target_id in target_connections:
                            target_ws = target_connections[target_id]
                            if not target_ws.closed:
                                data['from'] = peer_id
                                await target_ws.send_json(data)

                except json.JSONDecodeError:
                    print(f"[WS] Invalid JSON from peer {peer_id}")

            elif msg.type == WSMsgType.ERROR:
                print(f"[WS] Error: {ws.exception()}")

    finally:
        print(f"[WS] Peer {peer_id} disconnected from room {code}")

        state.remove_signaling_connection(code, peer_id)

        # Notify others about disconnect
        for pid, other_ws in list(state.get_signaling_connections(code).items()):
            if not other_ws.closed:
                try:
                    await other_ws.send_json({
                        'data_type': 'peer_disconnected',
                        'peer_id': peer_id,
                    })
                except:
                    pass

    return ws


# =============================================================================
# Route Registration
# =============================================================================

def register_websocket_routes(app: web.Application) -> None:
    """Register all WebSocket routes."""
    app.router.add_get('/lobby', handle_lobby_websocket)
    app.router.add_get('/ws/{code}', handle_signaling_websocket)
