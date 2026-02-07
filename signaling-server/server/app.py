# pyright: strict

"""
Application Factory and Main Entry Point
"""

from __future__ import annotations

import asyncio
import logging
import sys
from collections.abc import Awaitable, Callable
from typing import Any

from aiohttp import web

from .config import CONFIG, PORT
from .enums import ResponseType, SignalingDataType
from .http_handlers import register_http_routes
from .http_lobby_handlers import register_http_lobby_routes
from .state import state
from .websocket_handlers import register_websocket_routes

# Type alias for middleware handler
Handler = Callable[[web.Request], Awaitable[web.StreamResponse]]


# =============================================================================
# CORS Middleware
# =============================================================================


@web.middleware
async def cors_middleware(request: web.Request, handler: Handler) -> web.StreamResponse:
    """CORS middleware for cross-origin requests."""
    if request.method == "OPTIONS":
        response: web.StreamResponse = web.Response()
    else:
        try:
            response = await handler(request)
        except web.HTTPException as ex:
            response = web.Response(status=ex.status, text=ex.reason)

    response.headers["Access-Control-Allow-Origin"] = CONFIG.cors_origins
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Accept, Cache-Control"
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
                await peer.ws.send_json({"t": ResponseType.SERVER_SHUTDOWN})
                await peer.ws.close(code=1001, message=b"Server shutdown")
            except Exception:
                pass

    # Close signaling WebSocket connections
    for code in list(state.ws_connections.keys()):
        connections: dict[int, Any] = state.ws_connections.get(code, {})
        for _peer_id, ws in connections.items():
            if not ws.closed:
                try:
                    await ws.send_json({"data_type": SignalingDataType.SERVER_SHUTDOWN})
                    await ws.close(code=1001, message=b"Server shutdown")
                except Exception:
                    pass

    # Clear all state
    state.clear_all()

    print("[SHUTDOWN] All connections closed")


async def on_shutdown(_app: web.Application) -> None:
    """Called when the application is shutting down."""
    await cleanup_all_connections()


# =============================================================================
# Keyboard Input Handler
# =============================================================================


async def keyboard_listener() -> None:
    """Listen for keyboard commands in the terminal."""
    loop = asyncio.get_event_loop()

    while True:
        try:
            # Read input asynchronously
            line = await loop.run_in_executor(None, sys.stdin.readline)
            cmd = line.strip().lower()

            if cmd == "r":
                print("\n[RESTART] Clearing all connections and state...")
                await cleanup_all_connections()
                print("[RESTART] Server state reset. Ready for new connections.\n")
            elif cmd == "q":
                print("\n[QUIT] Shutting down server...")
                # Raise SystemExit to trigger graceful shutdown
                raise SystemExit(0)
            elif cmd == "h" or cmd == "help":
                print("\n  Commands:")
                print("    r     - Reset server state (disconnect all clients)")
                print("    q     - Quit server")
                print("    h     - Show this help\n")
            elif cmd:
                print(f"  Unknown command: '{cmd}' (type 'h' for help)")

        except EOFError:
            break
        except SystemExit:
            raise
        except Exception as e:
            print(f"[ERROR] Keyboard listener error: {e}")


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
    register_http_lobby_routes(app)  # New HTTP+SSE lobby routes
    register_websocket_routes(app)  # Keep WebSocket routes for backward compatibility

    return app


# =============================================================================
# Utilities
# =============================================================================


def suppress_connection_reset_errors() -> None:
    """Suppress noisy Windows socket errors."""
    logging.getLogger("asyncio").setLevel(logging.CRITICAL)


def print_banner() -> None:
    """Print server startup banner."""
    print()
    print("=" * 60)
    print("  Lobby Server (HTTP + SSE)")
    print("=" * 60)
    print()
    print(f"  Base URL:       http://localhost:{PORT}")
    print()
    print("  HTTP API (recommended for web):")
    print("    POST /api/lobby/connect     - Get peer ID")
    print("    POST /api/lobby/create      - Create lobby")
    print("    POST /api/lobby/join        - Join lobby")
    print("    POST /api/lobby/leave       - Leave lobby")
    print("    GET  /api/lobby/list        - List lobbies")
    print("    POST /api/lobby/broadcast   - Send game packets")
    print("    GET  /api/lobby/events      - SSE event stream")
    print()
    print("  Legacy WebSocket (backward compatible):")
    print("    WS   /lobby                 - Lobby events")
    print("    WS   /ws/{code}             - WebRTC signaling")
    print()
    print("=" * 60)
    print()
    print("  Commands: r = reset state, q = quit, h = help")
    print()
    print("[SERVER] Waiting for connections...")
    print()


# =============================================================================
# Main Entry Point
# =============================================================================


async def run_server() -> None:
    """Run the server with keyboard input support."""
    app = create_app()
    runner = web.AppRunner(app)
    await runner.setup()

    site = web.TCPSite(runner, CONFIG.host, PORT)
    await site.start()

    try:
        await keyboard_listener()
    finally:
        await runner.cleanup()


def main() -> None:
    """Main entry point for the server."""
    suppress_connection_reset_errors()
    print_banner()

    try:
        asyncio.run(run_server())
    except KeyboardInterrupt:
        print("\n[SERVER] Stopped.")


if __name__ == "__main__":
    main()
