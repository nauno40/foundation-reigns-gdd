class_name SwipeDetector
extends Node

# Drag horizontal de carte façon Reigns : la carte suit le doigt 1:1
# (delta brut en pixels, non clampé), validation au relâchement au-delà
# du seuil du prototype (92 px), sinon snap-back. Un relâchement quasi
# immobile est un tap (sert à balayer la réaction).

signal swiped_left
signal swiped_right
# velocity_px_s : vitesse horizontale instantanée du doigt (px/s), signée.
# Sert au tilt basé sur la vélocité (CardAnimator.HandleVelocityBasedRotation).
signal swipe_progress(drag_px: float, velocity_px_s: float)
signal drag_released
signal tapped

const COMMIT_THRESHOLD = 92.0  # = CardScreen.SWIPE_THRESHOLD (prototype)
const TAP_MAX_DISTANCE = 12.0
const MAX_SWIPE_ANGLE = 45.0

var _drag_start: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _last_x: float = 0.0
var _last_time_us: int = 0

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
	_last_x = pos.x
	_last_time_us = Time.get_ticks_usec()

func _update_progress(pos: Vector2) -> void:
	var now_us := Time.get_ticks_usec()
	var dt := float(now_us - _last_time_us) / 1_000_000.0
	var velocity := 0.0
	if dt > 0.0:
		velocity = (pos.x - _last_x) / dt
	_last_x = pos.x
	_last_time_us = now_us
	swipe_progress.emit(pos.x - _drag_start.x, velocity)

func _end_drag(pos: Vector2) -> void:
	if not _is_dragging:
		return
	_is_dragging = false

	var delta = pos - _drag_start
	if delta.length() < TAP_MAX_DISTANCE:
		tapped.emit()
		drag_released.emit()
		return

	var angle = abs(rad_to_deg(atan2(delta.y, delta.x)))
	var too_vertical: bool = angle > MAX_SWIPE_ANGLE and angle < 180.0 - MAX_SWIPE_ANGLE
	if abs(delta.x) < COMMIT_THRESHOLD or too_vertical:
		drag_released.emit()
		return

	if delta.x < 0:
		swiped_left.emit()
	else:
		swiped_right.emit()
