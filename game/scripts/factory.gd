extends Node2D
class_name ProductionFactory

signal selected(factory)
signal state_changed

var factory_id: String = "sawmill"
var display_name: String = "Sawmill"
var input_resource: String = "wood"
var output_resource: String = "timber"
var input_amount: float = 2.0
var output_amount: float = 2.0
var base_cycle_seconds: float = 4.0
var unlock_city_level: int = 2
var level: int = 0
var output_buffer: float = 0.0
var texture_path: String = ""
var visual_scale: float = 0.85
var cycle_progress: float = 0.0
var conveyor_level: int = 0

var _sprite: Sprite2D
var _shadow: Polygon2D
var _name_label: Label
var _buffer_label: Label
var _area: Area2D
var _locked_label: Label
var _status_label: Label

const LEVEL_MULTIPLIERS: Array[float] = [0.0, 1.0, 1.7, 2.7, 4.2, 6.5, 10.0, 15.0, 22.0, 32.0, 46.0]

func setup(config: Dictionary) -> void:
    factory_id = String(config.get("id", factory_id))
    display_name = String(config.get("name", display_name))
    input_resource = String(config.get("input", input_resource))
    output_resource = String(config.get("output", output_resource))
    input_amount = float(config.get("input_amount", input_amount))
    output_amount = float(config.get("output_amount", output_amount))
    base_cycle_seconds = float(config.get("cycle", base_cycle_seconds))
    unlock_city_level = int(config.get("unlock", unlock_city_level))
    texture_path = String(config.get("texture", texture_path))
    visual_scale = float(config.get("scale", visual_scale))

func _ready() -> void:
    add_to_group("factories")
    y_sort_enabled = true

    _shadow = Polygon2D.new()
    _shadow.polygon = _ellipse_points(Vector2.ZERO, Vector2(150, 38), 30)
    _shadow.color = Color(0.06, 0.03, 0.02, 0.28)
    _shadow.position = Vector2(18, 8)
    _shadow.z_index = -1
    add_child(_shadow)

    _sprite = Sprite2D.new()
    if texture_path != "":
        _sprite.texture = load(texture_path)
    _apply_safe_region_crop()
    var rendered_scale := visual_scale * 1.25
    _sprite.scale = Vector2.ONE * rendered_scale
    _sprite.position.y = -maxf(40.0, (_sprite.texture.get_height() if _sprite.texture else 150) * rendered_scale * 0.50)
    _sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    add_child(_sprite)

    _name_label = _make_label(24, Color("fff0bd"), Color(0.04, 0.10, 0.14, 0.94))
    _name_label.position = Vector2(-115, 48)
    _name_label.size = Vector2(230, 42)
    _name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(_name_label)

    _buffer_label = _make_label(19, Color.WHITE, Color(0.04, 0.10, 0.14, 0.82))
    _buffer_label.position = Vector2(-76, 91)
    _buffer_label.size = Vector2(152, 34)
    _buffer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(_buffer_label)

    _locked_label = _make_label(20, Color("ffdf8c"), Color(0.18, 0.08, 0.03, 0.92))
    _locked_label.position = Vector2(-98, -30)
    _locked_label.size = Vector2(196, 42)
    _locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(_locked_label)

    _status_label = _make_label(19, Color("fff3cb"), Color(0.50, 0.18, 0.06, 0.96))
    var texture_height := float(_sprite.texture.get_height() if _sprite.texture else 180)
    var status_y := _sprite.position.y - texture_height * rendered_scale * 0.46 - 44.0
    _status_label.position = Vector2(-132, status_y)
    _status_label.size = Vector2(264, 40)
    _status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status_label.visible = false
    add_child(_status_label)

    _area = Area2D.new()
    _area.input_pickable = true
    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(230, 190)
    shape.shape = rectangle
    shape.position = Vector2(0, -35)
    _area.add_child(shape)
    _area.input_event.connect(_on_input_event)
    add_child(_area)

    GameState.city_changed.connect(_refresh_visuals)
    _refresh_visuals()

func _apply_safe_region_crop() -> void:
    if not _sprite or not _sprite.texture:
        return
    var left_margin: float = 0.0
    var right_margin: float = 0.0
    if texture_path.ends_with("/bakery.webp"):
        left_margin = 24.0
    elif texture_path.ends_with("/sawmill.webp"):
        right_margin = 24.0
    elif texture_path.ends_with("/pottery.webp"):
        right_margin = 28.0
    elif texture_path.ends_with("/scribe.webp"):
        left_margin = 20.0
        right_margin = 12.0
    if left_margin <= 0.0 and right_margin <= 0.0:
        _sprite.region_enabled = false
        return
    var texture_size: Vector2 = _sprite.texture.get_size()
    _sprite.region_enabled = true
    _sprite.region_rect = Rect2(
        left_margin,
        0.0,
        maxf(1.0, texture_size.x - left_margin - right_margin),
        texture_size.y
    )


func _process(delta: float) -> void:
    if not is_unlocked() or level <= 0:
        return

    cycle_progress += delta * float(GameState.tuning["production_multiplier"]) * GameState.production_efficiency()
    var cycle: float = effective_cycle_seconds()
    while cycle_progress >= cycle:
        cycle_progress -= cycle
        _try_produce()

    _update_labels()

func is_unlocked() -> bool:
    return GameState.city_level >= unlock_city_level

func storage_capacity() -> float:
    if level <= 0:
        return 0.0
    return 80.0 + pow(float(level), 1.55) * 42.0

func effective_cycle_seconds() -> float:
    return maxf(0.55, base_cycle_seconds * pow(0.94, float(maxi(0, level - 1))))

func production_multiplier() -> float:
    return LEVEL_MULTIPLIERS[clampi(level, 0, 10)]

func output_per_cycle() -> float:
    return output_amount * production_multiplier()

func production_per_minute() -> float:
    if level <= 0:
        return 0.0
    return output_per_cycle() * 60.0 / effective_cycle_seconds() * float(GameState.tuning["production_multiplier"]) * GameState.production_efficiency()

func _try_produce() -> void:
    if output_buffer >= storage_capacity() - 0.001:
        return
    var multiplier: float = production_multiplier()
    var needed: float = input_amount * maxf(1.0, sqrt(multiplier))
    if not GameState.take_resource(input_resource, needed):
        return
    var produced: float = minf(output_per_cycle(), storage_capacity() - output_buffer)
    output_buffer += produced
    state_changed.emit()
    _pulse_sprite()

func take_output(max_amount: float) -> float:
    var amount: float = minf(max_amount, output_buffer)
    output_buffer -= amount
    if amount > 0.0:
        state_changed.emit()
    return amount

func factory_upgrade_cost() -> Dictionary:
    var next := level + 1
    if next > 10:
        return {}
    var base_coin := 450.0 + float(unlock_city_level - 1) * 500.0
    return {
        "coins": round(base_coin * pow(1.78, float(next - 1))),
        "timber": round(4.0 * pow(1.55, float(next - 1))),
        "bricks": round(5.0 * pow(1.55, float(next - 1))),
        "blocks": round(2.0 * pow(1.52, float(next - 1))),
    }

func maximum_level_for_city() -> int:
    return [1, 2, 4, 5, 6, 8, 10][GameState.city_level - 1]

func can_upgrade() -> bool:
    if not is_unlocked() or level >= maximum_level_for_city():
        return false
    var cost: Dictionary = factory_upgrade_cost()
    return GameState.coins >= float(cost["coins"]) \
        and GameState.can_take("timber", float(cost["timber"])) \
        and GameState.can_take("bricks", float(cost["bricks"])) \
        and GameState.can_take("blocks", float(cost["blocks"]))

func upgrade() -> bool:
    if not can_upgrade():
        return false
    var cost: Dictionary = factory_upgrade_cost()
    GameState.spend_coins(float(cost["coins"]))
    GameState.take_resource("timber", float(cost["timber"]))
    GameState.take_resource("bricks", float(cost["bricks"]))
    GameState.take_resource("blocks", float(cost["blocks"]))
    level += 1
    state_changed.emit()
    _refresh_visuals()
    _pulse_sprite(1.16)
    return true

func conveyor_upgrade_cost() -> Dictionary:
    var next := conveyor_level + 1
    if next > 5:
        return {}
    return {
        "coins": round(1800.0 * pow(2.15, float(next - 1))),
        "timber": round(25.0 * pow(1.75, float(next - 1))),
        "bricks": round(18.0 * pow(1.72, float(next - 1))),
        "blocks": round(12.0 * pow(1.65, float(next - 1))),
    }

func can_upgrade_conveyor() -> bool:
    if GameState.city_level < 5 or level <= 0 or conveyor_level >= 5:
        return false
    var cost: Dictionary = conveyor_upgrade_cost()
    return GameState.coins >= float(cost["coins"]) \
        and GameState.can_take("timber", float(cost["timber"])) \
        and GameState.can_take("bricks", float(cost["bricks"])) \
        and GameState.can_take("blocks", float(cost["blocks"]))

func upgrade_conveyor() -> bool:
    if not can_upgrade_conveyor():
        return false
    var cost: Dictionary = conveyor_upgrade_cost()
    GameState.spend_coins(float(cost["coins"]))
    GameState.take_resource("timber", float(cost["timber"]))
    GameState.take_resource("bricks", float(cost["bricks"]))
    GameState.take_resource("blocks", float(cost["blocks"]))
    conveyor_level += 1
    state_changed.emit()
    return true

func simulate_offline(seconds: float) -> void:
    if level <= 0 or not is_unlocked():
        return
    var cycles: float = floor(seconds / effective_cycle_seconds() * float(GameState.tuning["production_multiplier"]) * GameState.production_efficiency())
    if cycles <= 0.0:
        return
    var multiplier: float = production_multiplier()
    var needed_each: float = input_amount * maxf(1.0, sqrt(multiplier))
    var possible_by_input: float = floor(GameState.amount(input_resource) / needed_each)
    var actual_cycles: float = minf(cycles, possible_by_input)
    if actual_cycles <= 0.0:
        return
    var possible_output: float = minf(actual_cycles * output_per_cycle(), storage_capacity() - output_buffer)
    var actual_needed: float = ceil(possible_output / output_per_cycle()) * needed_each
    if GameState.take_resource(input_resource, actual_needed):
        output_buffer += possible_output

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
    var activate := false
    if event is InputEventScreenTouch and event.pressed:
        activate = true
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        activate = true
    if activate:
        selected.emit(self)
        get_viewport().set_input_as_handled()

func _refresh_visuals() -> void:
    if not is_node_ready():
        return
    if is_unlocked() and level == 0:
        level = 1
    _sprite.modulate = Color.WHITE if is_unlocked() else Color(0.36, 0.39, 0.43, 0.64)
    _locked_label.visible = not is_unlocked()
    _locked_label.text = "UNLOCKS AT CITY %d" % unlock_city_level
    _update_labels()

func _update_labels() -> void:
    if not is_node_ready():
        return
    _name_label.text = "%s  L%d" % [display_name.to_upper(), level]
    _buffer_label.text = "%s  %d/%d" % [output_resource.to_upper(), int(output_buffer), int(storage_capacity())]
    _buffer_label.visible = level > 0

    _status_label.visible = false
    if level > 0 and is_unlocked():
        var needed_input := input_amount * maxf(1.0, sqrt(production_multiplier()))
        if output_buffer >= storage_capacity() * 0.94:
            _status_label.text = "STORAGE FULL"
            _status_label.visible = true
        elif GameState.amount(input_resource) < needed_input:
            _status_label.text = "NEEDS %s" % input_resource.to_upper()
            _status_label.visible = true

func _pulse_sprite(target_scale: float = 1.06) -> void:
    if not _sprite:
        return
    var base := Vector2.ONE * visual_scale * 1.25
    var tween := create_tween()
    tween.tween_property(_sprite, "scale", base * target_scale, 0.09)
    tween.tween_property(_sprite, "scale", base, 0.13).set_trans(Tween.TRANS_BACK)

func _make_label(font_size: int, color: Color, background: Color) -> Label:
    var label := Label.new()
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.corner_radius_top_left = 14
    style.corner_radius_top_right = 14
    style.corner_radius_bottom_left = 14
    style.corner_radius_bottom_right = 14
    style.content_margin_left = 8
    style.content_margin_right = 8
    style.content_margin_top = 3
    style.content_margin_bottom = 3
    label.add_theme_stylebox_override("normal", style)
    return label

func _ellipse_points(center: Vector2, radius: Vector2, count: int) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in range(count):
        var angle := TAU * float(i) / float(count)
        points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
    return points
