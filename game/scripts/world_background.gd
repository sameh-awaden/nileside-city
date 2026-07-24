extends Node2D

const WORLD_RECT := Rect2(-2200.0, -3000.0, 4400.0, 6000.0)

func _ready() -> void:
    z_index = -100
    queue_redraw()

func _draw() -> void:
    # Continuous terrain. No floating platforms or disconnected islands.
    draw_rect(WORLD_RECT, Color("d9a95f"), true)

    # Soft sand bands and irrigated land.
    draw_rect(Rect2(-2200, -3000, 640, 6000), Color("2e8c9e"), true)
    draw_rect(Rect2(-1560, -3000, 90, 6000), Color("76b9aa"), true)
    draw_rect(Rect2(-1470, -3000, 210, 6000), Color("bad29b"), true)
    draw_rect(Rect2(-1260, -3000, 220, 6000), Color("c7c985"), true)

    # Nile water streaks.
    for y in range(-2900, 3000, 150):
        draw_line(Vector2(-2160, y), Vector2(-1600, y + 40), Color(0.75, 0.94, 0.95, 0.22), 5.0)

    # Main roads, drawn below gameplay sprites.
    var road_color := Color("e8c882")
    var road_edge := Color("a7643f")
    _draw_road(PackedVector2Array([
        Vector2(-700, 2400), Vector2(-650, 900), Vector2(0, 300), Vector2(0, -2500)
    ]), road_edge, 170.0)
    _draw_road(PackedVector2Array([
        Vector2(-1200, 200), Vector2(0, 300), Vector2(1250, 250)
    ]), road_edge, 170.0)
    _draw_road(PackedVector2Array([
        Vector2(-700, 2400), Vector2(-650, 900), Vector2(0, 300), Vector2(0, -2500)
    ]), road_color, 148.0)
    _draw_road(PackedVector2Array([
        Vector2(-1200, 200), Vector2(0, 300), Vector2(1250, 250)
    ]), road_color, 148.0)

    # City plaza.
    draw_circle(Vector2.ZERO, 520.0, Color("dfbd73"))
    draw_arc(Vector2.ZERO, 520.0, 0.0, TAU, 96, Color("945333"), 15.0, true)
    draw_circle(Vector2.ZERO, 365.0, Color("e8cc8b"))
    draw_arc(Vector2.ZERO, 365.0, 0.0, TAU, 80, Color("c08752"), 8.0, true)

    # Decorative paving pattern, light enough not to distract.
    for x in range(-420, 421, 105):
        for y in range(-420, 421, 105):
            if Vector2(x, y).length() < 340.0:
                var diamond := PackedVector2Array([
                    Vector2(x, y - 18), Vector2(x + 18, y),
                    Vector2(x, y + 18), Vector2(x - 18, y)
                ])
                draw_polyline(diamond, Color(0.16, 0.45, 0.55, 0.23), 3.0, true)
                draw_line(diamond[3], diamond[0], Color(0.16, 0.45, 0.55, 0.23), 3.0, true)

    # Random-looking but fixed sand dots.
    var rng := RandomNumberGenerator.new()
    rng.seed = 912733
    for i in range(420):
        var p := Vector2(rng.randf_range(-2100, 2100), rng.randf_range(-2950, 2950))
        if p.x > -1450:
            draw_circle(p, rng.randf_range(1.0, 4.0), Color(0.45, 0.25, 0.12, 0.13))

func _draw_road(points: PackedVector2Array, color: Color, width: float) -> void:
    draw_polyline(points, color, width, true)
