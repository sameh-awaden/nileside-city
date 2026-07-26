extends Node
class_name EngagementManager

signal message_requested(text_value: String, kind: String, focus_position: Vector2)
signal objective_changed
signal contract_changed
signal celebration_requested(title: String, body: String)

const CHAPTERS = [
    {
        "title": "Gather for the First Homes",
        "body": "Harvest enough palm wood to prepare the first riverside homes.",
        "kind": "resource",
        "resource": "wood",
        "target": 60.0,
    },
    {
        "title": "Secure the Grain Reserve",
        "body": "Build a comfortable food reserve before the settlement expands.",
        "kind": "food",
        "target": 12.0,
    },
    {
        "title": "Raise the Workshop District",
        "body": "Upgrade the Palace and open the first production workshops.",
        "kind": "city",
        "target": 2,
    },
    {
        "title": "Stock the Builders",
        "body": "Prepare timber, bricks and stone blocks for the growing city.",
        "kind": "materials",
        "requirements": {"timber": 30.0, "bricks": 30.0, "blocks": 15.0},
    },
    {
        "title": "Complete a Nile Contract",
        "body": "Choose a trade contract and deliver the requested goods.",
        "kind": "contracts",
        "target": 1,
    },
    {
        "title": "Prove the Market",
        "body": "Serve local buyers and establish a dependable trade economy.",
        "kind": "trade",
        "target": 250.0,
    },
    {
        "title": "Open the River Town",
        "body": "Advance the city and unlock pottery, papyrus and richer trade.",
        "kind": "city",
        "target": 4,
    },
    {
        "title": "Supply the Royal District",
        "body": "Complete several contracts to supply the expanding royal city.",
        "kind": "contracts",
        "target": 4,
    },
    {
        "title": "Raise the Temple City",
        "body": "Grow the settlement into a prestigious Temple City.",
        "kind": "city",
        "target": 6,
    },
    {
        "title": "Complete the Nile Capital",
        "body": "Finish the final city district and establish a Great Nile Capital.",
        "kind": "city",
        "target": 7,
    },
]

var market_manager = null
var factories: Array = []
var chapter_index: int = 0
var completed_contracts: int = 0
var active_contract: Dictionary = {}
var contract_offers: Array = []
var activity_log: Array[String] = []
var event_cooldown: float = 70.0
var check_accumulator: float = 0.0
var shortage_cooldowns: Dictionary = {}
var harvest_combo: int = 0
var harvest_combo_timer: float = 0.0
var lifetime_harvest_hits: int = 0
var initialized: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(manager, factory_nodes: Array) -> void:
    market_manager = manager
    factories = factory_nodes
    rng.randomize()
    initialized = true
    if contract_offers.is_empty() and active_contract.is_empty():
        generate_contracts()


func _process(delta: float) -> void:
    if not initialized:
        return

    harvest_combo_timer = maxf(0.0, harvest_combo_timer - delta)
    if harvest_combo_timer <= 0.0:
        harvest_combo = 0

    event_cooldown -= delta
    if event_cooldown <= 0.0:
        _start_random_event()

    for key in shortage_cooldowns.keys():
        shortage_cooldowns[key] = maxf(0.0, float(shortage_cooldowns[key]) - delta)

    check_accumulator += delta
    if check_accumulator >= 0.75:
        check_accumulator = 0.0
        _check_chapter()
        _check_city_status()


func _check_chapter() -> void:
    if chapter_index >= CHAPTERS.size():
        return
    var chapter: Dictionary = CHAPTERS[chapter_index]
    if not _chapter_complete(chapter):
        return

    chapter_index += 1
    objective_changed.emit()
    var next_text: String = "The Great Nile Capital is complete."
    if chapter_index < CHAPTERS.size():
        next_text = "Next: %s" % String(CHAPTERS[chapter_index]["title"])
    notify("Chapter completed: %s" % String(chapter["title"]), "success")
    celebration_requested.emit("CHAPTER COMPLETE", "%s\n\n%s" % [String(chapter["title"]), next_text])


func _chapter_complete(chapter: Dictionary) -> bool:
    match String(chapter["kind"]):
        "resource":
            return GameState.amount(String(chapter["resource"])) >= float(chapter["target"])
        "food":
            return GameState.food_minutes() >= float(chapter["target"])
        "city":
            return GameState.city_level >= int(chapter["target"])
        "contracts":
            return completed_contracts >= int(chapter["target"])
        "trade":
            return market_manager != null and float(market_manager.total_sold) >= float(chapter["target"])
        "materials":
            var requirements: Dictionary = chapter["requirements"]
            for resource_name in requirements.keys():
                if GameState.amount(String(resource_name)) < float(requirements[resource_name]):
                    return false
            return true
    return false


func objective_title() -> String:
    if chapter_index >= CHAPTERS.size():
        return "Great Nile Capital"
    return String(CHAPTERS[chapter_index]["title"])


func objective_body() -> String:
    if chapter_index >= CHAPTERS.size():
        return "Continue improving production, contracts and the beauty of the capital."
    return String(CHAPTERS[chapter_index]["body"])


func objective_progress() -> String:
    if chapter_index >= CHAPTERS.size():
        return "CAPITAL COMPLETE"

    var chapter: Dictionary = CHAPTERS[chapter_index]
    match String(chapter["kind"]):
        "resource":
            var resource_name: String = String(chapter["resource"])
            return "%s %d/%d" % [resource_name.capitalize(), int(GameState.amount(resource_name)), int(chapter["target"])]
        "food":
            return "Food reserve %.1f/%.1f min" % [GameState.food_minutes(), float(chapter["target"])]
        "city":
            return "City Level %d/%d" % [GameState.city_level, int(chapter["target"])]
        "contracts":
            return "Contracts %d/%d" % [completed_contracts, int(chapter["target"])]
        "trade":
            return "Goods sold %d/%d" % [int(market_manager.total_sold if market_manager else 0.0), int(chapter["target"])]
        "materials":
            var parts: Array[String] = []
            var requirements: Dictionary = chapter["requirements"]
            for resource_name in requirements.keys():
                parts.append("%s %d/%d" % [
                    String(resource_name).capitalize(),
                    int(GameState.amount(String(resource_name))),
                    int(requirements[resource_name])
                ])
            return "  •  ".join(parts)
    return ""


func record_harvest(resource_name: String, amount_value: float) -> void:
    if harvest_combo_timer > 0.0:
        harvest_combo += 1
    else:
        harvest_combo = 1
    harvest_combo_timer = 2.2
    lifetime_harvest_hits += 1

    if harvest_combo in [12, 24, 36]:
        var coin_bonus: float = 12.0 + float(harvest_combo) * 1.5
        GameState.add_coins(coin_bonus)
        notify("Harvest streak ×%d — bonus %d coins!" % [harvest_combo, int(coin_bonus)], "success")


func generate_contracts() -> void:
    contract_offers.clear()
    var resource_pool: Array[String] = ["dates"]
    if GameState.city_level >= 4:
        resource_pool.append("pottery")
        resource_pool.append("scrolls")

    var unit_values: Dictionary = {"dates": 2.2, "pottery": 8.5, "scrolls": 12.0}
    var bonus_resources: Array[String] = ["timber", "bricks", "blocks"]

    for index in range(3):
        var requirements: Dictionary = {}
        var first_resource: String = resource_pool[index % resource_pool.size()]
        var first_amount: float = round(16.0 + float(GameState.city_level) * 7.0 + float(index) * 6.0)
        requirements[first_resource] = first_amount

        if resource_pool.size() > 1 and index == 2:
            var second_resource: String = resource_pool[(index + 1) % resource_pool.size()]
            requirements[second_resource] = round(10.0 + float(GameState.city_level) * 4.0)

        var goods_value: float = 0.0
        for resource_name in requirements.keys():
            goods_value += float(requirements[resource_name]) * float(unit_values[resource_name])

        contract_offers.append({
            "name": ["Village Caravan", "Temple Suppliers", "Royal River Barge"][index],
            "requirements": requirements,
            "reward_coins": round(goods_value * (2.0 + float(index) * 0.35)),
            "bonus_resource": bonus_resources[index],
            "bonus_amount": round(6.0 + float(GameState.city_level) * 3.0 + float(index) * 2.0),
        })

    contract_changed.emit()


func select_contract(index: int) -> bool:
    if not active_contract.is_empty() or index < 0 or index >= contract_offers.size():
        return false
    active_contract = Dictionary(contract_offers[index]).duplicate(true)
    contract_offers.clear()
    contract_changed.emit()
    notify("Contract accepted: %s" % String(active_contract["name"]), "contract")
    return true


func can_deliver_contract() -> bool:
    if active_contract.is_empty():
        return false
    var requirements: Dictionary = active_contract["requirements"]
    for resource_name in requirements.keys():
        if not GameState.can_take(String(resource_name), float(requirements[resource_name])):
            return false
    return true


func deliver_active_contract() -> bool:
    if not can_deliver_contract():
        notify("The contract is not ready. Produce the remaining requested goods.", "warning")
        return false

    var completed_name: String = String(active_contract["name"])
    var reward_coins: float = float(active_contract["reward_coins"])
    var bonus_resource: String = String(active_contract["bonus_resource"])
    var bonus_amount: float = float(active_contract["bonus_amount"])
    var requirements: Dictionary = active_contract["requirements"]

    for resource_name in requirements.keys():
        GameState.take_resource(String(resource_name), float(requirements[resource_name]))

    GameState.add_coins(reward_coins)
    GameState.add_resource(bonus_resource, bonus_amount)
    completed_contracts += 1
    active_contract.clear()
    generate_contracts()
    contract_changed.emit()
    objective_changed.emit()

    notify("%s delivered — +%d coins and %d %s." % [
        completed_name, int(reward_coins), int(bonus_amount), bonus_resource
    ], "success")
    celebration_requested.emit("CONTRACT COMPLETE", "%s has departed successfully.\n\nReward: %d coins and %d %s." % [
        completed_name, int(reward_coins), int(bonus_amount), bonus_resource
    ])
    return true


func active_contract_summary() -> String:
    if active_contract.is_empty():
        return "No active contract. Choose one of the three available requests."
    return "%s\n%s\nReward: %d coins + %d %s" % [
        String(active_contract["name"]),
        contract_progress(),
        int(active_contract["reward_coins"]),
        int(active_contract["bonus_amount"]),
        String(active_contract["bonus_resource"])
    ]


func contract_progress() -> String:
    if active_contract.is_empty():
        return "Choose a contract"
    var parts: Array[String] = []
    var requirements: Dictionary = active_contract["requirements"]
    for resource_name in requirements.keys():
        parts.append("%s %d/%d" % [
            String(resource_name).capitalize(),
            int(GameState.amount(String(resource_name))),
            int(requirements[resource_name])
        ])
    return "  •  ".join(parts)


func contract_offer_text(index: int) -> String:
    if index < 0 or index >= contract_offers.size():
        return ""
    var offer: Dictionary = contract_offers[index]
    return "%s\n%s\nREWARD %d coins + %d %s" % [
        String(offer["name"]).to_upper(),
        _requirements_text(offer["requirements"]),
        int(offer["reward_coins"]),
        int(offer["bonus_amount"]),
        String(offer["bonus_resource"])
    ]


func _requirements_text(requirements: Dictionary) -> String:
    var parts: Array[String] = []
    for resource_name in requirements.keys():
        parts.append("%d %s" % [int(requirements[resource_name]), String(resource_name).capitalize()])
    return " + ".join(parts)


func _check_city_status() -> void:
    if GameState.food_minutes() < 3.0 and _cooldown_ready("food"):
        shortage_cooldowns["food"] = 75.0
        notify("Food reserves are low — population growth may pause.", "critical")

    for factory in factories:
        if not is_instance_valid(factory) or factory.level <= 0 or not factory.is_unlocked():
            continue

        var full_key: String = "%s_full" % String(factory.factory_id)
        if factory.output_buffer >= factory.storage_capacity() * 0.94 and _cooldown_ready(full_key):
            shortage_cooldowns[full_key] = 75.0
            notify("%s storage is full — improve hauling or its conveyor." % factory.display_name, "warning", factory.global_position)
            continue

        var input_key: String = "%s_input" % String(factory.factory_id)
        if GameState.amount(factory.input_resource) < factory.input_amount and _cooldown_ready(input_key):
            shortage_cooldowns[input_key] = 95.0
            notify("%s needs more %s." % [factory.display_name, factory.input_resource], "warning", factory.global_position)


func _cooldown_ready(key: String) -> bool:
    return not shortage_cooldowns.has(key) or float(shortage_cooldowns[key]) <= 0.0


func _start_random_event() -> void:
    event_cooldown = rng.randf_range(90.0, 135.0)
    var event_index: int = rng.randi_range(0, 3)

    match event_index:
        0:
            var grain_bonus: float = 28.0 + float(GameState.city_level) * 9.0
            var dates_bonus: float = 10.0 + float(GameState.city_level) * 4.0
            GameState.add_resource("grain", grain_bonus)
            GameState.add_resource("dates", dates_bonus)
            notify("Nile floodwaters enriched the farms.", "event")
            celebration_requested.emit("FLOOD SEASON", "The Nile has renewed the fields.\n\n+%d grain and +%d dates." % [int(grain_bonus), int(dates_bonus)])
        1:
            var stone_bonus: float = 24.0 + float(GameState.city_level) * 8.0
            var clay_bonus: float = 18.0 + float(GameState.city_level) * 6.0
            GameState.add_resource("stone", stone_bonus)
            GameState.add_resource("clay", clay_bonus)
            notify("Workers discovered a rich quarry seam.", "event")
            celebration_requested.emit("RICH QUARRY SEAM", "A fresh deposit has been uncovered.\n\n+%d stone and +%d raw clay." % [int(stone_bonus), int(clay_bonus)])
        2:
            var royal_coins: float = 180.0 + float(GameState.city_level) * 140.0
            GameState.add_coins(royal_coins)
            notify("A royal inspector rewarded the city's progress.", "event")
            celebration_requested.emit("ROYAL INSPECTION", "The city impressed the royal court.\n\n+%d coins." % int(royal_coins))
        3:
            generate_contracts()
            notify("A merchant flotilla brought three fresh contracts.", "contract")
            celebration_requested.emit("MERCHANT FLOTILLA", "New trade opportunities have arrived at the Nile market.")


func notify(text_value: String, kind: String = "info", focus_position: Vector2 = Vector2.ZERO) -> void:
    activity_log.push_front(text_value)
    while activity_log.size() > 24:
        activity_log.pop_back()
    message_requested.emit(text_value, kind, focus_position)


func recent_messages() -> String:
    if activity_log.is_empty():
        return "No city messages yet."
    return "\n\n".join(activity_log)


func to_dict() -> Dictionary:
    return {
        "chapter_index": chapter_index,
        "completed_contracts": completed_contracts,
        "active_contract": active_contract.duplicate(true),
        "contract_offers": contract_offers.duplicate(true),
        "activity_log": activity_log.duplicate(),
        "event_cooldown": event_cooldown,
        "lifetime_harvest_hits": lifetime_harvest_hits,
    }


func from_dict(data: Dictionary) -> void:
    if data.is_empty():
        if GameState.city_level >= 6:
            chapter_index = 8
        elif GameState.city_level >= 4:
            chapter_index = 4
        elif GameState.city_level >= 2:
            chapter_index = 3
        else:
            chapter_index = 0
        generate_contracts()
        return

    chapter_index = clampi(int(data.get("chapter_index", 0)), 0, CHAPTERS.size())
    completed_contracts = maxi(0, int(data.get("completed_contracts", 0)))
    active_contract = Dictionary(data.get("active_contract", {})).duplicate(true)
    contract_offers = Array(data.get("contract_offers", [])).duplicate(true)
    activity_log.clear()
    for message in Array(data.get("activity_log", [])):
        activity_log.append(String(message))
    event_cooldown = maxf(20.0, float(data.get("event_cooldown", 70.0)))
    lifetime_harvest_hits = maxi(0, int(data.get("lifetime_harvest_hits", 0)))

    if active_contract.is_empty() and contract_offers.is_empty():
        generate_contracts()
    objective_changed.emit()
    contract_changed.emit()
