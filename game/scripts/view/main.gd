extends Node
## Switches between the main menu, the Salt career slice and the parliament scenario.
## Command-line tools (after `--`): --shots=DIR (screenshot tour), --autoplay=SECONDS (interface smoke test),
## --pact-shots=DIR (parliament screenshots), --menu-shot=FILE.

var map: MapView
var hud: HUD
var layer: CanvasLayer
var menu: MainMenu
var pact: PactScreen
var mode := ""
var _drift: Tween


func _ready() -> void:
	map = MapView.new()
	add_child(map)
	layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--shots="):
			start_salt()
			_tour(a.substr(8))
			return
		if a.begins_with("--autoplay="):
			start_salt()
			_autoplay(float(a.substr(11)))
			return
		if a.begins_with("--pact-shots="):
			start_pact()
			_pact_tour(a.substr(13))
			return
		if a.begins_with("--menu-shot="):
			show_menu()
			await get_tree().create_timer(2.0).timeout
			await _save(a.substr(12))
			get_tree().quit()
			return
	show_menu()


func _clear() -> void:
	for c in layer.get_children():
		c.queue_free()
	hud = null
	menu = null
	pact = null
	if _drift:
		_drift.kill()


func show_menu() -> void:
	_clear()
	mode = "menu"
	map.set_shown(true)
	map.show_tokens = false
	Game.new_game(1953)
	Game.set_speed(0)
	Game.ui_hold = true
	Game.minutes = 18 * 60 + 10 # sunset over the map
	map.cam.position = Game.town_pos("amman") + Vector2(-70, 60)
	map.cam.zoom = Vector2(1.7, 1.7)
	_drift = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_drift.tween_property(map.cam, "position", Game.town_pos("amman") + Vector2(30, -30), 24.0)
	_drift.tween_property(map.cam, "position", Game.town_pos("amman") + Vector2(-70, 60), 24.0)
	menu = MainMenu.new()
	menu.chosen.connect(func(m): start_pact() if m == "pact" else start_salt())
	layer.add_child(menu)


func start_salt() -> void:
	_clear()
	mode = "salt"
	map.set_shown(true)
	map.show_tokens = true
	Game.new_game(randi())
	Game.ui_hold = false
	map.cam.position = Game.town_pos("salt") + Vector2(10, 4)
	map.cam.zoom = Vector2(3.2, 3.2)
	hud = HUD.new()
	hud.map = map
	hud.menu_requested.connect(show_menu)
	layer.add_child(hud)
	if not map.town_clicked.is_connected(_on_town):
		map.town_clicked.connect(_on_town)
	Game.set_speed(0)
	hud.show_intro()


func _on_town(id: String) -> void:
	if hud and mode == "salt":
		hud.ask_travel(id)


func start_pact() -> void:
	_clear()
	mode = "pact"
	map.set_shown(false)
	Game.set_speed(0)
	Game.ui_hold = true
	pact = PactScreen.new()
	pact.back_to_menu.connect(show_menu)
	layer.add_child(pact)
	pact.start(randi())


func _save(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path.get_file())


func _shot(dir: String, name: String) -> void:
	await _save("%s/%s.png" % [dir, name])


func _tour(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(1.0).timeout
	await _shot(dir, "01-intro")
	hud.close_modal()
	await _shot(dir, "02-salt-morning")
	hud.open_meet("mayor")
	await _shot(dir, "03-meet")
	hud.close_modal()
	Game.start_duel("mayor", "chat")
	hud._open_duel()
	await get_tree().process_frame
	Game.duel_play("listen")
	Game.duel_play("flatter")
	hud.close_modal()
	hud._open_duel()
	await _shot(dir, "04-duel")
	var r := Game.duel_finish()
	hud.close_modal()
	hud._duel_result(Game.people["mayor"], r)
	await _shot(dir, "05-duel-result")
	hud.close_modal()
	Game.advance(10 * 60 + 20)
	_clear_popups()
	map.focus(Game.town_pos("salt") + Vector2(6, 6), 4.2)
	await get_tree().create_timer(1.0).timeout
	await _shot(dir, "06-salt-evening")
	hud.open_schemes()
	await _shot(dir, "07-schemes")
	hud.close_modal()
	hud.open_cabinet()
	await _shot(dir, "08-cabinet")
	hud.close_modal()
	Game.do_action("sleep")
	_clear_popups()
	Game.start_travel("irbid")
	Game.advance(150)
	_clear_popups()
	map.focus(Game.player_pos(), 1.7)
	await get_tree().create_timer(1.0).timeout
	await _shot(dir, "09-travel")
	while Game.day() < 7 or Game.hour() < 7:
		_clear_popups()
		Game.advance(60, false)
		if Game.paper_open:
			break
	await _shot(dir, "10-newspaper")
	_clear_popups()
	Game.water["severity"] = 78
	Game.minutes = Game.day() * 1440 + 21 * 60
	map.focus(Game.town_pos("salt"), 2.4)
	await get_tree().create_timer(1.0).timeout
	await _shot(dir, "11-crisis-night")
	Game._water_event(2)
	await _shot(dir, "12-event")
	_clear_popups()
	Game._finish()
	await _shot(dir, "13-ending")
	get_tree().quit()


func _pact_tour(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(1.2).timeout
	await _shot(dir, "p01-intro")
	pact.modals.close()
	House.resolve_event("ok")
	await get_tree().create_timer(0.8).timeout
	await _shot(dir, "p02-house")
	var d: Dictionary = House.deputies[14]
	pact.select(d["id"])
	await get_tree().create_timer(0.6).timeout
	await _shot(dir, "p03-deputy")
	House.start_duel(d["id"], "chat")
	pact._open_duel()
	House.duel_play("listen")
	pact.modals.close()
	pact._open_duel()
	await get_tree().create_timer(0.4).timeout
	await _shot(dir, "p04-duel")
	House.duel_finish()
	pact.modals.close()
	House.end_day()
	await get_tree().create_timer(0.5).timeout
	await _shot(dir, "p05-event")
	while House.phase == "lobby":
		while not pact.modals.stack.is_empty():
			pact.modals.close()
		while not House.event_queue.is_empty():
			House.resolve_event(House.event_queue[0]["options"][0]["id"])
		for x in House.deputies:
			if x["stance"] > -20 and House.action_state("palace", x)["ok"]:
				House.act("palace", x["id"])
		House.end_day()
		House.street = min(House.street, 45.0) # keep the tour alive until the vote
	while not House.event_queue.is_empty():
		House.resolve_event(House.event_queue[0]["options"][0]["id"])
	await get_tree().create_timer(4.0).timeout
	await _shot(dir, "p06-vote")
	await get_tree().create_timer(12.0).timeout
	await _shot(dir, "p07-result")
	get_tree().quit()


func _clear_popups() -> void:
	while not hud.modal_stack.is_empty():
		hud.close_modal()
	if Game.paper_open:
		Game.close_paper()
	while not Game.event_queue.is_empty():
		Game.resolve_event(Game.event_queue[0]["options"][0]["id"])
	if not Game.duel.is_empty():
		Game.duel_finish()
	while not hud.modal_stack.is_empty():
		hud.close_modal()


## Smoke test of the real interface: runs at top speed, clicks the first enabled button in any window,
## and now and then travels or opens a meeting. Prints a summary and quits.
func _autoplay(seconds: float) -> void:
	await get_tree().create_timer(0.5).timeout
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var clicks := 0
	var t := 0.0
	while t < seconds and not Game.over:
		await get_tree().process_frame
		t += get_process_delta_time()
		if hud == null:
			break
		if not hud.modal_stack.is_empty():
			var top: Control = hud.modal_stack[-1]
			var buttons := top.find_children("*", "Button", true, false).filter(func(b): return not b.disabled and b.is_visible_in_tree())
			if not buttons.is_empty():
				var b: Button = buttons[rng.randi() % buttons.size()] if rng.randf() < 0.5 else buttons[0]
				b.pressed.emit()
				clicks += 1
			continue
		Game.set_speed(3)
		if Game.player["travel"].is_empty() and rng.randf() < 0.01:
			var ids := ["salt", "amman", "irbid", "zarqa", "madaba"]
			hud.ask_travel(ids[rng.randi() % ids.size()])
		elif Game.player["travel"].is_empty() and rng.randf() < 0.03:
			for pid in Game.people:
				if Game.people[pid]["town"] == Game.player["town"] and Game.person_place(pid) != "" and Game.can_meet(pid) == "":
					hud.open_meet(pid)
					break
		elif rng.randf() < 0.005:
			hud.open_schemes()
	print("AUTOPLAY day %d over=%s clicks=%d" % [Game.day(), Game.over, clicks])
	get_tree().quit()
