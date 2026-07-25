extends Node2D

const WORLD_RECT := Rect2(-2200.0, -3000.0, 4400.0, 6000.0)
const MAIN_ROAD := PackedVector2Array([
    Vector2(-700, 2400), Vector2(-650, 900), Vector2(0, 300), Vector2(0, -2500)
])
const CROSS_ROAD := PackedVector2Array([
    Vector2(-1200, 200), Vector2(0, 300), Vector2(1250, 250)
])

func _ready() -> void:
    z_index = -100
    _add_tiled_ground()
    _add_textured_road(MAIN_ROAD)
    _add_textured_road(CROSS_ROAD)
    queue_redraw()

func _add_tiled_ground() -> void:
    var ground := TextureRect.new()
    ground.position = WORLD_RECT.position
    ground.size = WORLD_RECT.size
    ground.texture = load("res://assets/terrain/sand_texture.webp")
    ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    ground.stretch_mode = TextureRect.STRETCH_TILE
    ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ground.z_index = -20
    add_child(ground)

func _add_textured_road(points: PackedVector2Array) -> void:
    var edge := Line2D.new()
    edge.points = points
    edge.width = 188.0
    edge.default_color = Color("9c603c")
    edge.joint_mode = Line2D.LINE_JOINT_ROUND
    edge.begin_cap_mode = Line2D.LINE_CAP_ROUND
    edge.end_cap_mode = Line2D.LINE_CAP_ROUND
    edge.z_index = -12
    add_child(edge)

    var road := Line2D.new()
    road.points = points
    road.width = 164.0
    road.texture = load("res://assets/terrain/road_texture.webp")
    road.texture_mode = Line2D.LINE_TEXTURE_TILE
    road.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    road.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    road.default_color = Color(1.0, 0.94, 0.82, 1.0)
    road.joint_mode = Line2D.LINE_JOINT_ROUND
    road.begin_cap_mode = Line2D.LINE_CAP_ROUND
    road.end_cap_mode = Line2D.LINE_CAP_ROUND
    road.z_index = -11
    add_child(road)

func _draw() -> void:
    # Nile and irrigated farmland use layered color plus drawn detail over the sand tile.
    draw_rect(Rect2(-2200, -3000, 640, 6000), Color("2e8c9e"), true)
    draw_rect(Rect2(-1560, -3000, 90, 6000), Color("76b9aa"), true)
    draw_rect(Rect2(-1470, -3000, 210, 6000), Color("a9c88f"), true)
    draw_rect(Rect2(-1260, -3000, 220, 6000), Color("c3c982"), true)

    for y in range(-2900, 3000, 150):
        draw_line(Vector2(-2160, y), Vector2(-1600, y + 40), Color(0.75, 0.94, 0.95, 0.24), 5.0)
    for y in range(-2960, 3000, 72):
        draw_line(Vector2(-1460, y), Vector2(-1050, y + 8), Color(0.20, 0.36, 0.16, 0.16), 3.0)

    # Textured-looking plaza made from warm paver cells rather than flat circles.
    draw_circle(Vector2.ZERO, 535.0, Color("a76742"))
    draw_circle(Vector2.ZERO, 516.0, Color("d8b674"))
    draw_circle(Vector2.ZERO, 378.0, Color("e1c58a"))
    for x in range(-455, 456, 70):
        for y in range(-455, 456, 56):
            var p := Vector2(x + (28 if int(y / 56) % 2 else 0), y)
            if p.length() < 485.0:
                var shade := 0.90 + float((abs(x + y) / 7) % 5) * 0.018
                draw_rect(Rect2(p - Vector2(30, 23), Vector2(60, 46)), Color(0.80 * shade, 0.65 * shade, 0.40 * shade, 0.72), true)
                draw_rect(Rect2(p - Vector2(30, 23), Vector2(60, 46)), Color(0.43, 0.28, 0.15, 0.22), false, 2.0)

    var rng := RandomNumberGenerator.new()
    rng.seed = 912733
    for i in range(260):
        var p := Vector2(rng.randf_range(-2100, 2100), rng.randf_range(-2950, 2950))
        if p.x > -1450:
            draw_circle(p, rng.randf_range(1.0, 3.0), Color(0.40, 0.23, 0.10, 0.10))
