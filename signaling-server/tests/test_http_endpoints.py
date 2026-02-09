# pyright: strict

"""
Tests for HTTP endpoints.

Run with: uv run pytest tests/ -v
"""

import pytest
from aiohttp import web
from aiohttp.test_utils import AioHTTPTestCase

from server.app import create_app
from server.enums import ErrorCode
from server.state import state


class TestHealthEndpoint(AioHTTPTestCase):
    """Tests for /health endpoint."""

    async def get_application(self) -> web.Application:
        state.clear_all()
        return create_app()

    async def test_health_returns_ok(self) -> None:
        """Health endpoint should return status ok."""
        resp = await self.client.request("GET", "/health")
        assert resp.status == 200

        data = await resp.json()
        assert data["status"] == "ok"
        assert "rooms" in data
        assert "lobbies" in data
        assert "lobby_peers" in data


class TestSessionHostEndpoint(AioHTTPTestCase):
    """Tests for /session/host endpoint."""

    async def get_application(self) -> web.Application:
        state.clear_all()
        return create_app()

    async def test_create_room_success(self) -> None:
        """Should create a room and return success."""
        resp = await self.client.request(
            "POST", "/session/host", json={"lobby_name": "TestLobby", "public": True}
        )
        assert resp.status == 200

        data = await resp.json()
        assert data["success"] is True
        assert "code" in data
        assert len(data["code"]) == 4
        assert "ws_url" in data
        assert data["lobby_name"] == "TestLobby"

    async def test_create_room_with_defaults(self) -> None:
        """Should create a room with default values."""
        resp = await self.client.request("POST", "/session/host", json={})
        assert resp.status == 200

        data = await resp.json()
        assert data["success"] is True
        assert "code" in data

    async def test_create_debug_room(self) -> None:
        """Should create a debug room with TEST code."""
        resp = await self.client.request("POST", "/session/host", json={"is_debug": True})
        assert resp.status == 200

        data = await resp.json()
        assert data["code"] == "TEST"


class TestSessionJoinEndpoint(AioHTTPTestCase):
    """Tests for /session/join endpoint."""

    async def get_application(self) -> web.Application:
        state.clear_all()
        return create_app()

    async def test_join_nonexistent_room(self) -> None:
        """Should return 404 for nonexistent room."""
        resp = await self.client.request("POST", "/session/join/XXXX")
        assert resp.status == 404

        data = await resp.json()
        assert data["success"] is False
        assert data["code"] == ErrorCode.ROOM_NOT_FOUND

    async def test_join_existing_room(self) -> None:
        """Should return ws_url for existing room."""
        # First create a room
        create_resp = await self.client.request(
            "POST", "/session/host", json={"lobby_name": "JoinTest"}
        )
        create_data = await create_resp.json()
        room_code = create_data["code"]

        # Then try to join it
        resp = await self.client.request("POST", f"/session/join/{room_code}")
        assert resp.status == 200

        data = await resp.json()
        assert data["success"] is True
        assert data["code"] == room_code
        assert "ws_url" in data

    async def test_join_by_lobby_name(self) -> None:
        """Should be able to join by lobby name."""
        # Create a room with a name
        create_resp = await self.client.request(
            "POST", "/session/host", json={"lobby_name": "MyTestLobby"}
        )
        create_data = await create_resp.json()
        room_code = create_data["code"]

        # Join by name (case insensitive)
        resp = await self.client.request("POST", "/session/join/mytestlobby")
        assert resp.status == 200

        data = await resp.json()
        assert data["code"] == room_code


class TestSessionCloseEndpoint(AioHTTPTestCase):
    """Tests for /session/close endpoint."""

    async def get_application(self) -> web.Application:
        state.clear_all()
        return create_app()

    async def test_close_nonexistent_room(self) -> None:
        """Should return 404 for nonexistent room."""
        resp = await self.client.request("POST", "/session/close/XXXX")
        assert resp.status == 404

    async def test_close_existing_room(self) -> None:
        """Should close existing room."""
        # Create a room
        create_resp = await self.client.request("POST", "/session/host", json={})
        create_data = await create_resp.json()
        room_code = create_data["code"]

        # Close it
        resp = await self.client.request("POST", f"/session/close/{room_code}")
        assert resp.status == 200

        data = await resp.json()
        assert data["success"] is True

        # Verify it's gone
        join_resp = await self.client.request("POST", f"/session/join/{room_code}")
        assert join_resp.status == 404


class TestLobbiesEndpoint(AioHTTPTestCase):
    """Tests for /lobbies endpoint."""

    async def get_application(self) -> web.Application:
        state.clear_all()
        return create_app()

    async def test_empty_lobbies(self) -> None:
        """Should return empty list when no lobbies."""
        resp = await self.client.request("GET", "/lobbies")
        assert resp.status == 200

        data = await resp.json()
        assert data["lobbies"] == []

    async def test_list_public_lobbies(self) -> None:
        """Should list public lobbies from rooms."""
        # Create a public room
        await self.client.request(
            "POST", "/session/host", json={"lobby_name": "PublicLobby", "public": True}
        )

        resp = await self.client.request("GET", "/lobbies")
        assert resp.status == 200

        data = await resp.json()
        assert len(data["lobbies"]) == 1
        assert data["lobbies"][0]["Name"] == "PublicLobby"


class TestRoomsEndpoint(AioHTTPTestCase):
    """Tests for /rooms endpoint (debug)."""

    async def get_application(self) -> web.Application:
        state.clear_all()
        return create_app()

    async def test_list_rooms(self) -> None:
        """Should list all rooms."""
        # Create some rooms
        await self.client.request("POST", "/session/host", json={"lobby_name": "Room1"})
        await self.client.request("POST", "/session/host", json={"lobby_name": "Room2"})

        resp = await self.client.request("GET", "/rooms")
        assert resp.status == 200

        data = await resp.json()
        assert len(data["rooms"]) == 2


class TestPlayerCountEndpoint(AioHTTPTestCase):
    """Tests for /session/players endpoint."""

    async def get_application(self) -> web.Application:
        state.clear_all()
        return create_app()

    async def test_update_player_count(self) -> None:
        """Should update player count."""
        # Create a room
        create_resp = await self.client.request("POST", "/session/host", json={})
        create_data = await create_resp.json()
        room_code = create_data["code"]

        # Update player count
        resp = await self.client.request(
            "POST", f"/session/players/{room_code}", json={"player_count": 5}
        )
        assert resp.status == 200

        data = await resp.json()
        assert data["player_count"] == 5


class TestUpdateEndpoint(AioHTTPTestCase):
    """Tests for /session/update endpoint."""

    async def get_application(self) -> web.Application:
        state.clear_all()
        return create_app()

    async def test_update_room_metadata(self) -> None:
        """Should update room metadata."""
        # Create a room
        create_resp = await self.client.request(
            "POST", "/session/host", json={"lobby_name": "OldName"}
        )
        create_data = await create_resp.json()
        room_code = create_data["code"]

        # Update it
        resp = await self.client.request(
            "POST", f"/session/update/{room_code}", json={"lobby_name": "NewName", "public": False}
        )
        assert resp.status == 200

        data = await resp.json()
        assert data["lobby_name"] == "NewName"
        assert data["public"] is False


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
