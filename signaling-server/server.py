#!/usr/bin/env python3
"""
Local WebRTC Signaling Server for PackRTC + Lobby Event Server

This server provides:
1. WebRTC signaling (ICE/SDP exchange) via /ws/{code}
2. Lobby events (create/join/leave, peer events) via /lobby WebSocket

Usage:
    python server.py [port]
    Default port: 3000

Requirements:
    pip install aiohttp

Then in Godot, set:
    var signaling_server_url: String = "http://localhost:3000"
"""

from server import main

if __name__ == '__main__':
    main()
