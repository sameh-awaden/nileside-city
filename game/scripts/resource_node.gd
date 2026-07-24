extends Node2D
class_name ResourceNode

var resource_type: String = "wood"
var max_health: float = 5.0
var health: float = 5.0
var yield_per_hit: float = 1.0
var respawn_seconds: float = 18.0
var texture_path: String = ""
var visual_scale: float = 0.55
var active: bool = true
var _respawn_left: float = 0.0
var _sprite: Sprite2D
var _shadow: Polygon2D
var _hit_flash: float = 0.0

func setup(kind: String, path: String, hp: float, yield_value: float, respawn: float, scale_value: float = 0.55) -> void:
    resource_type = kind
    texture_path = path
    max_health = hp
    health = hp
    yield_per_hit = yield_value
    respawn_seconds = respawn
    visual_scale = scale_value

func _ready() -> void:
    add_to_group("resource_nodes")
    y_sort_enabled = true

    _shadow = Polygon2D.new()
    _shadow.polygon = _ellipse_points(Vector2.ZERO, Vector2(74, 25), 24)
    _shadow.color = Color(0.15, 0.10, 0.06, 0.22)
    _shadow.position = Vector2(0, 24)
    _shadow.z_index = -1
    add_child(_shadow)

    _sprite = Sprite2D.new()
    if texture_path != "":
        _sprite.texture = load(texture_path)
    _sprite.scale = Vector2.ONE * visual_scale * 1.82
    _sprite.position.y = -maxf(15.0, (_sprite.texture.get_height() if _sprite.texture else 100) * visual_scale * 1.82 * 0.35)
    match resource_type:
        "stone":
            _sprite.modulate = Color(0.78, 0.82, 0.88, 1.0)
        "grain":
            _sprite.modulate = Color(1.0, 0.82, 0.34, 1.0)
        "clay":
            _sprite.modulate = Color(0.82, 0.40, 0.26, 1.0)
        "papyrus":
            _sprite.modulate = Color(0.62, 0.90, 0.58, 1.0)
        "dates":
            _sprite.modulate = Color(1.0, 0.72, 0.45, 1.0)
    add_child(_sprite)
    queue_redraw()

func _process(delta: float) -> void:
    if not active:
        _respawn_left -= delta
        if _respawn_left <= 0.0:
            _respawn()
        return

    if _hit_flash > 0.0:
        _hit_flash -= delta
        if _sprite:
            _sprite.modulate = Color(1.0, 0.75, 0.55, 1.0) if _hit_flash > 0.0 else Color.WHITE

func harvest(power: float) -> Dictionary:
    if not active:
        return {"resource": resource_type, "amount": 0.0, "depleted": false}

    var damage: float = maxf(0.1, power)
    health -= damage
    _hit_flash = 0.09
    if _sprite:
        _sprite.modulate = Color(1.0, 0.75, 0.55, 1.0)
        var tween := create_tween()
        tween.tween_property(_sprite, "rotation", 0.06, 0.04)
        tween.tween_property(_sprite, "rotation", -0.05, 0.04)
        tween.tween_property(_sprite, "rotation", 0.0, 0.05)

    var amount: float = yield_per_hit * damage
    var depleted: bool = health <= 0.0
    if depleted:
        amount += yield_per_hit * 1.5
        _deplete()
    _spawn_floating_text("+%d" % int(round(amount)))
    queue_redraw()
    return {"resource": resource_type, "amount": amount, "depleted": depleted}

func _deplete() -> void:
    active = false
    _respawn_left = respawn_seconds
    if _sprite:
        var tween := create_tween()
        tween.tween_property(_sprite, "scale", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_BACK)
    if _shadow:
        _shadow.visible = false

func _respawn() -> void:
    active = true
    health = max_health
    if _shadow:
        _shadow.visible = true
    if _sprite:
        _sprite.scale = Vector2.ZERO
        _sprite.visible = true
        var tween := create_tween()
        tween.tween_property(_sprite, "scale", Vector2.ONE * visual_scale * 1.82, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    queue_redraw()

func _draw() -> void:
    if not active:
        return
    var ratio: float = clampf(health / max_health, 0.0, 1.0)
    if ratio < 0.999:
        draw_arc(Vector2(0, 38), 27.0, PI, TAU, 24, Color(0.12, 0.08, 0.05, 0.55), 7.0, true)
        draw_arc(Vector2(0, 38), 27.0, PI, PI + PI * ratio, 24, Color("62b45f"), 7.0, true)

func _spawn_floating_text(text_value: String) -> void:
    var label := Label.new()
    label.text = text_value
    label.position = Vector2(-22, -105)
    label.z_index = 30
    label.add_theme_font_size_override("font_size", 26)
    label.add_theme_color_override("font_color", Color("fff2bf"))
    label.add_theme_color_override("font_shadow_color", Color(0.08, 0.04, 0.02, 0.85))
    label.add_theme_constant_override("shadow_offset_x", 2)
    label.add_theme_constant_override("shadow_offset_y", 3)
    add_child(label)
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(label, "position:y", label.position.y - 42.0, 0.55)
    tween.tween_property(label, "modulate:a", 0.0, 0.55)
    tween.chain().tween_callback(label.queue_free)

func _ellipse_points(center: Vector2, radius: Vector2, count: int) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in range(count):
        var angle := TAU * float(i) / float(count)
        points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
    return points
