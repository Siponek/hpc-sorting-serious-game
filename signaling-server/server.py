# pyright: strict
"""
Local HTTP & SSE Relay Server for Godot Web Multiplayer

This server acts as a centralized relay hub for browser-based multiplayer,
bypassing direct P2P WebRTC networking in favor of standard web protocols.

It provides:
1. Lobby Management (create/join/leave) via HTTP POST
2. Client action ingestion via HTTP POST endpoints
3. Real-time game state broadcasting via Server-Sent Events (SSE)

Usage:
    python server.py [--port PORT]
    Default port: 3000

Requirements:
    pip install aiohttp

Then in Godot (via GDSync Web Patch), set:
    var relay_server_url: String = "https://localhost:3000"
"""

import argparse


def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="HTTP & SSE Relay Server for Godot Web Multiplayer"
    )
    parser.add_argument(
        "--port", "-p", type=int, default=None, help="Port to run the server on (default: 3000)"
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()

    # Set port in environment if provided via CLI
    if args.port is not None:
        import os

        os.environ["SERVER_PORT"] = str(args.port)

    from server.app import main

    main()
