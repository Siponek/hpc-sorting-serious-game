# pyright: strict
"""
Local WebRTC Signaling Server for PackRTC + Lobby Event Server

This server provides:
1. WebRTC signaling (ICE/SDP exchange) via /ws/{code}
2. Lobby events (create/join/leave, peer events) via /lobby WebSocket

Usage:
    python server.py [--port PORT]
    Default port: 3000

Requirements:
    pip install aiohttp

Then in Godot, set:
    var signaling_server_url: String = "http://localhost:3000"
"""

import argparse


def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="WebRTC Signaling Server for PackRTC + Lobby Events"
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
