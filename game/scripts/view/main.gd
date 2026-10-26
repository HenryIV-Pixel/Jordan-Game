extends Node
## Puts the map and the interface together. With `-- --shots=DIR` it plays a scripted tour and saves screenshots.

var map: MapView
var hud: HUD


func _ready() -> void:
	map = MapView.new()
	add_child(map)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = HUD.new()
	hud.map = map
	layer.add_child(hud)
	map.town_clicked.connect(hud.ask_travel)
	Game.set_speed(0)
	hud.show_intro()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_tour(a.substr(8))


func _shot(dir: String, name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	print("shot ", name)


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
