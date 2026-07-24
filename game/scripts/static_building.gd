extends Node2D
class_name StaticBuilding

signal selected(building)

var building_type: String = "warehouse"
var display_name: String = "Warehouse"
var texture_path: String = ""
var visual_scale: float = 0.9
var _sprite: Sprite2D
var _label: Label

func setup(kind: String, title: String, path: String, scale_value: float = 0.9) -> void:
    building_type = kind
    display_name = title
    texture_path = path
    visual_scale = scale_value

func _ready() -> void:
    y_sort_enabled = true
    z_index = 5

    var shadow := Polygon2D.new()
    shadow.polygon = _ellipse_points(Vector2.ZERO, Vector2(120, 40), 30)
    shadow.color = Color(0.06, 0.03, 0.02, 0.28)
    shadow.position = Vector2(0, 37)
    shadow.z_index = -1
    add_child(shadow)

    _sprite = Sprite2D.new()
    _sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    add_child(_sprite)

    _label = Label.new()
    _label.add_theme_font_size_override("font_size", 25)
    _label.add_theme_color_override("font_color", Color("fff0bd"))
    _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _label.position = Vector2(-125, 55)
    _label.size = Vector2(250, 42)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.04, 0.10, 0.14, 0.92)
    style.corner_radius_top_left = 15
    style.corner_radius_top_right = 15
    style.corner_radius_bottom_left = 15
    style.corner_radius_bottom_right = 15
    _label.add_theme_stylebox_override("normal", style)
    add_child(_label)

    var area := Area2D.new()
    area.input_pickable = true
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(280, 240)
    shape.shape = rect
    shape.position = Vector2(0, -35)
    area.add_child(shape)
    area.input_event.connect(_on_input_event)
    add_child(area)

    GameState.city_changed.connect(refresh)
    GameState.economy_changed.connect(refresh)
    refresh()

func refresh() -> void:
    if not is_node_ready():
        return
    var path := texture_path
    match building_type:
        "palace":
            path = "res://assets/buildings/palace%d.png" % mini(5, GameState.city_level)
            _label.text = "PALACE  CITY %d" % GameState.city_level
        "market":
            path = "res://assets/buildings/market%d.png" % mini(4, GameState.market_level)
            _label.text = "TRADE MARKET  L%d" % GameState.market_level
        "warehouse":
            _label.text = "CITY WAREHOUSE"
        "logistics":
            _label.text = "LOGISTICS  L%d" % GameState.hauler_level
        _:
            _label.text = display_name.to_upper()
    if path != "" and (_sprite.texture == null or _sprite.texture.resource_path != path):
        _sprite.texture = load(path)
    var rendered_scale := visual_scale * 1.72
    _sprite.scale = Vector2.ONE * rendered_scale
    _sprite.position.y = -maxf(45.0, (_sprite.texture.get_height() if _sprite.texture else 180) * rendered_scale * 0.37)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
    var activate := false
    if event is InputEventScreenTouch and event.pressed:
        activate = true
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        activate = true
    if activate:
        selected.emit(self)
        get_viewport().set_input_as_handled()

func _ellipse_points(center: Vector2, radius: Vector2, count: int) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in range(count):
        var angle := TAU * float(i) / float(count)
        points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
    return points
