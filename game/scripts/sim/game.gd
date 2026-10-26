extends Node
## The whole simulation of the slice (autoload "Game"). No UI code here: views read state and call these functions.
## Time is in game minutes since 2 May 1953 00:00 (a Saturday).

signal changed
signal toast(text: String)
signal event_raised(ev: Dictionary)
signal newspaper(issue: Dictionary)
signal arrived(town: String)
signal ended(result: Dictionary)

const C := preload("res://scripts/sim/content.gd")
const ELECTION_DAY := 42
const RATES := [0.0, 0.5, 1.5, 5.0] # game hours per real second at speed 0..3
const KM_PER_HOUR := 22.0
const ROAD_FACTOR := 1.3
const MONTHS := ["", "كانون الثاني", "شباط", "آذار", "نيسان", "أيار", "حزيران", "تموز", "آب", "أيلول", "تشرين الأول", "تشرين الثاني", "كانون الأول"]
const WEEKDAYS := ["السبت", "الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة"]

var rng := RandomNumberGenerator.new()
var seed_value := 0
var minutes := 0
var speed := 2
var over := false
var result := {}
var map := {}
var towns := {}
var links := {} # town id -> {neighbour id: km}

var player := {}
var people := {}
var rival := {}
var water := {}
var schemes: Array = []
var secrets: Array = [] # {on, text, sev}
var favours: Array = [] # {who, dir: "me" (they owe me) | "owe" (I owe them), text}
var rumours: Array = [] # {min, text}
var history: Array = [] # {min, text}
var flags := {}
var local_news: Array = []
var issues_done := 0
var event_queue: Array = []
var duel := {}
var paper_open := false
var ui_hold := false # the interface has a window open: the clock waits
var _acc := 0.0


func _ready() -> void:
	_load_map()
	new_game(1953)


func _load_map() -> void:
	var f := FileAccess.open("res://data/map.json", FileAccess.READ)
	map = JSON.parse_string(f.get_as_text())
	towns.clear()
	links.clear()
	for t in map["towns"]:
		towns[t["id"]] = t
		links[t["id"]] = {}
	for l in map["links"]:
		var a: String = l[0]
		var b: String = l[1]
		var km := town_pos(a).distance_to(town_pos(b)) * float(map["km_per_unit"]) * ROAD_FACTOR
		links[a][b] = km
		links[b][a] = km


# ------------------------------------------------------------------ setup

func new_game(seed_in: int) -> void:
	seed_value = seed_in
	rng.seed = seed_in
	minutes = 8 * 60
	speed = 2
	over = false
	result = {}
	_acc = 0.0
	player = {"name": "سليم ناصر", "town": "salt", "place": "home", "travel": {}, "money": 40, "rep": 28, "scandal": 0,
		"stats": {"charisma": 7, "intrigue": 9, "diplomacy": 8, "administration": 11}, "gifts": 0, "today": {}, "met": {}}
	people = {}
	for id in C.PEOPLE:
		var d: Dictionary = C.PEOPLE[id].duplicate(true)
		d["id"] = id
		d["known"] = []
		d["pledged"] = ""
		d["hinted"] = false
		people[id] = d
	rival = {"id": "issa", "name": C.RIVAL["name"], "town": "salt", "place": "baladiya", "travel": {}, "rep": 34, "scandal": 0,
		"exposed": false, "plan": "", "plan_target": "", "amman_tries": 0, "last_news": "", "last_news_min": -99999, "hinted": false}
	water = {"severity": 36, "solved_by": "", "repairing": false, "well_open": false, "trucks": 0, "stage": 0}
	schemes = []
	secrets = []
	favours = [{"who": "sheikh", "dir": "owe", "text": "توسّط لك عمّك الشيخ لتحصل على وظيفتك في البلدية"}]
	rumours = []
	history = []
	flags = {}
	local_news = []
	issues_done = 0
	event_queue = []
	duel = {}
	paper_open = false
	add_history("بدأت عملك كاتباً في بلدية السلط.")
	changed.emit()


# ------------------------------------------------------------------ time

func day() -> int:
	return minutes / 1440

func hour() -> int:
	return (minutes % 1440) / 60

func hourf() -> float:
	return float(minutes % 1440) / 60.0

func weekday() -> int:
	return day() % 7

func days_to_election() -> int:
	return ELECTION_DAY - day()

static func ar(v) -> String:
	var s := str(v)
	var out := ""
	for ch in s:
		var i := "0123456789".find(ch)
		out += "٠١٢٣٤٥٦٧٨٩"[i] if i >= 0 else ch
	return out

func date_parts(m: int = -1) -> Dictionary:
	if m < 0:
		m = minutes
	var d := m / 1440
	var dom := 2 + d
	var month := 5
	if dom > 31:
		dom -= 31
		month = 6
	return {"dom": dom, "month": month, "wd": d % 7}

func date_text(m: int = -1, with_weekday := true) -> String:
	var p := date_parts(m)
	var s := "%s %s ١٩٥٣" % [ar(p["dom"]), MONTHS[p["month"]]]
	return (WEEKDAYS[p["wd"]] + " " + s) if with_weekday else s

func clock_text(m: int = -1) -> String:
	if m < 0:
		m = minutes
	var h := (m % 1440) / 60
	var mm := (m % 60) / 10 * 10
	return ar("%02d:%02d" % [h, mm])

func daylight() -> float:
	var h := hourf()
	if h < 5.0 or h >= 20.5:
		return 0.0
	if h < 7.0:
		return (h - 5.0) / 2.0
	if h < 18.0:
		return 1.0
	return 1.0 - (h - 18.0) / 2.5

func is_blocked() -> bool:
	return over or not event_queue.is_empty() or not duel.is_empty() or paper_open

func _process(delta: float) -> void:
	if is_blocked() or speed == 0 or ui_hold:
		return
	var rate: float = RATES[speed]
	if not player["travel"].is_empty():
		var trip_h: float = (player["travel"]["arr"] - player["travel"]["dep"]) / 60.0
		rate = min(max(rate, 1.5), trip_h / 2.5)
	_acc += delta * rate * 60.0
	var whole := int(_acc)
	if whole > 0:
		_acc -= whole
		advance(whole)

## Moves the clock forward, firing hourly logic at each hour boundary. Stops early if an event needs the player.
func advance(mins: int, stop_on_block := true) -> void:
	var target := minutes + mins
	while minutes < target and not over:
		var next_hour := (minutes / 60 + 1) * 60
		var step: int = min(next_hour, target) - minutes
		minutes += step
		if not player["travel"].is_empty() and minutes >= int(player["travel"]["arr"]):
			_arrive()
		if minutes % 60 == 0:
			_on_hour()
		if stop_on_block and is_blocked() and player["travel"].is_empty():
			break
	changed.emit()

func set_speed(s: int) -> void:
	speed = clampi(s, 0, 3)
	changed.emit()


# ------------------------------------------------------------------ helpers

func town_pos(id: String) -> Vector2:
	var p = towns[id]["pos"]
	return Vector2(p[0], p[1])

func town_name(id: String) -> String:
	return towns[id]["name"] if towns.has(id) else id

func add_history(text: String) -> void:
	history.push_front({"min": minutes, "text": text})

func add_rumour(text: String) -> void:
	rumours.push_front({"min": minutes, "text": text})

func news(text: String) -> void:
	if not local_news.has(text):
		local_news.append(text)

func say(text: String) -> void:
	toast.emit(text)

func clampv(v: float, lo := 0.0, hi := 100.0) -> float:
	return clamp(v, lo, hi)

func add_op(pid: String, d: float) -> void:
	if people.has(pid):
		if d > 0:
			d *= clampf(1.2 - people[pid]["opinion"] / 90.0, 0.2, 1.0) # trust grows slowly once it is high
		people[pid]["opinion"] = clampv(people[pid]["opinion"] + d, -100, 100)

func add_rival_op(pid: String, d: float) -> void:
	if people.has(pid):
		people[pid]["rival_op"] = clampv(people[pid]["rival_op"] + d, -100, 100)

func add_rep(d: float) -> void:
	if d > 0:
		d *= clampf(1.25 - player["rep"] / 80.0, 0.15, 1.0) # harder to grow a big name
	player["rep"] = clampv(player["rep"] + d)

func add_scandal(d: float) -> void:
	player["scandal"] = clampv(player["scandal"] + d)

func has_secret(on: String) -> bool:
	for s in secrets:
		if s["on"] == on:
			return true
	return false

func secret_of(pid: String) -> Dictionary:
	if pid == "issa":
		return C.RIVAL["secret"]
	return people[pid].get("secret", {}) if people.has(pid) else {}

func person_name(pid: String) -> String:
	if pid == "issa":
		return rival["name"]
	return people[pid]["name"] if people.has(pid) else pid

func notables() -> Array:
	var out := []
	for id in people:
		if people[id]["weight"] > 0:
			out.append(id)
	return out


# ------------------------------------------------------------------ places and presence

func places(town: String) -> Array:
	var list: Array = C.PLACES.get(town, C.DEFAULT_PLACES)
	var out := []
	for pl in list:
		if pl.has("flag") and not flags.get(pl["flag"], false):
			continue
		out.append(pl)
	return out

func place_def(town: String, pid: String) -> Dictionary:
	for pl in places(town):
		if pl["id"] == pid:
			return pl
	return {}

func place_open(pl: Dictionary) -> bool:
	var h := hourf()
	if not pl["days"].has(weekday()):
		return false
	if pl["id"] == "wedding" and day() != 19:
		return false
	return h >= pl["open"][0] and h < pl["open"][1]

func person_place(pid: String) -> String:
	var p: Dictionary = people[pid]
	var h := hourf()
	for s in p["sched"]:
		if s["days"].has(weekday()) and h >= s["from"] and h < s["to"]:
			return s["place"]
	return ""

## Who is at a place right now: list of person ids ("issa" for the rival).
func who_at(town: String, place: String) -> Array:
	var out := []
	for pid in people:
		if people[pid]["town"] == town and person_place(pid) == place:
			out.append(pid)
	if rival["travel"].is_empty() and rival["town"] == town and rival_place() == place:
		out.append("issa")
	return out

func rival_place() -> String:
	var h := hourf()
	if rival["plan"] == "court" and rival["plan_target"] != "":
		var tp := person_place(rival["plan_target"])
		if tp != "" and people[rival["plan_target"]]["town"] == rival["town"]:
			return tp
	if rival["town"] == "amman":
		return "interior" if (h >= 9 and h < 14 and C.WORKDAYS.has(weekday())) else "cafe"
	if C.WORKDAYS.has(weekday()) and h >= 8 and h < 14:
		return "baladiya"
	if h >= 17 and h < 22:
		return "cafe"
	return ""

func rival_visible() -> bool:
	return player["travel"].is_empty() and rival["travel"].is_empty() and rival["town"] == player["town"] or flags.get("ally_police", false)

func can_meet(pid: String) -> String:
	## Returns "" if a meeting is possible, otherwise the reason.
	if player["met"].get(pid, -1) == day():
		return "التقيته اليوم"
	return ""


# ------------------------------------------------------------------ actions at places

func action_state(aid: String) -> Dictionary:
	## {ok: bool, why: String}
	var a: Dictionary = C.ACTIONS[aid]
	if a.has("cost") and player["money"] < a["cost"]:
		return {"ok": false, "why": "لا يكفي المال"}
	match aid:
		"paperwork":
			if player["today"].has("paperwork"):
				return {"ok": false, "why": "أنجزت معاملات اليوم"}
		"round":
			if player["today"].has("round"):
				return {"ok": false, "why": "مرّة في اليوم"}
		"trucks":
			if water["solved_by"] != "" or water["severity"] < 40:
				return {"ok": false, "why": "لا حاجة الآن"}
			if water["trucks"] >= 2:
				return {"ok": false, "why": "لا صهاريج متاحة"}
		"majlis":
			if player["today"].has("majlis"):
				return {"ok": false, "why": "حضرت المجلس اليوم"}
		"wedding":
			if flags.get("wedding_attended", false):
				return {"ok": false, "why": "حضرت العرس"}
		"listen":
			if player["today"].get("listen", 0) >= 2:
				return {"ok": false, "why": "سمعت ما يكفي اليوم"}
	return {"ok": true, "why": ""}

func do_action(aid: String) -> void:
	var st := action_state(aid)
	if not st["ok"]:
		return
	var a: Dictionary = C.ACTIONS[aid]
	if a.has("cost"):
		player["money"] -= a["cost"]
	match aid:
		"paperwork":
			player["today"]["paperwork"] = true
			add_rep(1)
			if who_at("salt", "baladiya").has("mayor"):
				add_op("mayor", 2)
			if rng.randf() < 0.4:
				player["money"] += 1
				say("ترك لك أحد المراجعين ديناراً «إكرامية».")
			else:
				say("أنهيت معاملات اليوم. الحاج زياد لاحظ.")
		"archives":
			flags["archives_until"] = minutes + 3 * 1440
			say("وجدت أرقاماً لا تتطابق في دفاتر الإيصالات… التقصّي عن موظفي البلدية أسهل الآن.")
			if rival["town"] == "salt" and rival_place() == "baladiya":
				add_rival_op("mayor", 0)
				add_rumour("عيسى رآك تقلّب دفاتر الإيصالات. بدا متوتراً.")
		"trucks":
			water["trucks"] += 1
			water["severity"] = clampv(water["severity"] - 15)
			add_rep(5)
			add_op("mayor", 4)
			news("صهاريج ماء على نفقة كاتب في البلدية تصل أحياء السلط")
			add_history("استأجرت صهاريج ماء لأحياء السلط على نفقتك.")
			say("وصلت الصهاريج. الناس يذكرون اسمك عند العين.")
		"gift":
			player["gifts"] += 1
			say("اشتريت علبة حلوى فاخرة وعطراً. يمكنك تقديمها في لقاء.")
		"listen":
			player["today"]["listen"] = player["today"].get("listen", 0) + 1
			var r := _pick_rumour()
			add_rumour(r)
			say(r)
		"round":
			player["today"]["round"] = true
			add_rep(2)
			say("رفع الحاضرون أكوابهم باسمك.")
		"majlis":
			player["today"]["majlis"] = true
			add_op("sheikh", 3)
			add_rep(1)
			say("جلست في صدر المجلس قرب عمّك. الرجال لاحظوا.")
		"advice":
			say(advice())
		"sleep", "sleep_inn":
			var next7 := (day() + (1 if hour() >= 7 else 0)) * 1440 + 7 * 60
			advance(next7 - minutes)
			changed.emit()
			return
		"wedding":
			flags["wedding_attended"] = true
			add_op("sheikh", 18)
			add_rep(4)
			news("عرس آل الناصر في إربد يجمع وجهاء الشمال")
			add_history("حضرت عرس ابن أخ الشيخ فالح في إربد.")
			say("رآك الشيخ فالح بين الحاضرين. شدّ على يدك أمام الجميع.")
	advance(int(a["hours"] * 60))

func advice() -> String:
	if water["solved_by"] == "" and not flags.get("has_letter", false):
		return "أبوك: «المياه ستغرق الجميع هذا الصيف. اكسب رضا الحاج زياد، واطلب منه خطاباً إلى عمّان. في وزارة الداخلية رجل اسمه رفعت بك يحب من يعرف قدره.»"
	if water["solved_by"] == "" and flags.get("has_letter", false):
		return "أبوك: «معك خطاب الرئيس؟ لا تنتظر. اذهب إلى عمّان قبل أن يسبقك عيسى. الوزارة تغلق أبوابها بعد الظهر.»"
	if people["sheikh"]["pledged"] != "player":
		return "أبوك: «عمّك الشيخ فالح لا يردّ قريباً خائباً، لكنه يحب أن يُطلب منه. اجلس في مضافته مساءً.»"
	if not has_secret("issa"):
		return "أبوك: «عيسى يعيش فوق راتبه. دفاتر الإيصالات في البلدية قد تقول شيئاً، وآمر المخفر يعرف كل شيء في البلد.»"
	if player["scandal"] >= 40:
		return "أبوك: «الناس تتهامس عنك يا ابني. اهدأ قليلاً، واترك الدسائس لغيرك.»"
	return "أبوك: «الأستاذ فيصل والدكتور هاني لم يحسما أمرهما بعد. كل صوت في المجلس له ثمن أو حجّة.»"

func _pick_rumour() -> String:
	var opts := []
	if rival["last_news"] != "" and minutes - int(rival["last_news_min"]) < 2 * 1440 and not flags.get("heard_" + str(rival["last_news_min"]), false):
		flags["heard_" + str(rival["last_news_min"])] = true
		return rival["last_news"]
	if not rival["hinted"]:
		opts.append(["issa", "يقولون إن عيسى الحدّاد اشترى ساعة ذهبية… من أين لكاتب براتب مثل راتبك؟"])
	for pid in ["merchant", "police", "mayor"]:
		if people[pid].has("secret") and not people[pid]["hinted"]:
			var hints := {"merchant": "سمعت أن أبا خليل يبيع تنكة الماء بقرش ونصف ويخبّئ القمح في مخزنه.",
				"police": "صاحب الدكان يشكو: «الملازم يأخذ منّا شيئاً كل شهر… ولا تسأل.»",
				"mayor": "همسة: عقد ترميم السوق ذهب إلى قريب للحاج زياد دون مناقصة."}
			var t: String = hints[pid]
			opts.append([pid, t])
	for pid in ["sheikh", "teacher", "doctor", "merchant", "mayor"]:
		var p: Dictionary = people[pid]
		for tr in p["traits"]:
			if not p["known"].has(tr):
				opts.append(["trait:" + pid + ":" + tr, "يقولون عن %s: «%s»." % [p["name"], C.TRAITS[tr]["hint"]]])
				break
	if water["solved_by"] == "" and water["severity"] >= 45:
		opts.append(["water", "النساء يقفن في الطابور عند العين منذ الفجر. الغضب يكبر على البلدية."])
	var flavor := ["الرجال يتحلّقون حول المذياع يسمعون إذاعة القاهرة.", "حديث المقهى: أسعار القمح ترتفع ولا أحد يعرف السبب.",
		"شيخ عجوز يروي عن أيام الثورة العربية الكبرى.", "أحدهم يقرأ الجريدة بصوت عالٍ: الحكومة الجديدة تعد بالكثير."]
	opts.append(["flavor", flavor[rng.randi() % flavor.size()]])
	var pick: Array = opts[rng.randi() % opts.size()]
	var key: String = pick[0]
	if key == "issa":
		rival["hinted"] = true
	elif people.has(key):
		people[key]["hinted"] = true
	elif key.begins_with("trait:"):
		var parts := key.split(":")
		people[parts[1]]["known"].append(parts[2])
	return pick[1]


# ------------------------------------------------------------------ travel

func route(from: String, to: String) -> Dictionary:
	## Dijkstra over the road links. Returns {path: [...], km: float} or {} when unreachable.
	var dist := {from: 0.0}
	var prev := {}
	var todo := [from]
	while not todo.is_empty():
		var best := 0
		for i in todo.size():
			if dist[todo[i]] < dist[todo[best]]:
				best = i
		var u: String = todo.pop_at(best)
		if u == to:
			break
		for v in links[u]:
			var nd: float = dist[u] + links[u][v]
			if not dist.has(v) or nd < dist[v]:
				dist[v] = nd
				prev[v] = u
				if not todo.has(v):
					todo.append(v)
	if not dist.has(to):
		return {}
	var path := [to]
	while path[0] != from:
		path.push_front(prev[path[0]])
	return {"path": path, "km": dist[to]}

func trip_hours(to: String) -> float:
	var r := route(player["town"], to)
	if r.is_empty():
		return -1.0
	return r["km"] / KM_PER_HOUR + 0.5

func travel_state(to: String) -> Dictionary:
	if to == player["town"]:
		return {"ok": false, "why": "أنت هنا"}
	if not player["travel"].is_empty():
		return {"ok": false, "why": "أنت في الطريق"}
	if towns[to]["kind"] == "nb":
		return {"ok": false, "why": "خارج المملكة"}
	if trip_hours(to) < 0:
		return {"ok": false, "why": "لا طريق"}
	return {"ok": true, "why": ""}

func start_travel(to: String) -> void:
	if not travel_state(to)["ok"]:
		return
	var r := route(player["town"], to)
	var hours: float = r["km"] / KM_PER_HOUR + 0.5
	player["travel"] = {"path": r["path"], "km": r["km"], "dep": minutes, "arr": minutes + int(hours * 60), "from": player["town"], "to": to}
	player["town"] = ""
	player["place"] = ""
	# one road event on longer trips
	if rng.randf() < (0.35 if hours > 2.5 else 0.15):
		player["travel"]["event_at"] = minutes + int(hours * 30)
	add_history("سافرت إلى %s." % town_name(to))
	changed.emit()

func travel_progress() -> float:
	var t: Dictionary = player["travel"]
	if t.is_empty():
		return 0.0
	return clamp(float(minutes - t["dep"]) / max(1.0, float(t["arr"] - t["dep"])), 0.0, 1.0)

## Position along a multi-town path at fraction k (for drawing tokens).
func path_point(path: Array, k: float) -> Vector2:
	var total := 0.0
	var segs := []
	for i in range(1, path.size()):
		var d := town_pos(path[i - 1]).distance_to(town_pos(path[i]))
		segs.append(d)
		total += d
	var want := k * total
	for i in segs.size():
		if want <= segs[i] or i == segs.size() - 1:
			return town_pos(path[i]).lerp(town_pos(path[i + 1]), clamp(want / max(0.001, segs[i]), 0.0, 1.0))
		want -= segs[i]
	return town_pos(path[-1])

func _arrive() -> void:
	var to: String = player["travel"]["to"]
	player["travel"] = {}
	player["town"] = to
	player["place"] = ""
	_acc = 0.0
	speed = 0
	arrived.emit(to)
	say("وصلت إلى %s." % town_name(to))


# ------------------------------------------------------------------ hourly and daily simulation

func _on_hour() -> void:
	var h := hour()
	var t: Dictionary = player["travel"]
	if not t.is_empty() and t.has("event_at") and minutes >= int(t["event_at"]):
		t.erase("event_at")
		_road_event()
	if h == 0:
		player["today"] = {}
	if h == 6:
		_daily()
	if h == 7 and weekday() == 0 and day() >= 7:
		_issue_paper()
	if h == 9 or h == 18:
		_rival_act()
	_rival_travel_tick()
	_schemes_tick()
	_scripted_events()
	if day() == ELECTION_DAY and h == 18:
		_finish()

func _daily() -> void:
	player["scandal"] = clampv(player["scandal"] - 1)
	rival["scandal"] = clampv(rival["scandal"] - 1)
	rival["rep"] = clampv(rival["rep"] + 0.6 * clampf(1.2 - rival["rep"] / 80.0, 0.1, 1.0)) # he campaigns every day
	if weekday() == 0 and day() > 0:
		player["money"] += 6
		say("استلمت راتب الأسبوع: ٦ دنانير.")
	# water
	if water["repairing"]:
		water["severity"] = clampv(water["severity"] - 6, 5)
	else:
		water["severity"] = clampv(water["severity"] + (3 if day() >= 28 else 2))
		if water["well_open"]:
			water["severity"] = clampv(water["severity"] - 1)
	if water["solved_by"] == "":
		for st in [[1, 50], [2, 70], [3, 90]]:
			if water["stage"] < st[0] and water["severity"] >= st[1]:
				water["stage"] = st[0]
				_water_event(st[0])
				break
	# rival plans the day
	_rival_plan()


# ------------------------------------------------------------------ the rival

func _rival_plan() -> void:
	if not rival["travel"].is_empty():
		return
	if rival["town"] == "amman":
		_rival_go("salt")
		return
	rival["plan"] = ""
	rival["plan_target"] = ""
	if day() >= ELECTION_DAY:
		return
	var sev: float = water["severity"]
	if water["solved_by"] == "" and sev >= 42 and rival["amman_tries"] < 3 and day() >= 3 and rng.randf() < 0.3:
		rival["plan"] = "amman"
		rival["amman_tries"] += 1
		_rival_go("amman")
		_rival_note("عيسى سافر إلى عمّان اليوم. يقولون إنه يطرق أبواب وزارة الداخلية بشأن الخزّان.")
		return
	if rival["exposed"] and rng.randf() < 0.5:
		rival["plan"] = "defend"
		return
	if player["rep"] >= rival["rep"] - 4 and rng.randf() < 0.28:
		rival["plan"] = "rumour"
		return
	# court the notable he is weakest with, weighted by votes
	var best := ""
	var best_score := -1.0
	for pid in notables():
		var p: Dictionary = people[pid]
		if p["pledged"] != "":
			continue
		var score: float = p["weight"] * (1.0 - clamp(p["rival_op"], 0, 100) / 100.0) * rng.randf_range(0.6, 1.4)
		if score > best_score:
			best_score = score
			best = pid
	if best != "":
		rival["plan"] = "court"
		rival["plan_target"] = best

func _rival_act() -> void:
	if not rival["travel"].is_empty() or over:
		return
	match rival["plan"]:
		"court":
			var pid: String = rival["plan_target"]
			if pid == "" or person_place(pid) == "" or people[pid]["town"] != rival["town"]:
				return
			var p: Dictionary = people[pid]
			var gain := 6.0 + rng.randi_range(0, 7)
			if p["traits"].has("greedy"):
				gain += 4
			if p["traits"].has("principled") and rival["exposed"]:
				gain -= 6
			add_rival_op(pid, gain)
			_rival_note("رأوا عيسى يجالس %s طويلاً اليوم." % p["name"])
			if p["rival_op"] >= 55 and p["rival_op"] > p["opinion"] + 5 and p["pledged"] == "":
				p["pledged"] = "rival"
				news("%s يعلن تأييده لعيسى الحدّاد في انتخابات السلط" % p["name"])
				add_history("%s أعلن تأييده لعيسى." % p["name"])
				say("%s أعلن تأييده لعيسى الحدّاد!" % p["name"])
			rival["plan"] = "" if hour() >= 18 else rival["plan"]
		"rumour":
			add_rep(-3)
			add_scandal(4)
			var lines := ["عيسى يقول في المقهى إنك «ولد مدعوم» لا يعرف الشغل.", "عيسى يلمّح إلى أنك تأخذ «إكراميات» من المراجعين.", "إشاعة من عيسى: سليم ناصر يطمع بالمقعد ليخدم عشيرته فقط."]
			if flags.get("took_envelope", false):
				lines = ["عيسى يهمس بأنك قبلت مغلّفاً من مقاول. من أخبره؟"]
				add_scandal(4)
			_rival_note(lines[rng.randi() % lines.size()])
			if flags.get("ally_police", false):
				say("الملازم مازن يحذّرك: عيسى ينشر عنك كلاماً في المقهى.")
			rival["plan"] = ""
		"defend":
			if hour() < 12:
				rival["rep"] = clampv(rival["rep"] + 1)
		"amman_meet":
			if rival["town"] == "amman" and water["solved_by"] == "":
				var odds: float = 0.4 + (water["severity"] - 45.0) / 100.0
				if rng.randf() < odds:
					water["solved_by"] = "rival"
					water["repairing"] = true
					rival["rep"] = clampv(rival["rep"] + 12)
					add_rival_op("mayor", 15)
					news("عيسى الحدّاد يعود من عمّان بتمويل لإصلاح خزّان السلط")
					add_history("عيسى حصل على تمويل الخزّان من عمّان قبلك.")
					_rival_note("عيسى عاد من عمّان بوعد تمويل الخزّان! الناس تتحدث عنه.")
					say("عيسى سبقك: حصل على تمويل إصلاح الخزّان من عمّان.")
				else:
					_rival_note("يقولون إن رفعت بك صرف عيسى من مكتبه دون وعد.")
			rival["plan"] = ""
	if player["scandal"] >= 45 and not flags.get("rival_leaked", false):
		flags["rival_leaked"] = true
		add_scandal(10)
		news("مصادر في بلدية السلط تتحدث عن تجاوزات لأحد الموظفين الطامحين")
		_rival_note("عيسى سرّب ما يعرفه عنك إلى الصحف.")

func _rival_note(text: String) -> void:
	rival["last_news"] = text
	rival["last_news_min"] = minutes
	if rival_visible():
		add_rumour(text)

func _rival_go(to: String) -> void:
	var r := route(rival["town"], to)
	if r.is_empty():
		return
	var hours: float = r["km"] / KM_PER_HOUR + 0.5
	rival["travel"] = {"path": r["path"], "dep": minutes + 60, "arr": minutes + 60 + int(hours * 60), "to": to}

func _rival_travel_tick() -> void:
	var t: Dictionary = rival["travel"]
	if t.is_empty():
		return
	if minutes >= int(t["arr"]):
		rival["town"] = t["to"]
		rival["travel"] = {}
		if rival["town"] == "amman" and rival["plan"] == "amman":
			rival["plan"] = "amman_meet"

func rival_pos() -> Vector2:
	var t: Dictionary = rival["travel"]
	if t.is_empty() or minutes < int(t["dep"]):
		return town_pos(rival["town"])
	var k: float = clampf(float(minutes - int(t["dep"])) / maxf(1.0, float(int(t["arr"]) - int(t["dep"]))), 0.0, 1.0)
	return path_point(t["path"], k)

func player_pos() -> Vector2:
	if player["travel"].is_empty():
		return town_pos(player["town"])
	return path_point(player["travel"]["path"], travel_progress())


# ------------------------------------------------------------------ meetings (duels)

## Whether you can ask this person for this thing yet. {ok, why}
func ask_state(pid: String, ask: String) -> Dictionary:
	var op: float = people[pid]["opinion"]
	var need := {"pledge": 30, "letter": 35, "funds": 5, "well": 10, "ally": 20, "publish": 15, "profile": 20}
	match ask:
		"pledge":
			if day() < 7:
				return {"ok": false, "why": "باب الترشّح يُفتح يوم ٩ أيار"}
			if people[pid]["pledged"] == "player":
				return {"ok": false, "why": "وعدك بتأييده"}
			if op < 80 and not pledge_condition(pid):
				return {"ok": false, "why": pledge_terms(pid)}
		"funds":
			if not flags.get("has_letter", false):
				return {"ok": false, "why": "تحتاج خطاب توصية من رئيس البلدية"}
			if water["solved_by"] != "":
				return {"ok": false, "why": "أُقرّ التمويل"}
		"letter":
			if flags.get("has_letter", false):
				return {"ok": false, "why": "الخطاب معك"}
		"well":
			if water["well_open"] or water["solved_by"] != "":
				return {"ok": false, "why": "لا حاجة الآن"}
		"ally":
			if flags.get("ally_" + pid, false):
				return {"ok": false, "why": "هو حليفك"}
		"publish":
			if not has_secret("issa"):
				return {"ok": false, "why": "لا ملف عن عيسى في خزانتك"}
			if rival["exposed"]:
				return {"ok": false, "why": "القصة نُشرت"}
		"profile":
			if flags.get("profile_done", false):
				return {"ok": false, "why": "كتب عنك من قبل"}
	if need.has(ask) and op < need[ask]:
		return {"ok": false, "why": "يحتاج ثقة أكبر (رأيه %s من %s)" % [ar(int(op)), ar(need[ask])]}
	return {"ok": true, "why": ""}

func start_duel(pid: String, ask: String) -> void:
	if not ask_state(pid, ask)["ok"] or can_meet(pid) != "":
		return
	var p: Dictionary = people[pid]
	var start: float = 30.0 + p["opinion"] * 0.45
	if ask == "funds" and flags.get("has_letter", false):
		start += 14
	var last: int = player["met"].get(pid, -99)
	var tired := day() - last <= 2
	if tired:
		start -= 8 # seen you too often lately
	start = clampv(start, 5, 90)
	duel = {"pid": pid, "ask": ask, "target": C.ASKS[ask]["target"] + (pledge_mod(pid) if ask == "pledge" else 0), "mood": start, "start": start, "round": 0, "rounds": 3,
		"used": {}, "log": [], "pressured": false, "last": {}, "tired": tired}
	player["met"][pid] = day()
	changed.emit()

## Each notable's price for public support: positive makes it harder.
func pledge_mod(pid: String) -> int:
	var m := 0
	match pid:
		"mayor":
			m = -10 if water["solved_by"] == "player" else 10
		"sheikh":
			if flags.get("wedding_attended", false):
				m -= 8
			if player["scandal"] >= 30:
				m += 8
		"teacher":
			if flags.get("petition_signed", false):
				m -= 8
			if flags.get("took_envelope", false) or player["scandal"] >= 20:
				m += 12
		"doctor":
			m = -8 if water["solved_by"] == "player" else 6
		"merchant":
			m = -10 if flags.get("well_approved", false) else 10
	return m

func pledge_terms(pid: String) -> String:
	match pid:
		"mayor": return "شرطه: أن تحلّ أنت أزمة المياه"
		"sheikh": return "شرطه: أن تحضر مناسبات العائلة"
		"teacher": return "شرطه: موقف من قضايا الناس، ويد نظيفة"
		"doctor": return "شرطه: أن يرى الماء يعود إلى البيوت"
		"merchant": return "شرطه: خدمة مقابل خدمة"
	return ""

## The thing each notable needs to see before backing you (or a very high opinion of you).
func pledge_condition(pid: String) -> bool:
	match pid:
		"mayor": return water["solved_by"] == "player"
		"sheikh": return flags.get("wedding_attended", false)
		"teacher": return flags.get("petition_signed", false) and player["scandal"] < 25
		"doctor": return water["severity"] <= 40 or water["solved_by"] == "player"
		"merchant": return flags.get("well_approved", false)
	return true

func duel_options() -> Array:
	var out := []
	var pid: String = duel["pid"]
	for aid in C.APPROACHES:
		var a: Dictionary = C.APPROACHES[aid]
		var ok := true
		var why := ""
		if aid == "offer" and player["gifts"] <= 0 and player["money"] < 5:
			ok = false
			why = "لا مال ولا هدية"
		if aid == "pressure" and not has_secret(pid):
			ok = false
			why = "لا ملف عنه في خزانتك"
		out.append({"id": aid, "name": a["name"], "desc": a["desc"], "ok": ok, "why": why, "used": duel["used"].get(aid, 0)})
	return out

func _stat_bonus(stat: String) -> float:
	return player["stats"].get(stat, 6) / 3.0

func duel_play(aid: String) -> Dictionary:
	var p: Dictionary = people[duel["pid"]]
	var a: Dictionary = C.APPROACHES[aid]
	var d: float = a["base"] + _stat_bonus(a["stat"])
	var reveal := ""
	for tr in p["traits"]:
		var m: float = a["mods"].get(tr, 0)
		d += m
		if abs(m) >= 8 and not p["known"].has(tr) and reveal == "":
			reveal = tr
	var times: int = duel["used"].get(aid, 0)
	d *= pow(0.5, times)
	d += rng.randi_range(-3, 3)
	duel["used"][aid] = times + 1
	if aid == "listen" and reveal == "":
		for tr in p["traits"]:
			if not p["known"].has(tr):
				reveal = tr
				break
	if aid == "offer":
		if player["gifts"] > 0:
			player["gifts"] -= 1
		else:
			player["money"] -= 5
	if aid == "pressure":
		duel["pressured"] = true
		var sev: int = secret_of(duel["pid"]).get("sev", 1)
		if p["traits"].has("proud") and sev < 3:
			d -= 6
	if reveal != "":
		p["known"].append(reveal)
	duel["mood"] = clampv(duel["mood"] + d)
	duel["round"] += 1
	var text := _reaction(aid, d, p)
	var entry := {"aid": aid, "delta": d, "text": text, "reveal": reveal}
	duel["log"].append(entry)
	duel["last"] = entry
	changed.emit()
	return entry

func _reaction(aid: String, d: float, p: Dictionary) -> String:
	if aid == "pressure":
		return "تجمّد وجهه. «تهدّدني يا سليم؟»… ثم خفض صوته." if d > 10 else "احمرّ وجهه غضباً: «اخرج من هنا!»"
	if aid == "listen":
		return "تكلّم طويلاً، وأنت تصغي. عرفت عنه شيئاً."
	if d >= 15:
		return "ابتسم وانحنى نحوك. أصبت الوتر الصحيح."
	if d >= 8:
		return "أومأ برأسه موافقاً. كلامك وصل."
	if d >= 3:
		return "استمع بأدب، لكن دون حماس."
	if d >= 0:
		return "هزّ كتفيه. لم يتحرّك فيه شيء."
	return "عقد حاجبيه. هذا الكلام أزعجه."

func duel_success_now() -> bool:
	return duel["target"] == 0 or duel["mood"] >= duel["target"]

func duel_finish() -> Dictionary:
	var pid: String = duel["pid"]
	var p: Dictionary = people[pid]
	var ask: String = duel["ask"]
	var ok := duel_success_now()
	var dop := roundf((duel["mood"] - duel["start"]) / (8.0 if ask == "chat" else 6.0))
	if ask == "chat":
		dop += 1
	if duel.get("tired", false):
		dop = roundf(dop * 0.5)
	if duel["pressured"]:
		dop -= 25
	if not ok and ask != "chat":
		dop -= 3
	add_op(pid, dop)
	var text := ""
	if ok:
		match ask:
			"chat":
				text = "خرجت من اللقاء وقد صار %s أقرب إليك." % p["name"]
			"pledge":
				p["pledged"] = "player"
				news("%s يعلن تأييد سليم ناصر لمقعد السلط" % p["name"])
				add_history("%s وعدك بتأييده في الانتخابات." % p["name"])
				text = "«لك صوتي، وصوت من يسمع كلمتي.»"
			"letter":
				flags["has_letter"] = true
				add_history("حصلت على خطاب توصية من الحاج زياد إلى وزارة الداخلية.")
				text = "كتب الحاج زياد خطاباً بخطّه وختمه بختم البلدية. باب الوزارة صار أقرب."
			"funds":
				water["repairing"] = true
				water["solved_by"] = "player" if water["solved_by"] == "" else water["solved_by"]
				add_rep(12)
				add_op("mayor", 15)
				news("كاتب شاب من السلط يحصل على تمويل لإصلاح خزّان المدينة")
				add_history("أقنعت رفعت بك بتمويل إصلاح خزّان السلط.")
				text = "وقّع رفعت بك على الطلب: «قل للحاج زياد إن الوزارة لا تنسى السلط.»"
			"well":
				water["well_open"] = true
				water["severity"] = clampv(water["severity"] - 22)
				add_rep(5)
				favours.append({"who": "merchant", "dir": "owe", "text": "وعدت أبا خليل بخدمة مقابل فتح بئره"})
				flags["well_day"] = day()
				news("أبو خليل يفتح بئره لأهالي السلط")
				add_history("أقنعت أبا خليل بفتح بئره للناس — بثمن مؤجّل.")
				text = "«سأفتح البئر… وأنت لن تنسى أبا خليل حين يحتاجك.»"
			"ally":
				flags["ally_" + pid] = true
				favours.append({"who": pid, "dir": "me", "text": "سيمدّك بالأخبار ويساعدك في التقصّي"})
				text = "«ما يجري في السلط سيصلك قبل غيرك.»"
			"publish":
				_expose_rival("journalist")
				text = "«القصة ستكون على الصفحة الأولى يوم السبت.»"
			"profile":
				flags["profile_done"] = true
				add_rep(8)
				news("«الصباح» تكتب عن كاتب شاب يريد أن يغيّر بلدية السلط")
				text = "سيكتب جميل عنك مقالاً في عدد السبت."
	else:
		text = "«سأفكّر في الأمر.» — لم تحصل على ما أردت هذه المرة." if ask != "chat" else "انتهى اللقاء بفتور."
	var res := {"ok": ok, "text": text, "dop": dop, "pid": pid, "ask": ask}
	duel = {}
	advance(60)
	changed.emit()
	return res

func _expose_rival(via: String) -> void:
	if rival["exposed"]:
		return
	rival["exposed"] = true
	rival["scandal"] = clampv(rival["scandal"] + 30)
	rival["rep"] = clampv(rival["rep"] - 8)
	for pid in notables():
		add_rival_op(pid, -8)
		if people[pid]["pledged"] == "rival" and people[pid]["traits"].has("principled"):
			people[pid]["pledged"] = ""
	news("شبهات اختلاس في بلدية السلط تطال الكاتب عيسى الحدّاد")
	add_history("انكشفت اختلاسات عيسى الحدّاد.")


# ------------------------------------------------------------------ schemes

func scheme_targets(type: String) -> Array:
	var out := []
	match type:
		"dig":
			for pid in people:
				if people[pid].has("secret") and not has_secret(pid):
					out.append(pid)
			if not has_secret("issa"):
				out.append("issa")
		"rumour":
			out.append("issa")
		"bribe":
			for pid in notables():
				if people[pid]["pledged"] != "player":
					out.append(pid)
		"leak":
			for s in secrets:
				out.append(s["on"])
	return out

func scheme_odds(type: String, target: String) -> Dictionary:
	var d: Dictionary = C.SCHEMES[type]
	var odds: float = d["odds"]
	var disc: float = d["disc"]
	var st: Dictionary = player["stats"]
	match type:
		"dig":
			odds += st["intrigue"] * 1.5
			if flags.get("ally_police", false):
				odds += 12
				disc -= 6
			if flags.get("archives_until", 0) > minutes and (target == "issa" or target == "mayor"):
				odds += 10
			if (target == "issa" and rival["hinted"]) or (people.has(target) and people[target]["hinted"]):
				odds += 8
			if target == "official":
				odds -= 15
		"rumour":
			odds += st["intrigue"]
		"bribe":
			odds = 75.0 if people[target]["traits"].has("greedy") else 25.0
			if people[target]["traits"].has("principled"):
				odds = 5.0
				disc += 25
		"leak":
			if not (flags.get("ally_journalist", false) or people["journalist"]["opinion"] >= 25):
				odds = 0.0
	if scheme_running(target):
		odds = 0.0
	return {"odds": clamp(odds, 0, 95), "disc": clamp(disc, 2, 90)}

func scheme_running(target: String) -> bool:
	for s in schemes:
		if s["target"] == target:
			return true
	return false

func scheme_state(type: String, target: String) -> Dictionary:
	var d: Dictionary = C.SCHEMES[type]
	if d.has("cost") and player["money"] < d["cost"]:
		return {"ok": false, "why": "لا يكفي المال"}
	if scheme_running(target):
		return {"ok": false, "why": "لديك دسيسة جارية عليه"}
	if type == "leak" and scheme_odds(type, target)["odds"] <= 0:
		return {"ok": false, "why": "لا صحفي يثق بك بعد"}
	if schemes.size() >= 2:
		return {"ok": false, "why": "لا تستطيع إدارة أكثر من دسيستين"}
	return {"ok": true, "why": ""}

func start_scheme(type: String, target: String) -> void:
	if not scheme_state(type, target)["ok"]:
		return
	var d: Dictionary = C.SCHEMES[type]
	if d.has("cost"):
		player["money"] -= d["cost"]
	var o := scheme_odds(type, target)
	schemes.append({"type": type, "target": target, "start": minutes, "end": minutes + int(d["days"]) * 1440,
		"odds": o["odds"], "disc": o["disc"], "mid": false})
	say("بدأت: %s — %s." % [d["name"], person_name(target)])
	changed.emit()

func _schemes_tick() -> void:
	for s in schemes.duplicate():
		if not s["mid"] and minutes >= (int(s["start"]) + int(s["end"])) / 2:
			s["mid"] = true
			if rng.randf() < 0.5:
				_raise({"id": "complication", "title": "تعقيد في الطريق", "art": "scheme",
					"text": _complication_text(s), "data": {"scheme": s},
					"options": [{"id": "pay", "text": "ادفع ٥ دنانير لشراء الصمت", "note": "خطر الانكشاف أقل", "enabled": player["money"] >= 5},
						{"id": "push", "text": "تابع بجرأة", "note": "فرصة أعلى، وخطر أعلى"},
						{"id": "abort", "text": "أوقف كل شيء", "note": "لا ربح ولا خسارة"}]})
		if minutes >= int(s["end"]):
			schemes.erase(s)
			_resolve_scheme(s)

func _complication_text(s: Dictionary) -> String:
	match s["type"]:
		"dig": return "الحارس الليلي رآك تخرج من غرفة الأرشيف متأخراً. ينظر إليك كمن ينتظر شيئاً."
		"rumour": return "أحد رجال عيسى سمع الإشاعة تتردّد ويسأل من أين بدأت."
		"bribe": return "الوسيط يطلب المزيد: «الرجل خائف، ويحتاج طمأنة.»"
		_: return "المحرّر يتردّد: «أحتاج دليلاً آخر قبل النشر.»"

func _resolve_scheme(s: Dictionary) -> void:
	var t: String = s["target"]
	var ok := rng.randf() * 100.0 < float(s["odds"])
	var found := rng.randf() * 100.0 < float(s["disc"])
	var nm := person_name(t)
	var lines := []
	if ok:
		match s["type"]:
			"dig":
				var sec := secret_of(t)
				secrets.append({"on": t, "text": sec["text"], "sev": sec["sev"]})
				lines.append("وجدت ما تبحث عنه: %s %s." % [nm, sec["text"]])
				add_history("حصلت على ملف عن %s." % nm)
			"rumour":
				rival["rep"] = clampv(rival["rep"] - 7)
				for pid in notables():
					add_rival_op(pid, -4)
				lines.append("الإشاعة انتشرت. الناس ينظرون إلى عيسى بريبة.")
			"bribe":
				add_op(t, 25)
				if people[t]["opinion"] >= 40:
					people[t]["pledged"] = "player"
					lines.append("%s قبل المال، وسيقف معك في الانتخابات." % nm)
				else:
					lines.append("%s قبل المال، وصار أكثر ميلاً إليك." % nm)
			"leak":
				if t == "issa":
					_expose_rival("leak")
				else:
					add_op(t, -30)
					if people.has(t):
						people[t]["pledged"] = ""
					news("«الصباح»: %s %s" % [nm, secret_of(t)["text"]])
				lines.append("الملف وصل إلى الجريدة. القصة ستخرج يوم السبت.")
	else:
		lines.append("الدسيسة على %s لم تنجح." % nm)
	if found:
		var scale := {"dig": 8, "rumour": 12, "bribe": 18, "leak": 6}
		var sc: int = scale[s["type"]]
		add_scandal(sc)
		add_op(t, -25)
		if s["type"] == "bribe":
			for pid in notables():
				if people[pid]["traits"].has("principled"):
					add_op(pid, -10)
		lines.append("لكنّ أمرك انكشف! الناس يتهامسون باسمك.")
		if player["scandal"] >= 30:
			news("همسات عن دسائس في بلدية السلط")
	_raise({"id": "scheme_result", "title": "نتيجة الدسيسة: " + C.SCHEMES[s["type"]]["name"], "art": "scheme",
		"text": " ".join(lines), "data": {}, "options": [{"id": "ok", "text": "حسناً"}]})


# ------------------------------------------------------------------ events

func _raise(ev: Dictionary) -> void:
	for o in ev["options"]:
		if not o.has("enabled"):
			o["enabled"] = true
	event_queue.append(ev)
	if event_queue.size() == 1:
		event_raised.emit(ev)

func current_event() -> Dictionary:
	return event_queue[0] if not event_queue.is_empty() else {}

func resolve_event(opt_id: String) -> void:
	if event_queue.is_empty():
		return
	var ev: Dictionary = event_queue.pop_front()
	_event_fx(ev, opt_id)
	changed.emit()
	if not event_queue.is_empty():
		event_raised.emit(event_queue[0])

func _scripted_events() -> void:
	var d := day()
	var h := hour()
	if d == 1 and h == 9 and not flags.has("ev_report"):
		flags["ev_report"] = true
		_raise({"id": "report", "title": "تقرير المياه", "art": "office",
			"text": "الحاج زياد يطلب منك تقريراً عن حال عيون السلط قبل اجتماع المجلس. الأرقام سيئة: الصيف لم يبدأ بعد، والطوابير تطول.",
			"options": [{"id": "honest", "text": "اكتب الحقيقة كما هي", "note": "الرئيس يقدّر الصراحة… أحياناً"},
				{"id": "soft", "text": "خفّف الأرقام قليلاً", "note": "يرتاح الآن، وقد يندم لاحقاً"}]})
	if d >= 3 and h == 11 and not flags.has("ev_envelope") and player["town"] == "salt" and C.WORKDAYS.has(weekday()):
		flags["ev_envelope"] = true
		_raise({"id": "envelope", "title": "مغلّف على المكتب", "art": "envelope",
			"text": "وجدت تحت ملف رخصة بناء مغلّفاً فيه عشرة دنانير، ومعه بطاقة مقاول: «تقديراً لسرعتك في إنجاز المعاملة.»",
			"options": [{"id": "keep", "text": "احتفظ به", "note": "+١٠ دنانير — ومن يدري من رآك"},
				{"id": "return", "text": "أعده إلى صاحبه بهدوء", "note": "لا ربح، لا خطر"},
				{"id": "report", "text": "سلّمه للحاج زياد", "note": "الرئيس سيعرف من أنت"}]})
	if d == 9 and h == 8 and not flags.has("ev_wedding"):
		flags["ev_wedding"] = true
		flags["wedding_open"] = true
		_raise({"id": "wedding_invite", "title": "دعوة إلى إربد", "art": "letter",
			"text": "رسول من الشيخ فالح: ابن أخيه يتزوّج في إربد مساء الخميس ٢١ أيار. «الشيخ يريد أن يرى رجال العائلة هناك.» إربد على بعد نصف نهار في الحافلة.",
			"options": [{"id": "ok", "text": "سأكون هناك", "note": "العرس يُقام مساء الخميس فقط"}]})
	if flags.has("well_day") and not flags.has("ev_well_price") and d >= int(flags["well_day"]) + 5 and h == 10:
		flags["ev_well_price"] = true
		_raise({"id": "well_price", "title": "أبو خليل يطلب الثمن", "art": "market",
			"text": "أبو خليل في مكتبك: «البئر ما زالت مفتوحة للناس. والآن أريد ترخيص مخزن على أرض البلدية خلف السوق. أنت تعرف كيف تمرّر الأوراق.»",
			"options": [{"id": "approve", "text": "مرّر الترخيص", "note": "تفي بوعدك — والأرض ليست له"},
				{"id": "refuse", "text": "ارفض", "note": "سيغضب، وقد يذهب إلى عيسى"}]})
	if d == 20 and h == 17 and not flags.has("ev_petition"):
		flags["ev_petition"] = true
		_raise({"id": "petition", "title": "عريضة الأستاذ فيصل", "art": "letter",
			"text": "الأستاذ فيصل يجمع تواقيع على عريضة إلى الحكومة تطالب بمدارس لأبناء اللاجئين في السلط. توقيعك سيُقرأ في عمّان.",
			"options": [{"id": "sign", "text": "وقّع باسمك", "note": "الأستاذ سيذكرها، والوزارة أيضاً"},
				{"id": "decline", "text": "اعتذر بلطف", "note": "الموظف لا يوقّع العرائض"}]})
	if d == 33 and h == 19 and not flags.has("ev_debate"):
		flags["ev_debate"] = true
		if player["town"] == "salt":
			flags["debate_score"] = 0
			_raise(_debate_round(1))
		else:
			flags["debate"] = -4
			news("عيسى الحدّاد يخطب في مضافة الشيخ فالح… وسليم ناصر غائب")
			_rival_note("عيسى تكلّم وحده في المضافة الليلة. غيابك لم يمرّ دون تعليق.")
			say("فاتتك ليلة المضافة. عيسى تكلّم وحده.")
	if d == ELECTION_DAY and h == 7 and not flags.has("ev_vote"):
		flags["ev_vote"] = true
		_raise({"id": "vote_day", "title": "يوم الاقتراع", "art": "vote",
			"text": "السلط تستيقظ على يوم الاقتراع. الصناديق في دار البلدية، والرجال يصطفّون منذ الصباح. الفرز عند المغرب.",
			"options": [{"id": "ok", "text": "لننتظر النتيجة"}]})

func _debate_round(n: int) -> Dictionary:
	var has_s := has_secret("issa")
	match n:
		1:
			return {"id": "debate1", "title": "ليلة المضافة (١ من ٣)", "art": "debate", "data": {"n": 1},
				"text": "المضافة ممتلئة. الشيخ فالح في الصدر، وعيسى يقف: «سليم ولد طيّب، لكنه لا يعرف إلا الأوراق. السلط تحتاج رجلاً مجرّباً.» العيون تتجه إليك.",
				"options": [{"id": "numbers", "text": "ردّ بالأرقام: ما أنجزتَه في البلدية", "note": "يعتمد على إدارتك"},
					{"id": "kin", "text": "ذكّرهم بأهلك ومكانة عائلتك", "note": "يعجب العشائريين"},
					{"id": "joke", "text": "ردّ بنكتة لاذعة", "note": "مخاطرة: تضحكهم أو تُحرجك"}]}
		2:
			return {"id": "debate2", "title": "ليلة المضافة (٢ من ٣)", "art": "debate", "data": {"n": 2},
				"text": "رجل من آخر المجلس يسأل: «والماء؟ نساؤنا يقفن على العين من الفجر. ماذا فعلتما؟»",
				"options": [{"id": "water_did", "text": "اذكر ما فعلته للماء", "note": "ينفع إن كنت فعلت شيئاً فعلاً"},
					{"id": "water_promise", "text": "عِد بحلّ خلال شهر", "note": "وعد يسمعه الجميع"},
					{"id": "water_blame", "text": "حمّل عيسى والرئيس المسؤولية", "note": "قد يُغضب الحاج زياد"}]}
		_:
			var opts := [{"id": "close_kin", "text": "اختم بالدعاء للسلط وأهلها", "note": "ختام آمن"},
				{"id": "close_vision", "text": "اختم برؤيتك: بلدية نظيفة اليد", "note": "يعجب أصحاب المبادئ"}]
			if has_s:
				opts.append({"id": "close_file", "text": "لمّح إلى إيصالات عيسى المزوّرة", "note": "ضربة قاضية — أو فضيحة"})
			return {"id": "debate3", "title": "ليلة المضافة (٣ من ٣)", "art": "debate", "data": {"n": 3},
				"text": "الشيخ فالح يرفع يده: «كلمة أخيرة لكل واحد منكما.» عيسى يتكلّم عن خبرته. الآن دورك.", "options": opts}

func _check(base: float) -> bool:
	return rng.randf() * 100.0 < base

func _event_fx(ev: Dictionary, o: String) -> void:
	var st: Dictionary = player["stats"]
	match ev["id"]:
		"report":
			if o == "honest":
				add_op("mayor", 4)
				flags["honest_report"] = true
				say("قرأ الحاج زياد التقرير وتنهّد: «على الأقل أنت لا تكذب عليّ.»")
			else:
				add_op("mayor", 2)
				flags["downplayed"] = true
				say("ارتاح الحاج زياد. الأرقام بدت أقلّ سوءاً على الورق.")
		"envelope":
			match o:
				"keep":
					player["money"] += 10
					add_scandal(8)
					flags["took_envelope"] = true
				"return":
					add_rep(1)
				"report":
					add_op("mayor", 7)
					add_history("سلّمت مغلّف رشوة للحاج زياد.")
					say("الحاج زياد: «في هذه البلدية رجل نظيف إذن.»")
		"wedding_invite":
			pass
		"well_price":
			if o == "approve":
				flags["well_approved"] = true
				add_scandal(10)
				add_op("merchant", 18)
				if people["merchant"]["opinion"] >= 40:
					people["merchant"]["pledged"] = "player"
				_clear_favour("merchant")
				add_history("مرّرت ترخيص مخزن أبي خليل على أرض البلدية.")
			else:
				add_op("merchant", -30)
				add_rival_op("merchant", 15)
				_clear_favour("merchant")
				add_history("رفضت ترخيص أبي خليل. صار خصماً.")
		"petition":
			if o == "sign":
				flags["petition_signed"] = true
				add_op("teacher", 14)
				add_op("official", -8)
				add_rep(2)
			else:
				add_op("teacher", -4)
		"water1":
			if o == "calm" and player["town"] == "salt":
				add_rep(3)
				advance(120, false)
				say("فرّقت الشجار ووزّعت الدور. النساء يذكرنك بالخير.")
			else:
				add_rep(-1)
		"water2":
			if flags.get("downplayed", false):
				add_op("mayor", -12)
			if o == "speak" and player["town"] == "salt":
				if _check(35 + st["charisma"] * 3):
					add_rep(6)
					add_op("mayor", 5)
					say("صعدت على درج البلدية وتكلّمت. الجموع هدأت.")
					add_history("هدّأت مظاهرة المياه أمام البلدية.")
				else:
					add_rep(-5)
					say("صفّروا عليك. أحدهم رمى قشرة برتقال.")
			else:
				add_rep(-3)
		"water3":
			pass
		"complication":
			var s: Dictionary = ev["data"]["scheme"]
			match o:
				"pay":
					player["money"] -= 5
					s["disc"] = max(2, s["disc"] - 10)
				"push":
					s["odds"] = min(95, s["odds"] + 10)
					s["disc"] = min(90, s["disc"] + 10)
				"abort":
					schemes.erase(s)
		"road":
			_road_fx(ev, o)
		"debate1", "debate2", "debate3":
			_debate_fx(ev, o)
		"vote_day":
			pass

func _debate_fx(ev: Dictionary, o: String) -> void:
	var st: Dictionary = player["stats"]
	var score: int = flags.get("debate_score", 0)
	var line := ""
	match o:
		"numbers":
			if _check(30 + st["administration"] * 4):
				score += 2
				line = "الأرقام أسكتت المجلس. حتى الدكتور هاني أومأ."
			else:
				score -= 1
				line = "تلعثمت بين الأرقام. عيسى ابتسم."
		"kin":
			score += 2 if people["sheikh"]["pledged"] == "player" else 1
			add_op("sheikh", 3)
			line = "الشيخ فالح هزّ رأسه راضياً."
		"joke":
			if _check(25 + st["charisma"] * 4):
				score += 3
				line = "ضجّت المضافة بالضحك. عيسى احمرّ."
			else:
				score -= 2
				line = "لم يضحك أحد. صمت ثقيل."
		"water_did":
			if water["solved_by"] == "player" or water["trucks"] > 0 or water["well_open"]:
				score += 3
				line = "الكل يعرف ما فعلته للماء. هذا لا يُنكر."
			else:
				score -= 2
				line = "«وماذا فعلت؟» سأل أحدهم. لم يكن عندك جواب."
		"water_promise":
			score += 1
			flags["water_promise"] = true
			line = "وعدك سُمع. سيتذكّرونه."
		"water_blame":
			score += 1
			add_op("mayor", -10)
			line = "أصبت عيسى، لكن الحاج زياد سيعرف ما قلته عنه."
		"close_kin":
			score += 1
			line = "ختام هادئ. لا ربح كبير ولا خسارة."
		"close_vision":
			score += 2 if not flags.get("took_envelope", false) else -2
			add_op("teacher", 6)
			line = "«بلدية نظيفة اليد» — الأستاذ فيصل صفّق." if not flags.get("took_envelope", false) else "عيسى قاطعك: «وماذا عن المغلّف يا سليم؟» ساد الصمت."
		"close_file":
			if _check(55 + st["intrigue"] * 2):
				score += 4
				_expose_rival("debate")
				line = "حين ذكرت الإيصالات، شحب وجه عيسى. لم يجد رداً."
			else:
				score -= 3
				add_scandal(8)
				line = "عيسى انقلب عليك: «اتهامات بلا دليل!» بعض الرجال وافقوه."
	flags["debate_score"] = score
	say(line)
	var n: int = ev["data"]["n"]
	if n < 3:
		_raise(_debate_round(n + 1))
	else:
		flags["debate"] = clamp(score * 1.2, -6, 6)
		news("ليلة ساخنة في مضافة الشيخ فالح بين سليم ناصر وعيسى الحدّاد")
		add_history("واجهت عيسى في مضافة الشيخ فالح.")

func _clear_favour(who: String) -> void:
	for f in favours.duplicate():
		if f["who"] == who and f["dir"] == "owe":
			favours.erase(f)

func _water_event(stage: int) -> void:
	match stage:
		1:
			_raise({"id": "water1", "title": "شجار عند العين", "art": "water",
				"text": "تشاجرت امرأتان على الدور عند عين السلط، وتدخّل الرجال. الناس يسألون: أين البلدية؟",
				"options": [{"id": "calm", "text": "اذهب ونظّم الدور بنفسك", "note": "ساعتان — إن كنت في السلط", "enabled": player["town"] == "salt"},
					{"id": "ignore", "text": "ليس من شأني", "note": ""}]})
		2:
			news("مظاهرة أمام بلدية السلط احتجاجاً على شحّ المياه")
			_raise({"id": "water2", "title": "مظاهرة أمام البلدية", "art": "crowd",
				"text": "مئات تجمّعوا أمام دار البلدية يهتفون: «الماء! الماء!». الحاج زياد في مكتبه لا يخرج. الكتبة ينظرون إليك.",
				"options": [{"id": "speak", "text": "اخرج وكلّم الناس", "note": "يعتمد على حضورك (الكاريزما)", "enabled": player["town"] == "salt"},
					{"id": "hide", "text": "ابقَ في الداخل", "note": "الناس سيتذكرون من اختبأ"}]})
		3:
			add_rep(-6)
			add_op("mayor", -8)
			rival["rep"] = clampv(rival["rep"] - 4)
			news("أعمال شغب في السلط بسبب انقطاع المياه")
			add_history("اندلع شغب في السلط بسبب الماء.")
			_raise({"id": "water3", "title": "شغب في السلط", "art": "crowd",
				"text": "تحطّم زجاج دار البلدية الليلة الماضية. الشرطة اعتقلت شبّاناً، والمتصرّف أرسل يسأل. الكل في البلدية خاسر.",
				"options": [{"id": "ok", "text": "يا لها من فوضى"}]})

func _road_event() -> void:
	var kinds := ["checkpoint", "breakdown", "stranger"]
	var k: String = kinds[rng.randi() % kinds.size()]
	match k:
		"checkpoint":
			_raise({"id": "road", "title": "حاجز على الطريق", "art": "road", "data": {"k": k},
				"text": "دورية من البادية توقف الحافلة. العسكري يتفحّص الوجوه طويلاً، ويطلب الأوراق.",
				"options": [{"id": "papers", "text": "أبرز هويتك الحكومية", "note": "موظف بلدية — لا مشكلة عادة"},
					{"id": "tip", "text": "ادسّ له ديناراً ليسرّع", "note": "دينار واحد", "enabled": player["money"] >= 1}]})
		"breakdown":
			_raise({"id": "road", "title": "عطل في الحافلة", "art": "road", "data": {"k": k},
				"text": "انفجر إطار الحافلة على منعطف. السائق يشتم ويخرج العدّة. الركاب يجلسون في ظلّ صخرة.",
				"options": [{"id": "wait", "text": "انتظر مع الركاب", "note": "تأخير ساعة ونصف"},
					{"id": "help", "text": "ساعد السائق", "note": "أسرع قليلاً، والناس تلاحظ"}]})
		_:
			_raise({"id": "road", "title": "رفيق الطريق", "art": "road", "data": {"k": k},
				"text": "بجانبك في الحافلة معلّم لاجئ من يافا، يعمل في مدرسة الوكالة. يحكي عن بيته الذي تركه، ويسأل عن أحوال السلط.",
				"options": [{"id": "listen", "text": "أصغِ إليه طوال الطريق", "note": "ستعرف شيئاً"},
					{"id": "help", "text": "ادفع له أجرة الحافلة", "note": "دينار واحد", "enabled": player["money"] >= 1}]})

func _road_fx(ev: Dictionary, o: String) -> void:
	var t: Dictionary = player["travel"]
	match o:
		"papers":
			if player["scandal"] >= 40:
				if not t.is_empty():
					t["arr"] = int(t["arr"]) + 90
				say("العسكري سمع اسمك من قبل… احتجزك ساعة ونصف.")
			else:
				say("نظر في الهوية وأشار للحافلة: «توكّلوا على الله.»")
		"tip":
			player["money"] -= 1
			say("اختفى الدينار في جيب العسكري، وتحرّكت الحافلة.")
		"wait":
			if not t.is_empty():
				t["arr"] = int(t["arr"]) + 90
		"help":
			if ev["data"]["k"] == "breakdown":
				if not t.is_empty():
					t["arr"] = int(t["arr"]) + 45
				add_rep(1)
			else:
				player["money"] -= 1
				add_rep(1)
				say("شكرك بحرارة: «إن احتجت شيئاً في مخيّم البقعة، اسأل عن أبي سمير.»")
		"listen":
			var r := _pick_rumour()
			add_rumour(r)
			say(r)


# ------------------------------------------------------------------ newspaper

func _issue_paper() -> void:
	issues_done += 1
	var n := issues_done
	var local := local_news.duplicate()
	local_news.clear()
	if local.is_empty():
		local.append("هدوء في السلط… والكل ينتظر يوم الاقتراع")
	var issue := {"no": n, "date": date_text(-1, true), "national": C.NATIONAL.get(n, []), "local": local.slice(0, 3),
		"forecast": forecast(), "days_left": days_to_election()}
	paper_open = true
	newspaper.emit(issue)

func close_paper() -> void:
	paper_open = false
	changed.emit()
	if not event_queue.is_empty():
		event_raised.emit(event_queue[0])


# ------------------------------------------------------------------ election

func backing(pid: String) -> String:
	var p: Dictionary = people[pid]
	if p["pledged"] != "":
		return p["pledged"]
	var lean: float = p["opinion"] - p["rival_op"]
	if lean >= 10:
		return "lean_player"
	if lean <= -10:
		return "lean_rival"
	return ""

func forecast() -> Dictionary:
	var you: float = 18.0 + player["rep"] * 0.4 - player["scandal"] * 0.35
	var him: float = 30.0 + rival["rep"] * 0.4 - rival["scandal"] * 0.35 # the Haddads and the old clerks back him
	for pid in notables():
		var w: float = people[pid]["weight"]
		match backing(pid):
			"player": you += w
			"rival": him += w
			"lean_player": you += w * 0.5
			"lean_rival": him += w * 0.5
	if water["solved_by"] == "player":
		you += 8
	elif water["solved_by"] == "rival":
		him += 8
	if flags.get("wedding_attended", false):
		you += 3
	you += flags.get("debate", 0)
	you = max(you, 3.0)
	him = max(him, 3.0)
	var p := you / (you + him) * 100.0
	return {"you": p, "him": 100.0 - p}

func _finish() -> void:
	var f := forecast()
	var noise := rng.randf_range(-3.0, 3.0)
	var you: float = clamp(f["you"] + noise, 1, 99)
	var won := you > 50.0
	var total := 4300
	result = {"won": won, "you_pct": you, "him_pct": 100.0 - you, "you_votes": int(total * you / 100.0), "him_votes": total - int(total * you / 100.0),
		"water": water["solved_by"], "pledges": _pledge_names("player"), "rival_pledges": _pledge_names("rival"),
		"secrets": secrets.size(), "scandal": player["scandal"], "rival_exposed": rival["exposed"], "rep": player["rep"]}
	over = true
	add_history("أُعلنت نتيجة انتخابات مقعد السلط البلدي.")
	ended.emit(result)

func _pledge_names(side: String) -> Array:
	var out := []
	for pid in notables():
		if people[pid]["pledged"] == side:
			out.append(people[pid]["name"])
	return out


# ------------------------------------------------------------------ goals shown on the career card

func goals() -> Array:
	var pledges := _pledge_names("player").size()
	return [
		{"text": "اكسب ثقة رئيس البلدية", "done": people["mayor"]["opinion"] >= 50 or people["mayor"]["pledged"] == "player", "hint": "رأيه فيك %s" % ar(int(people["mayor"]["opinion"]))},
		{"text": "أنهِ أزمة المياه قبل أن تنفجر", "done": water["solved_by"] == "player", "fail": water["solved_by"] == "rival", "hint": "الخطورة %s٪" % ar(int(water["severity"]))},
		{"text": "احصل على تأييد ثلاثة من الوجهاء", "done": pledges >= 3, "hint": "%s من ٣" % ar(pledges)},
		{"text": "أبقِ الفضيحة تحت ٤٠", "done": player["scandal"] < 40, "hint": "الآن %s" % ar(int(player["scandal"]))},
	]
