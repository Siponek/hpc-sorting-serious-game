class_name TimerController
extends PanelContainer

signal timer_started_signal()
signal timer_stopped_signal()
signal time_updated(elapsed_time: int)

var timer_started: bool = false
var elapsed_time: int = 0
@onready var timerText = $MarginContainer/TimerPlaceholder
@onready var timer: Timer = Timer.new()

func _ready():
	# Configure the timer
	timer.wait_time = 1.0
	timer.one_shot = false
	add_child(timer)
	timer.timeout.connect(_on_timeout)
	# Initialize display if needed
	_update_placeholder_text(elapsed_time)

func start_timer():
	elapsed_time = 0
	timer_started = true
	timer.start()
	emit_signal("timer_started_signal")

func stop_timer():
	timer.stop()
	emit_signal("timer_stopped_signal")

func _on_timeout():
	elapsed_time += 1
	emit_signal("time_updated", elapsed_time)
	_update_placeholder_text(elapsed_time)

func _update_placeholder_text(time_sec: int):
	var minutes: float = float(time_sec) / 60
	var seconds = time_sec % 60
	# Assume this TimerPanel has a child RichTextLabel named "TimerPlaceholder"
	if timerText:
		timerText.text = "Time: %02d:%02d" % [minutes, seconds]

func getCurrentTime() -> int:
	return elapsed_time
	
func setCurrentTime(time_sec: int) -> void:
	elapsed_time = time_sec
	_update_placeholder_text(elapsed_time)

func getCurrentTimeAsString() -> String:
	var minutes: float = float(self.getCurrentTime()) / 60
	var seconds = elapsed_time % 60
	return "%02d:%02d" % [minutes, seconds]

func reset_timer() -> void:
	stop_timer()
	elapsed_time = 0
	timer_started = false
	_update_placeholder_text(elapsed_time)
