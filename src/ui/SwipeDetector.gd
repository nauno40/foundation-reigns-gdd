class_name SwipeDetector
extends Node

signal swiped_left
signal swiped_right
signal swipe_progress(ratio: float)

const MIN_SWIPE_DISTANCE = 80.0
const MAX_SWIPE_ANGLE = 45.0

var _drag_start: Vector2 = Vector2.ZERO
var _is_dragging: bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_start_drag(event.position)
		else:
			_end_drag(event.position)

	elif event is InputEventScreenDrag:
		if _is_dragging:
			_update_progress(event.position)

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(event.position)
			else:
				_end_drag(event.position)

	elif event is InputEventMouseMotion:
		if _is_dragging and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_update_progress(event.position)

func _start_drag(pos: Vector2) -> void:
	_drag_start = pos
	_is_dragging = true

func _update_progress(pos: Vector2) -> void:
	var delta = pos - _drag_start
	var ratio = clamp(delta.x / MIN_SWIPE_DISTANCE, -1.0, 1.0)
	swipe_progress.emit(ratio)

func _end_drag(pos: Vector2) -> void:
	if not _is_dragging:
		return
	_is_dragging = false

	var delta = pos - _drag_start
	var distance = abs(delta.x)
	if distance < MIN_SWIPE_DISTANCE:
		swipe_progress.emit(0.0)
		return

	var angle = abs(rad_to_deg(atan2(delta.y, delta.x)))
	if angle > MAX_SWIPE_ANGLE and angle < 180.0 - MAX_SWIPE_ANGLE:
		swipe_progress.emit(0.0)
		return

	swipe_progress.emit(0.0)
	if delta.x < 0:
		swiped_left.emit()
	else:
		swiped_right.emit()
