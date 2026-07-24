extends Node
class_name MarketManager

signal market_changed

var lanes := {
    "dates": {"remaining": 18.0, "unit_price": 2.2, "timer": 0.0},
    "pottery": {"remaining": 10.0, "unit_price": 8.5, "timer": 0.0},
    "scrolls": {"remaining": 8.0, "unit_price": 12.0, "timer": 0.0},
}

var total_sold: float = 0.0
var _sale_accumulator: float = 0.0

func _process(delta: float) -> void:
    _sale_accumulator += delta
    if _sale_accumulator < 0.25:
        return
    var step := _sale_accumulator
    _sale_accumulator = 0.0
    _process_sales(step)

func protected_reserve(resource_name: String) -> float:
    var base := {
        "dates": 22.0,
        "pottery": 12.0,
        "scrolls": 10.0,
    }
    return float(base.get(resource_name, 0.0)) + float(GameState.market_level - 1) * 6.0

func _process_sales(delta: float) -> void:
    var changed := false
    var lane_names: Array[String] = ["dates", "pottery", "scrolls"]
    for resource_name in lane_names:
        var lane: Dictionary = lanes[resource_name]
        lane["timer"] = float(lane["timer"]) + delta
        var service_interval: float = maxf(0.18, 1.15 / (1.0 + float(GameState.market_level) * 0.18) / float(GameState.tuning["demand_multiplier"]))
        if float(lane["timer"]) < service_interval:
            continue
        lane["timer"] = 0.0

        var available: float = maxf(0.0, GameState.amount(resource_name) - protected_reserve(resource_name))
        if available <= 0.0:
            continue

        var demand_step: float = minf(
            available,
            minf(float(lane["remaining"]), 1.0 + floor(float(GameState.market_level) / 3.0))
        )
        if demand_step <= 0.0:
            continue

        if GameState.take_resource(resource_name, demand_step):
            lane["remaining"] = float(lane["remaining"]) - demand_step
            var value: float = demand_step * float(lane["unit_price"]) * (1.0 + float(GameState.market_level - 1) * 0.08)
            GameState.treasury += value
            total_sold += demand_step
            changed = true

        if float(lane["remaining"]) <= 0.01:
            _new_order(resource_name)

    if changed:
        GameState.economy_changed.emit()
        market_changed.emit()

func _new_order(resource_name: String) -> void:
    var lane: Dictionary = lanes[resource_name]
    var production_pressure: float = sqrt(maxf(1.0, GameState.amount(resource_name) + total_sold * 0.08))
    var base_order: Dictionary = {
        "dates": 18.0,
        "pottery": 10.0,
        "scrolls": 8.0,
    }
    var order: float = float(base_order[resource_name]) \
        + float(GameState.city_level) * 6.0 \
        + float(GameState.market_level) * 4.0 \
        + production_pressure * 2.0
    lane["remaining"] = round(order * float(GameState.tuning["demand_multiplier"]))

func collect_treasury() -> float:
    var value: float = GameState.treasury
    GameState.treasury = 0.0
    GameState.add_coins(value)
    market_changed.emit()
    return value

func upgrade_cost() -> Dictionary:
    var next := GameState.market_level + 1
    if next > 10:
        return {}
    return {
        "coins": round(850.0 * pow(1.78, float(next - 1))),
        "timber": round(8.0 * pow(1.45, float(next - 1))),
        "bricks": round(10.0 * pow(1.45, float(next - 1))),
        "blocks": round(5.0 * pow(1.42, float(next - 1))),
    }

func can_upgrade() -> bool:
    if GameState.market_level >= 10:
        return false
    var cost: Dictionary = upgrade_cost()
    return GameState.coins >= float(cost["coins"]) \
        and GameState.can_take("timber", float(cost["timber"])) \
        and GameState.can_take("bricks", float(cost["bricks"])) \
        and GameState.can_take("blocks", float(cost["blocks"]))

func upgrade() -> bool:
    if not can_upgrade():
        return false
    var cost: Dictionary = upgrade_cost()
    GameState.spend_coins(float(cost["coins"]))
    GameState.take_resource("timber", float(cost["timber"]))
    GameState.take_resource("bricks", float(cost["bricks"]))
    GameState.take_resource("blocks", float(cost["blocks"]))
    GameState.market_level += 1
    market_changed.emit()
    return true

func simulate_offline(seconds: float) -> void:
    # Approximate sales without allowing market demand to consume protected stock.
    var sale_steps: float = seconds / maxf(0.3, 1.2 / (1.0 + GameState.market_level * 0.18))
    for resource_name in lanes.keys():
        var available: float = maxf(0.0, GameState.amount(resource_name) - protected_reserve(resource_name))
        var sold: float = minf(available, sale_steps * (1.0 + floor(float(GameState.market_level) / 3.0)))
        if sold > 0.0 and GameState.take_resource(resource_name, sold):
            var lane: Dictionary = lanes[resource_name]
            GameState.treasury += sold * float(lane["unit_price"]) * (1.0 + float(GameState.market_level - 1) * 0.08)
            total_sold += sold

func to_dict() -> Dictionary:
    return {"lanes": lanes.duplicate(true), "total_sold": total_sold}

func from_dict(data: Dictionary) -> void:
    var saved_lanes = data.get("lanes", {})
    for key in lanes.keys():
        if saved_lanes.has(key):
            lanes[key] = saved_lanes[key]
    total_sold = maxf(0.0, float(data.get("total_sold", 0.0)))
    market_changed.emit()
