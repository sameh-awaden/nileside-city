extends Panel

var game = null
var production_label: Label
var demand_label: Label
var harvest_label: Label
var food_label: Label

func setup(game_root) -> void:
    game = game_root

func _ready() -> void:
    position = Vector2(55, 250)
    size = Vector2(970, 1390)
    z_index = 300
    visible = false
    mouse_filter = Control.MOUSE_FILTER_STOP
    add_theme_stylebox_override("panel", _style(Color(0.02, 0.05, 0.07, 0.98), Color("d7a43c"), 5, 30))

    var title := _label("DEVELOPER CONTROL", 38, Color("ffd96a"))
    title.position = Vector2(34, 25)
    title.size = Vector2(720, 58)
    add_child(title)

    var subtitle := _label("Hidden prototype controls — changes are saved", 22, Color("d8e4e8"))
    subtitle.position = Vector2(36, 82)
    subtitle.size = Vector2(760, 42)
    add_child(subtitle)

    var close := _button("CLOSE", Vector2(755, 28), Vector2(178, 70), Color("6a3b32"))
    close.pressed.connect(close_panel)

    production_label = _section_label(Vector2(36, 145))
    demand_label = _section_label(Vector2(36, 285))
    harvest_label = _section_label(Vector2(36, 425))
    food_label = _section_label(Vector2(36, 565))

    _step_controls("PRODUCTION", production_label, "production_multiplier", 145)
    _step_controls("DEMAND", demand_label, "demand_multiplier", 285)
    _step_controls("HARVEST", harvest_label, "harvest_multiplier", 425)
    _step_controls("FOOD USE", food_label, "food_consumption_multiplier", 565)

    var add_coins := _button("ADD 100,000 COINS", Vector2(36, 735), Vector2(430, 86), Color("94701d"))
    add_coins.pressed.connect(_add_coins)
    var add_resources := _button("ADD 1,000 OF EVERYTHING", Vector2(500, 735), Vector2(434, 86), Color("356b48"))
    add_resources.pressed.connect(_add_resources)

    var max_all := _button("UNLOCK + MAX ALL SYSTEMS", Vector2(36, 845), Vector2(898, 88), Color("165f83"))
    max_all.pressed.connect(_max_all)

    var pause_prod := _button("TOGGLE PRODUCTION", Vector2(36, 965), Vector2(430, 82), Color("5a4778"))
    pause_prod.pressed.connect(func(): _toggle_multiplier("production_multiplier"))
    var pause_demand := _button("TOGGLE DEMAND", Vector2(500, 965), Vector2(434, 82), Color("5a4778"))
    pause_demand.pressed.connect(func(): _toggle_multiplier("demand_multiplier"))

    var save := _button("SAVE CHANGES", Vector2(36, 1085), Vector2(898, 88), Color("347a50"))
    save.pressed.connect(_save)

    var hint := _label("Open this panel by tapping the blue NILE CITY badge 7 times within 4 seconds.", 22, Color("f2dfaa"))
    hint.position = Vector2(42, 1210)
    hint.size = Vector2(880, 95)
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(hint)
    _refresh()

func open_panel() -> void:
    visible = true
    _refresh()

func close_panel() -> void:
    visible = false

func _step_controls(title: String, label: Label, key: String, y: float) -> void:
    label.text = title
    var minus := _button("−", Vector2(610, y), Vector2(140, 88), Color("7a3d35"))
    minus.add_theme_font_size_override("font_size", 46)
    minus.pressed.connect(func(): _adjust(key, 0.5))
    var plus := _button("+", Vector2(780, y), Vector2(154, 88), Color("38774c"))
    plus.add_theme_font_size_override("font_size", 42)
    plus.pressed.connect(func(): _adjust(key, 2.0))

func _section_label(pos: Vector2) -> Label:
    var result := _label("", 28, Color.WHITE)
    result.position = pos
    result.size = Vector2(540, 88)
    result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    add_child(result)
    return result

func _adjust(key: String, factor: float) -> void:
    var current: float = float(GameState.tuning[key])
    if current <= 0.0:
        current = 1.0
    GameState.tuning[key] = clampf(current * factor, 0.125, 16.0)
    GameState.settings_changed.emit()
    GameState.economy_changed.emit()
    _refresh()

func _toggle_multiplier(key: String) -> void:
    GameState.tuning[key] = 1.0 if float(GameState.tuning[key]) <= 0.0 else 0.0
    GameState.settings_changed.emit()
    GameState.economy_changed.emit()
    _refresh()

func _add_coins() -> void:
    GameState.add_coins(100000.0)
    _refresh()

func _add_resources() -> void:
    for key in GameState.resources.keys():
        GameState.add_resource(String(key), 1000.0)
    _refresh()

func _max_all() -> void:
    GameState.city_level = 7
    GameState.population_cap = 150
    GameState.population = 150
    GameState.sickle_level = 10
    GameState.market_level = 10
    GameState.hauler_level = 8
    for key in GameState.resources.keys():
        GameState.resources[key] = maxf(GameState.amount(String(key)), 10000.0)
    GameState.coins = maxf(GameState.coins, 1000000.0)
    if game:
        for factory in game.factories:
            factory.level = 10
            factory.conveyor_level = 5
            factory._refresh_visuals()
        game._refresh_workers()
    GameState.city_changed.emit()
    GameState.economy_changed.emit()
    _refresh()

func _save() -> void:
    if game:
        game._save_game(true)

func _refresh() -> void:
    if not production_label:
        return
    production_label.text = "PRODUCTION     ×%.2f" % float(GameState.tuning["production_multiplier"])
    demand_label.text = "DEMAND             ×%.2f" % float(GameState.tuning["demand_multiplier"])
    harvest_label.text = "HARVEST           ×%.2f" % float(GameState.tuning["harvest_multiplier"])
    food_label.text = "FOOD USE          ×%.2f" % float(GameState.tuning["food_consumption_multiplier"])

func _button(text_value: String, pos: Vector2, size_value: Vector2, color: Color) -> Button:
    var result := Button.new()
    result.text = text_value
    result.position = pos
    result.size = size_value
    result.add_theme_font_size_override("font_size", 24)
    result.add_theme_color_override("font_color", Color.WHITE)
    result.add_theme_stylebox_override("normal", _style(color, color.lightened(0.22), 3, 20))
    result.add_theme_stylebox_override("pressed", _style(color.darkened(0.16), Color("ffd96a"), 3, 20))
    add_child(result)
    return result

func _label(text_value: String, font_size: int, color: Color) -> Label:
    var result := Label.new()
    result.text = text_value
    result.add_theme_font_size_override("font_size", font_size)
    result.add_theme_color_override("font_color", color)
    return result

func _style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
    var result := StyleBoxFlat.new()
    result.bg_color = background
    result.border_color = border
    result.border_width_left = width
    result.border_width_right = width
    result.border_width_top = width
    result.border_width_bottom = width
    result.corner_radius_top_left = radius
    result.corner_radius_top_right = radius
    result.corner_radius_bottom_left = radius
    result.corner_radius_bottom_right = radius
    return result
