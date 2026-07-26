extends Node2D
class_name HaulerWorker

var factories: Array = []
var warehouse_position := Vector2.ZERO
var speed: float = 190.0
var carry_capacity: float = 8.0
var carried_resource: String = ""
var carried_amount: float = 0.0
var target_factory = null
var state: String = "idle"
var idle_timer: float = 0.0
var _walk_time: float = 0.0
var _sprite: Sprite2D
var _shadow: Polygon2D
var _cargo_icon: Sprite2D

func setup(factory_nodes: Array, warehouse_pos: Vector2, spawn_position: Vector2) -> void:
    factories = factory_nodes
    warehouse_position = warehouse_pos
    global_position = spawn_position

func _ready() -> void:
    add_to_group("haulers")
    z_index = 15
    y_sort_enabled = true

    _shadow = Polygon2D.new()
    _shadow.polygon = _ellipse_points(Vector2.ZERO, Vector2(44, 15), 20)
    _shadow.color = Color(0.06, 0.03, 0.02, 0.28)
    _shadow.position = Vector2(0, 12)
    _shadow.z_index = -1
    add_child(_shadow)

    _sprite = Sprite2D.new()
    _sprite.texture = load("res://assets/characters/hauler_baskets.png")
    _sprite.scale = Vector2(0.62, 0.62)
    _sprite.position = Vector2(0, -72)
    _sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    add_child(_sprite)

    _cargo_icon = Sprite2D.new()
    _cargo_icon.scale = Vector2(0.28, 0.28)
    _cargo_icon.position = Vector2(0, -150)
    _cargo_icon.visible = false
    add_child(_cargo_icon)

func _process(delta: float) -> void:
    _walk_time += delta
    speed = (180.0 + float(GameState.hauler_level) * 28.0) * float(GameState.tuning["worker_speed_multiplier"]) * GameState.worker_efficiency()
    carry_capacity = 7.0 + float(GameState.hauler_level) * 5.0

    match state:
        "idle":
            idle_timer -= delta
            if idle_timer <= 0.0:
                _choose_factory()
        "to_factory":
            if not is_instance_valid(target_factory):
                state = "idle"
            elif _move_toward(target_factory.global_position, delta):
                _load_from_factory()
        "to_warehouse":
            if _move_toward(warehouse_position, delta):
                _deliver_to_warehouse()

    _animate()

func _choose_factory() -> void:
    var best = null
    var best_score := 0.0
    for candidate in factories:
        if not is_instance_valid(candidate) or candidate.level <= 0 or not candidate.is_unlocked():
            continue
        # Conveyors take over mature routes; haulers prioritize routes without belts.
        var score: float = float(candidate.output_buffer) / maxf(1.0, float(candidate.storage_capacity()))
        if candidate.conveyor_level > 0:
            score *= 0.28
        score -= global_position.distance_to(candidate.global_position) / 12000.0
        if candidate.output_buffer >= 1.0 and score > best_score:
            best_score = score
            best = candidate

    if best == null:
        idle_timer = 0.65
        state = "idle"
        return

    target_factory = best
    state = "to_factory"

func _load_from_factory() -> void:
    if not is_instance_valid(target_factory):
        state = "idle"
        return
    carried_amount = target_factory.take_output(carry_capacity)
    carried_resource = target_factory.output_resource
    if carried_amount <= 0.0:
        carried_resource = ""
        state = "idle"
        idle_timer = 0.4
        return
    _cargo_icon.texture = _texture_for_resource(carried_resource)
    _cargo_icon.visible = true
    state = "to_warehouse"

func _deliver_to_warehouse() -> void:
    if carried_amount > 0.0 and carried_resource != "":
        GameState.add_resource(carried_resource, carried_amount)
    carried_amount = 0.0
    carried_resource = ""
    _cargo_icon.visible = false
    state = "idle"
    idle_timer = 0.2

func _move_toward(target: Vector2, delta: float) -> bool:
    var offset := target - global_position
    var distance := offset.length()
    if distance <= maxf(8.0, speed * delta):
        global_position = target
        return true
    var direction := offset / distance
    global_position += direction * speed * delta
    if absf(direction.x) > 0.05:
        _sprite.scale.x = absf(_sprite.scale.x) * (1.0 if direction.x >= 0.0 else -1.0)
    return false

func _animate() -> void:
    var walking := state == "to_factory" or state == "to_warehouse"
    if walking:
        var bob := sin(_walk_time * 12.0)
        _sprite.position.y = -72.0 + bob * 2.8
        _sprite.rotation = sin(_walk_time * 6.0) * 0.022
        _cargo_icon.position.y = -150.0 + bob * 2.8
        _shadow.scale.x = 1.0 - absf(bob) * 0.08
    else:
        _sprite.position.y = -72.0 + sin(_walk_time * 2.0) * 1.0
        _sprite.rotation = 0.0
        _cargo_icon.position.y = -150.0
        _shadow.scale = Vector2.ONE

func _texture_for_resource(resource_name: String) -> Texture2D:
    var paths := {
        "timber": "res://assets/resources/timber.png",
        "blocks": "res://assets/resources/stone_blocks.png",
        "bread": "res://assets/resources/bread.png",
        "bricks": "res://assets/resources/bricks.png",
        "pottery": "res://assets/resources/pottery_icon.png",
        "scrolls": "res://assets/resources/scrolls.png",
    }
    return load(String(paths.get(resource_name, "res://assets/resources/timber.png")))

func _ellipse_points(center: Vector2, radius: Vector2, count: int) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in range(count):
        var angle := TAU * float(i) / float(count)
        points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
    return points
