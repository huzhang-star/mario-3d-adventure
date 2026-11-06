extends Control

signal value_changed(value: Vector2)

@export var radius := 78.0
@export var knob_radius := 32.0

var _value := Vector2.ZERO
var _dragging := false
var _touch_index := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(radius * 2.0 + 20.0, radius * 2.0 + 20.0)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not _dragging and _inside_pad(event.position):
			_touch_index = event.index
			_dragging = true
			_update_value(event.position)
			accept_event()
		elif not event.pressed and _dragging and event.index == _touch_index:
			_release_stick()
			accept_event()
		return

	if event is InputEventScreenDrag and _dragging and event.index == _touch_index:
		_update_value(event.position)
		accept_event()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not _dragging and _inside_pad(event.position):
			_dragging = true
			_update_value(event.position)
			accept_event()
		elif not event.pressed and _dragging:
			_release_stick()
			accept_event()
		return

	if event is InputEventMouseMotion and _dragging:
		_update_value(event.position)
		accept_event()

func _exit_tree() -> void:
	_release_stick()

func _inside_pad(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= radius + 18.0

func _update_value(point: Vector2) -> void:
	var centre := size * 0.5
	var offset := point - centre
	if offset.length() > radius:
		offset = offset.normalized() * radius
	_value = Vector2(offset.x, -offset.y) / radius
	if _value.length() < 0.12:
		_value = Vector2.ZERO
	value_changed.emit(_value)
	queue_redraw()

func _release_stick() -> void:
	if not _dragging and _value == Vector2.ZERO:
		return
	_dragging = false
	_touch_index = -1
	_value = Vector2.ZERO
	value_changed.emit(_value)
	queue_redraw()

func _draw() -> void:
	var centre := size * 0.5
	draw_circle(centre, radius + 7.0, Color(0.02, 0.07, 0.09, 0.18))
	draw_circle(centre, radius, Color(0.035, 0.11, 0.14, 0.64))
	draw_arc(centre, radius, 0.0, TAU, 64, Color(0.74, 0.94, 0.95, 0.42), 2.0, true)
	draw_circle(centre + Vector2(_value.x, -_value.y) * radius, knob_radius, Color(0.95, 0.63, 0.20, 0.95))
	draw_arc(centre + Vector2(_value.x, -_value.y) * radius, knob_radius, 0.0, TAU, 48, Color(1.0, 0.92, 0.61, 0.9), 2.0, true)
