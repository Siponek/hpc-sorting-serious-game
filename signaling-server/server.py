#!/usr/bin/env python3
"""
Local WebRTC Signaling Server for PackRTC

Usage:
    python server.py [port]
    Default port: 3000

Requirements:
    pip install aiohttp

Then in Godot, set:
    var signaling_server_url: String = "http://localhost:3000"
"""

import asyncio
import json
import random
import sys
from datetime import datetime

try:
    from aiohttp import web
except ImportError:
    print("ERROR: aiohttp library not installed.")
    print("Install it with: pip install aiohttp")
    sys.exit(1)

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 3000

# Store active rooms
rooms: dict = {}
ws_connections: dict = {}
# Mapping of lobby names to room codes for lobby discovery
lobby_name_to_code: dict = {}


def generate_code() -> str:
    """Generate a random 4-character room code."""
    chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    return ''.join(random.choice(chars) for _ in range(4))


# CORS middleware
@web.middleware
async def cors_middleware(request, handler):
    # Handle preflight
    if request.method == 'OPTIONS':
        response = web.Response()
    else:
        try:
            response = await handler(request)
        except web.HTTPException as ex:
            response = web.Response(status=ex.status, text=ex.reason)

    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
    return response


async def handle_host(request):
    """POST /session/host - Create a new room"""
    try:
        body = await request.json()
    except:
        body = {}

    is_debug = body.get('is_debug', False)
    channel = body.get('channel', 'default')
    # Lobby metadata for discovery
    lobby_name = body.get('lobby_name', '')
    lobby_public = body.get('public', True)
    player_limit = body.get('player_limit', 0)

    # Generate unique code
    if is_debug:
        code = 'TEST'
    else:
        code = generate_code()
        while code in rooms:
            code = generate_code()

    # Create room
    rooms[code] = {
        'channel': channel,
        'next_peer_id': 1,
        'created_at': datetime.now().isoformat(),
        'lobby_name': lobby_name,
        'public': lobby_public,
        'player_limit': player_limit,
    }
    ws_connections[code] = {}

    # Store lobby name to code mapping for discovery
    if lobby_name:
        lobby_name_to_code[lobby_name.lower()] = code

    print(f"[HOST] Room created: {code} (channel: {channel}, lobby: {lobby_name})")

    # Build WebSocket URL
    host = request.host.split(':')[0]
    ws_url = f'ws://{host}:{PORT}/ws/{code}'

    return web.json_response({
        'success': True,
        'code': code,
        'ws_url': ws_url,
        'lobby_name': lobby_name,
    })


async def handle_join(request):
    """POST /session/join/:code - Join an existing room by code or lobby name"""
    code_or_name = request.match_info['code']

    # First try as room code (uppercase)
    code = code_or_name.upper()
    if code not in rooms:
        # Try as lobby name (case-insensitive)
        code = lobby_name_to_code.get(code_or_name.lower())
        if not code or code not in rooms:
            return web.json_response(
                {'success': False, 'code': 'ROOM_NOT_FOUND'},
                status=404
            )

    room = rooms[code]
    print(f"[JOIN] Joining room: {code} (lobby: {room.get('lobby_name', 'N/A')})")

    host = request.host.split(':')[0]
    ws_url = f'ws://{host}:{PORT}/ws/{code}'

    return web.json_response({
        'success': True,
        'ws_url': ws_url,
        'code': code,
        'lobby_name': room.get('lobby_name', ''),
    })


async def handle_health(request):
    """GET /health - Health check"""
    return web.json_response({
        'status': 'ok',
        'rooms': len(rooms),
    })


async def handle_rooms(request):
    """GET /rooms - List all rooms (for debugging)"""
    room_list = []
    for code, room in rooms.items():
        room_list.append({
            'code': code,
            'channel': room['channel'],
            'peers': len(ws_connections.get(code, {})),
            'created_at': room['created_at'],
            'lobby_name': room.get('lobby_name', ''),
            'public': room.get('public', True),
            'player_limit': room.get('player_limit', 0),
        })
    return web.json_response({'rooms': room_list})


async def handle_lobbies(request):
    """GET /lobbies - List public lobbies for discovery"""
    lobbies = []
    for code, room in rooms.items():
        # Only include public lobbies
        if room.get('public', True):
            lobbies.append({
                'Name': room.get('lobby_name', code),
                'Code': code,
                'PlayerCount': len(ws_connections.get(code, {})),
                'PlayerLimit': room.get('player_limit', 0),
                'Public': True,
                'Open': True,
                'HasPassword': False,
            })
    return web.json_response({'lobbies': lobbies})


async def handle_websocket(request):
    """WebSocket handler for signaling"""
    code = request.match_info['code'].upper()

    if code not in rooms:
        return web.Response(status=404, text='Room not found')

    ws = web.WebSocketResponse()
    await ws.prepare(request)

    room = rooms[code]
    peer_id = room['next_peer_id']
    room['next_peer_id'] += 1

    if code not in ws_connections:
        ws_connections[code] = {}
    ws_connections[code][peer_id] = ws

    print(f"[WS] Peer {peer_id} connected to room {code} (total: {len(ws_connections[code])})")

    try:
        # Send initialization
        existing_peers = [pid for pid in ws_connections[code].keys() if pid != peer_id]
        await ws.send_json({
            'data_type': 'initialize',
            'id': peer_id,
            'peers': existing_peers,
        })

        # Notify others
        for pid, other_ws in ws_connections[code].items():
            if pid != peer_id and not other_ws.closed:
                await other_ws.send_json({
                    'data_type': 'new_connection',
                    'peer_id': peer_id,
                })

        # Message loop
        async for msg in ws:
            if msg.type == web.WSMsgType.TEXT:
                try:
                    data = json.loads(msg.data)

                    if data.get('data_type') == 'ready':
                        print(f"[WS] Peer {peer_id} ready in room {code}")
                        continue

                    # Forward to target peer
                    if 'to' in data:
                        target_id = data['to']
                        if target_id in ws_connections.get(code, {}):
                            target_ws = ws_connections[code][target_id]
                            if not target_ws.closed:
                                data['from'] = peer_id
                                await target_ws.send_json(data)
                except json.JSONDecodeError:
                    pass
            elif msg.type == web.WSMsgType.ERROR:
                print(f"[WS] Error: {ws.exception()}")

    finally:
        # Cleanup
        print(f"[WS] Peer {peer_id} disconnected from room {code}")

        if code in ws_connections and peer_id in ws_connections[code]:
            del ws_connections[code][peer_id]

            # Notify others
            for pid, other_ws in list(ws_connections.get(code, {}).items()):
                if not other_ws.closed:
                    try:
                        await other_ws.send_json({
                            'data_type': 'peer_disconnected',
                            'peer_id': peer_id,
                        })
                    except:
                        pass

            # Cleanup empty rooms
            if len(ws_connections.get(code, {})) == 0 and code != 'TEST':
                # Remove lobby name mapping
                room = rooms.get(code, {})
                lobby_name = room.get('lobby_name', '')
                if lobby_name and lobby_name.lower() in lobby_name_to_code:
                    del lobby_name_to_code[lobby_name.lower()]
                rooms.pop(code, None)
                ws_connections.pop(code, None)
                print(f"[ROOM] Room {code} deleted (empty)")

    return ws


def main():
    app = web.Application(middlewares=[cors_middleware])

    # Routes
    app.router.add_post('/session/host', handle_host)
    app.router.add_post('/session/join/{code}', handle_join)
    app.router.add_get('/health', handle_health)
    app.router.add_get('/rooms', handle_rooms)
    app.router.add_get('/lobbies', handle_lobbies)
    app.router.add_get('/ws/{code}', handle_websocket)

    # Also handle OPTIONS for all routes
    app.router.add_route('OPTIONS', '/session/host', lambda r: web.Response())
    app.router.add_route('OPTIONS', '/session/join/{code}', lambda r: web.Response())
    app.router.add_route('OPTIONS', '/lobbies', lambda r: web.Response())

    print()
    print('=' * 60)
    print('  WebRTC Signaling Server for PackRTC')
    print('=' * 60)
    print()
    print(f'  HTTP:      http://localhost:{PORT}')
    print(f'  WebSocket: ws://localhost:{PORT}/ws/{{code}}')
    print()
    print('  In Godot, set:')
    print(f'    signaling_server_url = "http://localhost:{PORT}"')
    print()
    print('=' * 60)
    print()

    web.run_app(app, host='0.0.0.0', port=PORT, print=None)


if __name__ == '__main__':
    main()
