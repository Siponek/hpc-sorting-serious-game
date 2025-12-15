"""
Server Configuration
"""

import sys
from dataclasses import dataclass


@dataclass
class ServerConfig:
    """Server configuration settings."""
    port: int = 3000
    host: str = "0.0.0.0"
    cors_origins: str = "*"
    room_code_length: int = 4
    room_code_chars: str = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    default_channel: str = "gdsync-hpc-sorting"


# Global config instance
CONFIG = ServerConfig()

# Override port from command line
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else CONFIG.port
CONFIG.port = PORT
