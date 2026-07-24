extends Node2D

const SAVE_PATH := "user://nileside_city_native_v01.json"
const MAX_OFFLINE_SECONDS := 8.0 * 3600.0

const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const MARKET_MANAGER_SCRIPT := preload("res://scripts/market_manager.gd")
const FACTORY_SCRIPT := preload("res://scripts/factory.gd")
const CONVEYOR_SCRIPT := preload("res://scripts/conveyor.gd")
const WORKER_SCRIPT := preload("res://scripts/worker.gd")
const STATIC_BUILDING_SCRIPT := preload("res://scripts/static_building.gd")
const RESOURCE_NODE_SCRIPT := preload("res://scripts/resource_node.gd")

var world_root: Node2D
var actors_root: Node2D
var player = null
var camera: Camera2D
var market_manager = null
var factories: Array = []
var conveyors: Array = []
var workers: Array = []
var static_buildings: Dictionary = {}
var pending_save: Dictionary = {}
var warehouse_position := Vector2(0, 420)
var market_position := Vector2(0, -80)
var autosave_timer: float = 0.0
var treasury_collect_timer: float = 0.0
var customer_labels: Dictionary = {}

# UI
var ui_root: Control
var city_badge: Label
var coin_label: Label
var food_label: Label
var timber_label: Label
var blocks_label: Label
var bricks_label: Label
var population_label: Label
var reserve_label: Label
var trade_label: Label
var goal_label: Label
var save_toast: Label
var bottom_panel: Panel
var panel_title: Label
var panel_details: Label
var primary_button: Button
var secondary_button: Button
var close_button: Button
var selected_mode: String = ""
var selected_object: Variant = null
var menu_panel: Panel
var admin_tap_count: int = 0
var admin_tap_deadline: float = 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _read_save_file()
    _build_world()
    _build_ui()
    _apply_pending_save()
    _simulate_offline_progress()
    _refresh_workers()
    _update_ui()

    GameState.economy_changed.connect(_update_ui)
    GameState.city_changed.connect(_on_city_changed)
    market_manager.market_changed.connect(_update_ui)

    var boot_overlay := get_node_or_null("BootOverlay")
    if boot_overlay:
        boot_overlay.visible = false

    get_tree().auto_accept_quit = false

func _process(delta: float) -> void:
    GameState.process_local_economy(delta)
    autosave_timer += delta
    treasury_collect_timer += delta

    if autosave_timer >= 10.0:
        autosave_timer = 0.0
        _save_game(false)

    _auto_collect_treasury(delta)
    _update_customer_labels()

    if admin_tap_deadline > 0.0 and Time.get_ticks_msec() / 1000.0 > admin_tap_deadline:
        admin_tap_count = 0
        admin_tap_deadline = 0.0

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED \
    or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
    or what == NOTIFICATION_WM_CLOSE_REQUEST:
        _save_game(false)
        if what == NOTIFICATION_WM_CLOSE_REQUEST:
            get_tree().quit()

# -----------------------------------------------------------------------------
# World
# -----------------------------------------------------------------------------

func _build_world() -> void:
    world_root = Node2D.new()
    world_root.name = "World"
    world_root.y_sort_enabled = true
    add_child(world_root)

    var background := Node2D.new()
    background.name = "ContinuousTerrain"
    background.set_script(preload("res://scripts/world_background.gd"))
    world_root.add_child(background)

    actors_root = Node2D.new()
    actors_root.name = "Actors"
    actors_root.y_sort_enabled = true
    world_root.add_child(actors_root)

    market_manager = MARKET_MANAGER_SCRIPT.new()
    add_child(market_manager)

    _spawn_static_buildings()
    _spawn_factories()
    _spawn_conveyors()
    _spawn_resources()
    _spawn_customers()

    player = PLAYER_SCRIPT.new()
    player.name = "Player"
    player.global_position = Vector2(-250, 720)
    actors_root.add_child(player)

    camera = Camera2D.new()
    camera.name = "GameCamera"
    camera.position = Vector2(0, -145)
    camera.position_smoothing_enabled = true
    camera.position_smoothing_speed = 6.5
    camera.zoom = Vector2(1.0, 1.0)
    camera.limit_left = -2200
    camera.limit_right = 2200
    camera.limit_top = -3000
    camera.limit_bottom = 3000
    player.add_child(camera)
    camera.make_current()

func _spawn_static_buildings() -> void:
    var palace = STATIC_BUILDING_SCRIPT.new()
    palace.setup("palace", "Palace", "res://assets/buildings/palace1.png", 1.04)
    palace.global_position = Vector2(0, -510)
    palace.selected.connect(_on_static_building_selected)
    actors_root.add_child(palace)
    static_buildings["palace"] = palace

    var market = STATIC_BUILDING_SCRIPT.new()
    market.setup("market", "Trade Market", "res://assets/buildings/market1.png", 1.0)
    market.global_position = market_position
    market.selected.connect(_on_static_building_selected)
    actors_root.add_child(market)
    static_buildings["market"] = market

    var warehouse = STATIC_BUILDING_SCRIPT.new()
    warehouse.setup("warehouse", "City Warehouse", "res://assets/buildings/warehouse.png", 0.90)
    warehouse.global_position = warehouse_position
    warehouse.selected.connect(_on_static_building_selected)
    actors_root.add_child(warehouse)
    static_buildings["warehouse"] = warehouse

    var logistics = STATIC_BUILDING_SCRIPT.new()
    logistics.setup("logistics", "Logistics Depot", "res://assets/buildings/logistics.png", 0.92)
    logistics.global_position = Vector2(0, 890)
    logistics.selected.connect(_on_static_building_selected)
    actors_root.add_child(logistics)
    static_buildings["logistics"] = logistics

func _spawn_factories() -> void:
    var configs := [
        {
            "id": "sawmill", "name": "Sawmill", "input": "wood", "output": "timber",
            "input_amount": 2.0, "output_amount": 2.0, "cycle": 4.0, "unlock": 2,
            "texture": "res://assets/buildings/sawmill.png", "scale": 0.92,
            "position": Vector2(-710, -700)
        },
        {
            "id": "bakery", "name": "Bakery", "input": "grain", "output": "bread",
            "input_amount": 2.0, "output_amount": 2.0, "cycle": 4.0, "unlock": 2,
            "texture": "res://assets/buildings/bakery.png", "scale": 0.92,
            "position": Vector2(710, -700)
        },
        {
            "id": "masonry", "name": "Masonry Yard", "input": "stone", "output": "blocks",
            "input_amount": 2.0, "output_amount": 2.0, "cycle": 5.0, "unlock": 2,
            "texture": "res://assets/buildings/masonry.png", "scale": 0.98,
            "position": Vector2(-820, 180)
        },
        {
            "id": "kiln", "name": "Brick Kiln", "input": "clay", "output": "bricks",
            "input_amount": 3.0, "output_amount": 3.0, "cycle": 4.5, "unlock": 2,
            "texture": "res://assets/buildings/kiln.png", "scale": 1.0,
            "position": Vector2(820, 180)
        },
        {
            "id": "pottery", "name": "Pottery House", "input": "clay", "output": "pottery",
            "input_amount": 3.0, "output_amount": 2.0, "cycle": 6.0, "unlock": 4,
            "texture": "res://assets/buildings/pottery.png", "scale": 0.98,
            "position": Vector2(-720, 1220)
        },
        {
            "id": "scribe", "name": "Scribe House", "input": "papyrus", "output": "scrolls",
            "input_amount": 2.0, "output_amount": 2.0, "cycle": 4.5, "unlock": 4,
            "texture": "res://assets/buildings/papyrus_workshop.png", "scale": 0.82,
            "position": Vector2(720, 1220)
        },
    ]

    for config in configs:
        var factory = FACTORY_SCRIPT.new()
        factory.setup(config)
        factory.global_position = config["position"]
        factory.selected.connect(_on_factory_selected)
        factory.state_changed.connect(_update_ui)
        actors_root.add_child(factory)
        factories.append(factory)

func _spawn_conveyors() -> void:
    var routes := {
        "sawmill": PackedVector2Array([Vector2(-710, -700), Vector2(-420, -380), Vector2(-420, 420), warehouse_position]),
        "bakery": PackedVector2Array([Vector2(710, -700), Vector2(420, -380), Vector2(420, 420), warehouse_position]),
        "masonry": PackedVector2Array([Vector2(-820, 180), Vector2(-500, 300), Vector2(-500, 420), warehouse_position]),
        "kiln": PackedVector2Array([Vector2(820, 180), Vector2(500, 300), Vector2(500, 420), warehouse_position]),
        "pottery": PackedVector2Array([Vector2(-720, 1220), Vector2(-430, 1000), Vector2(-430, 520), warehouse_position]),
        "scribe": PackedVector2Array([Vector2(720, 1220), Vector2(430, 1000), Vector2(430, 520), warehouse_position]),
    }

    for factory in factories:
        var conveyor = CONVEYOR_SCRIPT.new()
        conveyor.setup(factory, warehouse_position, routes[factory.factory_id])
        world_root.add_child(conveyor)
        conveyors.append(conveyor)

func _spawn_resources() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 842149

    _spawn_resource_cluster(rng, "wood", "res://assets/resources/palm.png", Vector2(-1120, -1250), Vector2(610, 690), 34, 6.0, 1.1, 20.0, 0.78)
    _spawn_resource_cluster(rng, "wood", "res://assets/resources/palm.png", Vector2(1180, 2050), Vector2(520, 480), 18, 6.0, 1.1, 20.0, 0.72)
    _spawn_resource_cluster(rng, "stone", "res://assets/resources/stone_blocks.png", Vector2(-1320, 700), Vector2(450, 820), 32, 7.0, 1.0, 23.0, 0.55)
    _spawn_resource_cluster(rng, "grain", "res://assets/resources/reed.png", Vector2(1250, -950), Vector2(520, 760), 38, 4.0, 1.1, 14.0, 0.68)
    _spawn_resource_cluster(rng, "clay", "res://assets/resources/stock_clay.png", Vector2(1260, 820), Vector2(470, 720), 28, 6.0, 1.0, 20.0, 0.48)
    _spawn_resource_cluster(rng, "papyrus", "res://assets/resources/reed.png", Vector2(-1320, -80), Vector2(180, 1100), 36, 4.0, 1.2, 14.0, 0.78)
    _spawn_resource_cluster(rng, "dates", "res://assets/resources/palm.png", Vector2(1180, 1560), Vector2(500, 430), 26, 5.0, 1.0, 17.0, 0.63)
    _spawn_resource_cluster(rng, "dates", "res://assets/resources/palm.png", Vector2(620, 850), Vector2(210, 180), 10, 5.0, 1.0, 17.0, 0.58)

func _spawn_resource_cluster(
    rng: RandomNumberGenerator,
    resource_type: String,
    texture_path: String,
    center: Vector2,
    spread: Vector2,
    count: int,
    health: float,
    yield_value: float,
    respawn: float,
    scale_value: float
) -> void:
    for i in range(count):
        var node = RESOURCE_NODE_SCRIPT.new()
        node.setup(resource_type, texture_path, health, yield_value, respawn, scale_value * rng.randf_range(0.86, 1.12))
        node.global_position = center + Vector2(rng.randf_range(-spread.x, spread.x), rng.randf_range(-spread.y, spread.y))
        actors_root.add_child(node)

func _spawn_customers() -> void:
    var configs := [
        {"resource": "dates", "texture": "res://assets/characters/customer1.png", "position": Vector2(-205, 120)},
        {"resource": "pottery", "texture": "res://assets/characters/customer2.png", "position": Vector2(0, 145)},
        {"resource": "scrolls", "texture": "res://assets/characters/customer3.png", "position": Vector2(205, 120)},
    ]

    for config in configs:
        var sprite := Sprite2D.new()
        sprite.texture = load(config["texture"])
        sprite.scale = Vector2(0.36, 0.36)
        sprite.position = config["position"]
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
        static_buildings["market"].add_child(sprite)

        var label := Label.new()
        label.position = Vector2(-65, -102)
        label.size = Vector2(130, 42)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 22)
        label.add_theme_color_override("font_color", Color("422414"))
        var style := StyleBoxFlat.new()
        style.bg_color = Color(1.0, 0.96, 0.82, 0.96)
        style.corner_radius_top_left = 18
        style.corner_radius_top_right = 18
        style.corner_radius_bottom_left = 18
        style.corner_radius_bottom_right = 18
        label.add_theme_stylebox_override("normal", style)
        sprite.add_child(label)
        customer_labels[config["resource"]] = label

# -----------------------------------------------------------------------------
# UI
# -----------------------------------------------------------------------------

func _build_ui() -> void:
    var canvas := CanvasLayer.new()
    canvas.layer = 100
    add_child(canvas)

    ui_root = Control.new()
    ui_root.position = Vector2.ZERO
    ui_root.size = Vector2(1080, 1920)
    ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
    canvas.add_child(ui_root)

    var top_panel := Panel.new()
    top_panel.position = Vector2(18, 18)
    top_panel.size = Vector2(1044, 140)
    top_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.98, 0.94, 0.80, 0.96), Color("ad7b36"), 4, 28))
    ui_root.add_child(top_panel)

    city_badge = _create_label("1\nNILE CITY", 29, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
    city_badge.position = Vector2(14, 14)
    city_badge.size = Vector2(130, 112)
    city_badge.add_theme_stylebox_override("normal", _panel_style(Color("15547b"), Color("d7a43c"), 4, 32))
    city_badge.mouse_filter = Control.MOUSE_FILTER_STOP
    city_badge.gui_input.connect(_on_city_badge_input)
    top_panel.add_child(city_badge)

    coin_label = _create_resource_card(top_panel, 158, "res://assets/resources/coins.png", "250")
    food_label = _create_resource_card(top_panel, 332, "res://assets/resources/bread.png", "24")
    timber_label = _create_resource_card(top_panel, 506, "res://assets/resources/timber.png", "0")
    blocks_label = _create_resource_card(top_panel, 680, "res://assets/resources/stone_blocks.png", "0")
    bricks_label = _create_resource_card(top_panel, 854, "res://assets/resources/bricks.png", "0")

    var status_panel := Panel.new()
    status_panel.position = Vector2(18, 166)
    status_panel.size = Vector2(1044, 78)
    status_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.08, 0.105, 0.88), Color(0.03, 0.07, 0.09, 0.0), 0, 28))
    ui_root.add_child(status_panel)

    population_label = _create_status_label(status_panel, Vector2(24, 12), Vector2(230, 54))
    reserve_label = _create_status_label(status_panel, Vector2(255, 12), Vector2(250, 54))
    trade_label = _create_status_label(status_panel, Vector2(505, 12), Vector2(190, 54))
    goal_label = _create_status_label(status_panel, Vector2(690, 12), Vector2(330, 54))
    goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

    var menu_button := Button.new()
    menu_button.text = "☰"
    menu_button.position = Vector2(952, 258)
    menu_button.size = Vector2(90, 72)
    menu_button.add_theme_font_size_override("font_size", 36)
    menu_button.add_theme_stylebox_override("normal", _panel_style(Color(0.04, 0.12, 0.17, 0.92), Color("d7a43c"), 3, 22))
    menu_button.add_theme_stylebox_override("pressed", _panel_style(Color("15547b"), Color("f4c85a"), 3, 22))
    menu_button.pressed.connect(_toggle_menu)
    ui_root.add_child(menu_button)

    var tools_button := Button.new()
    tools_button.text = "SICKLES"
    tools_button.position = Vector2(842, 1460)
    tools_button.size = Vector2(200, 88)
    tools_button.add_theme_font_size_override("font_size", 25)
    tools_button.add_theme_stylebox_override("normal", _panel_style(Color(0.04, 0.20, 0.26, 0.92), Color("d7a43c"), 3, 24))
    tools_button.pressed.connect(_open_tools_panel)
    ui_root.add_child(tools_button)

    bottom_panel = Panel.new()
    bottom_panel.position = Vector2(18, 1572)
    bottom_panel.size = Vector2(1044, 320)
    bottom_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.06, 0.08, 0.94), Color("d7a43c"), 4, 30))
    bottom_panel.visible = false
    ui_root.add_child(bottom_panel)

    panel_title = _create_label("BUILDING", 34, Color("ffd96a"), HORIZONTAL_ALIGNMENT_LEFT)
    panel_title.position = Vector2(34, 24)
    panel_title.size = Vector2(780, 48)
    bottom_panel.add_child(panel_title)

    close_button = Button.new()
    close_button.text = "×"
    close_button.position = Vector2(934, 18)
    close_button.size = Vector2(74, 64)
    close_button.add_theme_font_size_override("font_size", 38)
    close_button.pressed.connect(_close_panel)
    bottom_panel.add_child(close_button)

    panel_details = _create_label("", 24, Color("f4ecd5"), HORIZONTAL_ALIGNMENT_LEFT)
    panel_details.position = Vector2(34, 82)
    panel_details.size = Vector2(976, 114)
    panel_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel_details.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    bottom_panel.add_child(panel_details)

    primary_button = _create_action_button(bottom_panel, Vector2(520, 218), Vector2(480, 78), "UPGRADE", Color("4f9e56"))
    primary_button.pressed.connect(_on_primary_pressed)
    secondary_button = _create_action_button(bottom_panel, Vector2(34, 218), Vector2(462, 78), "CONVEYOR", Color("1c6e9b"))
    secondary_button.pressed.connect(_on_secondary_pressed)

    save_toast = _create_label("SAVED", 24, Color("fff2b3"), HORIZONTAL_ALIGNMENT_CENTER)
    save_toast.position = Vector2(420, 270)
    save_toast.size = Vector2(240, 54)
    save_toast.add_theme_stylebox_override("normal", _panel_style(Color(0.02, 0.08, 0.10, 0.92), Color("d7a43c"), 2, 20))
    save_toast.visible = false
    ui_root.add_child(save_toast)

    _build_menu_panel()

func _build_menu_panel() -> void:
    menu_panel = Panel.new()
    menu_panel.position = Vector2(660, 340)
    menu_panel.size = Vector2(382, 330)
    menu_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.06, 0.08, 0.97), Color("d7a43c"), 4, 26))
    menu_panel.visible = false
    ui_root.add_child(menu_panel)

    var save_button := _create_action_button(menu_panel, Vector2(22, 24), Vector2(338, 74), "SAVE GAME", Color("15547b"))
    save_button.pressed.connect(func(): _save_game(true))

    var new_button := _create_action_button(menu_panel, Vector2(22, 116), Vector2(338, 74), "NEW CITY", Color("8c3f2b"))
    new_button.pressed.connect(_confirm_new_city)

    var close_menu := _create_action_button(menu_panel, Vector2(22, 208), Vector2(338, 74), "CLOSE", Color("4f5960"))
    close_menu.pressed.connect(_toggle_menu)

func _create_resource_card(parent: Control, x: float, icon_path: String, starting_text: String) -> Label:
    var card := Panel.new()
    card.position = Vector2(x, 22)
    card.size = Vector2(164, 96)
    card.add_theme_stylebox_override("panel", _panel_style(Color(1.0, 0.98, 0.89, 0.72), Color(0.63, 0.42, 0.18, 0.35), 2, 20))
    parent.add_child(card)

    var icon := TextureRect.new()
    icon.texture = load(icon_path)
    icon.position = Vector2(10, 19)
    icon.size = Vector2(54, 54)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    card.add_child(icon)

    var label := _create_label(starting_text, 28, Color("342112"), HORIZONTAL_ALIGNMENT_RIGHT)
    label.position = Vector2(62, 20)
    label.size = Vector2(90, 56)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    card.add_child(label)
    return label

func _create_status_label(parent: Control, position_value: Vector2, size_value: Vector2) -> Label:
    var label := _create_label("", 25, Color("f7edce"), HORIZONTAL_ALIGNMENT_LEFT)
    label.position = position_value
    label.size = size_value
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    parent.add_child(label)
    return label

func _create_label(text_value: String, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
    var label := Label.new()
    label.text = text_value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.horizontal_alignment = alignment
    return label

func _create_action_button(parent: Control, pos: Vector2, size_value: Vector2, text_value: String, color: Color) -> Button:
    var button := Button.new()
    button.text = text_value
    button.position = pos
    button.size = size_value
    button.add_theme_font_size_override("font_size", 27)
    button.add_theme_color_override("font_color", Color.WHITE)
    button.add_theme_stylebox_override("normal", _panel_style(color, color.lightened(0.20), 3, 24))
    button.add_theme_stylebox_override("hover", _panel_style(color.lightened(0.10), color.lightened(0.28), 3, 24))
    button.add_theme_stylebox_override("pressed", _panel_style(color.darkened(0.12), Color("ffd96a"), 3, 24))
    button.add_theme_stylebox_override("disabled", _panel_style(Color(0.25, 0.28, 0.30, 0.72), Color(0.35, 0.36, 0.37, 0.5), 2, 24))
    parent.add_child(button)
    return button

func _panel_style(background: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.border_width_left = border_width
    style.border_width_right = border_width
    style.border_width_top = border_width
    style.border_width_bottom = border_width
    style.corner_radius_top_left = radius
    style.corner_radius_top_right = radius
    style.corner_radius_bottom_left = radius
    style.corner_radius_bottom_right = radius
    return style

# -----------------------------------------------------------------------------
# Selection and upgrades
# -----------------------------------------------------------------------------

func _on_factory_selected(factory) -> void:
    selected_mode = "factory"
    selected_object = factory
    _show_selection_panel()

func _on_static_building_selected(building) -> void:
    selected_mode = building.building_type
    selected_object = building
    _show_selection_panel()

func _open_tools_panel() -> void:
    selected_mode = "tools"
    selected_object = null
    _show_selection_panel()

func _show_selection_panel() -> void:
    bottom_panel.visible = true
    _refresh_selection_panel()

func _close_panel() -> void:
    bottom_panel.visible = false
    selected_mode = ""
    selected_object = null

func _refresh_selection_panel() -> void:
    if not bottom_panel.visible:
        return

    primary_button.visible = true
    secondary_button.visible = true
    primary_button.disabled = false
    secondary_button.disabled = false

    match selected_mode:
        "factory":
            _refresh_factory_panel(selected_object)
        "palace":
            _refresh_palace_panel()
        "market":
            _refresh_market_panel()
        "warehouse":
            _refresh_warehouse_panel()
        "logistics":
            _refresh_logistics_panel()
        "tools":
            _refresh_tools_panel()
        _:
            bottom_panel.visible = false

func _refresh_factory_panel(factory) -> void:
    if not is_instance_valid(factory):
        _close_panel()
        return
    panel_title.text = "%s - LEVEL %d" % [factory.display_name.to_upper(), factory.level]
    if not factory.is_unlocked():
        panel_details.text = "Unlocks at City Level %d. Upgrade the Palace to open this production district." % factory.unlock_city_level
        primary_button.text = "LOCKED"
        primary_button.disabled = true
        secondary_button.visible = false
        return

    var cost: Dictionary = factory.factory_upgrade_cost()
    panel_details.text = "%s → %s\nOutput: %d/min  |  Buffer: %d/%d\nNext upgrade: %s" % [
        factory.input_resource.capitalize(), factory.output_resource.capitalize(),
        int(factory.production_per_minute()), int(factory.output_buffer), int(factory.storage_capacity()),
        _format_cost(cost)
    ]
    primary_button.text = "UPGRADE FACTORY"
    primary_button.disabled = not factory.can_upgrade()

    secondary_button.visible = GameState.city_level >= 5
    if secondary_button.visible:
        if factory.conveyor_level >= 5:
            secondary_button.text = "CONVEYOR MAX"
            secondary_button.disabled = true
        else:
            secondary_button.text = "CONVEYOR L%d → L%d" % [factory.conveyor_level, factory.conveyor_level + 1]
            secondary_button.disabled = not factory.can_upgrade_conveyor()

func _refresh_palace_panel() -> void:
    panel_title.text = "PALACE - CITY LEVEL %d" % GameState.city_level
    secondary_button.visible = false
    if GameState.city_level >= 7:
        panel_details.text = "Great Nile Capital completed. Continue expanding production, population and export contracts."
        primary_button.text = "CAPITAL COMPLETE"
        primary_button.disabled = true
        return

    var req: Dictionary = GameState.city_upgrade_requirements()
    panel_details.text = "Build the next city district.\nPopulation %d/%d  |  %s" % [
        GameState.population, int(req["population"]), _format_cost(req)
    ]
    primary_button.text = "BUILD CITY LEVEL %d" % (GameState.city_level + 1)
    primary_button.disabled = not GameState.can_upgrade_city()

func _refresh_market_panel() -> void:
    panel_title.text = "TRADE MARKET - LEVEL %d" % GameState.market_level
    var order_text := ""
    for key in ["dates", "pottery", "scrolls"]:
        var lane: Dictionary = market_manager.lanes[key]
        order_text += "%s %d   " % [String(key).capitalize(), int(lane["remaining"])]
    panel_details.text = "Treasury: %s coins\nIndependent demand: %s\nUpgrade: %s" % [
        _compact_number(GameState.treasury), order_text, _format_cost(market_manager.upgrade_cost())
    ]
    primary_button.text = "UPGRADE MARKET"
    primary_button.disabled = not market_manager.can_upgrade()
    secondary_button.visible = true
    secondary_button.text = "COLLECT TREASURY"
    secondary_button.disabled = GameState.treasury < 1.0

func _refresh_warehouse_panel() -> void:
    panel_title.text = "CITY WAREHOUSE"
    panel_details.text = "Local: Grain %s  Bread %s  Dates %s\nConstruction: Timber %s  Bricks %s  Blocks %s\nTrade: Pottery %s  Scrolls %s" % [
        _compact_number(GameState.amount("grain")), _compact_number(GameState.amount("bread")), _compact_number(GameState.amount("dates")),
        _compact_number(GameState.amount("timber")), _compact_number(GameState.amount("bricks")), _compact_number(GameState.amount("blocks")),
        _compact_number(GameState.amount("pottery")), _compact_number(GameState.amount("scrolls"))
    ]
    primary_button.visible = false
    secondary_button.visible = false

func _refresh_logistics_panel() -> void:
    panel_title.text = "LOGISTICS DEPOT - LEVEL %d" % GameState.hauler_level
    var next := GameState.hauler_level + 1
    var cost: Dictionary = _hauler_upgrade_cost()
    panel_details.text = "%d human haulers. Each carries %d units at %d movement speed.\nNext upgrade: %s" % [
        workers.size(), int(7 + GameState.hauler_level * 5), int(180 + GameState.hauler_level * 28), _format_cost(cost)
    ]
    primary_button.text = "UPGRADE HAULERS"
    primary_button.disabled = GameState.hauler_level >= 8 or not _can_upgrade_haulers()
    secondary_button.visible = false

func _refresh_tools_panel() -> void:
    panel_title.text = "HARVEST SICKLES - LEVEL %d" % GameState.sickle_level
    var cost: Dictionary = _sickle_upgrade_cost()
    panel_details.text = "%d sickles  |  Radius %d  |  Faster multi-node harvesting\nNext upgrade: %s" % [
        player.sickle_count(), int(player.harvest_radius()), _format_cost(cost)
    ]
    primary_button.text = "UPGRADE SICKLES"
    primary_button.disabled = GameState.sickle_level >= 10 or not _can_upgrade_sickles()
    secondary_button.visible = false

func _on_primary_pressed() -> void:
    var changed := false
    match selected_mode:
        "factory":
            changed = selected_object.upgrade()
        "palace":
            changed = GameState.upgrade_city()
        "market":
            changed = market_manager.upgrade()
        "logistics":
            changed = _upgrade_haulers()
        "tools":
            changed = _upgrade_sickles()
    if changed:
        _refresh_workers()
        _save_game(false)
    _update_ui()
    _refresh_selection_panel()

func _on_secondary_pressed() -> void:
    match selected_mode:
        "factory":
            selected_object.upgrade_conveyor()
        "market":
            market_manager.collect_treasury()
    _save_game(false)
    _update_ui()
    _refresh_selection_panel()

func _sickle_upgrade_cost() -> Dictionary:
    var next := GameState.sickle_level + 1
    if next > 10:
        return {}
    return {
        "coins": round(420.0 * pow(1.72, float(next - 1))),
        "timber": round(4.0 * pow(1.40, float(next - 1))),
        "bricks": 0.0,
        "blocks": round(2.0 * pow(1.35, float(next - 1))),
    }

func _can_upgrade_sickles() -> bool:
    if GameState.sickle_level >= 10:
        return false
    var cost: Dictionary = _sickle_upgrade_cost()
    return GameState.coins >= float(cost["coins"]) \
        and GameState.can_take("timber", float(cost["timber"])) \
        and GameState.can_take("blocks", float(cost["blocks"]))

func _upgrade_sickles() -> bool:
    if not _can_upgrade_sickles():
        return false
    var cost: Dictionary = _sickle_upgrade_cost()
    GameState.spend_coins(float(cost["coins"]))
    GameState.take_resource("timber", float(cost["timber"]))
    GameState.take_resource("blocks", float(cost["blocks"]))
    GameState.sickle_level += 1
    GameState.economy_changed.emit()
    return true

func _hauler_upgrade_cost() -> Dictionary:
    var next := GameState.hauler_level + 1
    if next > 8:
        return {}
    return {
        "coins": round(700.0 * pow(1.82, float(next - 1))),
        "timber": round(8.0 * pow(1.45, float(next - 1))),
        "bricks": round(6.0 * pow(1.42, float(next - 1))),
        "blocks": round(3.0 * pow(1.38, float(next - 1))),
    }

func _can_upgrade_haulers() -> bool:
    if GameState.hauler_level >= 8:
        return false
    var cost: Dictionary = _hauler_upgrade_cost()
    return GameState.coins >= float(cost["coins"]) \
        and GameState.can_take("timber", float(cost["timber"])) \
        and GameState.can_take("bricks", float(cost["bricks"])) \
        and GameState.can_take("blocks", float(cost["blocks"]))

func _upgrade_haulers() -> bool:
    if not _can_upgrade_haulers():
        return false
    var cost: Dictionary = _hauler_upgrade_cost()
    GameState.spend_coins(float(cost["coins"]))
    GameState.take_resource("timber", float(cost["timber"]))
    GameState.take_resource("bricks", float(cost["bricks"]))
    GameState.take_resource("blocks", float(cost["blocks"]))
    GameState.hauler_level += 1
    GameState.economy_changed.emit()
    return true

func _refresh_workers() -> void:
    var desired := clampi(GameState.hauler_level, 1, 8)
    while workers.size() < desired:
        var worker = WORKER_SCRIPT.new()
        var index := workers.size()
        worker.setup(factories, warehouse_position, Vector2(-150 + index * 42, 770 + (index % 2) * 42))
        actors_root.add_child(worker)
        workers.append(worker)
    while workers.size() > desired:
        var worker: Node = workers.pop_back()
        worker.queue_free()

# -----------------------------------------------------------------------------
# Economy, save and menu
# -----------------------------------------------------------------------------

func _auto_collect_treasury(delta: float) -> void:
    if GameState.treasury < 0.1:
        return
    if player.global_position.distance_to(market_position) > 175.0:
        return
    var transfer: float = minf(GameState.treasury, maxf(10.0, GameState.treasury * 3.5 * delta))
    GameState.treasury -= transfer
    GameState.add_coins(transfer)

func _on_city_changed() -> void:
    for factory in factories:
        factory._refresh_visuals()
    for building in static_buildings.values():
        building.refresh()
    _update_ui()
    _refresh_selection_panel()

func _update_customer_labels() -> void:
    if not market_manager:
        return
    for key in customer_labels.keys():
        var lane: Dictionary = market_manager.lanes[key]
        customer_labels[key].text = "%s ×%d" % [String(key).capitalize(), int(lane["remaining"])]

func _update_ui() -> void:
    if not city_badge:
        return
    city_badge.text = "%d\nNILE CITY" % GameState.city_level
    coin_label.text = _compact_number(GameState.coins)
    food_label.text = _compact_number(GameState.local_food_points())
    timber_label.text = _compact_number(GameState.amount("timber"))
    blocks_label.text = _compact_number(GameState.amount("blocks"))
    bricks_label.text = _compact_number(GameState.amount("bricks"))
    population_label.text = "POP %d/%d" % [GameState.population, GameState.population_cap]
    reserve_label.text = "FOOD %.1f min" % GameState.food_minutes()
    trade_label.text = "TRADE %s" % _compact_number(market_manager.total_sold if market_manager else 0.0)
    if GameState.city_level < 7:
        var req: Dictionary = GameState.city_upgrade_requirements()
        goal_label.text = "GOAL: Population %d/%d" % [GameState.population, int(req.get("population", GameState.population_cap))]
    else:
        goal_label.text = "GOAL: Expand the Nile capital"
    _refresh_selection_panel()

func _read_save_file() -> void:
    pending_save = {}
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        pending_save = parsed
        GameState.from_dict(pending_save.get("game_state", {}))

func _apply_pending_save() -> void:
    if pending_save.is_empty():
        return
    var saved_factories: Dictionary = pending_save.get("factories", {})
    for factory in factories:
        if saved_factories.has(factory.factory_id):
            var data: Dictionary = saved_factories[factory.factory_id]
            factory.level = clampi(int(data.get("level", factory.level)), 0, 10)
            factory.output_buffer = maxf(0.0, float(data.get("output_buffer", 0.0)))
            factory.conveyor_level = clampi(int(data.get("conveyor_level", 0)), 0, 5)
            factory.cycle_progress = maxf(0.0, float(data.get("cycle_progress", 0.0)))
            factory._refresh_visuals()
    market_manager.from_dict(pending_save.get("market", {}))
    if pending_save.has("player_position"):
        var pos = pending_save["player_position"]
        if pos is Array and pos.size() >= 2:
            player.global_position = Vector2(float(pos[0]), float(pos[1]))

func _simulate_offline_progress() -> void:
    if pending_save.is_empty():
        return
    var now: float = Time.get_unix_time_from_system()
    var last: float = float(pending_save.get("last_timestamp", now))
    var elapsed: float = clampf(now - last, 0.0, MAX_OFFLINE_SECONDS)
    if elapsed < 3.0:
        return

    GameState.simulate_offline(elapsed)
    for factory in factories:
        factory.simulate_offline(elapsed)
        var transport_rate: float = 0.55 * float(GameState.hauler_level)
        if factory.conveyor_level > 0:
            transport_rate += 1.5 * pow(float(factory.conveyor_level), 1.35)
        var moved: float = float(factory.take_output(minf(factory.output_buffer, elapsed * transport_rate)))
        if moved > 0.0:
            GameState.add_resource(factory.output_resource, moved)
    market_manager.simulate_offline(elapsed)

func _save_game(show_feedback: bool = true) -> void:
    var saved_factories := {}
    for factory in factories:
        saved_factories[factory.factory_id] = {
            "level": factory.level,
            "output_buffer": factory.output_buffer,
            "conveyor_level": factory.conveyor_level,
            "cycle_progress": factory.cycle_progress,
        }

    var data := {
        "game_state": GameState.to_dict(),
        "factories": saved_factories,
        "market": market_manager.to_dict(),
        "player_position": [player.global_position.x, player.global_position.y],
        "last_timestamp": Time.get_unix_time_from_system(),
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))
    if show_feedback:
        _show_save_toast("SAVED")

func _toggle_menu() -> void:
    menu_panel.visible = not menu_panel.visible

func _confirm_new_city() -> void:
    # Two-step confirmation without a modal that blocks the entire screen.
    var button := menu_panel.get_child(1) as Button
    if button.text == "TAP AGAIN TO RESET":
        if FileAccess.file_exists(SAVE_PATH):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
        GameState.reset()
        get_tree().reload_current_scene()
    else:
        button.text = "TAP AGAIN TO RESET"
        var timer := get_tree().create_timer(3.5)
        timer.timeout.connect(func():
            if is_instance_valid(button):
                button.text = "NEW CITY"
        )

func _show_save_toast(text_value: String) -> void:
    save_toast.text = text_value
    save_toast.visible = true
    save_toast.modulate.a = 1.0
    var tween := create_tween()
    tween.tween_interval(0.65)
    tween.tween_property(save_toast, "modulate:a", 0.0, 0.35)
    tween.tween_callback(func(): save_toast.visible = false)

func _on_city_badge_input(event: InputEvent) -> void:
    var tapped := false
    if event is InputEventScreenTouch and event.pressed:
        tapped = true
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        tapped = true
    if not tapped:
        return
    var now := Time.get_ticks_msec() / 1000.0
    if admin_tap_deadline == 0.0 or now > admin_tap_deadline:
        admin_tap_count = 0
    admin_tap_count += 1
    admin_tap_deadline = now + 4.0
    if admin_tap_count >= 7:
        admin_tap_count = 0
        _open_dev_boost()

func _open_dev_boost() -> void:
    # Temporary native-build backdoor. Full admin panel comes in the next build.
    GameState.add_coins(100000.0)
    for key in GameState.resources.keys():
        GameState.add_resource(key, 1000.0)
    _show_save_toast("DEV BOOST APPLIED")

func _format_cost(cost: Dictionary) -> String:
    if cost.is_empty():
        return "MAX"
    var parts: Array[String] = []
    if cost.has("coins"):
        parts.append("%s coins" % _compact_number(float(cost["coins"])))
    for key in ["wood", "stone", "clay", "grain", "papyrus", "timber", "bricks", "blocks"]:
        if cost.has(key) and float(cost[key]) > 0.0:
            parts.append("%d %s" % [int(cost[key]), String(key)])
    return "  •  ".join(parts)

func _compact_number(value: float) -> String:
    if value >= 1000000.0:
        return "%.1fM" % (value / 1000000.0)
    if value >= 1000.0:
        return "%.1fk" % (value / 1000.0)
    return str(int(round(value)))
