extends Node
## Headless playthroughs of the slice. Run:
##   godot --headless --path game res://tests/test.tscn
## Plays many seeds with three bots (careful, passive, random), checks invariants and prints balance numbers.
## Exits with code 1 if any check fails.

const C := preload("res://scripts/sim/content.gd")
var failures := 0
var bot := "careful"


func _ready() -> void:
	Game.set_process(false)
	Game.newspaper.connect(func(_i): Game.close_paper())
	var stats := {}
	for b in ["careful", "passive", "random"]:
		bot = b
		var wins := 0
		var pct := 0.0
		var n := 30
		for s in n:
			var r := play(1000 + s)
			if OS.get_environment("VERBOSE") == "1" and b == "careful" and s < 12:
				print("  seed %d: %.0f%% water=%s pledges=%s rival=%s exposed=%s scandal=%d rep=%d rrep=%d debate=%s letter=%s wed=%s" % [s, r["you_pct"], r["water"], r["pledges"], r["rival_pledges"], r["rival_exposed"], r["scandal"], r["rep"], Game.rival["rep"], Game.flags.get("debate", "-"), Game.flags.get("has_letter", false), Game.flags.get("wedding_attended", false)])
				for hh in Game.history:
					if "رفعت" in hh["text"] or "خطاب" in hh["text"] or "ملف" in hh["text"] or "وعدك" in hh["text"]:
						print("      day %d: %s" % [hh["min"] / 1440, hh["text"]])
			if r.get("won", false):
				wins += 1
			pct += r.get("you_pct", 0.0)
		stats[b] = {"wins": wins, "n": n, "avg": pct / n}
		print("%-8s wins %d/%d  avg vote %.1f%%" % [b, wins, n, pct / n])
	check(stats["careful"]["wins"] >= 15, "careful player should win at least half the time (got %d/30)" % stats["careful"]["wins"])
	check(stats["careful"]["wins"] <= 29, "careful player should sometimes lose (got %d/30)" % stats["careful"]["wins"])
	check(stats["passive"]["wins"] <= 8, "passive player should usually lose (got %d/30)" % stats["passive"]["wins"])
	# determinism
	bot = "careful"
	var a := play(77)
	var b := play(77)
	check(a.get("you_pct") == b.get("you_pct"), "same seed gives same result")
	print("FAILURES: %d" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: " + msg)


func invariants() -> void:
	var p: Dictionary = Game.player
	check(p["money"] >= 0, "money never negative (%s)" % p["money"])
	check(p["rep"] >= 0 and p["rep"] <= 100, "reputation in range")
	check(p["scandal"] >= 0 and p["scandal"] <= 100, "scandal in range")
	for pid in Game.people:
		var o: float = Game.people[pid]["opinion"]
		check(o >= -100 and o <= 100, "opinion in range")
	check(Game.water["severity"] >= 0 and Game.water["severity"] <= 100, "water in range")


func play(seed_in: int) -> Dictionary:
	Game.new_game(seed_in)
	var guard := 0
	var last_min := -1
	var stuck := 0
	while not Game.over and guard < 20000:
		guard += 1
		if Game.paper_open:
			Game.close_paper()
			continue
		if not Game.event_queue.is_empty():
			var ev: Dictionary = Game.event_queue[0]
			Game.resolve_event(choose_event(ev))
			continue
		if not Game.duel.is_empty():
			if Game.duel["round"] >= Game.duel["rounds"]:
				Game.duel_finish()
			else:
				Game.duel_play(choose_approach())
			continue
		step()
		invariants()
		if Game.minutes == last_min:
			stuck += 1
			if stuck > 50:
				Game.advance(60)
		else:
			stuck = 0
		last_min = Game.minutes
	check(Game.over, "game reached the election (seed %d, bot %s, day %d)" % [seed_in, bot, Game.day()])
	return Game.result


func choose_event(ev: Dictionary) -> String:
	var opts: Array = ev["options"].filter(func(o): return o["enabled"])
	if bot == "random":
		return opts[Game.rng.randi() % opts.size()]["id"]
	if bot == "passive":
		return opts[0]["id"]
	var prefer := {"report": "honest", "envelope": "report", "well_price": "refuse", "petition": "sign", "water1": "calm",
		"water2": "speak", "complication": "pay", "debate1": "numbers", "debate2": "water_did", "debate3": "close_file"}
	var want: String = prefer.get(ev["id"], "")
	for o in opts:
		if o["id"] == want:
			return want
	return opts[0]["id"]


func choose_approach() -> String:
	var pid: String = Game.duel["pid"]
	var p: Dictionary = Game.people[pid]
	var opts: Array = Game.duel_options().filter(func(o): return o["ok"])
	if bot == "random":
		return opts[Game.rng.randi() % opts.size()]["id"]
	if Game.duel["round"] == 0 and p["known"].size() < p["traits"].size():
		return "listen"
	var best := "flatter"
	var best_v := -999.0
	for o in opts:
		var a: Dictionary = C.APPROACHES[o["id"]]
		if o["id"] == "pressure" or (o["id"] == "offer" and Game.player["gifts"] <= 0):
			continue
		var v: float = a["base"] * pow(0.5, o["used"])
		for tr in p["known"]:
			v += a["mods"].get(tr, 0) * pow(0.5, o["used"])
		if v > best_v:
			best_v = v
			best = o["id"]
	return best


func ask_or_chat(pid: String, ask: String) -> void:
	Game.start_duel(pid, ask if Game.ask_state(pid, ask)["ok"] else "chat")


func here(pid: String) -> bool:
	var town: String = Game.player["town"]
	if town == "" or not Game.people.has(pid):
		return false
	var pl := Game.person_place(pid)
	return Game.people[pid]["town"] == town and pl != "" and Game.can_meet(pid) == ""


func step() -> void:
	if not Game.player["travel"].is_empty():
		Game.advance(30)
		return
	if bot == "passive":
		if Game.player["town"] == "salt":
			Game.do_action("sleep")
		else:
			Game.advance(60)
		return
	if bot == "random":
		random_step()
		return
	careful_step()


func random_step() -> void:
	var r := Game.rng.randi() % 10
	var town: String = Game.player["town"]
	if r == 0:
		var ids := Game.towns.keys()
		Game.start_travel(ids[Game.rng.randi() % ids.size()])
	elif r <= 3:
		var pls := Game.places(town)
		var pl: Dictionary = pls[Game.rng.randi() % pls.size()]
		if Game.place_open(pl) and not pl["actions"].is_empty():
			Game.do_action(pl["actions"][Game.rng.randi() % pl["actions"].size()])
		else:
			Game.advance(60)
	elif r <= 6:
		for pid in Game.people:
			if here(pid):
				var asks: Array = Game.people[pid]["asks"]
				Game.start_duel(pid, asks[Game.rng.randi() % asks.size()])
				return
		Game.advance(60)
	elif r == 7:
		var types := C.SCHEMES.keys()
		var t: String = types[Game.rng.randi() % types.size()]
		var tg := Game.scheme_targets(t)
		if not tg.is_empty():
			Game.start_scheme(t, tg[Game.rng.randi() % tg.size()])
		Game.advance(60)
	else:
		Game.advance(60)


func careful_step() -> void:
	var g := Game
	var town: String = g.player["town"]
	var h := g.hour()
	var water_open: bool = g.water["solved_by"] == ""
	# the wedding in Irbid on day 19
	if g.day() == 19 and not g.flags.get("wedding_attended", false):
		if town != "irbid":
			if h >= 6 and h < 12:
				g.start_travel("irbid")
			else:
				g.advance(60)
			return
		if g.action_state("wedding")["ok"] and g.place_open(g.place_def("irbid", "wedding")):
			g.do_action("wedding")
		else:
			g.advance(60)
		return
	if town == "irbid" or (town != "salt" and town != "amman"):
		if h >= 6 and h < 18:
			g.start_travel("salt")
		else:
			g.do_action("sleep_inn")
		return
	if town == "amman":
		if water_open and g.flags.get("has_letter", false) and here("official"):
			ask_or_chat("official", "funds")
			return
		if g.has_secret("issa") and not g.rival["exposed"] and here("journalist"):
			ask_or_chat("journalist", "publish")
			return
		if water_open and g.flags.get("has_letter", false) and h < 14 and C.WORKDAYS.has(g.weekday()) and g.can_meet("official") == "":
			g.advance(60)
			return
		if h >= 6 and h < 18:
			g.start_travel("salt")
		else:
			g.do_action("sleep_inn")
		return
	# in Salt
	if water_open and g.flags.get("has_letter", false) and C.WORKDAYS.has(g.weekday()) and h >= 6 and h < 9 and g.day() - int(g.player["met"].get("official", -9)) >= 3:
		g.start_travel("amman")
		return
	if g.has_secret("issa") and not g.rival["exposed"] and g.schemes.is_empty() and h >= 7 and h < 12 and g.day() < 38:
		if g.scheme_state("leak", "issa")["ok"]:
			g.start_scheme("leak", "issa")
		else:
			g.start_travel("amman")
		return
	if here("mayor"):
		if not g.flags.get("has_letter", false) and water_open:
			ask_or_chat("mayor", "letter")
			return
		if g.people["mayor"]["pledged"] == "":
			ask_or_chat("mayor", "pledge")
			return
	if g.place_open(g.place_def("salt", "baladiya")) and g.action_state("paperwork")["ok"]:
		g.do_action("paperwork")
		return
	if not g.has_secret("issa") and not g.scheme_running("issa") and g.schemes.size() < 2:
		if g.place_open(g.place_def("salt", "baladiya")) and g.flags.get("archives_until", 0) < g.minutes:
			g.do_action("archives")
			return
		g.start_scheme("dig", "issa")
	if here("police") and not g.flags.get("ally_police", false):
		ask_or_chat("police", "ally")
		return
	for pid in ["sheikh", "doctor", "teacher"]:
		if here(pid) and g.people[pid]["pledged"] == "":
			ask_or_chat(pid, "pledge")
			return
	if g.water["solved_by"] == "" and g.water["severity"] >= 60 and g.action_state("trucks")["ok"] and g.place_open(g.place_def("salt", "baladiya")):
		g.do_action("trucks")
		return
	if g.place_open(g.place_def("salt", "madafa")) and g.action_state("majlis")["ok"]:
		g.do_action("majlis")
		return
	if g.place_open(g.place_def("salt", "cafe")) and g.action_state("listen")["ok"]:
		g.do_action("listen")
		return
	if h >= 22 or h < 6:
		g.do_action("sleep")
		return
	g.advance(60)
