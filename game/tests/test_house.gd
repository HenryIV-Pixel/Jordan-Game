extends Node
## Headless playthroughs of the parliament scenario: a careful whip and a passive one.
## Run: godot --headless --path game res://tests/test_house.tscn

const H := preload("res://scripts/sim/house_content.gd")
const C := preload("res://scripts/sim/content.gd")
var failures := 0


func _ready() -> void:
	var stats := {}
	for bot in ["careful", "passive"]:
		var kinds := {}
		var yes := 0.0
		for s in 40:
			var r := play(bot, 500 + s)
			kinds[r["kind"]] = kinds.get(r["kind"], 0) + 1
			yes += r.get("yes", 0)
		stats[bot] = kinds
		print("%-8s %s  avg yes %.1f" % [bot, kinds, yes / 40.0])
	var careful_pass: int = stats["careful"].get("passed", 0)
	var passive_pass: int = stats["passive"].get("passed", 0)
	check(careful_pass >= 14 and careful_pass <= 32, "careful whip passes the pact 35-80%% of the time (got %d/40)" % careful_pass)
	check(passive_pass <= 6, "doing nothing rarely works (got %d/40)" % passive_pass)
	var a := play("careful", 9)
	var b := play("careful", 9)
	check(a["kind"] == b["kind"] and a.get("yes") == b.get("yes"), "same seed, same result")
	print("FAILURES: %d" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func check(c: bool, msg: String) -> void:
	if not c:
		failures += 1
		print("FAIL: " + msg)


func play(bot: String, seed_in: int) -> Dictionary:
	House.new_game(seed_in)
	var guard := 0
	while not House.over and guard < 5000:
		guard += 1
		if not House.event_queue.is_empty():
			var ev: Dictionary = House.event_queue[0]
			var pref := {"templer": "firm", "ministers": "honest", "king": "truth", "riot": "army"}
			var oid: String = pref.get(ev["id"], ev["options"][0]["id"]) if bot == "careful" else ev["options"][0]["id"]
			House.resolve_event(oid)
			continue
		if not House.duel.is_empty():
			if House.duel["round"] >= House.duel["rounds"]:
				House.duel_finish()
			else:
				House.duel_play(approach())
			continue
		if bot == "passive" or not careful_step():
			House.end_day()
		check(House.street >= 0 and House.street <= 100 and House.trust >= 0 and House.trust <= 100, "meters in range")
	check(House.over, "scenario ends")
	return House.result


func approach() -> String:
	var d := House.dep(House.duel["id"])
	if House.duel["round"] == 0 and d["known"].size() < 2:
		return "listen"
	var best := "flatter"
	var best_v := -99.0
	for o in House.duel_options():
		if not o["ok"] or o["id"] in ["pressure", "offer"]:
			continue
		var a: Dictionary = C.APPROACHES[o["id"]]
		var v: float = a["base"]
		for t in d["known"]:
			v += a["mods"].get(t, 0)
		if o["id"] == "kin" and d["bloc"] in ["bedouin", "east_tribal"]:
			v += 5
		if o["id"] == "principle" and d["want"] == "egypt" and d["want_known"]:
			v += 6
		v *= pow(0.5, o["used"])
		if v > best_v:
			best_v = v
			best = o["id"]
	return best


## One sensible move; returns false when the day is done.
func careful_step() -> bool:
	var hs := House
	if hs.ap <= 0:
		return false
	if hs.day == 0 and hs.global_state("whips")["ok"]:
		hs.global_act("whips")
		return true
	if hs.street >= 45 and hs.global_state("statement")["ok"]:
		hs.global_act("statement")
		return true
	if hs.day == 1 and hs.global_state("aid")["ok"]:
		hs.global_act("aid")
		return true
	if hs.street >= 75 and hs.global_state("curfew")["ok"]:
		hs.global_act("curfew")
		return true
	# free moves first: promises where they hit what the deputy wants
	var swing := hs.deputies.filter(func(d): return not d["committed"] and not d["absent"] and d["stance"] > -40 and d["stance"] < 45)
	swing.sort_custom(func(a, b): return abs(a["stance"] - 10) < abs(b["stance"] - 10))
	for d in swing:
		if d["want_known"] and d["want"] == "post" and hs.action_state("post", d)["ok"]:
			hs.act("post", d["id"])
			return true
		if d["want_known"] and d["want"] in ["road", "school", "water"] and hs.action_state("project", d)["ok"]:
			hs.act("project", d["id"])
			return true
		if d["known"].has("greedy") and hs.action_state("pay", d)["ok"]:
			hs.act("pay", d["id"])
			return true
		if d["secret_known"] and hs.action_state("file", d)["ok"]:
			hs.act("file", d["id"])
			return true
	for d in swing:
		if d["bloc"] in ["east_tribal", "east_urban", "west_notable"] and d["stance"] < 30 and hs.action_state("palace", d)["ok"]:
			hs.act("palace", d["id"])
			return true
		if hs.action_state("meet", d)["ok"]:
			var ask := "support" if d["stance"] >= 5 else ("abstain" if d["stance"] < -10 else "chat")
			if not d["want_known"] and d["stance"] < 5:
				ask = "chat"
			hs.start_duel(d["id"], ask)
			return true
	# stubborn opponents: dig, then ask them to stay home
	for d in hs.deputies:
		if d["stance"] <= -40 and not d["absent"] and hs.action_state("dig", d)["ok"]:
			hs.act("dig", d["id"])
			return true
	return false
