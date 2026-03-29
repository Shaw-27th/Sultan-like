extends Control

const MAX_TURN := 14
const MAX_OPEN_EVENTS := 6
const WIN_RESOLVED_EVENTS := 8

@onready var title_label: Label = %TitleLabel
@onready var turn_label: Label = %TurnLabel
@onready var goal_label: Label = %GoalLabel
@onready var stats_label: Label = %StatsLabel
@onready var card_buttons: Array[Button] = [%Card1Button, %Card2Button, %Card3Button]
@onready var capital_spot_button: Button = %CapitalSpotButton
@onready var frontier_spot_button: Button = %FrontierSpotButton
@onready var port_spot_button: Button = %PortSpotButton
@onready var location_detail_label: Label = %LocationDetailLabel
@onready var events_list: ItemList = %EventsList
@onready var event_detail_label: Label = %EventDetailLabel
@onready var assign_button: Button = %AssignButton
@onready var cancel_assign_button: Button = %CancelAssignButton
@onready var next_turn_button: Button = %NextTurnButton
@onready var restart_button: Button = %RestartButton
@onready var log_label: RichTextLabel = %LogLabel

var turn := 1
var game_over := false
var resolved_events := 0

var realm := {
	"gold": 8,
	"food": 8,
	"stability": 8
}

var selected_card_id := -1
var selected_location_id := -1
var selected_event_index := -1
var event_instance_seed := 0

var cards: Array[Dictionary] = []
var locations: Array[Dictionary] = []
var open_events: Array[Dictionary] = []
var spawned_fixed_event_keys: Dictionary = {}

func _ready() -> void:
	randomize()
	title_label.text = "苏丹式互动演示"
	goal_label.text = "地图地点会周期刷出事件。每回合可派遣一个或多个角色，下一回合按顺序结算。"

	for i in card_buttons.size():
		var idx := i
		card_buttons[i].pressed.connect(func() -> void:
			_on_card_selected(idx)
		)

	capital_spot_button.pressed.connect(func() -> void:
		_on_location_selected_by_id(0)
	)
	frontier_spot_button.pressed.connect(func() -> void:
		_on_location_selected_by_id(1)
	)
	port_spot_button.pressed.connect(func() -> void:
		_on_location_selected_by_id(2)
	)
	events_list.item_selected.connect(_on_event_selected)
	assign_button.pressed.connect(_on_assign_pressed)
	cancel_assign_button.pressed.connect(_on_cancel_assign_pressed)
	next_turn_button.pressed.connect(_on_next_turn_pressed)
	restart_button.pressed.connect(_on_restart_pressed)

	_start_new_game()

func _start_new_game() -> void:
	turn = 1
	game_over = false
	resolved_events = 0
	selected_card_id = -1
	selected_location_id = -1
	selected_event_index = -1
	event_instance_seed = 0
	realm = {"gold": 8, "food": 8, "stability": 8}
	cards = _build_cards()
	locations = _build_locations()
	open_events.clear()
	spawned_fixed_event_keys.clear()
	log_label.clear()
	_append_log("新的统治开始了。")
	_spawn_events_for_turn()
	restart_button.visible = false
	_refresh_all_ui()

func _build_cards() -> Array[Dictionary]:
	return [
		{"id": 0, "name": "阿济姆将军", "mil": 5, "wit": 2, "cha": 2, "cooldown": 0, "assigned_event_id": ""},
		{"id": 1, "name": "纳迪尔宰相", "mil": 1, "wit": 5, "cha": 3, "cooldown": 0, "assigned_event_id": ""},
		{"id": 2, "name": "萨米拉使者", "mil": 2, "wit": 3, "cha": 5, "cooldown": 0, "assigned_event_id": ""}
	]

func _build_locations() -> Array[Dictionary]:
	return [
		{
			"id": 0,
			"name": "王都",
			"desc": "政治中心，稳定与财政事件更频繁。",
			"events": [
				{
					"id": "capital_audit",
					"title": "御史清查",
					"desc": "中央财政接受审计，官僚系统紧张。",
					"attr": "wit",
					"dc": 7,
					"deadline": 2,
					"spawn": {"type": "fixed_turn", "turns": [1]},
					"success": {"gold": 3, "food": 0, "stability": 1},
					"fail": {"gold": -3, "food": 0, "stability": -2}
				},
				{
					"id": "capital_petition",
					"title": "百官联署",
					"desc": "群臣递交联署，请求改革官阶。",
					"attr": "cha",
					"dc": 7,
					"deadline": 2,
					"spawn": {"type": "interval", "start": 2, "every": 3},
					"success": {"gold": 1, "food": 0, "stability": 2},
					"fail": {"gold": -1, "food": 0, "stability": -2}
				}
			]
		},
		{
			"id": 1,
			"name": "边境",
			"desc": "军事压力大，突发冲突多。",
			"events": [
				{
					"id": "frontier_bandits",
					"title": "边境劫掠",
					"desc": "盗匪袭扰商路，边防告急。",
					"attr": "mil",
					"dc": 6,
					"deadline": 2,
					"spawn": {"type": "fixed_turn", "turns": [1, 5]},
					"success": {"gold": 2, "food": 1, "stability": 1},
					"fail": {"gold": -2, "food": -1, "stability": -2}
				},
				{
					"id": "frontier_merc",
					"title": "佣兵哗变",
					"desc": "军饷拖欠引发兵营不满。",
					"attr": "mil",
					"dc": 7,
					"deadline": 1,
					"spawn": {"type": "random", "chance": 0.45},
					"success": {"gold": -1, "food": 0, "stability": 2},
					"fail": {"gold": -2, "food": -1, "stability": -3}
				}
			]
		},
		{
			"id": 2,
			"name": "港口",
			"desc": "贸易与外交汇聚，收益与风险并存。",
			"events": [
				{
					"id": "port_envoys",
					"title": "外邦使团",
					"desc": "港口来访使团，提出苛刻条约。",
					"attr": "cha",
					"dc": 6,
					"deadline": 2,
					"spawn": {"type": "interval", "start": 3, "every": 2},
					"success": {"gold": 2, "food": 1, "stability": 1},
					"fail": {"gold": -1, "food": 0, "stability": -2}
				},
				{
					"id": "port_storm",
					"title": "港区风暴",
					"desc": "风暴影响航运，码头急需调度。",
					"attr": "wit",
					"dc": 6,
					"deadline": 1,
					"spawn": {"type": "random", "chance": 0.35},
					"success": {"gold": 1, "food": 2, "stability": 0},
					"fail": {"gold": -2, "food": -2, "stability": -1}
				}
			]
		}
	]

func _refresh_all_ui() -> void:
	turn_label.text = "回合：%d / %d | 已解决：%d / %d" % [turn, MAX_TURN, resolved_events, WIN_RESOLVED_EVENTS]
	stats_label.text = "国库：%d    粮食：%d    稳定：%d" % [realm["gold"], realm["food"], realm["stability"]]
	_refresh_cards_ui()
	_refresh_locations_ui()
	_refresh_events_ui()
	assign_button.disabled = game_over
	cancel_assign_button.disabled = game_over
	next_turn_button.disabled = game_over

func _refresh_cards_ui() -> void:
	for i in cards.size():
		var c: Dictionary = cards[i]
		var status := "可用"
		if c["cooldown"] > 0:
			status = "忙碌(%d)" % c["cooldown"]
		elif String(c["assigned_event_id"]) != "":
			status = "已派遣"
		var selected_mark := ""
		if selected_card_id == c["id"]:
			selected_mark = "【已选】"
		card_buttons[i].text = "%s%s\n武力 %d | 智略 %d | 魅力 %d\n%s" % [c["name"], selected_mark, c["mil"], c["wit"], c["cha"], status]
		card_buttons[i].disabled = game_over

func _refresh_locations_ui() -> void:
	if selected_location_id == -1 and locations.size() > 0:
		selected_location_id = int(locations[0]["id"])

	var idx := _find_location_index(selected_location_id)
	if idx >= 0:
		location_detail_label.text = "地图地点：%s\n%s" % [locations[idx]["name"], locations[idx]["desc"]]
		capital_spot_button.text = _spot_button_text(0, "王都")
		frontier_spot_button.text = _spot_button_text(1, "边境")
		port_spot_button.text = _spot_button_text(2, "港口")

func _refresh_events_ui() -> void:
	events_list.clear()
	var visible_indices: Array[int] = []
	for i in open_events.size():
		var e: Dictionary = open_events[i]
		if selected_location_id != -1 and int(e["location_id"]) != selected_location_id:
			continue
		visible_indices.append(i)
		var assigned_count := int(e["assigned_cards"].size())
		events_list.add_item("[%s] %s | %s≥%d | 剩余:%d | 已派遣:%d" % [e["location_name"], e["title"], _attr_label(String(e["attr"])), e["dc"], e["deadline"], assigned_count])

	if selected_event_index >= open_events.size():
		selected_event_index = -1

	if selected_event_index >= 0:
		var visible_pos := visible_indices.find(selected_event_index)
		if visible_pos != -1:
			events_list.select(visible_pos)
			_show_event_detail(selected_event_index)
		else:
			selected_event_index = -1
			event_detail_label.text = "请选择一个事件查看详情。"
	else:
		event_detail_label.text = "请选择一个事件查看详情。"

func _show_event_detail(index: int) -> void:
	if index < 0 or index >= open_events.size():
		return
	var e: Dictionary = open_events[index]
	var members: Array[String] = []
	for card_id in e["assigned_cards"]:
		members.append(_card_name(int(card_id)))
	var members_text := "无"
	if members.size() > 0:
		members_text = ", ".join(members)
	event_detail_label.text = "[%s] %s\n%s\n需求：%s ≥ %d\n已派遣：%s\n成功：%s\n失败：%s" % [
		e["location_name"],
		e["title"],
		e["desc"],
		_attr_label(String(e["attr"])),
		e["dc"],
		members_text,
		_effects_text(e["success"]),
		_effects_text(e["fail"])
	]

func _on_card_selected(index: int) -> void:
	if game_over:
		return
	var c: Dictionary = cards[index]
	if c["cooldown"] > 0:
		_append_log("%s 本回合仍在忙碌。" % c["name"])
		return
	selected_card_id = c["id"]
	_refresh_cards_ui()

func _on_location_selected_by_id(location_id: int) -> void:
	selected_location_id = location_id
	selected_event_index = -1
	_refresh_all_ui()

func _on_event_selected(index: int) -> void:
	var visible_indices: Array[int] = []
	for i in open_events.size():
		if selected_location_id == -1 or int(open_events[i]["location_id"]) == selected_location_id:
			visible_indices.append(i)
	if index < 0 or index >= visible_indices.size():
		return
	selected_event_index = visible_indices[index]
	_show_event_detail(selected_event_index)

func _on_assign_pressed() -> void:
	if game_over:
		return
	if selected_card_id < 0:
		_append_log("请先选择一张角色卡。")
		return
	if selected_event_index < 0 or selected_event_index >= open_events.size():
		_append_log("请先选择一个事件。")
		return

	var card_index := _find_card_index(selected_card_id)
	if card_index == -1:
		return
	var card: Dictionary = cards[card_index]
	if card["cooldown"] > 0:
		_append_log("该角色卡当前忙碌，无法派遣。")
		return
	if String(card["assigned_event_id"]) != "":
		_append_log("%s 已经被派往其他事件。" % card["name"])
		return

	var event: Dictionary = open_events[selected_event_index]
	if event["assigned_cards"].has(selected_card_id):
		_append_log("%s 已在该事件队伍中。" % card["name"])
		return

	event["assigned_cards"].append(selected_card_id)
	cards[card_index]["assigned_event_id"] = String(event["instance_id"])
	open_events[selected_event_index] = event
	_append_log("派遣：%s 前往 [%s]「%s」。" % [card["name"], event["location_name"], event["title"]])
	selected_card_id = -1
	_refresh_all_ui()

func _on_cancel_assign_pressed() -> void:
	if game_over:
		return
	if selected_event_index < 0 or selected_event_index >= open_events.size():
		_append_log("请先选择一个事件，再取消派遣。")
		return

	var event: Dictionary = open_events[selected_event_index]
	if event["assigned_cards"].is_empty():
		_append_log("该事件当前没有已派遣角色。")
		return

	if selected_card_id >= 0:
		if not event["assigned_cards"].has(selected_card_id):
			_append_log("所选角色并未派遣到该事件。")
			return
		event["assigned_cards"].erase(selected_card_id)
		var card_index := _find_card_index(selected_card_id)
		if card_index != -1:
			cards[card_index]["assigned_event_id"] = ""
		_append_log("取消派遣：%s 从 [%s]「%s」撤回。" % [_card_name(selected_card_id), event["location_name"], event["title"]])
		selected_card_id = -1
	else:
		for card_id in event["assigned_cards"]:
			var card_index := _find_card_index(int(card_id))
			if card_index != -1:
				cards[card_index]["assigned_event_id"] = ""
		event["assigned_cards"].clear()
		_append_log("取消派遣：已撤回 [%s]「%s」的全部角色。" % [event["location_name"], event["title"]])

	open_events[selected_event_index] = event
	_refresh_all_ui()

func _on_next_turn_pressed() -> void:
	if game_over:
		return

	turn += 1
	for i in cards.size():
		if cards[i]["cooldown"] > 0:
			cards[i]["cooldown"] -= 1

	_append_log("[b]--- 第 %d 回合结算开始 ---[/b]" % turn)
	_resolve_assigned_events_in_order()
	_process_event_deadlines()
	_spawn_events_for_turn()
	_check_game_state()
	_refresh_all_ui()

func _resolve_assigned_events_in_order() -> void:
	var resolved_indices: Array[int] = []
	var order := 1
	for i in open_events.size():
		var event: Dictionary = open_events[i]
		if event["assigned_cards"].size() == 0:
			continue
		var total_power := 0
		for card_id in event["assigned_cards"]:
			var card_index := _find_card_index(int(card_id))
			if card_index == -1:
				continue
			var card: Dictionary = cards[card_index]
			total_power += int(card[String(event["attr"])])
			total_power += randi_range(-1, 1)
			cards[card_index]["cooldown"] = 1
			cards[card_index]["assigned_event_id"] = ""

		if total_power >= int(event["dc"]):
			resolved_events += 1
			_apply_effects(event["success"])
			_append_log("%d) 成功结算 [%s]「%s」(总战力 %d / 难度 %d)。" % [order, event["location_name"], event["title"], total_power, event["dc"]])
		else:
			_apply_effects(event["fail"])
			_append_log("%d) 失败结算 [%s]「%s」(总战力 %d / 难度 %d)。" % [order, event["location_name"], event["title"], total_power, event["dc"]])
		resolved_indices.append(i)
		order += 1

	resolved_indices.reverse()
	for idx in resolved_indices:
		open_events.remove_at(idx)
	selected_event_index = -1

func _process_event_deadlines() -> void:
	var survivors: Array[Dictionary] = []
	for e in open_events:
		e["deadline"] -= 1
		if e["deadline"] < 0:
			_apply_effects(e["fail"])
			_append_log("逾期：[%s]「%s」未处理，按失败结算。" % [e["location_name"], e["title"]])
			for card_id in e["assigned_cards"]:
				var card_index := _find_card_index(int(card_id))
				if card_index != -1:
					cards[card_index]["assigned_event_id"] = ""
		else:
			survivors.append(e)
	open_events = survivors
	selected_event_index = -1

func _spawn_events_for_turn() -> void:
	for location in locations:
		for template in location["events"]:
			if open_events.size() >= MAX_OPEN_EVENTS:
				return
			if not _should_spawn_event(location, template):
				continue
			if _has_open_event(String(template["id"]), int(location["id"])):
				continue
			open_events.append(_instantiate_event(location, template))

func _should_spawn_event(location: Dictionary, template: Dictionary) -> bool:
	var spawn: Dictionary = template["spawn"]
	var spawn_type := String(spawn["type"])
	if spawn_type == "fixed_turn":
		for t in spawn["turns"]:
			if int(t) == turn:
				var key := "%s#%d#%d" % [template["id"], location["id"], int(t)]
				if spawned_fixed_event_keys.has(key):
					return false
				spawned_fixed_event_keys[key] = true
				return true
		return false
	if spawn_type == "interval":
		var start := int(spawn["start"])
		var every := int(spawn["every"])
		if turn >= start and (turn - start) % every == 0:
			return true
		return false
	if spawn_type == "random":
		return randf() < float(spawn["chance"])
	return false

func _instantiate_event(location: Dictionary, template: Dictionary) -> Dictionary:
	event_instance_seed += 1
	return {
		"instance_id": "%s_%d" % [template["id"], event_instance_seed],
		"template_id": template["id"],
		"location_id": location["id"],
		"location_name": location["name"],
		"title": template["title"],
		"desc": template["desc"],
		"attr": template["attr"],
		"dc": template["dc"],
		"deadline": template["deadline"],
		"success": template["success"],
		"fail": template["fail"],
		"assigned_cards": []
	}

func _has_open_event(template_id: String, location_id: int) -> bool:
	for e in open_events:
		if String(e["template_id"]) == template_id and int(e["location_id"]) == location_id:
			return true
	return false

func _check_game_state() -> void:
	if realm["stability"] <= 0 or realm["gold"] < 0 or realm["food"] < 0:
		_end_game(false, "国政崩溃，王朝失序。")
		return
	if resolved_events >= WIN_RESOLVED_EVENTS:
		_end_game(true, "你稳住了朝局，政权得以延续。")
		return
	if turn > MAX_TURN:
		_end_game(false, "时限已到，改革未竟。")

func _end_game(win: bool, msg: String) -> void:
	if game_over:
		return
	game_over = true
	restart_button.visible = true
	if win:
		_append_log("[color=lime][b]胜利：[/b][/color] %s" % msg)
	else:
		_append_log("[color=red][b]失败：[/b][/color] %s" % msg)

func _on_restart_pressed() -> void:
	_start_new_game()

func _find_card_index(card_id: int) -> int:
	for i in cards.size():
		if cards[i]["id"] == card_id:
			return i
	return -1

func _find_location_index(location_id: int) -> int:
	for i in locations.size():
		if int(locations[i]["id"]) == location_id:
			return i
	return -1

func _spot_button_text(location_id: int, base_name: String) -> String:
	if selected_location_id == location_id:
		return "▶ %s" % base_name
	return base_name

func _card_name(card_id: int) -> String:
	var idx := _find_card_index(card_id)
	if idx == -1:
		return "未知"
	return String(cards[idx]["name"])

func _apply_effects(effects: Dictionary) -> void:
	for k in ["gold", "food", "stability"]:
		if effects.has(k):
			realm[k] += int(effects[k])

func _effects_text(effects: Dictionary) -> String:
	var out: Array[String] = []
	for k in ["gold", "food", "stability"]:
		if effects.has(k):
			var v := int(effects[k])
			var sign := "+"
			if v < 0:
				sign = ""
			out.append("%s%s %s" % [sign, str(v), _resource_label(k)])
	return ", ".join(out)

func _resource_label(key: String) -> String:
	match key:
		"gold":
			return "国库"
		"food":
			return "粮食"
		"stability":
			return "稳定"
		_:
			return key

func _attr_label(key: String) -> String:
	match key:
		"mil":
			return "武力"
		"wit":
			return "智略"
		"cha":
			return "魅力"
		_:
			return key

func _append_log(text: String) -> void:
	log_label.append_text(text + "\n")
