class_name HUD
extends Control
## All on-screen interface over the map. Rebuilds the side panels only when the visible state changes.

const C := preload("res://scripts/sim/content.gd")

var map: MapView
var top_date: Label
var top_time: Label
var top_money: Label
var top_rep: Label
var top_scandal: UI.BarControl
var top_scandal_lbl: Label
var top_days: Label
var speed_btns: Array = []
var left_box: VBoxContainer
var right_box: VBoxContainer
var rumour_box: VBoxContainer
var toast_box: VBoxContainer
var modal_layer: Control
var modal_stack: Array = []
var _sig := ""
var _last_speed := 2
var _paused_banner: Label


func _ready() -> void:
	theme = UI.theme()
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top()
	_build_columns()
	_build_bottom()
	modal_layer = Control.new()
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_layer)
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Game.toast.connect(_on_toast)
	Game.event_raised.connect(_on_event)
	Game.newspaper.connect(_on_paper)
	Game.arrived.connect(_on_arrived)
	Game.ended.connect(_on_ended)
	refresh(true)


func _process(_d: float) -> void:
	Game.ui_hold = not modal_stack.is_empty()
	_update_top()
	refresh(false)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_SPACE:
			if Game.speed == 0:
				Game.set_speed(_last_speed)
			else:
				_last_speed = Game.speed
				Game.set_speed(0)
		KEY_1: Game.set_speed(1)
		KEY_2: Game.set_speed(2)
		KEY_3: Game.set_speed(3)
		KEY_ESCAPE:
			if not modal_stack.is_empty() and modal_stack[-1].get_meta("closable", false):
				close_modal()
		KEY_HOME:
			map.focus(Game.player_pos())
		KEY_F11:
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			return
	get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ top bar

func _build_top() -> void:
	var bar := UI.panel(false, 14)
	bar.position = Vector2(20, 14)
	bar.size = Vector2(1880, 76)
	bar.custom_minimum_size = Vector2(1880, 76)
	add_child(bar)
	var h := UI.hbox(14)
	bar.add_child(h)
	var crown := CrownIcon.new()
	crown.custom_minimum_size = Vector2(44, 44)
	h.add_child(crown)
	var dt := UI.vbox(0)
	top_date = UI.label("", 22, UI.TEXT, 700)
	top_time = UI.label("", 15, UI.TEXT2)
	dt.add_child(top_date)
	dt.add_child(top_time)
	dt.custom_minimum_size.x = 300
	h.add_child(dt)
	h.add_child(_vline())
	top_money = _stat_chip(h, "المال")
	top_rep = _stat_chip(h, "السمعة")
	var sc := UI.vbox(4)
	sc.custom_minimum_size.x = 170
	var sch := UI.hbox(6)
	sch.add_child(UI.label("الفضيحة", 14, UI.TEXT2))
	sch.add_child(UI.spacer())
	top_scandal_lbl = UI.label("", 15, UI.TEXT, 700)
	sch.add_child(top_scandal_lbl)
	sc.add_child(sch)
	top_scandal = UI.bar(0, UI.RED, 8)
	sc.add_child(top_scandal)
	h.add_child(_wrap_chip(sc))
	top_days = _stat_chip(h, "الاقتراع")
	h.add_child(UI.spacer())
	_paused_banner = UI.label("", 17, UI.RED, 700)
	h.add_child(_paused_banner)
	var sp := UI.hbox(6)
	for i in 4:
		var b := SpeedButton.new()
		b.level = i
		b.custom_minimum_size = Vector2(48, 48)
		b.pressed_speed.connect(func(l): Game.set_speed(l))
		speed_btns.append(b)
		sp.add_child(b)
	# show speed buttons left-to-right: pause, 1, 2, 3
	sp.layout_direction = Control.LAYOUT_DIRECTION_LTR
	h.add_child(sp)


func _vline() -> ColorRect:
	var r := ColorRect.new()
	r.color = UI.LINE
	r.custom_minimum_size = Vector2(1, 44)
	return r


func _wrap_chip(c: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(UI.RAISED, 9, Color(0, 0, 0, 0), 1, 12))
	p.add_child(c)
	return p


func _stat_chip(parent: Control, title: String) -> Label:
	var h := UI.hbox(10)
	h.add_child(UI.label(title, 14, UI.TEXT2))
	var v := UI.label("", 19, UI.TEXT, 700)
	h.add_child(v)
	parent.add_child(_wrap_chip(h))
	return v


func _update_top() -> void:
	top_date.text = Game.date_text()
	var where := ""
	if not Game.player["travel"].is_empty():
		where = "في الطريق إلى " + Game.town_name(Game.player["travel"]["to"])
	else:
		where = Game.town_name(Game.player["town"])
	top_time.text = "الساعة %s · %s" % [Game.clock_text(), where]
	top_money.text = "%s د." % Game.ar(int(Game.player["money"]))
	top_rep.text = Game.ar(int(Game.player["rep"]))
	top_scandal.value = Game.player["scandal"] / 100.0
	top_scandal.queue_redraw()
	top_scandal_lbl.text = Game.ar(int(Game.player["scandal"]))
	var d := Game.days_to_election()
	top_days.text = "بعد %s يوماً" % Game.ar(d) if d > 0 else "اليوم"
	for b in speed_btns:
		b.active = Game.speed
		b.queue_redraw()
	if Game.is_blocked() and not Game.over:
		_paused_banner.text = "متوقّف — بانتظار قرارك"
	elif Game.speed == 0:
		_paused_banner.text = "الوقت متوقّف — اضغط مسافة"
	else:
		_paused_banner.text = ""


# ------------------------------------------------------------------ side columns

func _build_columns() -> void:
	var lscroll := ScrollContainer.new()
	lscroll.position = Vector2(20, 104)
	lscroll.size = Vector2(450, 860)
	lscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(lscroll)
	left_box = UI.vbox(12)
	left_box.custom_minimum_size.x = 440
	lscroll.add_child(left_box)
	right_box = UI.vbox(12)
	right_box.position = Vector2(1920 - 20 - 420, 104)
	right_box.custom_minimum_size = Vector2(420, 0)
	right_box.size = Vector2(420, 0)
	add_child(right_box)


func _signature() -> String:
	var p: Dictionary = Game.player
	var parts := [Game.hour(), Game.day(), p["town"], p["travel"].is_empty(), int(p["money"]), int(p["rep"]), int(p["scandal"]), p["gifts"],
		Game.water["solved_by"], int(Game.water["severity"]) / 5, Game.secrets.size(), Game.schemes.size(), Game.rumours.size(), Game.flags.size(),
		Game.rival["town"], Game.rival["exposed"], p["today"].size(), p["met"].size(), Game.over]
	for pid in Game.people:
		var q: Dictionary = Game.people[pid]
		parts.append("%s%d%d%s" % [pid, int(q["opinion"]) / 3, int(q["rival_op"]) / 5, q["pledged"]])
		parts.append(q["known"].size())
	return str(parts)


func refresh(force: bool) -> void:
	var s := _signature()
	if s == _sig and not force:
		return
	_sig = s
	_build_left()
	_build_right()
	_build_rumours()


func _build_left() -> void:
	UI.clear(left_box)
	var t: Dictionary = Game.player["travel"]
	if not t.is_empty():
		var card := UI.panel(true)
		var v := UI.vbox(10)
		card.add_child(v)
		v.add_child(UI.label("في الطريق إلى %s" % Game.town_name(t["to"]), 24, UI.TEXT, 700))
		v.add_child(UI.label("بالحافلة من %s · %s كم" % [Game.town_name(t["from"]), Game.ar(int(t["km"]))], 15, UI.TEXT2))
		v.add_child(UI.bar(Game.travel_progress() * 100.0, UI.GOLD, 10))
		var eta: int = t["arr"]
		v.add_child(UI.label("الوصول نحو الساعة %s" % Game.clock_text(eta), 15, UI.TEXT2))
		left_box.add_child(card)
		return
	var town: String = Game.player["town"]
	var head := UI.panel(true)
	var hv := UI.vbox(4)
	head.add_child(hv)
	var hh := UI.hbox(8)
	hh.add_child(UI.label(Game.town_name(town), 30, UI.TEXT, 700))
	hh.add_child(UI.spacer())
	hh.add_child(UI.chip("أنت هنا", UI.GOLD, UI.GOLD_SOFT))
	hv.add_child(hh)
	hv.add_child(UI.label("انقر على مدينة في الخريطة للسفر إليها", 14, UI.FAINT))
	left_box.add_child(head)
	for pl in Game.places(town):
		left_box.add_child(_place_card(town, pl))


func _place_card(town: String, pl: Dictionary) -> Control:
	var open := Game.place_open(pl)
	var card := UI.panel(false, 14)
	var v := UI.vbox(8)
	card.add_child(v)
	var h := UI.hbox(8)
	h.add_child(UI.label(pl["name"], 19, UI.TEXT if open else UI.TEXT2, 700))
	h.add_child(UI.spacer())
	var hrs := "%s–%s" % [Game.ar(pl["open"][0]), Game.ar(pl["open"][1])] if pl["open"][1] - pl["open"][0] < 24 else "طوال اليوم"
	h.add_child(UI.label(("مفتوح · " if open else "مغلق · ") + hrs, 13, UI.GREEN if open else UI.FAINT))
	v.add_child(h)
	if not open:
		card.modulate = Color(1, 1, 1, 0.6)
		return card
	var here := Game.who_at(town, pl["id"])
	for pid in here:
		v.add_child(_person_row(pid))
	for aid in pl["actions"]:
		var a: Dictionary = C.ACTIONS[aid]
		var st := Game.action_state(aid)
		var b := UI.button(a["name"], "", 15)
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.tooltip_text = a["desc"] + ("" if st["ok"] else "\n" + st["why"])
		var note := " · %s ساعة" % Game.ar(a["hours"]) if a["hours"] > 0 else ""
		b.text = a["name"] + note
		b.disabled = not st["ok"]
		b.pressed.connect(func(): Game.do_action(aid))
		v.add_child(b)
	return card


func _person_row(pid: String) -> Control:
	var h := UI.hbox(10)
	var look: Dictionary = C.RIVAL["look"] if pid == "issa" else Game.people[pid]["look"]
	var por := Portrait.make(look, 40)
	if pid == "issa":
		por.border = UI.RED
	h.add_child(por)
	var v := UI.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label(Game.person_name(pid), 16, UI.TEXT, 700))
	if pid == "issa":
		v.add_child(UI.label("منافسك — يراقبك", 13, UI.RED))
	else:
		var p: Dictionary = Game.people[pid]
		v.add_child(UI.label("%s · رأيه %s" % [p["role"], Game.ar(int(p["opinion"]))], 13, UI.TEXT2))
	h.add_child(v)
	if pid != "issa":
		var why := Game.can_meet(pid)
		var b := UI.button("اجلس معه" if why == "" else why, "gold" if why == "" else "", 14)
		b.disabled = why != ""
		b.pressed.connect(func(): open_meet(pid))
		h.add_child(b)
	return h


func _build_right() -> void:
	UI.clear(right_box)
	# character card
	var cc := UI.panel(true)
	var ch := UI.hbox(12)
	cc.add_child(ch)
	var por := Portrait.make({"hw": -1, "skin": 1, "beard": 1}, 64, 0.3)
	por.you = true
	ch.add_child(por)
	var cv := UI.vbox(2)
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.add_child(UI.label("سليم ناصر", 24, UI.TEXT, 700))
	cv.add_child(UI.label("كاتب في بلدية السلط · ٢٤ عاماً", 14, UI.GOLD))
	var st: Dictionary = Game.player["stats"]
	var sh := UI.hbox(6)
	for k in [["الحضور", "charisma"], ["الدهاء", "intrigue"], ["الدبلوماسية", "diplomacy"], ["الإدارة", "administration"]]:
		sh.add_child(UI.chip("%s %s" % [k[0], Game.ar(st[k[1]])], UI.TEXT2))
	cv.add_child(sh)
	ch.add_child(cv)
	right_box.add_child(cc)
	# career card
	var card := UI.panel(false)
	var v := UI.vbox(10)
	card.add_child(v)
	var th := UI.hbox()
	th.add_child(UI.label("الطموح: مقعد في المجلس البلدي", 19, UI.TEXT, 700))
	v.add_child(th)
	v.add_child(UI.label("الاقتراع السبت ١٣ حزيران · بعد %s يوماً" % Game.ar(max(0, Game.days_to_election())), 14, UI.TEXT2))
	for g in Game.goals():
		var gh := UI.hbox(10)
		var ic := GoalIcon.new()
		ic.state = 1 if g["done"] else (2 if g.get("fail", false) else 0)
		ic.custom_minimum_size = Vector2(18, 18)
		gh.add_child(ic)
		var gl := UI.label(g["text"], 16, UI.TEXT if not g["done"] else UI.TEXT2)
		gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gh.add_child(gl)
		gh.add_child(UI.label(g["hint"], 13, UI.FAINT))
		v.add_child(gh)
	v.add_child(UI.sep_line())
	var f := Game.forecast()
	var fh := UI.hbox()
	fh.add_child(UI.label("حديث المقاهي عن الانتخابات", 15, UI.TEXT2))
	v.add_child(fh)
	v.add_child(_vote_row("أنت", f["you"], UI.GOLD))
	v.add_child(_vote_row("عيسى", f["him"], UI.RED))
	v.add_child(UI.sep_line())
	v.add_child(UI.label("الوجهاء", 15, UI.TEXT2))
	for pid in Game.notables():
		v.add_child(_backer_row(pid))
	right_box.add_child(card)
	# buttons
	var bh := UI.hbox(8)
	var cab := UI.button("خزانة الملفات (%s)" % Game.ar(Game.secrets.size()), "gold", 15)
	cab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.pressed.connect(open_cabinet)
	bh.add_child(cab)
	var sch := UI.button("الدسائس (%s)" % Game.ar(Game.schemes.size()), "gold", 15)
	sch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sch.pressed.connect(open_schemes)
	bh.add_child(sch)
	var his := UI.button("السجلّ", "", 15)
	his.pressed.connect(open_history)
	bh.add_child(his)
	right_box.add_child(bh)


func _vote_row(name: String, pct: float, c: Color) -> Control:
	var h := UI.hbox(10)
	var l := UI.label(name, 15, UI.TEXT, 600)
	l.custom_minimum_size.x = 50
	h.add_child(l)
	h.add_child(UI.bar(pct, c, 10))
	var n := UI.label("%s٪" % Game.ar(int(round(pct))), 15, c, 700)
	n.custom_minimum_size.x = 44
	h.add_child(n)
	return h


func _backer_row(pid: String) -> Control:
	var p: Dictionary = Game.people[pid]
	var h := UI.hbox(8)
	var l := UI.label(p["name"], 15, UI.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var b := Game.backing(pid)
	var txts := {"player": "يؤيّدك", "rival": "يؤيّد عيسى", "lean_player": "يميل إليك", "lean_rival": "يميل لعيسى", "": "متردّد"}
	var cols := {"player": UI.GREEN, "rival": UI.RED, "lean_player": Color("b9d9a0"), "lean_rival": Color("e9a493"), "": UI.TEXT2}
	var txt: String = txts[b]
	var col: Color = cols[b]
	h.add_child(UI.label(txt, 14, col, 600))
	h.tooltip_text = Game.pledge_terms(pid)
	h.mouse_filter = Control.MOUSE_FILTER_STOP
	return h


# ------------------------------------------------------------------ rumours and toasts

func _build_bottom() -> void:
	rumour_box = UI.vbox(6)
	rumour_box.position = Vector2(500, 960)
	rumour_box.custom_minimum_size = Vector2(920, 0)
	rumour_box.size = Vector2(920, 0)
	add_child(rumour_box)
	toast_box = UI.vbox(8)
	toast_box.position = Vector2(560, 104)
	toast_box.custom_minimum_size = Vector2(800, 0)
	toast_box.size = Vector2(800, 0)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)


func _build_rumours() -> void:
	UI.clear(rumour_box)
	if Game.rumours.is_empty():
		return
	var p := UI.panel(false, 12)
	var v := UI.vbox(4)
	p.add_child(v)
	var r: Dictionary = Game.rumours[0]
	var h := UI.hbox(8)
	h.add_child(UI.chip("همسات", UI.GOLD, UI.GOLD_SOFT))
	var l := UI.label(r["text"], 16, UI.TEXT, 400, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(UI.label(Game.date_text(r["min"], false), 13, UI.FAINT))
	v.add_child(h)
	rumour_box.add_child(p)
	rumour_box.position.y = 1080 - 24 - p.get_combined_minimum_size().y


func _on_toast(text: String) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color(0.1, 0.12, 0.15, 0.96), 10, UI.GOLD_LINE, 1, 14))
	var l := UI.label(text, 17, UI.TEXT, 600, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(p)
	while toast_box.get_child_count() > 3:
		toast_box.get_child(0).queue_free()
		toast_box.remove_child(toast_box.get_child(0))
	var tw := create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func _on_arrived(town: String) -> void:
	map.focus(Game.town_pos(town), max(map.zoom(), 3.0))
	refresh(true)


# ------------------------------------------------------------------ modals

func open_modal(content: Control, closable := true, width := 760) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_meta("closable", closable)
	modal_layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.05, 0.62)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.custom_minimum_size.x = width
	center.add_child(content)
	modal_stack.append(root)
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.18)
	return root


func close_modal() -> void:
	if modal_stack.is_empty():
		return
	var root: Control = modal_stack.pop_back()
	root.queue_free()
	refresh(true)


func _modal_header(v: VBoxContainer, title: String, subtitle := "", closable := true) -> void:
	var h := UI.hbox(10)
	h.add_child(UI.label(title, 26, UI.TEXT, 700))
	h.add_child(UI.spacer())
	if closable:
		var x := UI.button("✕", "", 16)
		x.custom_minimum_size = Vector2(40, 40)
		x.pressed.connect(close_modal)
		h.add_child(x)
	v.add_child(h)
	if subtitle != "":
		v.add_child(UI.label(subtitle, 15, UI.TEXT2, 400, true))


# --- events

func _on_event(ev: Dictionary) -> void:
	var card := UI.panel(true, 22)
	var v := UI.vbox(14)
	card.add_child(v)
	var art := EventArt.new()
	art.kind = ev.get("art", "office")
	art.custom_minimum_size = Vector2(0, 150)
	v.add_child(art)
	v.add_child(UI.label(ev["title"], 28, UI.TEXT, 700))
	v.add_child(UI.label(Game.date_text() + " · الساعة " + Game.clock_text(), 14, UI.FAINT))
	v.add_child(UI.label(ev["text"], 18, UI.TEXT, 400, true))
	v.add_child(UI.sep_line())
	for o in ev["options"]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = not o.get("enabled", true)
		b.custom_minimum_size = Vector2(0, 58)
		var bv := UI.vbox(0)
		bv.set_anchors_preset(Control.PRESET_FULL_RECT)
		bv.offset_left = 16
		bv.offset_right = -16
		bv.offset_top = 6
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(UI.label(o["text"], 18, UI.TEXT if not b.disabled else UI.FAINT, 600))
		if o.get("note", "") != "":
			bv.add_child(UI.label(o["note"], 14, UI.TEXT2))
		b.add_child(bv)
		var oid: String = o["id"]
		b.pressed.connect(func():
			close_modal()
			Game.resolve_event(oid))
		v.add_child(b)
	open_modal(card, false, 720)


# --- newspaper

func _on_paper(issue: Dictionary) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.box(Color("efe6d2"), 6, Color("b9a57a"), 2, 30))
	var v := UI.vbox(10)
	card.add_child(v)
	var ink := Color("2a2218")
	var mast := UI.label("الصباح", 54, ink, 700)
	mast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(mast)
	var sub := UI.label("جريدة يومية سياسية · عمّان · العدد %s · %s" % [Game.ar(400 + issue["no"]), issue["date"]], 14, Color("5a4a34"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var rule := ColorRect.new()
	rule.color = ink
	rule.custom_minimum_size = Vector2(0, 3)
	v.add_child(rule)
	var first := true
	for line in issue["local"]:
		var l := UI.label(line, 30 if first else 21, ink, 700, true)
		v.add_child(l)
		first = false
	var rule2 := ColorRect.new()
	rule2.color = Color(0.16, 0.13, 0.09, 0.4)
	rule2.custom_minimum_size = Vector2(0, 1)
	v.add_child(rule2)
	v.add_child(UI.label("أخبار المملكة", 15, Color("7a2a1c"), 700))
	for line in issue["national"]:
		v.add_child(UI.label("— " + line, 18, ink, 600, true))
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.box(Color(0.16, 0.13, 0.09, 0.08), 4, Color(0.16, 0.13, 0.09, 0.3), 1, 14))
	var bv := UI.vbox(4)
	box.add_child(bv)
	var f: Dictionary = issue["forecast"]
	bv.add_child(UI.label("مقعد السلط: ماذا تقول المقاهي؟", 16, ink, 700))
	bv.add_child(UI.label("سليم ناصر %s٪ — عيسى الحدّاد %s٪ · الاقتراع بعد %s يوماً" % [Game.ar(int(round(f["you"]))), Game.ar(int(round(f["him"]))), Game.ar(max(0, issue["days_left"]))], 16, ink))
	v.add_child(box)
	var b := UI.button("اطوِ الجريدة", "primary", 17)
	b.pressed.connect(func():
		close_modal()
		Game.close_paper())
	v.add_child(b)
	open_modal(card, false, 760)


# --- meetings

func open_meet(pid: String) -> void:
	var p: Dictionary = Game.people[pid]
	var card := UI.panel(true, 22)
	var v := UI.vbox(14)
	card.add_child(v)
	var h := UI.hbox(16)
	h.add_child(Portrait.make(p["look"], 110, clampf(p["opinion"] / 60.0, -1, 1)))
	var iv := UI.vbox(6)
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	iv.add_child(UI.label(p["name"], 28, UI.TEXT, 700))
	iv.add_child(UI.label(p["role"], 16, UI.GOLD))
	iv.add_child(UI.label("رأيه فيك %s · رأيه في عيسى %s" % [Game.ar(int(p["opinion"])), Game.ar(int(p["rival_op"]))], 15, UI.TEXT2))
	iv.add_child(_traits_row(p))
	if p["weight"] > 0:
		iv.add_child(UI.label(Game.pledge_terms(pid), 14, UI.FAINT))
	h.add_child(iv)
	v.add_child(h)
	v.add_child(UI.sep_line())
	v.add_child(UI.label("ماذا تريد من هذا اللقاء؟", 18, UI.TEXT, 600))
	for ask in p["asks"]:
		var a: Dictionary = C.ASKS[ask]
		var st := Game.ask_state(pid, ask)
		var b := UI.button("", "gold" if ask != "chat" and st["ok"] else "", 16)
		b.custom_minimum_size = Vector2(0, 54)
		b.disabled = not st["ok"]
		var bv := UI.vbox(0)
		bv.set_anchors_preset(Control.PRESET_FULL_RECT)
		bv.offset_left = 14
		bv.offset_right = -14
		bv.offset_top = 5
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(UI.label(a["name"], 17, UI.TEXT if st["ok"] else UI.FAINT, 700))
		bv.add_child(UI.label(a["desc"] if st["ok"] else st["why"], 13, UI.TEXT2))
		b.add_child(bv)
		b.pressed.connect(func():
			close_modal()
			Game.start_duel(pid, ask)
			_open_duel())
		v.add_child(b)
	open_modal(card, true, 680)


func _traits_row(p: Dictionary) -> Control:
	var h := UI.hbox(6)
	for tr in p["traits"]:
		if p["known"].has(tr):
			var c := UI.chip(C.TRAITS[tr]["name"], UI.BLUE, Color(0.56, 0.71, 0.79, 0.14))
			c.tooltip_text = C.TRAITS[tr]["hint"]
			c.mouse_filter = Control.MOUSE_FILTER_STOP
			h.add_child(c)
		else:
			h.add_child(UI.chip("؟ طبع مجهول", UI.FAINT))
	return h


func _open_duel() -> void:
	if Game.duel.is_empty():
		return
	var pid: String = Game.duel["pid"]
	var p: Dictionary = Game.people[pid]
	var card := UI.panel(true, 22)
	var v := UI.vbox(14)
	card.add_child(v)
	var ask: Dictionary = C.ASKS[Game.duel["ask"]]
	var top := UI.hbox(18)
	var por := Portrait.make(p["look"], 130, 0.0)
	top.add_child(por)
	var iv := UI.vbox(8)
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	iv.add_child(UI.label("جلسة مع %s" % p["name"], 26, UI.TEXT, 700))
	iv.add_child(UI.label("طلبك: " + ask["name"] + ("" if ask["target"] == 0 else " · تحتاج مزاجه %s" % Game.ar(int(Game.duel["target"]))), 16, UI.GOLD))
	var mood_bar := UI.bar(Game.duel["mood"], UI.GREEN, 14)
	if ask["target"] > 0:
		mood_bar.marker = Game.duel["target"] / 100.0
	iv.add_child(UI.label("مزاجه", 14, UI.TEXT2))
	iv.add_child(mood_bar)
	var traits_slot := VBoxContainer.new()
	traits_slot.add_child(_traits_row(p))
	iv.add_child(traits_slot)
	var round_lbl := UI.label("", 15, UI.TEXT2)
	iv.add_child(round_lbl)
	top.add_child(iv)
	v.add_child(top)
	var reaction := UI.label("يجلس %s قبالتك وينتظر أن تبدأ." % p["name"], 18, UI.TEXT, 400, true)
	var rp := PanelContainer.new()
	rp.add_theme_stylebox_override("panel", UI.box(UI.RAISED, 10, Color(0, 0, 0, 0), 1, 14))
	rp.add_child(reaction)
	v.add_child(rp)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var foot := UI.hbox(10)
	v.add_child(foot)
	var refresh_duel := func(): pass
	refresh_duel = func():
		UI.clear(grid)
		UI.clear(foot)
		mood_bar.value = Game.duel["mood"] / 100.0
		mood_bar.queue_redraw()
		por.set_mood(clampf((Game.duel["mood"] - 45.0) / 35.0, -1.0, 1.0))
		UI.clear(traits_slot)
		traits_slot.add_child(_traits_row(p))
		round_lbl.text = "الجولة %s من %s" % [Game.ar(min(Game.duel["round"] + 1, Game.duel["rounds"])), Game.ar(Game.duel["rounds"])]
		var done: bool = Game.duel["round"] >= Game.duel["rounds"]
		if not done:
			for o in Game.duel_options():
				var b := Button.new()
				b.focus_mode = Control.FOCUS_NONE
				b.custom_minimum_size = Vector2(330, 64)
				b.disabled = not o["ok"]
				var bv := UI.vbox(0)
				bv.set_anchors_preset(Control.PRESET_FULL_RECT)
				bv.offset_left = 12
				bv.offset_right = -12
				bv.offset_top = 6
				bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var title: String = o["name"] + ("" if o["used"] == 0 else " (أضعف الآن)")
				bv.add_child(UI.label(title, 17, UI.TEXT if o["ok"] else UI.FAINT, 700))
				bv.add_child(UI.label(o["desc"] if o["ok"] else o["why"], 13, UI.TEXT2))
				b.add_child(bv)
				var hint := _approach_hint(p, o["id"])
				if hint != "":
					b.tooltip_text = hint
				var aid: String = o["id"]
				b.pressed.connect(func():
					var e := Game.duel_play(aid)
					var extra := ""
					if e["reveal"] != "":
						extra = "\nعرفت عنه: %s — %s." % [C.TRAITS[e["reveal"]]["name"], C.TRAITS[e["reveal"]]["hint"]]
					var sign := "+" if e["delta"] >= 0 else "−"
					reaction.text = "%s  (%s%s)%s" % [e["text"], sign, Game.ar(int(abs(round(e["delta"])))), extra]
					refresh_duel.call())
				grid.add_child(b)
		var ok_now := Game.duel_success_now()
		var status := UI.label("", 16, UI.GREEN if ok_now else UI.TEXT2, 600)
		if ask["target"] > 0:
			status.text = "سيوافق إن انتهى اللقاء الآن" if ok_now else "لم يقتنع بعد"
		status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(status)
		if done or Game.duel["round"] >= 1:
			var fin := UI.button("أنهِ اللقاء واطلب" if ask["target"] > 0 else "أنهِ اللقاء", "primary" if done else "", 16)
			fin.pressed.connect(func():
				var r := Game.duel_finish()
				close_modal()
				_duel_result(p, r))
			foot.add_child(fin)
	refresh_duel.call()
	open_modal(card, false, 760)


func _approach_hint(p: Dictionary, aid: String) -> String:
	var a: Dictionary = C.APPROACHES[aid]
	var bits := []
	for tr in p["known"]:
		var m: int = a["mods"].get(tr, 0)
		if m >= 8:
			bits.append("لأنه %s: سيعجبه هذا" % C.TRAITS[tr]["name"])
		elif m <= -5:
			bits.append("لأنه %s: قد يزعجه هذا" % C.TRAITS[tr]["name"])
	return "\n".join(bits)


func _duel_result(p: Dictionary, r: Dictionary) -> void:
	var card := UI.panel(true, 22)
	var v := UI.vbox(14)
	card.add_child(v)
	var h := UI.hbox(16)
	h.add_child(Portrait.make(p["look"], 90, 0.6 if r["ok"] else -0.4))
	var iv := UI.vbox(6)
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	iv.add_child(UI.label("نجح طلبك" if r["ok"] and r["ask"] != "chat" else ("انتهى اللقاء" if r["ask"] == "chat" else "لم ينجح طلبك"), 26, UI.GREEN if r["ok"] else UI.TEXT, 700))
	iv.add_child(UI.label(r["text"], 18, UI.TEXT, 400, true))
	var d: float = r["dop"]
	iv.add_child(UI.label("رأيه فيك %s%s" % ["+" if d >= 0 else "−", Game.ar(int(abs(d)))], 16, UI.GREEN if d >= 0 else UI.RED, 600))
	h.add_child(iv)
	v.add_child(h)
	var b := UI.button("متابعة", "primary", 17)
	b.pressed.connect(close_modal)
	v.add_child(b)
	open_modal(card, true, 640)


# --- file cabinet, schemes, history

func open_cabinet() -> void:
	var card := UI.panel(true, 22)
	var v := UI.vbox(12)
	card.add_child(v)
	_modal_header(v, "خزانة الملفات", "ما تعرفه عن الناس، وما لك وما عليك.")
	v.add_child(UI.label("الأسرار", 19, UI.GOLD, 700))
	if Game.secrets.is_empty():
		v.add_child(UI.label("لا شيء بعد. التقصّي في «الدسائس» يملأ هذا الدرج.", 15, UI.TEXT2, 400, true))
	for s in Game.secrets:
		var p := UI.panel(false, 12)
		var pv := UI.vbox(2)
		p.add_child(pv)
		pv.add_child(UI.label(Game.person_name(s["on"]), 17, UI.TEXT, 700))
		pv.add_child(UI.label(s["text"], 15, UI.TEXT2, 400, true))
		v.add_child(p)
	v.add_child(UI.sep_line())
	v.add_child(UI.label("الأفضال", 19, UI.GOLD, 700))
	for f in Game.favours:
		var h := UI.hbox(8)
		h.add_child(UI.chip("لك عنده" if f["dir"] == "me" else "عليك له", UI.GREEN if f["dir"] == "me" else UI.RED))
		var l := UI.label("%s: %s" % [Game.person_name(f["who"]), f["text"]], 15, UI.TEXT, 400, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		v.add_child(h)
	v.add_child(UI.sep_line())
	v.add_child(UI.label("طباع الناس", 19, UI.GOLD, 700))
	for pid in Game.people:
		var p: Dictionary = Game.people[pid]
		var h := UI.hbox(8)
		var l := UI.label(p["name"], 15, UI.TEXT)
		l.custom_minimum_size.x = 150
		h.add_child(l)
		h.add_child(_traits_row(p))
		v.add_child(h)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(700, 760)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.remove_child(v)
	sc.add_child(v)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(sc)
	open_modal(card, true, 740)


func open_schemes() -> void:
	var card := UI.panel(true, 22)
	var v := UI.vbox(12)
	card.add_child(v)
	_modal_header(v, "الدسائس", "خطط تجري في الخفاء أياماً. كل دسيسة لها فرصة نجاح، وخطر أن ينكشف أمرك.")
	if not Game.schemes.is_empty():
		v.add_child(UI.label("جارية الآن", 18, UI.GOLD, 700))
		for s in Game.schemes:
			var p := UI.panel(false, 12)
			var pv := UI.vbox(6)
			p.add_child(pv)
			pv.add_child(UI.label("%s — %s" % [C.SCHEMES[s["type"]]["name"], Game.person_name(s["target"])], 17, UI.TEXT, 700))
			var k := clampf(float(Game.minutes - s["start"]) / float(s["end"] - s["start"]), 0, 1)
			pv.add_child(UI.bar(k * 100, UI.GOLD, 8))
			pv.add_child(UI.label("النجاح %s٪ · الانكشاف %s٪ · تنتهي %s" % [Game.ar(int(s["odds"])), Game.ar(int(s["disc"])), Game.date_text(s["end"], false)], 14, UI.TEXT2))
			v.add_child(p)
		v.add_child(UI.sep_line())
	v.add_child(UI.label("دسيسة جديدة", 18, UI.GOLD, 700))
	var list := UI.vbox(10)
	v.add_child(list)
	for type in C.SCHEMES:
		var d: Dictionary = C.SCHEMES[type]
		var p := UI.panel(false, 12)
		var pv := UI.vbox(6)
		p.add_child(pv)
		var hh := UI.hbox()
		hh.add_child(UI.label(d["name"], 18, UI.TEXT, 700))
		hh.add_child(UI.spacer())
		hh.add_child(UI.label("%s أيام" % Game.ar(d["days"]), 14, UI.TEXT2))
		pv.add_child(hh)
		pv.add_child(UI.label(d["desc"], 14, UI.TEXT2))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		var targets := Game.scheme_targets(type)
		if targets.is_empty():
			pv.add_child(UI.label("لا هدف متاح الآن", 14, UI.FAINT))
		for t in targets:
			var o := Game.scheme_odds(type, t)
			var st := Game.scheme_state(type, t)
			var b := UI.button("%s · %s٪" % [Game.person_name(t), Game.ar(int(o["odds"]))], "gold" if st["ok"] else "", 14)
			b.disabled = not st["ok"]
			b.tooltip_text = ("فرصة النجاح %s٪ · خطر الانكشاف %s٪" % [Game.ar(int(o["odds"])), Game.ar(int(o["disc"]))]) + ("" if st["ok"] else "\n" + st["why"])
			var tt: String = t
			b.pressed.connect(func():
				Game.start_scheme(type, tt)
				close_modal())
			flow.add_child(b)
		pv.add_child(flow)
		list.add_child(p)
	open_modal(card, true, 760)


func open_history() -> void:
	var card := UI.panel(true, 22)
	var v := UI.vbox(10)
	card.add_child(v)
	_modal_header(v, "سجلّ الأيام")
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 600)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var lv := UI.vbox(8)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(lv)
	for e in Game.history:
		var h := UI.hbox(12)
		var d := UI.label(Game.date_text(e["min"], false), 14, UI.GOLD)
		d.custom_minimum_size.x = 110
		h.add_child(d)
		var l := UI.label(e["text"], 16, UI.TEXT, 400, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		lv.add_child(h)
	v.add_child(sc)
	open_modal(card, true, 700)


# --- travel

func ask_travel(town: String) -> void:
	if not modal_stack.is_empty():
		return
	var card := UI.panel(true, 22)
	var v := UI.vbox(12)
	card.add_child(v)
	var st := Game.travel_state(town)
	_modal_header(v, Game.town_name(town))
	if st["ok"]:
		var hours := Game.trip_hours(town)
		v.add_child(UI.label("بالحافلة: نحو %s ساعة" % Game.ar(snappedf(hours, 0.5)).replace(".", "٫"), 18, UI.TEXT))
		var arr := Game.minutes + int(hours * 60)
		v.add_child(UI.label("الوصول %s · الساعة %s" % [Game.date_text(arr, false), Game.clock_text(arr)], 15, UI.TEXT2))
		var names := []
		for pl in Game.places(town):
			names.append(pl["name"])
		v.add_child(UI.label("هناك: " + "، ".join(names), 15, UI.TEXT2, 400, true))
		if town == "amman":
			v.add_child(UI.label("وزارة الداخلية تستقبل الناس من التاسعة حتى الثانية ظهراً.", 14, UI.FAINT, 400, true))
		var h := UI.hbox(10)
		var go := UI.button("سافر الآن", "primary", 17)
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		go.pressed.connect(func():
			close_modal()
			Game.start_travel(town)
			if Game.speed == 0:
				Game.set_speed(2))
		h.add_child(go)
		var no := UI.button("ابقَ هنا", "", 17)
		no.pressed.connect(close_modal)
		h.add_child(no)
		v.add_child(h)
	else:
		v.add_child(UI.label(st["why"], 17, UI.TEXT2))
	open_modal(card, true, 520)


# --- intro and ending

func show_intro() -> void:
	var card := UI.panel(true, 26)
	var v := UI.vbox(14)
	card.add_child(v)
	v.add_child(UI.label("السلط — السبت ٢ أيار ١٩٥٣", 30, UI.TEXT, 700))
	v.add_child(UI.label("اليوم يُتوَّج الحسين بن طلال ملكاً في عمّان. وفي السلط، مات عضو في المجلس البلدي الأسبوع الماضي، وسيُنتخب بديله يوم السبت ١٣ حزيران.", 18, UI.TEXT, 400, true))
	v.add_child(UI.label("أنت سليم ناصر، كاتب في البلدية في الرابعة والعشرين. تريد ذلك المقعد. وكذلك عيسى الحدّاد، الكاتب الذي يجلس قبالتك ويبتسم أكثر مما ينبغي. والصيف يقترب، وعيون السلط تجفّ.", 18, UI.TEXT, 400, true))
	v.add_child(UI.sep_line())
	v.add_child(UI.label("كيف تلعب", 18, UI.GOLD, 700))
	for line in ["الوقت يجري وحده: مسافة للإيقاف، و١ ٢ ٣ للسرعة.", "الأماكن تفتح وتغلق، والناس يتنقّلون بين بيوتهم وأعمالهم. انظر من في المكان واجلس معه.",
		"انقر على مدينة في الخريطة لتسافر. عجلة الفأرة للتقريب، والسحب لتحريك الخريطة. F11 لملء الشاشة.", "في كل لقاء اقرأ طباع الرجل واختر ما يناسبه. الدسائس أسرع… وأخطر."]:
		v.add_child(UI.label("• " + line, 16, UI.TEXT2, 400, true))
	var b := UI.button("ابدأ", "primary", 20)
	b.custom_minimum_size.y = 52
	b.pressed.connect(func():
		close_modal()
		Game.set_speed(1)
		Game.say("ابدأ من دار البلدية: الحاج زياد في مكتبه حتى الثانية ظهراً. وأبوك في البيت إن احترت."))
	v.add_child(b)
	open_modal(card, false, 780)


func _on_ended(r: Dictionary) -> void:
	var card := UI.panel(true, 26)
	var v := UI.vbox(14)
	card.add_child(v)
	var won: bool = r["won"]
	v.add_child(UI.label("فزت بمقعد السلط!" if won else "خسرت المقعد", 36, UI.GREEN if won else UI.RED, 700))
	v.add_child(UI.label("فُرزت الأصوات في دار البلدية مساء ١٣ حزيران ١٩٥٣.", 16, UI.TEXT2))
	v.add_child(_vote_row("أنت", r["you_pct"], UI.GOLD))
	v.add_child(_vote_row("عيسى", r["him_pct"], UI.RED))
	v.add_child(UI.label("%s صوتاً مقابل %s" % [Game.ar(r["you_votes"]), Game.ar(r["him_votes"])], 15, UI.TEXT2))
	v.add_child(UI.sep_line())
	var lines := []
	if r["water"] == "player":
		lines.append("أنقذت السلط من العطش، والناس لم تنسَ.")
	elif r["water"] == "rival":
		lines.append("عيسى هو من جاء بتمويل الخزّان، وحصد الشكر.")
	else:
		lines.append("بقيت أزمة المياه بلا حل، والكل في البلدية دفع الثمن.")
	if not r["pledges"].is_empty():
		lines.append("وقف معك: " + "، ".join(r["pledges"]) + ".")
	if not r["rival_pledges"].is_empty():
		lines.append("ووقف مع عيسى: " + "، ".join(r["rival_pledges"]) + ".")
	if r["rival_exposed"]:
		lines.append("فضيحة إيصالات عيسى لاحقته حتى صندوق الاقتراع.")
	if r["scandal"] >= 40:
		lines.append("لكنّ الهمسات عنك لم تهدأ — وسترافقك طويلاً.")
	for l in lines:
		v.add_child(UI.label("• " + l, 17, UI.TEXT, 400, true))
	v.add_child(UI.sep_line())
	var epi := "عضو المجلس البلدي سليم ناصر… الخطوة الأولى. في اللعبة الكاملة: رئاسة البلدية، ثم المتصرفية، ثم البرلمان والوزارة." if won else "الخسارة ليست النهاية. في اللعبة الكاملة: من يسقط يستطيع أن ينهض — بعد أربع سنوات، أو عبر باب آخر."
	v.add_child(UI.label(epi, 16, UI.TEXT2, 400, true))
	v.add_child(UI.label("هذه نهاية الشريحة التجريبية. شكراً لأنك لعبت.", 15, UI.GOLD, 600))
	var h := UI.hbox(10)
	var again := UI.button("العب مجدداً", "primary", 18)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func():
		close_modal()
		Game.new_game(randi())
		map.focus(Game.town_pos("salt"), 3.2)
		refresh(true)
		show_intro())
	h.add_child(again)
	var q := UI.button("خروج", "", 18)
	q.pressed.connect(func(): get_tree().quit())
	h.add_child(q)
	v.add_child(h)
	open_modal(card, false, 760)


# ------------------------------------------------------------------ small drawn widgets

class CrownIcon extends Control:
	func _draw() -> void:
		var s := size.x / 40.0
		var pts := PackedVector2Array([Vector2(4, 30), Vector2(8, 12), Vector2(14, 20), Vector2(20, 6), Vector2(26, 20), Vector2(32, 12), Vector2(36, 30)])
		for i in pts.size():
			pts[i] *= s
		draw_colored_polygon(pts, UI.GOLD)


class GoalIcon extends Control:
	var state := 0 # 0 open, 1 done, 2 failed

	func _draw() -> void:
		var c := size / 2
		var r := size.x / 2 - 1
		match state:
			1:
				draw_circle(c, r, UI.GREEN)
				draw_polyline(PackedVector2Array([c + Vector2(-4, 0), c + Vector2(-1, 3), c + Vector2(4, -3)]), Color("0f1318"), 2.0, true)
			2:
				draw_circle(c, r, UI.RED)
				draw_line(c + Vector2(-3, -3), c + Vector2(3, 3), Color("0f1318"), 2.0)
				draw_line(c + Vector2(3, -3), c + Vector2(-3, 3), Color("0f1318"), 2.0)
			_:
				draw_arc(c, r - 1, 0, TAU, 24, Color("6b7580"), 1.6, true)


class SpeedButton extends Control:
	signal pressed_speed(level: int)
	var level := 0
	var active := 2

	func _ready() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = ["إيقاف (مسافة)", "سرعة ١", "سرعة ٢", "سرعة ٣"][level]

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			pressed_speed.emit(level)
			accept_event()

	func _draw() -> void:
		var on := active == level or (level > 0 and active >= level and active > 0)
		var bg := UI.RAISED
		if on:
			bg = UI.RED.darkened(0.1) if level == 0 else UI.GOLD
		draw_style_box(UI.box(bg, 9), Rect2(Vector2.ZERO, size))
		var fg := Color("15110a") if on else UI.TEXT2
		var c := size / 2
		if level == 0:
			draw_rect(Rect2(c + Vector2(-7, -9), Vector2(5, 18)), fg)
			draw_rect(Rect2(c + Vector2(2, -9), Vector2(5, 18)), fg)
		else:
			var n := level
			var w := 9.0
			var start := c.x - (n * w) / 2.0 - 1
			for i in n:
				var x := start + i * w
				draw_colored_polygon(PackedVector2Array([Vector2(x, c.y - 8), Vector2(x + 10, c.y), Vector2(x, c.y + 8)]), fg)


## Small drawn scene at the top of event windows.
class EventArt extends Control:
	var kind := "office"

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var top: Color = {"water": Color("1d3a44"), "crowd": Color("3a1f1a"), "road": Color("3a3226"), "debate": Color("2e2418"), "vote": Color("1f2b22"),
			"letter": Color("2a2a20"), "envelope": Color("2a2620"), "market": Color("33291b"), "scheme": Color("1a1d26")}.get(kind, Color("222a33"))
		draw_style_box(UI.box(top, 10), r)
		var w := size.x
		var h := size.y
		var ink := Color(0, 0, 0, 0.45)
		match kind:
			"crowd", "debate", "vote":
				for i in 26:
					var x := w * (i + 0.5) / 26.0
					var hh := 30.0 + fmod(i * 37.0, 22.0)
					draw_circle(Vector2(x, h - hh - 8), 8, ink)
					draw_rect(Rect2(x - 9, h - hh, 18, hh), ink)
				if kind == "crowd":
					draw_circle(Vector2(w * 0.78, h * 0.4), 34, Color(1, 0.5, 0.2, 0.25))
				if kind == "vote":
					draw_rect(Rect2(w / 2 - 40, h * 0.25, 80, 60), Color("8a6a3a"))
					draw_rect(Rect2(w / 2 - 20, h * 0.25 - 4, 40, 8), Color(0, 0, 0, 0.6))
			"water":
				for i in 7:
					draw_arc(Vector2(w * 0.5, h * 1.6), 120.0 + i * 26.0, PI * 1.2, PI * 1.8, 48, Color(0.5, 0.75, 0.85, 0.12 + i * 0.03), 3.0)
				draw_rect(Rect2(w * 0.46, h * 0.35, 40, 70), Color("8a7a60"))
				draw_circle(Vector2(w * 0.5, h * 0.35), 22, Color("8a7a60"))
			"road":
				draw_colored_polygon(PackedVector2Array([Vector2(w * 0.45, h * 0.3), Vector2(w * 0.55, h * 0.3), Vector2(w * 0.9, h), Vector2(w * 0.1, h)]), Color("4a4236"))
				draw_rect(Rect2(w * 0.5 - 60, h * 0.45, 120, 50), Color("6d5a3a"))
				draw_circle(Vector2(w * 0.5 - 35, h * 0.45 + 52), 10, ink)
				draw_circle(Vector2(w * 0.5 + 35, h * 0.45 + 52), 10, ink)
			"letter", "envelope":
				draw_rect(Rect2(w / 2 - 90, h * 0.2, 180, h * 0.6), Color("d9ccb0"))
				draw_line(Vector2(w / 2 - 90, h * 0.2), Vector2(w / 2, h * 0.5), Color("a89878"), 2)
				draw_line(Vector2(w / 2 + 90, h * 0.2), Vector2(w / 2, h * 0.5), Color("a89878"), 2)
				if kind == "letter":
					draw_circle(Vector2(w / 2, h * 0.5), 12, Color("8e2b1e"))
			"market":
				for i in 6:
					draw_rect(Rect2(w * 0.1 + i * w * 0.14, h * 0.45, w * 0.1, h * 0.4), Color(0.6, 0.45, 0.25, 0.35))
					draw_colored_polygon(PackedVector2Array([Vector2(w * 0.08 + i * w * 0.14, h * 0.45), Vector2(w * 0.22 + i * w * 0.14, h * 0.45), Vector2(w * 0.15 + i * w * 0.14, h * 0.3)]), Color(0.7, 0.3, 0.2, 0.4))
			"scheme":
				draw_circle(Vector2(w * 0.5, h * 0.5), 46, Color(0.83, 0.66, 0.31, 0.12))
				draw_rect(Rect2(w * 0.5 - 50, h * 0.3, 100, 70), Color("3a3026"))
				draw_rect(Rect2(w * 0.5 - 40, h * 0.38, 80, 4), Color("8a7a60"))
				draw_rect(Rect2(w * 0.5 - 40, h * 0.48, 60, 4), Color("8a7a60"))
			_:
				draw_rect(Rect2(w * 0.3, h * 0.55, w * 0.4, 10), Color("5a4630"))
				draw_rect(Rect2(w * 0.42, h * 0.3, 60, 60), Color("d9ccb0"))
				draw_circle(Vector2(w * 0.62, h * 0.4), 14, Color(1, 0.85, 0.5, 0.4))
