extends Node2D

const WORLD_RECT := Rect2(-2200.0, -3000.0, 4400.0, 6000.0)
var main_road := PackedVector2Array([
    Vector2(-700, 2400), Vector2(-650, 900), Vector2(0, 300), Vector2(0, -2500)
])
var cross_road := PackedVector2Array([
    Vector2(-1200, 200), Vector2(0, 300), Vector2(1250, 250)
])

func _ready() -> void:
    z_index = -100
    _add_tiled_ground()
    _add_water_and_fields()
    _add_textured_road(main_road)
    _add_textured_road(cross_road)
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

func _add_water_and_fields() -> void:
    var water := ColorRect.new()
    water.position = Vector2(-2200, -3000)
    water.size = Vector2(640, 6000)
    water.color = Color("2f9eb5")
    water.mouse_filter = Control.MOUSE_FILTER_IGNORE
    water.z_index = -19
    add_child(water)

    var river_bank := ColorRect.new()
    river_bank.position = Vector2(-1560, -3000)
    river_bank.size = Vector2(90, 6000)
    river_bank.color = Color("78b9a8")
    river_bank.mouse_filter = Control.MOUSE_FILTER_IGNORE
    river_bank.z_index = -18
    add_child(river_bank)

    var field_texture: Texture2D = load("res://assets/terrain/sand_texture.webp")
    for field_data in [
        {"rect": Rect2(-1470, -3000, 210, 6000), "color": Color(0.58, 0.76, 0.47, 0.88)},
        {"rect": Rect2(-1260, -3000, 220, 6000), "color": Color(0.69, 0.73, 0.35, 0.88)}
    ]:
        var field := TextureRect.new()
        field.position = field_data["rect"].position
        field.size = field_data["rect"].size
        field.texture = field_texture
        field.modulate = field_data["color"]
        field.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
        field.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
        field.stretch_mode = TextureRect.STRETCH_TILE
        field.mouse_filter = Control.MOUSE_FILTER_IGNORE
        field.z_index = -18
        add_child(field)

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

    for y in range(-2940, 3000, 92):
        var wave_points := PackedVector2Array()
        for x in range(-2180, -1580, 36):
            var wave_y: float = float(y) + sin(float(x + y) * 0.022) * 12.0
            wave_points.append(Vector2(float(x), wave_y))
        draw_polyline(wave_points, Color(0.78, 0.96, 0.98, 0.22), 4.0, true)

    var water_rng := RandomNumberGenerator.new()
    water_rng.seed = 44129
    for i in range(190):
        var sparkle := Vector2(water_rng.randf_range(-2170, -1590), water_rng.randf_range(-2980, 2980))
        draw_circle(sparkle, water_rng.randf_range(1.0, 3.5), Color(0.88, 1.0, 1.0, 0.16))
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
