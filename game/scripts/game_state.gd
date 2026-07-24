extends Node

signal resource_changed(resource_name: String, amount: float)
signal economy_changed
signal city_changed
signal settings_changed

const SAVE_VERSION := 1

var city_level: int = 1
var population: int = 10
var population_cap: int = 10
var coins: float = 250.0
var treasury: float = 0.0
var sickle_level: int = 1
var market_level: int = 1
var hauler_level: int = 1

var resources: Dictionary = {
    "wood": 20.0,
    "stone": 12.0,
    "grain": 24.0,
    "clay": 8.0,
    "papyrus": 0.0,
    "dates": 8.0,
    "bread": 0.0,
    "timber": 0.0,
    "bricks": 0.0,
    "blocks": 0.0,
    "pottery": 0.0,
    "scrolls": 0.0,
}

var tuning: Dictionary = {
    "harvest_multiplier": 1.0,
    "production_multiplier": 1.0,
    "demand_multiplier": 1.0,
    "food_consumption_multiplier": 1.0,
    "worker_speed_multiplier": 1.0,
    "conveyor_speed_multiplier": 1.0,
}

var _food_accumulator: float = 0.0
var _growth_accumulator: float = 0.0

func reset() -> void:
    city_level = 1
    population = 10
    population_cap = 10
    coins = 250.0
    treasury = 0.0
    sickle_level = 1
    market_level = 1
    hauler_level = 1
    resources = {
        "wood": 20.0,
        "stone": 12.0,
        "grain": 24.0,
        "clay": 8.0,
        "papyrus": 0.0,
        "dates": 8.0,
        "bread": 0.0,
        "timber": 0.0,
        "bricks": 0.0,
        "blocks": 0.0,
        "pottery": 0.0,
        "scrolls": 0.0,
    }
    tuning = {
        "harvest_multiplier": 1.0,
        "production_multiplier": 1.0,
        "demand_multiplier": 1.0,
        "food_consumption_multiplier": 1.0,
        "worker_speed_multiplier": 1.0,
        "conveyor_speed_multiplier": 1.0,
    }
    _food_accumulator = 0.0
    _growth_accumulator = 0.0
    economy_changed.emit()
    city_changed.emit()

func amount(resource_name: String) -> float:
    return float(resources.get(resource_name, 0.0))

func add_resource(resource_name: String, value: float) -> void:
    if value <= 0.0:
        return
    resources[resource_name] = amount(resource_name) + value
    resource_changed.emit(resource_name, amount(resource_name))
    economy_changed.emit()

func can_take(resource_name: String, value: float) -> bool:
    return amount(resource_name) + 0.0001 >= value

func take_resource(resource_name: String, value: float) -> bool:
    if value <= 0.0:
        return true
    if not can_take(resource_name, value):
        return false
    resources[resource_name] = maxf(0.0, amount(resource_name) - value)
    resource_changed.emit(resource_name, amount(resource_name))
    economy_changed.emit()
    return true

func add_coins(value: float) -> void:
    coins += maxf(0.0, value)
    economy_changed.emit()

func spend_coins(value: float) -> bool:
    if coins + 0.0001 < value:
        return false
    coins -= value
    economy_changed.emit()
    return true

func local_food_points() -> float:
    return amount("grain") + amount("bread") * 3.0

func food_use_per_minute() -> float:
    # Noticeable local demand without making the first minutes oppressive.
    return maxf(0.4, float(population) / 5.0) * float(tuning["food_consumption_multiplier"])

func food_minutes() -> float:
    var use_rate: float = food_use_per_minute()
    if use_rate <= 0.001:
        return 999.0
    return local_food_points() / use_rate

func process_local_economy(delta: float) -> void:
    _food_accumulator += delta
    _growth_accumulator += delta

    if _food_accumulator >= 1.0:
        var seconds: float = _food_accumulator
        _food_accumulator = 0.0
        _consume_food(food_use_per_minute() * seconds / 60.0)

    if _growth_accumulator >= 90.0:
        _growth_accumulator = 0.0
        if population < population_cap and food_minutes() >= 5.0:
            population += 1
            city_changed.emit()

func _consume_food(points: float) -> void:
    var remaining: float = points
    # Residents consume only local food: bread first because it is efficient, then grain.
    # Dates are a separate trade crop and are never consumed locally.
    var bread_needed: float = minf(amount("bread"), remaining / 3.0)
    if bread_needed > 0.0:
        take_resource("bread", bread_needed)
        remaining -= bread_needed * 3.0
    if remaining > 0.0:
        var grain_used: float = minf(amount("grain"), remaining)
        if grain_used > 0.0:
            take_resource("grain", grain_used)
            remaining -= grain_used


func simulate_offline(seconds: float) -> void:
    var bounded: float = clampf(seconds, 0.0, 8.0 * 3600.0)
    if bounded <= 0.0:
        return
    _consume_food(food_use_per_minute() * bounded / 60.0)
    var growth_steps: int = int(floor(bounded / 90.0))
    for i in range(growth_steps):
        if population >= population_cap or food_minutes() < 5.0:
            break
        population += 1
    economy_changed.emit()
    city_changed.emit()

func city_upgrade_requirements() -> Dictionary:
    var next_level := city_level + 1
    var table: Dictionary = {
        2: {"coins": 350.0, "population": 10, "wood": 25.0, "stone": 15.0, "clay": 10.0},
        3: {"coins": 1600.0, "population": 16, "timber": 25.0, "bricks": 30.0, "blocks": 18.0},
        4: {"coins": 4800.0, "population": 28, "timber": 65.0, "bricks": 85.0, "blocks": 55.0},
        5: {"coins": 13500.0, "population": 45, "timber": 130.0, "bricks": 180.0, "blocks": 130.0},
        6: {"coins": 32000.0, "population": 70, "timber": 260.0, "bricks": 360.0, "blocks": 300.0},
        7: {"coins": 75000.0, "population": 110, "timber": 520.0, "bricks": 720.0, "blocks": 650.0},
    }
    return table.get(next_level, {})

func can_upgrade_city() -> bool:
    var req: Dictionary = city_upgrade_requirements()
    if req.is_empty():
        return false
    if coins < float(req["coins"]) or population < int(req["population"]):
        return false
    for key in req.keys():
        if key in ["coins", "population"]:
            continue
        if not can_take(String(key), float(req[key])):
            return false
    return true

func upgrade_city() -> bool:
    if not can_upgrade_city():
        return false
    var req: Dictionary = city_upgrade_requirements()
    spend_coins(float(req["coins"]))
    for key in req.keys():
        if key in ["coins", "population"]:
            continue
        take_resource(String(key), float(req[key]))
    city_level += 1
    population_cap = [10, 18, 32, 52, 80, 115, 150][city_level - 1]
    city_changed.emit()
    return true

func to_dict() -> Dictionary:
    return {
        "save_version": SAVE_VERSION,
        "city_level": city_level,
        "population": population,
        "population_cap": population_cap,
        "coins": coins,
        "treasury": treasury,
        "sickle_level": sickle_level,
        "market_level": market_level,
        "hauler_level": hauler_level,
        "resources": resources.duplicate(true),
        "tuning": tuning.duplicate(true),
        "food_accumulator": _food_accumulator,
        "growth_accumulator": _growth_accumulator,
    }

func from_dict(data: Dictionary) -> void:
    city_level = clampi(int(data.get("city_level", 1)), 1, 7)
    population = maxi(1, int(data.get("population", 10)))
    population_cap = maxi(population, int(data.get("population_cap", 10)))
    coins = maxf(0.0, float(data.get("coins", 250.0)))
    treasury = maxf(0.0, float(data.get("treasury", 0.0)))
    sickle_level = clampi(int(data.get("sickle_level", 1)), 1, 10)
    market_level = clampi(int(data.get("market_level", 1)), 1, 10)
    hauler_level = clampi(int(data.get("hauler_level", 1)), 1, 8)

    var saved_resources: Dictionary = data.get("resources", {})
    for key in resources.keys():
        resources[key] = maxf(0.0, float(saved_resources.get(key, resources[key])))

    var saved_tuning: Dictionary = data.get("tuning", {})
    for key in tuning.keys():
        tuning[key] = maxf(0.0, float(saved_tuning.get(key, tuning[key])))

    _food_accumulator = maxf(0.0, float(data.get("food_accumulator", 0.0)))
    _growth_accumulator = maxf(0.0, float(data.get("growth_accumulator", 0.0)))
    economy_changed.emit()
    city_changed.emit()
