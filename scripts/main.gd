extends Control

const MAX_TURN := 12
const MAX_OPEN_EVENTS := 3
const WIN_RESOLVED_EVENTS := 6

@onready var title_label: Label = %TitleLabel
@onready var turn_label: Label = %TurnLabel
@onready var goal_label: Label = %GoalLabel
@onready var stats_label: Label = %StatsLabel
@onready var card_buttons: Array[Button] = [%Card1Button, %Card2Button, %Card3Button]
@onready var events_list: ItemList = %EventsList
@onready var event_detail_label: Label = %EventDetailLabel
@onready var assign_button: Button = %AssignButton
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
var selected_event_index := -1

var cards: Array[Dictionary] = []
var fixed_event_queue: Array[Dictionary] = []
var random_event_pool: Array[Dictionary] = []
var open_events: Array[Dictionary] = []

func _ready() -> void:
	randomize()
	title_label.text = "苏丹式互动演示"
	goal_label.text = "派遣角色卡处理事件，在第 %d 回合前解决 %d 个事件即可获胜。" % [MAX_TURN, WIN_RESOLVED_EVENTS]

	for i in card_buttons.size():
		var idx := i
		card_buttons[i].pressed.connect(func() -> void:
			_on_card_selected(idx)
		)

	events_list.item_selected.connect(_on_event_selected)
	assign_button.pressed.connect(_on_assign_pressed)
	next_turn_button.pressed.connect(_on_next_turn_pressed)
	restart_button.pressed.connect(_on_restart_pressed)

	_start_new_game()

func _start_new_game() -> void:
	turn = 1
	game_over = false
	resolved_events = 0
	selected_card_id = -1
	selected_event_index = -1
	realm = {"gold": 8, "food": 8, "stability": 8}
	cards = _build_cards()
	fixed_event_queue = _build_fixed_events()
	random_event_pool = _build_random_events()
	open_events.clear()
	log_label.clear()
	_append_log("新的统治开始了。")
	_spawn_event_if_possible()
	restart_button.visible = false
	_refresh_all_ui()

func _build_cards() -> Array[Dictionary]:
	return [
		{"id": 0, "name": "阿济姆将军", "mil": 5, "wit": 2, "cha": 2, "cooldown": 0},
		{"id": 1, "name": "纳迪尔宰相", "mil": 1, "wit": 5, "cha": 3, "cooldown": 0},
		{"id": 2, "name": "萨米拉使者", "mil": 2, "wit": 3, "cha": 5, "cooldown": 0}
	]

func _build_fixed_events() -> Array[Dictionary]:
	return [
		{
			"id": "fixed_bandits",
			"title": "边境劫掠",
			"desc": "盗匪袭扰商路，边境告急。",
			"attr": "mil",
			"dc": 5,
			"deadline": 2,
			"success": {"gold": 3, "food": 0, "stability": 1},
			"fail": {"gold": -2, "food": -1, "stability": -1}
		},
		{
			"id": "fixed_famine",
			"title": "粮仓危机",
			"desc": "霉变侵蚀粮仓，储粮受损。",
			"attr": "wit",
			"dc": 5,
			"deadline": 2,
			"success": {"gold": 0, "food": 3, "stability": 1},
			"fail": {"gold": -1, "food": -3, "stability": -1}
		}
	]

func _build_random_events() -> Array[Dictionary]:
	return [
		{
			"id": "rand_envoy",
			"title": "外邦使团",
			"desc": "敌对邦国派来使节，提出紧张条约。",
			"attr": "cha",
			"dc": 5,
			"deadline": 2,
			"success": {"gold": 2, "food": 1, "stability": 1},
			"fail": {"gold": -1, "food": 0, "stability": -2}
		},
		{
			"id": "rand_corruption",
			"title": "税路贪腐",
			"desc": "官员在征税线路层层盘剥。",
			"attr": "wit",
			"dc": 6,
			"deadline": 2,
			"success": {"gold": 2, "food": 0, "stability": 1},
			"fail": {"gold": -2, "food": 0, "stability": -2}
		},
		{
			"id": "rand_merc",
			"title": "佣兵哗变",
			"desc": "欠饷佣兵威胁军营秩序。",
			"attr": "mil",
			"dc": 6,
			"deadline": 1,
			"success": {"gold": 0, "food": 0, "stability": 2},
			"fail": {"gold": -1, "food": -1, "stability": -3}
		}
	]

func _refresh_all_ui() -> void:
	turn_label.text = "回合：%d / %d | 已解决：%d / %d" % [turn, MAX_TURN, resolved_events, WIN_RESOLVED_EVENTS]
	stats_label.text = "国库：%d    粮食：%d    稳定：%d" % [realm["gold"], realm["food"], realm["stability"]]
	_refresh_cards_ui()
	_refresh_events_ui()
	assign_button.disabled = game_over
	next_turn_button.disabled = game_over

func _refresh_cards_ui() -> void:
	for i in cards.size():
		var c: Dictionary = cards[i]
		var status := "可用"
		if c["cooldown"] > 0:
			status = "忙碌(%d)" % c["cooldown"]
		var selected_mark := ""
		if selected_card_id == c["id"]:
			selected_mark = "【已选】"
		card_buttons[i].text = "%s%s\n武力 %d | 智略 %d | 魅力 %d\n%s" % [c["name"], selected_mark, c["mil"], c["wit"], c["cha"], status]
		card_buttons[i].disabled = game_over

func _refresh_events_ui() -> void:
	events_list.clear()
	for i in open_events.size():
		var e: Dictionary = open_events[i]
		events_list.add_item("%s | 需求：%s ≥ %d | 剩余：%d 回合" % [e["title"], _attr_label(String(e["attr"])), e["dc"], e["deadline"]])

	if selected_event_index >= open_events.size():
		selected_event_index = -1

	if selected_event_index >= 0 and selected_event_index < open_events.size():
		events_list.select(selected_event_index)
		_show_event_detail(selected_event_index)
	else:
		event_detail_label.text = "请选择一个事件查看详情。"

func _show_event_detail(index: int) -> void:
	if index < 0 or index >= open_events.size():
		return
	var e: Dictionary = open_events[index]
	event_detail_label.text = "%s\n%s\n成功：%s\n失败：%s" % [
		e["title"],
		e["desc"],
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

func _on_event_selected(index: int) -> void:
	selected_event_index = index
	_show_event_detail(index)

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

	var event: Dictionary = open_events[selected_event_index]
	var attr_name: String = event["attr"]
	var power: int = int(card[attr_name]) + randi_range(-1, 2)
	var dc: int = event["dc"]
	var success := power >= dc

	if success:
		resolved_events += 1
		_apply_effects(event["success"])
		_append_log("成功：%s 处理了「%s」（%d 对 %d）。" % [card["name"], event["title"], power, dc])
	else:
		_apply_effects(event["fail"])
		_append_log("失败：%s 未能处理「%s」（%d 对 %d）。" % [card["name"], event["title"], power, dc])

	cards[card_index]["cooldown"] = 1
	open_events.remove_at(selected_event_index)
	selected_event_index = -1
	selected_card_id = -1

	_check_game_state()
	_refresh_all_ui()

func _on_next_turn_pressed() -> void:
	if game_over:
		return

	turn += 1
	for i in cards.size():
		if cards[i]["cooldown"] > 0:
			cards[i]["cooldown"] -= 1

	_process_event_deadlines()
	_spawn_event_if_possible()
	_check_game_state()
	_refresh_all_ui()

func _process_event_deadlines() -> void:
	var survivors: Array[Dictionary] = []
	for e in open_events:
		e["deadline"] -= 1
		if e["deadline"] < 0:
			_apply_effects(e["fail"])
			_append_log("逾期：事件「%s」被拖延错过了。" % e["title"])
		else:
			survivors.append(e)
	open_events = survivors
	selected_event_index = -1

func _spawn_event_if_possible() -> void:
	while open_events.size() < MAX_OPEN_EVENTS:
		var event_to_add: Dictionary = {}
		if fixed_event_queue.size() > 0:
			event_to_add = fixed_event_queue.pop_front().duplicate(true)
		else:
			if randf() > 0.65:
				break
			event_to_add = random_event_pool[randi() % random_event_pool.size()].duplicate(true)
		open_events.append(event_to_add)

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
