extends CharacterBody2D
class_name NilesidePlayer

signal harvested(resource_name: String, amount: float)

@export var move_speed: float = 410.0
@export var world_bounds := Rect2(-2050.0, -2850.0, 4100.0, 5700.0)

var active_pointer: int = -1
var pointer_origin := Vector2.ZERO
var pointer_position := Vector2.ZERO
var input_vector := Vector2.ZERO
var _mouse_dragging := false
var _walk_time: float = 0.0
var _harvest_time: float = 0.0
var _sickle_angle: float = 0.0
var _resource_rotation_index: int = 0

var body_sprite: Sprite2D
var shadow: Polygon2D
var harvest_ring: Node2D
var sickle_container: Node2D
var sickles: Array[Sprite2D] = []

const WALK_FRAMES: Array[int] = [0, 1, 2, 3, 2, 1]
const TYPE_ORDER := ["wood", "stone", "grain", "clay", "papyrus", "dates"]

func _ready() -> void:
    z_index = 20
    y_sort_enabled = true

    shadow = Polygon2D.new()
    shadow.polygon = _ellipse_points(Vector2.ZERO, Vector2(42, 17), 30)
    shadow.color = Color(0.06, 0.03, 0.02, 0.32)
    shadow.position = Vector2(0, 19)
    shadow.z_index = -1
    add_child(shadow)

    body_sprite = Sprite2D.new()
    body_sprite.texture = load("res://assets/characters/player_walk.png")
    body_sprite.hframes = 4
    body_sprite.frame = 1
    body_sprite.scale = Vector2(0.40, 0.40)
    body_sprite.position = Vector2(0, -79)
    body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    add_child(body_sprite)

    harvest_ring = Node2D.new()
    harvest_ring.set_script(preload("res://scripts/harvest_ring.gd"))
    add_child(harvest_ring)

    sickle_container = Node2D.new()
    sickle_container.z_index = 5
    add_child(sickle_container)
    _rebuild_sickles()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and active_pointer == -1:
            active_pointer = event.index
            pointer_origin = event.position
            pointer_position = event.position
            input_vector = Vector2.ZERO
            get_viewport().set_input_as_handled()
        elif not event.pressed and event.index == active_pointer:
            active_pointer = -1
            input_vector = Vector2.ZERO
            get_viewport().set_input_as_handled()

    elif event is InputEventScreenDrag and event.index == active_pointer:
        pointer_position = event.position
        input_vector = ((pointer_position - pointer_origin) / 95.0).limit_length(1.0)
        get_viewport().set_input_as_handled()

    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        _mouse_dragging = event.pressed
        if _mouse_dragging:
            pointer_origin = event.position
            pointer_position = event.position
        else:
            input_vector = Vector2.ZERO

    elif event is InputEventMouseMotion and _mouse_dragging:
        pointer_position = event.position
        input_vector = ((pointer_position - pointer_origin) / 95.0).limit_length(1.0)

func _physics_process(delta: float) -> void:
    _walk_time += delta
    _harvest_time += delta
    _sickle_angle += delta * sickle_spin_speed()

    velocity = input_vector * move_speed
    move_and_slide()
    global_position.x = clampf(global_position.x, world_bounds.position.x, world_bounds.end.x)
    global_position.y = clampf(global_position.y, world_bounds.position.y, world_bounds.end.y)

    _animate_body()
    _update_sickles()

    if _harvest_time >= harvest_interval():
        _harvest_time = 0.0
        _harvest_nearby_nodes()

func _animate_body() -> void:
    var moving := velocity.length_squared() > 36.0
    if moving:
        body_sprite.frame = WALK_FRAMES[int(_walk_time * 6.0) % WALK_FRAMES.size()]
        body_sprite.flip_h = velocity.x < -3.0
        body_sprite.position.y = -79.0
        body_sprite.rotation = 0.0
        body_sprite.scale = Vector2(0.40, 0.40)
        var stride := absf(sin(_walk_time * 6.0 * PI))
        shadow.scale = Vector2(1.0 - stride * 0.08, 1.0 - stride * 0.03)
        shadow.modulate.a = 0.92 - stride * 0.10
    else:
        body_sprite.frame = 1
        body_sprite.position.y = -79.0 + sin(_walk_time * 2.1) * 1.2
        body_sprite.rotation = 0.0
        body_sprite.scale = Vector2(0.40, 0.40)
        shadow.scale = Vector2.ONE
        shadow.modulate.a = 1.0

func harvest_radius() -> float:
    return 145.0 + float(GameState.sickle_level - 1) * 11.0

func sickle_count() -> int:
    return mini(12, 2 + GameState.sickle_level)

func sickle_spin_speed() -> float:
    return 2.2 + float(GameState.sickle_level) * 0.38

func harvest_interval() -> float:
    return maxf(0.12, 0.34 - float(GameState.sickle_level - 1) * 0.018)

func harvest_power() -> float:
    return (0.72 + float(GameState.sickle_level) * 0.28) * float(GameState.tuning["harvest_multiplier"])

func _rebuild_sickles() -> void:
    for sickle in sickles:
        sickle.queue_free()
    sickles.clear()

    for i in range(sickle_count()):
        var sprite := Sprite2D.new()
        sprite.texture = load("res://assets/resources/sickle.png")
        sprite.scale = Vector2(0.36, 0.36)
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
        sickle_container.add_child(sprite)
        sickles.append(sprite)

func _update_sickles() -> void:
    if sickles.size() != sickle_count():
        _rebuild_sickles()
    var radius := harvest_radius() * 0.78
    for i in range(sickles.size()):
        var phase := _sickle_angle + TAU * float(i) / float(sickles.size())
        sickles[i].position = Vector2(cos(phase), sin(phase) * 0.58) * radius
        sickles[i].rotation = phase + PI * 0.5
        sickles[i].z_index = 4 if sin(phase) > 0.0 else -2
    if harvest_ring and harvest_ring.has_method("set_radius"):
        harvest_ring.set_radius(harvest_radius())

func _harvest_nearby_nodes() -> void:
    var nearby: Array = []
    var radius_sq := harvest_radius() * harvest_radius()
    for node in get_tree().get_nodes_in_group("resource_nodes"):
        if not is_instance_valid(node) or not node.active:
            continue
        var distance_sq: float = global_position.distance_squared_to(node.global_position)
        if distance_sq <= radius_sq:
            nearby.append({"node": node, "distance": distance_sq, "kind": node.resource_type})

    if nearby.is_empty():
        return

    # Round-robin across resource categories prevents palms from blocking reeds or clay.
    var selected: Array = []
    var used_nodes := {}
    var max_hits := mini(sickle_count(), nearby.size())
    var start := _resource_rotation_index % TYPE_ORDER.size()

    for offset in range(TYPE_ORDER.size()):
        var kind: String = TYPE_ORDER[(start + offset) % TYPE_ORDER.size()]
        var best = null
        for entry in nearby:
            var node = entry["node"]
            if entry["kind"] == kind and not used_nodes.has(node.get_instance_id()):
                if best == null or float(entry["distance"]) < float(best["distance"]):
                    best = entry
        if best != null:
            selected.append(best["node"])
            used_nodes[best["node"].get_instance_id()] = true
            if selected.size() >= max_hits:
                break

    if selected.size() < max_hits:
        nearby.sort_custom(func(a, b): return float(a["distance"]) < float(b["distance"]))
        for entry in nearby:
            var node = entry["node"]
            if not used_nodes.has(node.get_instance_id()):
                selected.append(node)
                used_nodes[node.get_instance_id()] = true
                if selected.size() >= max_hits:
                    break

    _resource_rotation_index = (_resource_rotation_index + 1) % TYPE_ORDER.size()
    for node in selected:
        var result: Dictionary = node.harvest(harvest_power())
        var amount: float = float(result.get("amount", 0.0))
        if amount > 0.0:
            GameState.add_resource(String(result["resource"]), amount)
            harvested.emit(String(result["resource"]), amount)

func _ellipse_points(center: Vector2, radius: Vector2, count: int) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in range(count):
        var angle := TAU * float(i) / float(count)
        points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
    return points
