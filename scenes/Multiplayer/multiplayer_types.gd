class_name MultiplayerTypes
extends RefCounted


## Data class representing a single player in the lobby
class PlayerData:
	extends RefCounted

	var client_id: int = -1
	var name: String = ""
	var color: Color = Color.WHITE
	var is_host: bool = false

	func _init(
		p_client_id: int = -1, p_name: String = "", p_is_host: bool = false
	) -> void:
		client_id = p_client_id
		name = p_name if not p_name.is_empty() else "Player " + str(p_client_id)
		is_host = p_is_host

	## Create PlayerData from a dictionary (for backwards compatibility)
	static func from_dict(id: int, data: Dictionary) -> PlayerData:
		var player := PlayerData.new()
		player.client_id = id
		player.name = data.get("name", "Player " + str(id))
		player.color = data.get("color", Color.WHITE)
		player.is_host = data.get("is_host", false)
		return player

	## Convert to dictionary (for serialization/network)
	func to_dict() -> Dictionary:
		return {
			"client_id": client_id,
			"name": name,
			"color": color,
			"is_host": is_host
		}


## Data class representing the full player list in a lobby
## Maps client_id -> PlayerData
class PlayersMap:
	extends RefCounted

	var _players: Dictionary = {}  # int -> PlayerData

	func add_player(player: PlayerData) -> void:
		_players[player.client_id] = player

	func remove_player(client_id: int) -> bool:
		return _players.erase(client_id)

	func get_player(client_id: int) -> PlayerData:
		return _players.get(client_id)

	func has_player(client_id: int) -> bool:
		return _players.has(client_id)

	func get_all_players() -> Array[PlayerData]:
		var result: Array[PlayerData] = []
		for player in _players.values():
			result.append(player)
		return result

	func get_client_ids() -> Array[int]:
		var result: Array[int] = []
		for id in _players.keys():
			result.append(id)
		return result

	func size() -> int:
		return _players.size()

	func clear() -> void:
		_players.clear()

	func duplicate() -> PlayersMap:
		var copy := PlayersMap.new()
		for id in _players:
			var player: PlayerData = _players[id]
			var player_copy := PlayerData.new(
				player.client_id, player.name, player.is_host
			)
			player_copy.color = player.color
			copy.add_player(player_copy)
		return copy

	## Create PlayersMap from raw dictionary (for backwards compatibility)
	static func from_dict(data: Dictionary) -> PlayersMap:
		var players_map := PlayersMap.new()
		for client_id in data:
			var player := PlayerData.from_dict(client_id, data[client_id])
			players_map.add_player(player)
		return players_map

	## Convert to raw dictionary (for serialization/network)
	func to_dict() -> Dictionary:
		var result: Dictionary = {}
		for client_id in _players:
			result[client_id] = _players[client_id].to_dict()
		return result


## Data class representing lobby info (for discovery)
class LobbyInfo:
	extends RefCounted

	var code: String = ""
	var name: String = ""
	var host_id: int = -1
	var player_count: int = 0
	var player_limit: int = 0
	var is_public: bool = true
	var is_open: bool = true

	static func from_dict(data: Dictionary) -> LobbyInfo:
		var info := LobbyInfo.new()
		info.code = data.get("code", "")
		info.name = data.get("name", "")
		info.host_id = data.get("host_id", -1)
		info.player_count = data.get("player_count", 0)
		info.player_limit = data.get("player_limit", 0)
		info.is_public = data.get("public", true)
		info.is_open = data.get("open", true)
		return info
