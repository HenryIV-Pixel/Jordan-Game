extends Node
## Parliament scenario "The Pact", December 1955 (autoload "House").
## You are the prime minister's fixer. Six days to win a majority of the deputies present for joining the
## Baghdad Pact, while the street, egged on by Cairo radio, grows angrier and the King's patience runs out.
## Day-based: 4 action slots per day; ending the day runs the night (opposition lobbying, the street, events).

signal changed
signal toast(text: String)
signal event_raised(ev: Dictionary)
signal vote_started(roll: Array)
signal ended(result: Dictionary)

const H := preload("res://scripts/sim/house_content.gd")
const C := preload("res://scripts/sim/content.gd")
const QUORUM := 21

var rng := RandomNumberGenerator.new()
var day := 0
var ap := 4
var deputies: Array = []
var street := 30.0 # anger in the street, 0..100
var trust := 70.0 # the King's trust in the government, 0..100
var posts := 3
var projects := 5
var fund := 300
var palace_words := 2
var used := {}
var log: Array = []
var event_queue: Array = []
var duel := {}
var over := false
var result := {}
var phase := "lobby" # lobby | vote | done


func new_game(seed_in: int) -> void:
	rng.seed = seed_in
	day = 0
	ap = H.AP_PER_DAY
	street = 30.0
	trust = 70.0
	posts = 3
	projects = 5
	fund = 300
	palace_words = 2
	used = {}
	log = []
	event_queue = []
	duel = {}
	over = false
	result = {}
	phase = "lobby"
	_make_deputies()
	note("كلّفك رئيس الوزراء هزّاع المجالي بمهمة واحدة: أغلبية في مجلس النواب للانضمام إلى حلف بغداد قبل مساء ٢٠ كانون الأول.")
	_raise(_event_intro())
	changed.emit()


func _make_deputies() -> void:
	deputies = []
	var first := H.FIRST.duplicate()
	var fe := H.FAMILY_EAST.duplicate()
	var fw := H.FAMILY_WEST.duplicate()
	_shuffle(first)
	_shuffle(fe)
	_shuffle(fw)
	var east_i := 0
	var west_i := 0
	var trait_ids := C.TRAITS.keys()
	var idx := 0
	for comp in H.COMPOSITION:
		var bloc: String = comp[0]
		var b: Dictionary = H.BLOCS[bloc]
		for k in comp[1]:
			var bank: String = comp[2]
			var town := ""
			var family := ""
			if bloc == "bedouin":
				town = ["mafraq", "qatrana", "maan"][k]
				family = ["الزبن", "الفايز", "الحويطات"][k]
			elif bank == "east":
				town = H.TOWNS_EAST[east_i % H.TOWNS_EAST.size()]
				family = fe[east_i % fe.size()]
				east_i += 1
			else:
				town = H.TOWNS_WEST[west_i % H.TOWNS_WEST.size()]
				family = fw[west_i % fw.size()]
				west_i += 1
			var seat := ""
			if bloc == "east_urban":
				seat = ["christian", "circassian", "christian", ""][k]
			var name: String = first[idx % first.size()] + " " + family
			if seat == "circassian":
				name = first[idx % first.size()] + " شابسوغ"
			var traits := []
			while traits.size() < 2:
				var t: String = trait_ids[rng.randi() % trait_ids.size()]
				if not traits.has(t):
					traits.append(t)
			if bloc == "bedouin" and not traits.has("tribal"):
				traits[0] = "tribal"
			if bloc == "opposition" and not traits.has("principled") and rng.randf() < 0.6:
				traits[0] = "principled"
			var want := _pick_want(bloc)
			var stance: float = b["base"] + rng.randf_range(-b["spread"], b["spread"])
			deputies.append({"id": "d%d" % idx, "name": name, "town": town, "bank": bank, "bloc": bloc, "seat": seat,
				"stance": clampf(stance, -95, 95), "traits": traits, "known": [], "want": want, "want_known": false,
				"secret": H.SECRETS[rng.randi() % H.SECRETS.size()] if rng.randf() < 0.35 else "", "secret_known": false,
				"promised": false, "paid": false, "palace": false, "absent": false, "committed": false, "met_day": -1, "dug": false,
				"look": {"hw": 0 if bloc in ["bedouin", "east_tribal"] else (1 if rng.randf() < 0.5 else -1), "skin": rng.randi() % 4, "beard": rng.randi() % 3, "old": rng.randf() < 0.5}})
			idx += 1


func _pick_want(bloc: String) -> String:
	var pools := {"bedouin": ["tribe", "money", "water", "road"], "east_tribal": ["road", "post", "tribe", "school", "water", "money", "pardon"],
		"east_urban": ["post", "money", "road", "school"], "west_notable": ["egypt", "post", "school", "pardon", "road"],
		"west_indep": ["egypt", "egypt", "school", "pardon", "water"], "opposition": ["egypt", "egypt", "egypt", "pardon"]}
	var pool: Array = pools[bloc]
	return pool[rng.randi() % pool.size()]


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


# ------------------------------------------------------------------ reading the state

func date_text(d := -1) -> String:
	if d < 0:
		d = day
	d = min(d, H.DAYS - 1)
	var wds := ["الخميس", "الجمعة", "السبت", "الأحد", "الاثنين", "الثلاثاء"]
	var wd: String = wds[d % 6]
	return "%s %s كانون الأول ١٩٥٥" % [wd, Game.ar(H.START_DAY + d)]

func dep(id: String) -> Dictionary:
	for d in deputies:
		if d["id"] == id:
			return d
	return {}

func category(d: Dictionary) -> String:
	if d["absent"]:
		return "absent"
	var s: float = d["stance"]
	if s >= 35 or d["committed"]:
		return "for"
	if s >= 10:
		return "lean_for"
	if s > -10:
		return "undecided"
	if s > -35:
		return "lean_against"
	return "against"

func counts() -> Dictionary:
	var c := {"for": 0, "lean_for": 0, "undecided": 0, "lean_against": 0, "against": 0, "absent": 0}
	for d in deputies:
		c[category(d)] += 1
	c["present"] = deputies.size() - c["absent"]
	c["needed"] = int(c["present"] / 2) + 1
	return c

## Rough forecast of the vote if it were held now: firm and leaning votes count, undecided split by stance.
func forecast() -> Dictionary:
	var yes := 0.0
	var present := 0
	for d in deputies:
		if d["absent"]:
			continue
		present += 1
		yes += _p_yes(d)
	return {"yes": yes, "present": present, "needed": int(present / 2) + 1}

func _p_yes(d: Dictionary) -> float:
	var s: float = d["stance"]
	if d["committed"]:
		return 0.97
	return clampf(0.5 + s / 50.0, 0.02, 0.98)

func note(text: String) -> void:
	log.push_front({"day": day, "text": text})

func say(text: String) -> void:
	toast.emit(text)

func move(d: Dictionary, amount: float) -> void:
	if d["committed"] and amount < 0:
		amount *= 0.25 # a man who gave his word moves slowly
	d["stance"] = clampf(d["stance"] + amount, -100, 100)


# ------------------------------------------------------------------ deputy actions

func action_state(aid: String, d: Dictionary) -> Dictionary:
	var a: Dictionary = H.DEPUTY_ACTIONS[aid]
	if phase != "lobby" or over:
		return {"ok": false, "why": "انتهى وقت المساعي"}
	if a["ap"] > ap:
		return {"ok": false, "why": "لا وقت اليوم — أنهِ اليوم"}
	match aid:
		"meet":
			if d["met_day"] == day:
				return {"ok": false, "why": "التقيته اليوم"}
		"post":
			if posts <= 0:
				return {"ok": false, "why": "لا مناصب باقية"}
			if d["promised"]:
				return {"ok": false, "why": "وعدته من قبل"}
		"project":
			if projects <= 0:
				return {"ok": false, "why": "نفدت ميزانية المشاريع"}
			if d["promised"]:
				return {"ok": false, "why": "وعدته من قبل"}
		"pay":
			if fund < 50:
				return {"ok": false, "why": "نفدت المخصّصات"}
			if d["paid"]:
				return {"ok": false, "why": "دفعت له من قبل"}
		"palace":
			if palace_words <= 0:
				return {"ok": false, "why": "لا يمكن إزعاج الملك أكثر"}
			if d["palace"]:
				return {"ok": false, "why": "استُدعي من قبل"}
		"dig":
			if d["dug"]:
				return {"ok": false, "why": "تقصّيت عنه من قبل"}
		"file":
			if not d["secret_known"]:
				return {"ok": false, "why": "لا ملف عنه"}
	return {"ok": true, "why": ""}

func act(aid: String, id: String) -> String:
	var d := dep(id)
	if d.is_empty() or not action_state(aid, d)["ok"]:
		return ""
	ap -= int(H.DEPUTY_ACTIONS[aid]["ap"])
	var line := ""
	var tr: Array = d["traits"]
	match aid:
		"post":
			posts -= 1
			d["promised"] = true
			var g := 45.0 if d["want"] == "post" else 15.0
			if d["bloc"] == "opposition":
				g *= 0.3
			move(d, g)
			line = "وعدت %s بمنصب. %s" % [d["name"], "لمعت عيناه." if d["want"] == "post" else "قبل الوعد ببرود."]
			if d["want"] == "post":
				d["want_known"] = true
		"project":
			projects -= 1
			d["promised"] = true
			var hit: bool = d["want"] in ["road", "school", "water"]
			var g2 := 38.0 if hit else 10.0
			if d["bloc"] == "opposition":
				g2 *= 0.4
			move(d, g2)
			line = "وعدت %s بمشروع لقضاء %s. %s" % [d["name"], Game.town_name(d["town"]), "هذا ما كان ينتظره." if hit else "شكرك، لكن ليس هذا ما يريده."]
			if hit:
				d["want_known"] = true
		"pay":
			fund -= 50
			d["paid"] = true
			if tr.has("principled") or tr.has("pious"):
				move(d, -25)
				street += 6
				trust -= 3
				line = "%s ردّ المال في وجه رسولك… والقصة تنتشر في المقاهي." % d["name"]
				note(line)
			else:
				move(d, 32.0 if tr.has("greedy") or d["want"] == "money" else 12.0)
				line = "%s أخذ المغلّف دون كلمة." % d["name"]
		"palace":
			palace_words -= 1
			d["palace"] = true
			var palace_gain := {"bedouin": 40, "east_tribal": 40, "east_urban": 32, "west_notable": 20, "west_indep": 10, "opposition": 0}
			var g3: float = palace_gain[d["bloc"]]
			if d["want"] == "tribe":
				g3 += 15
				d["want_known"] = true
			move(d, g3)
			if d["bloc"] == "opposition":
				street += 5
				trust -= 4
				line = "استدعى الملك %s… فخرج يقول للصحفيين إن القصر يضغط على النواب." % d["name"]
			else:
				line = "خرج %s من القصر متأثراً: «لا أردّ لجلالته طلباً.»" % d["name"]
				if g3 >= 30:
					d["committed"] = true
		"dig":
			d["dug"] = true
			if d["secret"] != "" and rng.randf() < 0.6:
				d["secret_known"] = true
				line = "رجالك وجدوا شيئاً: %s %s." % [d["name"], d["secret"]]
			else:
				line = "لم يجد رجالك شيئاً عن %s… أو أنه أذكى منهم." % d["name"]
		"file":
			var blow := 0.25 if not tr.has("proud") else 0.45
			if rng.randf() < blow:
				move(d, -40)
				street += 10
				trust -= 6
				d["secret_known"] = false
				line = "%s لم ينحنِ: ذهب بنفسه إلى «فلسطين» وقال إن الحكومة تبتزّ النواب!" % d["name"]
				note(line)
			else:
				if d["bloc"] == "opposition" or d["stance"] < -30:
					d["absent"] = true
					line = "%s شحب وجهه. «سأكون مريضاً يوم الجلسة.»" % d["name"]
				else:
					d["stance"] = max(d["stance"], 50.0)
					d["committed"] = true
					line = "%s فهم الرسالة. سيرفع يده." % d["name"]
				d["secret_known"] = false
	if line != "":
		say(line)
	changed.emit()
	return line


# ------------------------------------------------------------------ meeting a deputy (a short duel, as in Salt)

func asks_for(d: Dictionary) -> Array:
	var out := [{"id": "chat", "name": "استمع إليه", "desc": "تعرف ما يريد وما يخشى", "target": 0}]
	if not d["committed"]:
		out.append({"id": "support", "name": "صوّت مع الحكومة", "desc": "التزام صريح بالتصويت", "target": 72})
	if d["stance"] < 15 and not d["absent"]:
		out.append({"id": "abstain", "name": "غِب عن الجلسة", "desc": "لا تصوّت ضدنا — كن مريضاً ذلك اليوم", "target": 55})
	return out

func start_duel(id: String, ask: String) -> void:
	var d := dep(id)
	if d.is_empty() or not action_state("meet", d)["ok"]:
		return
	ap -= 1
	d["met_day"] = day
	var target := 0
	for a in asks_for(d):
		if a["id"] == ask:
			target = a["target"]
	var start := clampf(42.0 + d["stance"] * 0.35, 5, 90)
	if d["bank"] == "west" and ask == "support":
		start -= street * 0.12 # every West Bank deputy hears the street outside his house
	duel = {"id": id, "ask": ask, "target": target, "mood": start, "start": start, "round": 0, "rounds": 3, "used": {}, "last": {}}
	changed.emit()

func duel_options() -> Array:
	var out := []
	var d := dep(duel["id"])
	for aid in C.APPROACHES:
		var a: Dictionary = C.APPROACHES[aid]
		var ok := true
		var why := ""
		if aid == "offer" and fund < 25:
			ok = false
			why = "نفدت المخصّصات"
		if aid == "pressure" and not d["secret_known"]:
			ok = false
			why = "لا ملف عنه"
		out.append({"id": aid, "name": a["name"], "desc": a["desc"] if aid != "offer" else "٢٥ ديناراً من المخصّصات", "ok": ok, "why": why, "used": duel["used"].get(aid, 0)})
	return out

func duel_play(aid: String) -> Dictionary:
	var d := dep(duel["id"])
	var a: Dictionary = C.APPROACHES[aid]
	var delta: float = a["base"] + 3.0
	var reveal := ""
	for tr in d["traits"]:
		var m: float = a["mods"].get(tr, 0)
		delta += m
		if abs(m) >= 8 and not d["known"].has(tr) and reveal == "":
			reveal = tr
	if aid == "principle" and d["want"] == "egypt":
		delta += 6
	if aid == "kin" and d["bloc"] in ["bedouin", "east_tribal"]:
		delta += 5
	var times: int = duel["used"].get(aid, 0)
	delta *= pow(0.5, times)
	delta += rng.randi_range(-3, 3)
	duel["used"][aid] = times + 1
	if aid == "listen":
		if reveal == "":
			for tr in d["traits"]:
				if not d["known"].has(tr):
					reveal = tr
					break
		d["want_known"] = true
	if aid == "offer":
		fund -= 25
	if aid == "pressure":
		delta += 10
	if reveal != "":
		d["known"].append(reveal)
	duel["mood"] = clampf(duel["mood"] + delta, 0, 100)
	duel["round"] += 1
	var text := ""
	if delta >= 15:
		text = "هزّ رأسه موافقاً وابتسم. أصبت الوتر."
	elif delta >= 7:
		text = "أصغى باهتمام. كلامك وصل."
	elif delta >= 0:
		text = "استمع بأدب دون حماس."
	else:
		text = "عقد حاجبيه. لم يعجبه هذا."
	if aid == "listen":
		text = "تكلّم طويلاً عن قضائه وهمومه. عرفت أنه يريد: %s." % H.WANTS[d["want"]]["name"]
	var e := {"aid": aid, "delta": delta, "text": text, "reveal": reveal}
	duel["last"] = e
	changed.emit()
	return e

func duel_success_now() -> bool:
	return duel["target"] == 0 or duel["mood"] >= duel["target"]

func duel_finish() -> Dictionary:
	var d := dep(duel["id"])
	var ok := duel_success_now()
	var gain: float = (duel["mood"] - duel["start"]) / 3.0
	move(d, gain)
	var text := ""
	match duel["ask"]:
		"chat":
			d["want_known"] = true
			text = "عرفت ما يريد %s: %s." % [d["name"], H.WANTS[d["want"]]["name"]]
		"support":
			if ok:
				d["stance"] = max(d["stance"], 45.0)
				d["committed"] = true
				text = "«لك صوتي يا ابني. قل لهزّاع باشا إن %s لا يخلف وعداً.»" % d["name"].split(" ")[0]
			else:
				move(d, -4)
				text = "«سأفكّر… الشارع يغلي، وأهل قضائي يراقبون.»"
		"abstain":
			if ok:
				d["absent"] = true
				text = "«سأكون في القدس ذلك اليوم… عند الطبيب.»"
			else:
				text = "«أغيب؟ ويقولون إنني بعت ضميري؟ لا.»"
	var res := {"ok": ok, "text": text, "gain": gain, "id": d["id"], "ask": duel["ask"]}
	duel = {}
	changed.emit()
	return res


# ------------------------------------------------------------------ global actions

func global_state(gid: String) -> Dictionary:
	var g: Dictionary = H.GLOBAL_ACTIONS[gid]
	if phase != "lobby" or over:
		return {"ok": false, "why": "انتهى وقت المساعي"}
	if g["ap"] > ap:
		return {"ok": false, "why": "لا وقت اليوم"}
	if g.get("once", false) and used.has(gid):
		return {"ok": false, "why": "فعلت ذلك"}
	if gid == "statement" and used.get("statement_day", -1) == day:
		return {"ok": false, "why": "مرة في اليوم"}
	return {"ok": true, "why": ""}

func global_act(gid: String) -> String:
	if not global_state(gid)["ok"]:
		return ""
	ap -= int(H.GLOBAL_ACTIONS[gid]["ap"])
	used[gid] = true
	var line := ""
	match gid:
		"statement":
			used["statement_day"] = day
			street = max(0.0, street - 6)
			line = "صحف عمّان الموالية تنشر بيانك: «الحلف يحمي الأردن ولا يمسّ عروبته.»"
		"aid":
			for d in deputies:
				if d["traits"].has("pragmatic") or d["bloc"] in ["east_urban", "east_tribal"]:
					move(d, 8)
			street += 3
			line = "السفارة البريطانية تعد كتابةً بمعاهدة معدّلة ومزيد من المال للجيش. العمليون يحسبون."
		"cairo":
			for d in deputies:
				if d["bank"] == "west" and d["bloc"] != "opposition":
					move(d, 12)
					if d["want"] == "egypt":
						move(d, 10)
			trust -= 8
			line = "مبعوثك عاد من القاهرة بكلام مطمئن. وجهاء الضفة الغربية ارتاحوا… والسفير البريطاني غاضب، والقصر لم يُسأل."
		"curfew":
			street = max(0.0, street - 22)
			trust -= 4
			for d in deputies:
				if d["bank"] == "west":
					move(d, -6)
			line = "الجيش في الشوارع ومنع التجوّل في نابلس والقدس. الهدوء عاد… والغضب صار صامتاً."
		"whips":
			var unknown := deputies.filter(func(x): return not x["want_known"])
			_shuffle(unknown)
			var names := []
			for d in unknown.slice(0, 3):
				d["want_known"] = true
				names.append(d["name"])
			line = "رجالك عادوا بأخبار عن: " + "، ".join(names) + "." if not names.is_empty() else "تعرف ما يريده الجميع."
	note(line)
	say(line)
	street = clampf(street, 0, 100)
	trust = clampf(trust, 0, 100)
	changed.emit()
	return line


# ------------------------------------------------------------------ the night: opposition, the street, the palace

func end_day() -> void:
	if phase != "lobby" or over or not duel.is_empty():
		return
	# the street: Cairo radio every night, worse in the West Bank
	var rise := 8.0 + rng.randf_range(0, 6) + (5.0 if day >= 2 else 0.0)
	street = clampf(street + rise, 0, 100)
	# opposition lobbying and street pressure on deputies
	var targets := deputies.filter(func(x): return x["bloc"] != "opposition" and not x["absent"] and x["stance"] > -40 and x["stance"] < 40)
	_shuffle(targets)
	for d in targets.slice(0, 3):
		move(d, -rng.randf_range(4, 9))
	for d in deputies:
		var w: float = H.BLOCS[d["bloc"]]["street"]
		move(d, -w * street / 17.0)
	# the King watches the street
	if street >= 70:
		trust -= 6
	elif street >= 50:
		trust -= 2
	trust = clampf(trust, 0, 100)
	day += 1
	ap = H.AP_PER_DAY
	if street >= 100 or trust <= 25:
		_dismissed()
		return
	if day >= H.DAYS:
		start_vote()
		return
	_night_events()
	changed.emit()

func _night_events() -> void:
	match day:
		1:
			_raise({"id": "templer", "who": "templer", "title": "تمبلر يلحّ", "text": "الجنرال تمبلر يغادر عمّان، لكنه يترك رسالة: «لندن تريد جواباً قبل نهاية الأسبوع. المعاهدة الجديدة والمال على الطاولة — لا أكثر.» السفير يلمّح إلى أن الإعانة السنوية للجيش قد تتأخر إن تأخر الأردن.",
				"options": [{"id": "firm", "text": "قل لهم إن الجواب سيأتي من مجلس النواب", "note": "ثقة الملك +٤"}, {"id": "ask", "text": "اطلب مهلة", "note": "الإنجليز يتأففون — نائبان عمليّان يترددان"}]})
		2:
			_raise({"id": "radio", "who": "nasser", "title": "صوت العرب", "text": "إذاعة القاهرة تخصّص نشرتها المسائية للأردن: «الحلف استعمار بثوب جديد… ومن يصوّت له خائن لفلسطين.» في نابلس والخليل يتحلّق الناس حول المذياع في المقاهي.",
				"options": [{"id": "ok", "text": "الشارع سيغلي غداً", "note": "الشارع +٨"}]})
		3:
			_raise({"id": "ministers", "who": "pm", "title": "وزيران يستقيلان", "text": "وزيران من الضفة الغربية قدّما استقالتهما من الحكومة احتجاجاً. المجالي غاضب: «من معنا ومن علينا يا ابني؟ أريد الأسماء.»",
				"options": [{"id": "honest", "text": "أعطه الأرقام كما هي", "note": "الصراحة تحمي ظهرك"}, {"id": "inflate", "text": "طمئنه: الأغلبية مضمونة", "note": "إن خسرت ستُحمَّل اللوم كله"}]})
		4:
			_raise({"id": "king", "who": "king", "title": "استدعاء إلى القصر", "text": "الملك الشاب يستقبلك في مكتبه. يقف عند النافذة: «أريد هذا الحلف للأردن، لكني لا أريد أن تحترق نابلس. كم صوتاً عندكم؟ الحقيقة.»",
				"options": [{"id": "truth", "text": "قل الحقيقة، حتى لو كانت سيئة", "note": "الملك يقدّر من لا يكذب عليه"}, {"id": "promise", "text": "عِده بالأغلبية", "note": "كلمة واحدة: إن خابت سقطت معها"}, {"id": "word", "text": "اطلب منه كلمة لنائبين إضافيين", "note": "استدعاءان إضافيان إلى القصر — والشارع سيعرف"}]})
		5:
			_raise({"id": "eve", "who": "glubb", "title": "يوم الجلسة", "text": "غلوب باشا يتصل فجراً: «إن خرجت الأمور عن السيطرة اليوم، الجيش جاهز. لكن تذكّر: كل رصاصة تُطلق في نابلس تكسب لعبد الناصر ألف نصير.» هذا المساء يُنادى على الأسماء واحداً واحداً.",
				"options": [{"id": "ok", "text": "لننهِ ما بدأناه", "note": "يومك الأخير قبل الجلسة"}]})
	if street >= 60 and not used.has("riot_event"):
		used["riot_event"] = true
		_raise({"id": "riot", "who": "", "title": "الشارع ينفجر", "text": "مظاهرات في القدس ونابلس والخليل وعمّان. حُرقت سيارات، وهوجم مكتب حكومي. نواب الضفة الغربية لا يجرؤون على الخروج من بيوتهم.",
			"options": [{"id": "army", "text": "اطلب من الجيش التدخّل", "note": "الشارع −١٥ · ثقة الملك −٥ · نواب الضفة الغربية ينفرون"}, {"id": "wait", "text": "انتظر حتى تهدأ", "note": "الشارع يبقى مشتعلاً"}]})

func _raise(ev: Dictionary) -> void:
	event_queue.append(ev)
	if event_queue.size() == 1:
		event_raised.emit(ev)

func resolve_event(oid: String) -> void:
	if event_queue.is_empty():
		return
	var ev: Dictionary = event_queue.pop_front()
	match ev["id"] + ":" + oid:
		"templer:firm":
			trust += 4
		"templer:ask":
			var prag := deputies.filter(func(x): return x["traits"].has("pragmatic"))
			for d in prag.slice(0, 2):
				move(d, -8)
		"radio:ok":
			street += 8
		"ministers:honest":
			used["honest"] = true
			for d in deputies:
				if d["bank"] == "west":
					move(d, -4)
		"ministers:inflate":
			used["inflated"] = true
			for d in deputies:
				if d["bank"] == "west":
					move(d, -4)
		"king:truth":
			trust += 6
		"king:promise":
			used["promised_king"] = true
			trust += 3
		"king:word":
			palace_words += 2
			street += 4
		"riot:army":
			street -= 15
			trust -= 5
			for d in deputies:
				if d["bank"] == "west":
					move(d, -5)
	street = clampf(street, 0, 100)
	trust = clampf(trust, 0, 100)
	changed.emit()
	if not event_queue.is_empty():
		event_raised.emit(event_queue[0])

func _event_intro() -> Dictionary:
	return {"id": "intro", "who": "pm", "title": "الخميس ١٥ كانون الأول ١٩٥٥", "text": "حكومة سعيد المفتي سقطت أمس، والملك كلّف هزّاع المجالي بتشكيل حكومة تُدخل الأردن حلف بغداد. المجالي يضع أمامك قائمة بأربعين اسماً: «المعاهدة تحتاج موافقة مجلس الأمة. أريد أغلبية الحاضرين يوم الثلاثاء مساءً. ولا يصلح الاجتماع إلا بحضور واحد وعشرين نائباً. عندك ستة أيام.»",
		"options": [{"id": "ok", "text": "سأبدأ الليلة", "note": "هذه رواية «ماذا لو» مبنية على أحداث حقيقية"}]}


# ------------------------------------------------------------------ the vote

func start_vote() -> void:
	phase = "vote"
	var roll := []
	var order := deputies.duplicate()
	_shuffle(order)
	var c := counts()
	if c["present"] < QUORUM:
		_finish({"kind": "no_quorum", "yes": 0, "no": 0, "present": c["present"]})
		return
	for d in order:
		if d["absent"]:
			roll.append({"id": d["id"], "vote": "absent"})
			continue
		var p := _p_yes(d)
		if d["bank"] == "west" and not d["committed"]:
			p -= street / 400.0
		roll.append({"id": d["id"], "vote": "yes" if rng.randf() < p else "no"})
	vote_started.emit(roll)
	var yes := roll.filter(func(r): return r["vote"] == "yes").size()
	var no := roll.filter(func(r): return r["vote"] == "no").size()
	_finish({"kind": "passed" if yes > no else "failed", "yes": yes, "no": no, "present": yes + no, "roll": roll})

func _dismissed() -> void:
	phase = "done"
	_finish({"kind": "dismissed", "yes": 0, "no": 0, "present": 0, "why": "street" if street >= 100 else "trust"})

func _finish(r: Dictionary) -> void:
	r["street"] = street
	r["trust"] = trust
	r["day"] = day
	r["lied"] = used.has("promised_king") or used.has("inflated")
	result = r
	over = true
	phase = "done"
	ended.emit(r)
	changed.emit()
