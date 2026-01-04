class_name BarrierManager
extends RefCounted

## Manages the barrier synchronization state machine for multiplayer parallel sorting simulation
## Simulates barrier synchronization from HPC/parallel computing

enum BarrierState { RUNNING, WAITING_AT_BARRIER, BARRIER_ACTIVE }  # Default gameplay - all threads (players) working independently  # A thread reached the barrier, waiting for others  # All threads at barrier - main thread processing, others blocked

signal barrier_state_changed(new_state: BarrierState)
signal thread_reached_barrier(player_id: int)
signal main_thread_assigned(player_id: int)

var current_state: BarrierState = BarrierState.RUNNING
var threads_at_barrier: Dictionary = {}  # player_id: bool (true = reached barrier)
var main_thread_id: int = -1
var last_main_thread_id: int = -1  # For round-robin mode
var barrier_mode: int = 0  # 0 = first to reach, 1 = round-robin


func _init():
	reset()


func reset():
	"""Release the barrier and return to running state"""
	current_state = BarrierState.RUNNING
	threads_at_barrier.clear()
	main_thread_id = -1
	barrier_state_changed.emit(current_state)


func set_barrier_mode(mode: int):
	barrier_mode = mode


func is_main_thread(player_id: int) -> bool:
	return player_id == main_thread_id


func mark_thread_at_barrier(player_id: int):
	"""Mark a thread (player) as having reached the barrier"""
	threads_at_barrier[player_id] = true
	thread_reached_barrier.emit(player_id)


func has_thread_reached_barrier(player_id: int) -> bool:
	return threads_at_barrier.get(player_id, false)


func all_threads_at_barrier(player_ids: Array) -> bool:
	"""Check if all threads have reached the barrier"""
	for id in player_ids:
		if not threads_at_barrier.get(id, false):
			return false
	return true


func determine_main_thread(first_thread_id: int, all_player_ids: Array) -> int:
	"""Determine which thread becomes the coordinator based on barrier mode"""
	if barrier_mode == 0:  # First to reach barrier
		return first_thread_id
	else:  # Round-robin
		return _get_next_in_rotation(all_player_ids)


func _get_next_in_rotation(player_ids: Array) -> int:
	"""Get next thread in round-robin rotation"""
	if player_ids.is_empty():
		return -1

	# Sort player IDs for consistent order across all clients
	var sorted_ids = player_ids.duplicate()
	sorted_ids.sort()

	if last_main_thread_id == -1:
		return sorted_ids[0]

	# Find next thread after last main thread
	var last_index = sorted_ids.find(last_main_thread_id)
	if last_index == -1:
		return sorted_ids[0]

	var next_index = (last_index + 1) % sorted_ids.size()
	return sorted_ids[next_index]


func enter_waiting_state(initiator_id: int, all_player_ids: Array):
	"""First thread reached barrier - transition to waiting state"""
	if current_state != BarrierState.RUNNING:
		return

	current_state = BarrierState.WAITING_AT_BARRIER
	main_thread_id = determine_main_thread(initiator_id, all_player_ids)
	mark_thread_at_barrier(initiator_id)

	barrier_state_changed.emit(current_state)
	main_thread_assigned.emit(main_thread_id)


func activate_barrier():
	"""All threads at barrier - activate main thread processing"""
	if current_state != BarrierState.WAITING_AT_BARRIER:
		return

	current_state = BarrierState.BARRIER_ACTIVE
	barrier_state_changed.emit(current_state)


func release_barrier():
	"""Main thread done - release the barrier"""
	last_main_thread_id = main_thread_id
	reset()
