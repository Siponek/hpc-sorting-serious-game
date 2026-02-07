# pyright: strict

"""
Server Configuration
"""

import os
import sys
from dataclasses import dataclass


@dataclass(frozen=True)
class ServerConfig:
    """Immutable server configuration settings."""

    host: str = "0.0.0.0"
    default_port: int = 3000
    cors_origins: str = "*"
    room_code_length: int = 4
    room_code_chars: str = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    default_channel: str = "gdsync-hpc-sorting"


# Global immutable config instance
CONFIG = ServerConfig()


def _get_port() -> int:
    """Get port from environment or command line args."""
    # First check environment variable
    env_port = os.environ.get("SERVER_PORT")
    if env_port:
        try:
            return int(env_port)
        except ValueError:
            pass

    # Then check command line args (only if it looks like a port number)
    if len(sys.argv) > 1:
        try:
            return int(sys.argv[1])
        except ValueError:
            pass

    return CONFIG.default_port


# Port can be overridden from command line or environment
PORT = _get_port()
