extends Node2D
class_name MarketCustomer

var resource_name: String
var texture_path: String
var market_manager = null
var queue_position := Vector2.ZERO
var stall_position := Vector2.ZERO
var exit_position := Vector2.ZERO
var state := "queue"
var pause_left := 0.8
var speed := 76.0
var walk_time := 0.0
var sprite: Sprite2D
var label: Label
var shadow: Polygon2D

func setup(resource: String, path: String, manager, queue_pos: Vector2, stall_pos: Vector2, exit_pos: Vector2) -> void:
    resource_name = resource
    texture_path = path
    market_manager = manager
    queue_position = queue_pos
    stall_position = stall_pos
    exit_position = exit_pos
    position = queue_position

func _ready() -> void:
    z_index = 12
    shadow = Polygon2D.new()
    shadow.polygon = _ellipse_points(Vector2.ZERO, Vector2(34, 12), 20)
    shadow.color = Color(0.08, 0.04, 0.02, 0.30)
    shadow.position = Vector2(7, 5)
    shadow.z_index = -1
    add_child(shadow)

    sprite = Sprite2D.new()
    sprite.texture = load(texture_path)
    sprite.scale = Vector2(0.76, 0.76)
    sprite.position = Vector2(0, -76)
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    add_child(sprite)

    label = Label.new()
    label.position = Vector2(-78, -156)
    label.size = Vector2(156, 42)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 20)
    label.add_theme_color_override("font_color", Color("422414"))
    var style := StyleBoxFlat.new()
    style.bg_color = Color(1.0, 0.96, 0.82, 0.96)
    style.corner_radius_top_left = 16
    style.corner_radius_top_right = 16
    style.corner_radius_bottom_left = 16
    style.corner_radius_bottom_right = 16
    label.add_theme_stylebox_override("normal", style)
    add_child(label)

func _process(delta: float) -> void:
    walk_time += delta
    _refresh_label()
    match state:
        "queue":
            pause_left -= delta
            if pause_left <= 0.0:
                state = "approach"
        "approach":
            if _walk_to(stall_position, delta):
                state = "buy"
                pause_left = 1.1
        "buy":
            pause_left -= delta
            sprite.position.y = -76.0 + sin(walk_time * 5.0) * 1.2
            if pause_left <= 0.0:
                state = "leave"
        "leave":
            if _walk_to(exit_position, delta):
                state = "return"
        "return":
            if _walk_to(queue_position, delta):
                state = "queue"
                pause_left = 0.7 + float(resource_name.length() % 4) * 0.22

func _walk_to(target: Vector2, delta: float) -> bool:
    var offset := target - position
    var distance := offset.length()
    if distance <= speed * delta:
        position = target
        sprite.position.y = -76.0
        return true
    var direction := offset / distance
    position += direction * speed * delta
    sprite.flip_h = direction.x < 0.0
    var stride := sin(walk_time * 10.0)
    sprite.position.y = -76.0 - absf(stride) * 1.1
    sprite.rotation = stride * 0.010
    shadow.scale.x = 1.0 - absf(stride) * 0.06
    return false

func _refresh_label() -> void:
    if not market_manager or not market_manager.lanes.has(resource_name):
        return
    var lane: Dictionary = market_manager.lanes[resource_name]
    label.text = "%s ×%d" % [resource_name.capitalize(), int(lane["remaining"])]

func _ellipse_points(center: Vector2, radius: Vector2, count: int) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in range(count):
        var angle := TAU * float(i) / float(count)
        points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
    return points
