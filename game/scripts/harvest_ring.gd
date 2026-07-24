extends Node2D

var radius: float = 145.0
var pulse: float = 0.0

func set_radius(value: float) -> void:
    if absf(value - radius) > 0.2:
        radius = value
        queue_redraw()

func _process(delta: float) -> void:
    pulse += delta
    queue_redraw()

func _draw() -> void:
    var alpha := 0.20 + sin(pulse * 2.5) * 0.035
    draw_circle(Vector2.ZERO, radius, Color(0.12, 0.64, 0.76, alpha * 0.18))
    draw_arc(Vector2.ZERO, radius, 0.0, TAU, 80, Color(0.20, 0.76, 0.88, alpha), 4.0, true)
