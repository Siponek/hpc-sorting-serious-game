# pyright: strict

"""
Tests for Lobby WebSocket endpoint.

Run with: uv run pytest tests/ -v
"""

import pytest
from aiohttp import web
from aiohttp.test_utils import AioHTTPTestCase

from server.app import create_app
from server.enums import ErrorCode, MessageType, ResponseType
from server.state import state


class TestLobbyWebSocket(AioHTTPTestCase):
    """Tests for /lobby WebSocket endpoint."""

    async def get_application(self) -> web.Application:
        state.clear_all()
        return create_app()

    async def test_connect_receives_welcome(self) -> None:
        """Should receive welcome message with peer ID on connect."""
        async with self.client.ws_connect("/lobby") as ws:
            msg = await ws.receive_json()
            assert msg["t"] == ResponseType.WELCOME
            assert "your_id" in msg
            assert isinstance(msg["your_id"], int)

    async def test_ping_pong(self) -> None:
        """Should respond to ping with pong."""
        async with self.client.ws_connect("/lobby") as ws:
            # Skip welcome
            await ws.receive_json()

            await ws.send_json({"t": MessageType.PING})
            msg = await ws.receive_json()
            assert msg["t"] == ResponseType.PONG

    async def test_create_lobby(self) -> None:
        """Should create a lobby successfully."""
        async with self.client.ws_connect("/lobby") as ws:
            welcome = await ws.receive_json()
            peer_id = welcome["your_id"]

            await ws.send_json(
                {
                    "t": MessageType.CREATE_LOBBY,
                    "name": "TestLobby",
                    "public": True,
                }
            )

            msg = await ws.receive_json()
            assert msg["t"] == ResponseType.LOBBY_CREATED
            assert msg["name"] == "TestLobby"
            assert msg["host_id"] == peer_id
            assert msg["your_id"] == peer_id
            assert len(msg["code"]) == 4

    async def test_list_lobbies_empty(self) -> None:
        """Should return empty list when no lobbies exist."""
        async with self.client.ws_connect("/lobby") as ws:
            await ws.receive_json()  # skip welcome

            await ws.send_json({"t": MessageType.LIST_LOBBIES})
            msg = await ws.receive_json()

            assert msg["t"] == ResponseType.LOBBY_LIST
            assert msg["items"] == []

    async def test_list_lobbies_with_lobby(self) -> None:
        """Should list created lobbies."""
        async with self.client.ws_connect("/lobby") as ws:
            await ws.receive_json()  # skip welcome

            # Create a lobby
            await ws.send_json(
                {
                    "t": MessageType.CREATE_LOBBY,
                    "name": "ListTestLobby",
                    "public": True,
                }
            )
            await ws.receive_json()  # skip lobby_created

            # List lobbies
            await ws.send_json({"t": MessageType.LIST_LOBBIES})
            msg = await ws.receive_json()

            assert msg["t"] == ResponseType.LOBBY_LIST
            assert len(msg["items"]) == 1
            assert msg["items"][0]["name"] == "ListTestLobby"

    async def test_join_nonexistent_lobby(self) -> None:
        """Should return error when joining nonexistent lobby."""
        async with self.client.ws_connect("/lobby") as ws:
            await ws.receive_json()  # skip welcome

            await ws.send_json(
                {
                    "t": MessageType.JOIN_LOBBY,
                    "code": "XXXX",
                }
            )
            msg = await ws.receive_json()

            assert msg["t"] == ResponseType.ERROR
            assert msg["code"] == ErrorCode.LOBBY_NOT_FOUND

    async def test_join_lobby_success(self) -> None:
        """Should join lobby successfully."""
        # Host creates lobby
        async with self.client.ws_connect("/lobby") as host_ws:
            host_welcome = await host_ws.receive_json()
            host_id = host_welcome["your_id"]

            await host_ws.send_json(
                {
                    "t": MessageType.CREATE_LOBBY,
                    "name": "JoinTestLobby",
                }
            )
            created = await host_ws.receive_json()
            lobby_code = created["code"]

            # Client joins lobby
            async with self.client.ws_connect("/lobby") as client_ws:
                client_welcome = await client_ws.receive_json()
                client_id = client_welcome["your_id"]

                await client_ws.send_json(
                    {
                        "t": MessageType.JOIN_LOBBY,
                        "code": lobby_code,
                        "player": {"name": "TestPlayer"},
                    }
                )

                # Client receives lobby_joined
                joined = await client_ws.receive_json()
                assert joined["t"] == ResponseType.LOBBY_JOINED
                assert joined["code"] == lobby_code
                assert joined["host_id"] == host_id
                assert joined["your_id"] == client_id
                assert len(joined["players"]) == 2

                # Host receives peer_joined
                peer_joined = await host_ws.receive_json()
                assert peer_joined["t"] == ResponseType.PEER_JOINED
                assert peer_joined["id"] == client_id
                assert peer_joined["player"]["name"] == "TestPlayer"

    async def test_leave_lobby(self) -> None:
        """Should leave lobby successfully."""
        async with self.client.ws_connect("/lobby") as host_ws:
            await host_ws.receive_json()  # skip welcome

            await host_ws.send_json(
                {
                    "t": MessageType.CREATE_LOBBY,
                    "name": "LeaveTestLobby",
                }
            )
            created = await host_ws.receive_json()
            lobby_code = created["code"]

            async with self.client.ws_connect("/lobby") as client_ws:
                await client_ws.receive_json()  # skip welcome

                # Join
                await client_ws.send_json(
                    {
                        "t": MessageType.JOIN_LOBBY,
                        "code": lobby_code,
                    }
                )
                await client_ws.receive_json()  # skip lobby_joined
                await host_ws.receive_json()  # skip peer_joined on host

                # Leave
                await client_ws.send_json({"t": MessageType.LEAVE_LOBBY})
                left = await client_ws.receive_json()
                assert left["t"] == ResponseType.LOBBY_LEFT

                # Host receives peer_left
                peer_left = await host_ws.receive_json()
                assert peer_left["t"] == ResponseType.PEER_LEFT

    async def test_leave_when_not_in_lobby(self) -> None:
        """Should return error when leaving without being in a lobby."""
        async with self.client.ws_connect("/lobby") as ws:
            await ws.receive_json()  # skip welcome

            await ws.send_json({"t": MessageType.LEAVE_LOBBY})
            msg = await ws.receive_json()

            assert msg["t"] == ResponseType.ERROR
            assert msg["code"] == ErrorCode.NOT_IN_LOBBY

    async def test_already_in_lobby_error(self) -> None:
        """Should return error when trying to join while already in a lobby."""
        # First create a lobby with a different peer
        async with self.client.ws_connect("/lobby") as other_ws:
            await other_ws.receive_json()  # skip welcome
            await other_ws.send_json(
                {
                    "t": MessageType.CREATE_LOBBY,
                    "name": "OtherLobby",
                }
            )
            other_created = await other_ws.receive_json()
            other_code = other_created["code"]

            # Now test with our main peer
            async with self.client.ws_connect("/lobby") as ws:
                await ws.receive_json()  # skip welcome

                # Create first lobby
                await ws.send_json(
                    {
                        "t": MessageType.CREATE_LOBBY,
                        "name": "FirstLobby",
                    }
                )
                await ws.receive_json()  # skip lobby_created

                # Try to join another existing lobby
                await ws.send_json(
                    {
                        "t": MessageType.JOIN_LOBBY,
                        "code": other_code,
                    }
                )
                msg = await ws.receive_json()

                assert msg["t"] == ResponseType.ERROR
                assert msg["code"] == ErrorCode.ALREADY_IN_LOBBY

    async def test_unknown_command(self) -> None:
        """Should return error for unknown command."""
        async with self.client.ws_connect("/lobby") as ws:
            await ws.receive_json()  # skip welcome

            await ws.send_json({"t": "unknown_command"})
            msg = await ws.receive_json()

            assert msg["t"] == ResponseType.ERROR
            assert msg["code"] == ErrorCode.UNKNOWN_COMMAND

    async def test_invalid_json(self) -> None:
        """Should return error for invalid JSON."""
        async with self.client.ws_connect("/lobby") as ws:
            await ws.receive_json()  # skip welcome

            await ws.send_str("not valid json")
            msg = await ws.receive_json()

            assert msg["t"] == ResponseType.ERROR
            assert msg["code"] == ErrorCode.INVALID_JSON

    async def test_host_disconnect_closes_lobby(self) -> None:
        """When host disconnects, lobby should close and clients notified."""
        async with self.client.ws_connect("/lobby") as host_ws:
            await host_ws.receive_json()  # skip welcome

            await host_ws.send_json(
                {
                    "t": MessageType.CREATE_LOBBY,
                    "name": "DisconnectTestLobby",
                }
            )
            created = await host_ws.receive_json()
            lobby_code = created["code"]

            async with self.client.ws_connect("/lobby") as client_ws:
                await client_ws.receive_json()  # skip welcome

                await client_ws.send_json(
                    {
                        "t": MessageType.JOIN_LOBBY,
                        "code": lobby_code,
                    }
                )
                await client_ws.receive_json()  # skip lobby_joined
                await host_ws.receive_json()  # skip peer_joined

                # Host disconnects
                await host_ws.close()

                # Client should receive lobby_closed
                msg = await client_ws.receive_json()
                assert msg["t"] == ResponseType.LOBBY_CLOSED
                assert msg["code"] == lobby_code
                assert msg["reason"] == "host_disconnected"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
