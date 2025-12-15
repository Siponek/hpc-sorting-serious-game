"""
Application Factory and Main Entry Point
"""

from __future__ import annotations
import logging
from aiohttp import web

from .config import PORT, CONFIG
from .state import state
from .http_handlers import register_http_routes
from .websocket_handlers import register_websocket_routes


# =============================================================================
# CORS Middleware
# =============================================================================

@web.middleware
async def cors_middleware(request: web.Request, handler) -> web.Response:
    """CORS middleware for cross-origin requests."""
    if request.method == 'OPTIONS':
        response = web.Response()
    else:
        try:
            response = await handler(request)
        except web.HTTPException as ex:
            response = web.Response(status=ex.status, text=ex.reason)

    response.headers['Access-Control-Allow-Origin'] = CONFIG.cors_origins
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
    return response


# =============================================================================
# Shutdown Handling
# =============================================================================

async def cleanup_all_connections() -> None:
    """Close all WebSocket connections gracefully."""
    print("\n[SHUTDOWN] Closing all connections...")

    # Close lobby WebSocket connections
    for peer in list(state.lobby_peers.values()):
        if peer.ws and not peer.ws.closed:
            try:
                await peer.ws.send_json({"t": "server_shutdown"})
                await peer.ws.close(code=1001, message=b'Server shutdown')
            except:
                pass

    # Close signaling WebSocket connections
    for code in list(state.ws_connections.keys()):
        for peer_id, ws in list(state.ws_connections.get(code, {}).items()):
            if not ws.closed:
                try:
                    await ws.send_json({'data_type': 'server_shutdown'})
                    await ws.close(code=1001, message=b'Server shutdown')
                except:
                    pass

    # Clear all state
    state.clear_all()

    print("[SHUTDOWN] All connections closed")


async def on_shutdown(app: web.Application) -> None:
    """Called when the application is shutting down."""
    await cleanup_all_connections()


# =============================================================================
# Application Factory
# =============================================================================

def create_app() -> web.Application:
    """Create and configure the aiohttp application."""
    app = web.Application(middlewares=[cors_middleware])

    # Register shutdown handler
    app.on_shutdown.append(on_shutdown)

    # Register routes
    register_http_routes(app)
    register_websocket_routes(app)

    return app


# =============================================================================
# Utilities
# =============================================================================

def suppress_connection_reset_errors() -> None:
    """Suppress noisy Windows socket errors."""
    logging.getLogger('asyncio').setLevel(logging.CRITICAL)


def print_banner() -> None:
    """Print server startup banner."""
    print()
    print('=' * 60)
    print('  WebRTC Signaling + Lobby Event Server')
    print('=' * 60)
    print()
    print(f'  HTTP:           http://localhost:{PORT}')
    print(f'  WebRTC WS:      ws://localhost:{PORT}/ws/{{code}}')
    print(f'  Lobby WS:       ws://localhost:{PORT}/lobby')
    print()
    print('  Lobby Protocol (JSON over WebSocket):')
    print('    -> {"t":"create_lobby","name":"...","public":true}')
    print('    -> {"t":"list_lobbies"}')
    print('    -> {"t":"join_lobby","code":"XXXX","player":{"name":"..."}}')
    print('    -> {"t":"leave_lobby"}')
    print('    <- {"t":"lobby_created","code":"...","host_id":1,"your_id":1}')
    print('    <- {"t":"lobby_joined","code":"...","host_id":1,"your_id":2,...}')
    print('    <- {"t":"peer_joined","id":2,"player":{...}}')
    print('    <- {"t":"peer_left","id":2}')
    print('    <- {"t":"lobby_closed","code":"...","reason":"..."}')
    print()
    print('=' * 60)
    print()
    print('[SERVER] Waiting for connections...')
    print()


# =============================================================================
# Main Entry Point
# =============================================================================

def main() -> None:
    """Main entry point for the server."""
    suppress_connection_reset_errors()
    print_banner()

    app = create_app()
    web.run_app(app, host=CONFIG.host, port=PORT, print=None)


if __name__ == '__main__':
    main()
