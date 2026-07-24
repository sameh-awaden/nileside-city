extends Node2D
class_name FactoryConveyor

var factory = null
var warehouse_position := Vector2.ZERO
var route_points := PackedVector2Array()
var packets: Array = []
var spawn_timer: float = 0.0
var _icon_texture: Texture2D

func setup(factory_node, warehouse_pos: Vector2, optional_points: PackedVector2Array = PackedVector2Array()) -> void:
    factory = factory_node
    warehouse_position = warehouse_pos
    if optional_points.size() >= 2:
        route_points = optional_points
    else:
        route_points = PackedVector2Array([
            factory_node.global_position,
            Vector2(factory_node.global_position.x, warehouse_pos.y),
            warehouse_pos,
        ])

func _ready() -> void:
    z_index = -4
    _icon_texture = _texture_for_resource(factory.output_resource if factory else "timber")
    queue_redraw()

func _process(delta: float) -> void:
    if not factory or not is_instance_valid(factory) or factory.conveyor_level <= 0:
        packets.clear()
        visible = false
        return

    visible = true
    spawn_timer += delta
    var interval: float = maxf(0.18, 1.05 / (1.0 + float(factory.conveyor_level) * 0.65) / float(GameState.tuning["conveyor_speed_multiplier"]))
    if spawn_timer >= interval:
        spawn_timer = 0.0
        var capacity: float = 2.5 * pow(float(factory.conveyor_level), 1.42)
        var amount: float = float(factory.take_output(capacity))
        if amount > 0.0:
            packets.append({"progress": 0.0, "amount": amount})

    var travel_speed: float = (0.19 + float(factory.conveyor_level) * 0.055) * float(GameState.tuning["conveyor_speed_multiplier"])
    for packet in packets:
        packet["progress"] = float(packet["progress"]) + delta * travel_speed

    for i in range(packets.size() - 1, -1, -1):
        var packet: Dictionary = packets[i]
        if float(packet["progress"]) >= 1.0:
            GameState.add_resource(factory.output_resource, float(packet["amount"]))
            packets.remove_at(i)

    queue_redraw()

func _draw() -> void:
    if not factory or factory.conveyor_level <= 0 or route_points.size() < 2:
        return

    # Proper continuous belt with rails and slats - not disconnected decorative pieces.
    draw_polyline(route_points, Color(0.16, 0.10, 0.06, 0.72), 38.0, true)
    draw_polyline(route_points, Color("315c66"), 29.0, true)
    draw_polyline(route_points, Color("d39b38"), 4.0, true)

    var total_length: float = _path_length()
    var spacing: float = 42.0
    var slat_count := maxi(1, int(total_length / spacing))
    for i in range(slat_count + 1):
        var progress: float = float(i) / float(slat_count)
        var pos: Vector2 = _point_at(progress)
        var tangent: Vector2 = _tangent_at(progress)
        var normal: Vector2 = tangent.orthogonal().normalized()
        draw_line(pos - normal * 13.0, pos + normal * 13.0, Color(0.88, 0.72, 0.40, 0.72), 3.0, true)

    for packet in packets:
        var progress: float = clampf(float(packet["progress"]), 0.0, 1.0)
        var pos: Vector2 = _point_at(progress)
        draw_circle(pos + Vector2(3, 5), 17.0, Color(0.04, 0.02, 0.01, 0.30))
        if _icon_texture:
            draw_texture_rect(_icon_texture, Rect2(pos - Vector2(18, 18), Vector2(36, 36)), false, Color.WHITE)
        else:
            draw_circle(pos, 13.0, Color("f2c14d"))

func _path_length() -> float:
    var total: float = 0.0
    for i in range(route_points.size() - 1):
        total += route_points[i].distance_to(route_points[i + 1])
    return total

func _point_at(progress: float) -> Vector2:
    var total: float = _path_length()
    if total <= 0.001:
        return route_points[0]
    var target: float = clampf(progress, 0.0, 1.0) * total
    var walked: float = 0.0
    for i in range(route_points.size() - 1):
        var a: Vector2 = route_points[i]
        var b: Vector2 = route_points[i + 1]
        var segment: float = a.distance_to(b)
        if walked + segment >= target:
            return a.lerp(b, (target - walked) / maxf(segment, 0.001))
        walked += segment
    return route_points[route_points.size() - 1]

func _tangent_at(progress: float) -> Vector2:
    var before: Vector2 = _point_at(maxf(0.0, progress - 0.01))
    var after: Vector2 = _point_at(minf(1.0, progress + 0.01))
    var tangent: Vector2 = after - before
    return tangent.normalized() if tangent.length_squared() > 0.001 else Vector2.RIGHT

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
