class_name PactScreen
extends Control
## The parliament screen for "The Pact": the whip count as a half-circle of 40 seats, the deputy's card,
## your tools, the street and the King, and the roll-call vote animated seat by seat.

signal back_to_menu

const H := preload("res://scripts/sim/house_content.gd")
const C := preload("res://scripts/sim/content.gd")
const CAT_COLOR := {"for": Color("6fbf7f"), "lean_for": Color("a9d58f"), "undecided": Color("9aa3ad"), "lean_against": Color("e6a08c"),
	"against": Color("d0503f"), "absent": Color("3a414b")}
const CAT_NAME := {"for": "مع الحكومة", "lean_for": "يميل إلينا", "undecided": "متردّد", "lean_against": "يميل ضدنا", "against": "ضد الحلف", "absent": "سيغيب"}

var modals: ModalHost
var hemi: Hemicycle
var card_box: VBoxContainer
var left_box: VBoxContainer
var tally_box: HBoxContainer
var forecast_lbl: Label
var date_lbl: Label
var ap_pips: HBoxContainer
var res_box: HBoxContainer
var street_bar: UI.BarControl
var trust_bar: UI.BarControl
var street_lbl: Anim.CountLabel
var trust_lbl: Anim.CountLabel
var end_btn: Button
var day_lbl: Label
var toast_box: VBoxContainer
var selected := ""
var voting := false
var vote_state := {}
var _pending_result := {}


func _ready() -> void:
	theme = UI.theme()
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1920, 1080)
	var bg := HallBackground.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.size = size
	add_child(bg)
	_build_header()
	_build_tally()
	hemi = Hemicycle.new()
	hemi.screen = self
	hemi.position = Vector2(470, 200)
	hemi.size = Vector2(980, 660)
	add_child(hemi)
	_build_left()
	_build_right()
	_build_bottom()
	toast_box = UI.vbox(8)
	toast_box.position = Vector2(560, 230)
	toast_box.size = Vector2(800, 0)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)
	modals = ModalHost.new()
	add_child(modals)
	House.changed.connect(_refresh)
	House.toast.connect(_toast)
	House.event_raised.connect(_on_event)
	House.vote_started.connect(_on_vote)
	House.ended.connect(_on_ended)


func start(seed_in: int) -> void:
	voting = false
	vote_state = {}
	selected = ""
	House.new_game(seed_in)
	hemi.build()
	_refresh()
	Anim.slide_in(hemi, Vector2(0, 40), 0.5)
	if not House.event_queue.is_empty() and modals.stack.is_empty():
		_on_event(House.event_queue[0])


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and k.keycode == KEY_ESCAPE and modals.top_closable():
		modals.close()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ header and tally

func _build_header() -> void:
	var bar := UI.panel(false, 14)
	bar.position = Vector2(20, 14)
	bar.size = Vector2(1880, 92)
	add_child(bar)
	var h := UI.hbox(18)
	bar.add_child(h)
	var tv := UI.vbox(0)
	tv.add_child(UI.label("مجلس النواب · معاهدة الانضمام إلى حلف بغداد", 22, UI.TEXT, 700))
	date_lbl = UI.label("", 15, UI.GOLD)
	tv.add_child(date_lbl)
	tv.custom_minimum_size.x = 560
	h.add_child(tv)
	var apv := UI.vbox(4)
	apv.add_child(UI.label("وقتك اليوم", 13, UI.TEXT2))
	ap_pips = UI.hbox(6)
	apv.add_child(ap_pips)
	h.add_child(apv)
	res_box = UI.hbox(8)
	h.add_child(res_box)
	h.add_child(UI.spacer())
	var meters := UI.vbox(6)
	meters.custom_minimum_size.x = 300
	var sr := UI.hbox(8)
	sr.add_child(UI.label("غضب الشارع", 14, UI.TEXT2))
	street_bar = UI.bar(0, UI.RED, 8)
	sr.add_child(street_bar)
	street_lbl = Anim.CountLabel.new()
	street_lbl.add_theme_font_override("font", UI.font(700))
	street_lbl.custom_minimum_size.x = 34
	sr.add_child(street_lbl)
	sr.tooltip_text = "الشارع يغضب كل ليلة، وتغذّيه إذاعة القاهرة.\nكلما اشتدّ، ابتعد عنك نواب الضفة الغربية.\nإن بلغ ١٠٠ أقال الملك الحكومة."
	sr.mouse_filter = Control.MOUSE_FILTER_STOP
	meters.add_child(sr)
	var tr := UI.hbox(8)
	tr.add_child(UI.label("ثقة الملك", 14, UI.TEXT2))
	trust_bar = UI.bar(0, UI.GOLD, 8)
	tr.add_child(trust_bar)
	trust_lbl = Anim.CountLabel.new()
	trust_lbl.add_theme_font_override("font", UI.font(700))
	trust_lbl.custom_minimum_size.x = 34
	tr.add_child(trust_lbl)
	tr.tooltip_text = "ثقة الملك بالحكومة. تنقص حين يحترق الشارع،\nوحين تكذب عليه، وحين تزعج القصر.\nإن نزلت تحت ٢٥ أقال الحكومة."
	tr.mouse_filter = Control.MOUSE_FILTER_STOP
	meters.add_child(tr)
	h.add_child(meters)
	var menu := UI.button("القائمة", "", 15)
	menu.pressed.connect(_confirm_menu)
	h.add_child(menu)
	Anim.slide_in(bar, Vector2(0, -120), 0.45)


func _build_tally() -> void:
	var p := UI.panel(true, 12)
	p.position = Vector2(560, 120)
	p.size = Vector2(800, 0)
	p.custom_minimum_size = Vector2(800, 0)
	add_child(p)
	p.resized.connect(func(): p.size.y = p.get_combined_minimum_size().y)
	var v := UI.vbox(4)
	p.add_child(v)
	tally_box = UI.hbox(18)
	tally_box.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(tally_box)
	forecast_lbl = UI.label("", 15, UI.TEXT2)
	forecast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(forecast_lbl)
	Anim.slide_in(p, Vector2(0, -60), 0.5, 0.1)


func _refresh() -> void:
	if not is_inside_tree():
		return
	date_lbl.text = House.date_text() + (" · " + H.SLOTS[H.AP_PER_DAY - House.ap] if House.ap > 0 and House.phase == "lobby" else "")
	UI.clear(ap_pips)
	for i in H.AP_PER_DAY:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(26, 10)
		pip.color = UI.GOLD if i < House.ap else Color(1, 1, 1, 0.1)
		ap_pips.add_child(pip)
	UI.clear(res_box)
	for r in [["مناصب", House.posts, "وعود بمناصب وزارية أو وظائف"], ["مشاريع", House.projects, "طرق ومدارس ومشاريع ماء"], ["المخصّصات", House.fund, "مال سري بالدينار — للمغلّفات والهدايا"], ["كلمات الملك", House.palace_words, "كم مرة تستطيع أن تطلب استدعاء نائب إلى القصر"]]:
		var c := UI.chip("%s %s" % [r[0], Game.ar(r[1])], UI.TEXT)
		c.tooltip_text = r[2]
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		res_box.add_child(c)
	street_bar.value = House.street / 100.0
	street_bar.queue_redraw()
	trust_bar.value = House.trust / 100.0
	trust_bar.queue_redraw()
	street_lbl.set_value(House.street)
	trust_lbl.set_value(House.trust)
	_refresh_tally()
	hemi.refresh()
	_build_card()
	_refresh_left()
	day_lbl.text = "اليوم %s من %s" % [Game.ar(min(House.day + 1, H.DAYS)), Game.ar(H.DAYS)]
	end_btn.disabled = House.phase != "lobby" or House.over
	end_btn.text = "إلى الجلسة: نداء الأسماء" if House.day == H.DAYS - 1 else "أنهِ اليوم"


func _refresh_tally() -> void:
	UI.clear(tally_box)
	var c := House.counts()
	for k in [["for", "مع"], ["lean_for", "يميل إلينا"], ["undecided", "متردّد"], ["lean_against", "يميل ضدنا"], ["against", "ضد"], ["absent", "غائب"]]:
		var v := UI.vbox(0)
		var n := UI.label(Game.ar(c[k[0]]), 34, CAT_COLOR[k[0]], 700)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(n)
		var l := UI.label(k[1], 13, UI.TEXT2)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		tally_box.add_child(v)
	var f := House.forecast()
	forecast_lbl.text = "الحاضرون %s · المطلوب %s صوتاً · لو جرى التصويت الآن: نحو %s" % [Game.ar(f["present"]), Game.ar(f["needed"]), Game.ar(int(round(f["yes"])))]
	forecast_lbl.add_theme_color_override("font_color", UI.GREEN if f["yes"] >= f["needed"] else UI.TEXT2)
	if f["present"] < House.QUORUM:
		forecast_lbl.text = "تحذير: الحاضرون %s فقط — لا نصاب للجلسة بأقل من ٢١!" % Game.ar(f["present"])
		forecast_lbl.add_theme_color_override("font_color", UI.RED)


# ------------------------------------------------------------------ left: your tools and the news

func _build_left() -> void:
	var sc := ScrollContainer.new()
	sc.position = Vector2(20, 120)
	sc.size = Vector2(430, 760)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	left_box = UI.vbox(10)
	left_box.custom_minimum_size.x = 420
	sc.add_child(left_box)
	Anim.slide_in(sc, Vector2(-80, 0), 0.5, 0.15)


func _refresh_left() -> void:
	UI.clear(left_box)
	var p := UI.panel(false, 14)
	var v := UI.vbox(8)
	p.add_child(v)
	v.add_child(UI.label("أدواتك", 19, UI.GOLD, 700))
	for gid in H.GLOBAL_ACTIONS:
		var g: Dictionary = H.GLOBAL_ACTIONS[gid]
		var st := House.global_state(gid)
		var b := ModalHost.choice(g["name"], g["desc"] if st["ok"] else st["why"], st["ok"], 54)
		b.pressed.connect(func(): House.global_act(gid))
		v.add_child(b)
	left_box.add_child(p)
	var n := UI.panel(false, 14)
	var nv := UI.vbox(8)
	n.add_child(nv)
	nv.add_child(UI.label("آخر الأخبار", 19, UI.GOLD, 700))
	for e in House.log.slice(0, 7):
		var h := UI.hbox(8)
		var d := UI.label(House.date_text(e["day"]).split(" ")[0], 13, UI.FAINT)
		d.custom_minimum_size.x = 64
		h.add_child(d)
		var l := UI.label(e["text"], 14, UI.TEXT, 400, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		nv.add_child(h)
	left_box.add_child(n)


# ------------------------------------------------------------------ right: the selected deputy

func _build_right() -> void:
	var sc := ScrollContainer.new()
	sc.position = Vector2(1470, 120)
	sc.size = Vector2(430, 760)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	card_box = UI.vbox(10)
	card_box.custom_minimum_size.x = 420
	sc.add_child(card_box)
	Anim.slide_in(sc, Vector2(80, 0), 0.5, 0.15)


func select(id: String) -> void:
	selected = id
	hemi.refresh()
	_build_card()
	Anim.cascade(card_box)


func _build_card() -> void:
	UI.clear(card_box)
	var d := House.dep(selected)
	var p := UI.panel(true, 16)
	var v := UI.vbox(10)
	p.add_child(v)
	card_box.add_child(p)
	if d.is_empty():
		v.add_child(UI.label("اختر نائباً من المقاعد", 20, UI.TEXT, 700))
		v.add_child(UI.label("كل مقعد صورة نائب، ولونه يقول أين يقف من الحلف. مرّر الفأرة على المقعد لترى اسمه، وانقر لتعرف ما يريد وما يمكنك فعله معه.", 15, UI.TEXT2, 400, true))
		for k in CAT_NAME:
			var h := UI.hbox(8)
			var sw := ColorRect.new()
			sw.color = CAT_COLOR[k]
			sw.custom_minimum_size = Vector2(16, 16)
			h.add_child(sw)
			h.add_child(UI.label(CAT_NAME[k], 15, UI.TEXT))
			v.add_child(h)
		return
	var cat := House.category(d)
	var h := UI.hbox(14)
	var por := Portrait.make(d["look"], 96, clampf(d["stance"] / 60.0, -1, 1))
	por.border = CAT_COLOR[cat]
	h.add_child(por)
	var iv := UI.vbox(4)
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	iv.add_child(UI.label(d["name"], 23, UI.TEXT, 700))
	var seats_txt := {"christian": " · مقعد مسيحي", "circassian": " · مقعد شركسي"}
	var seat: String = seats_txt.get(d["seat"], "")
	if d["bloc"] == "bedouin":
		seat = " · مقعد البدو"
	iv.add_child(UI.label("نائب %s%s" % [Game.town_name(d["town"]), seat], 15, UI.GOLD))
	iv.add_child(UI.chip(H.BLOCS[d["bloc"]]["name"], UI.TEXT2))
	h.add_child(iv)
	v.add_child(h)
	var sh := UI.hbox(8)
	sh.add_child(UI.label(CAT_NAME[cat], 16, CAT_COLOR[cat], 700))
	var sbar := StanceBar.new()
	sbar.value = d["stance"]
	sbar.custom_minimum_size = Vector2(0, 14)
	sbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(sbar)
	v.add_child(sh)
	if d["committed"]:
		v.add_child(UI.label("أعطاك كلمته", 14, UI.GREEN, 600))
	var tr := UI.hbox(6)
	for t in d["traits"]:
		if d["known"].has(t):
			var chip := UI.chip(C.TRAITS[t]["name"], UI.BLUE, Color(0.56, 0.71, 0.79, 0.14))
			chip.tooltip_text = C.TRAITS[t]["hint"]
			chip.mouse_filter = Control.MOUSE_FILTER_STOP
			tr.add_child(chip)
		else:
			tr.add_child(UI.chip("؟ طبع مجهول", UI.FAINT))
	v.add_child(tr)
	v.add_child(UI.label("يريد: " + (H.WANTS[d["want"]]["name"] if d["want_known"] else "لا تعرف بعد — اجلس معه أو أرسل رجالك"), 15, UI.TEXT if d["want_known"] else UI.FAINT, 600, true))
	if d["secret_known"]:
		v.add_child(UI.label("في ملفّه: " + d["secret"], 14, UI.RED, 600, true))
	var flags := []
	if d["promised"]:
		flags.append("وعدته")
	if d["paid"]:
		flags.append("دفعت له")
	if d["palace"]:
		flags.append("استُدعي إلى القصر")
	if not flags.is_empty():
		v.add_child(UI.label("، ".join(flags), 14, UI.TEXT2))
	v.add_child(UI.sep_line())
	for aid in H.DEPUTY_ACTIONS:
		var a: Dictionary = H.DEPUTY_ACTIONS[aid]
		var st := House.action_state(aid, d)
		var cost := " · نصف يوم" if a["ap"] > 0 else ""
		var b := ModalHost.choice(a["name"] + cost, a["desc"] if st["ok"] else st["why"], st["ok"], 52)
		var id: String = d["id"]
		if aid == "meet":
			b.pressed.connect(func(): _open_meet(id))
		else:
			b.pressed.connect(func(): House.act(aid, id))
		v.add_child(b)


# ------------------------------------------------------------------ bottom: end the day

func _build_bottom() -> void:
	var p := UI.panel(false, 12)
	p.position = Vector2(560, 950)
	p.size = Vector2(800, 0)
	p.custom_minimum_size = Vector2(800, 0)
	add_child(p)
	var h := UI.hbox(14)
	p.add_child(h)
	day_lbl = UI.label("", 18, UI.TEXT, 700)
	h.add_child(day_lbl)
	h.add_child(UI.label("الليل للمعارضة والإذاعة: كل يوم تنهيه يقرّب الجلسة ويرفع غضب الشارع.", 14, UI.TEXT2, 400, true))
	h.get_child(1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	end_btn = UI.button("أنهِ اليوم", "primary", 18)
	end_btn.custom_minimum_size = Vector2(240, 52)
	end_btn.pressed.connect(func(): House.end_day())
	h.add_child(end_btn)
	Anim.slide_in(p, Vector2(0, 120), 0.5, 0.2)


func _toast(text: String) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color(0.1, 0.12, 0.15, 0.96), 10, UI.GOLD_LINE, 1, 14))
	var l := UI.label(text, 17, UI.TEXT, 600, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(p)
	Anim.pop_in(p, 0.25)
	while toast_box.get_child_count() > 2:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


# ------------------------------------------------------------------ events

func _on_event(ev: Dictionary) -> void:
	var card := UI.panel(true, 22)
	var v := UI.vbox(14)
	card.add_child(v)
	var h := UI.hbox(16)
	if ev.get("who", "") != "":
		var fig: Dictionary = H.FIGURES[ev["who"]]
		var look: Dictionary = fig["look"].duplicate()
		look["photo"] = fig["photo"]
		h.add_child(Portrait.make(look, 120))
		var fv := UI.vbox(4)
		fv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fv.add_child(UI.label(ev["title"], 28, UI.TEXT, 700))
		fv.add_child(UI.label(fig["name"] + " · " + fig["role"], 15, UI.GOLD))
		fv.add_child(UI.label(House.date_text(), 14, UI.FAINT))
		h.add_child(fv)
	else:
		var art := HUD.EventArt.new()
		art.kind = "crowd"
		art.custom_minimum_size = Vector2(0, 140)
		art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(art)
		h.add_child(UI.label(ev["title"], 28, UI.TEXT, 700))
	v.add_child(h)
	v.add_child(UI.label(ev["text"], 18, UI.TEXT, 400, true))
	v.add_child(UI.sep_line())
	for o in ev["options"]:
		var b := ModalHost.choice(o["text"], o.get("note", ""))
		var oid: String = o["id"]
		b.pressed.connect(func():
			modals.close()
			House.resolve_event(oid))
		v.add_child(b)
	modals.open(card, false, 780)


# ------------------------------------------------------------------ meeting a deputy

func _open_meet(id: String) -> void:
	var d := House.dep(id)
	var card := UI.panel(true, 22)
	var v := UI.vbox(12)
	card.add_child(v)
	modals.header(v, "جلسة مع " + d["name"], "كل جلسة تأخذ نصف يوم. ماذا تريد منه؟")
	for a in House.asks_for(d):
		var b := ModalHost.choice(a["name"], a["desc"] + ("" if a["target"] == 0 else " · تحتاج مزاجه %s" % Game.ar(a["target"])), true, 56)
		var ask: String = a["id"]
		b.pressed.connect(func():
			modals.close()
			House.start_duel(id, ask)
			_open_duel())
		v.add_child(b)
	modals.open(card, true, 620)


func _open_duel() -> void:
	if House.duel.is_empty():
		return
	var d := House.dep(House.duel["id"])
	var card := UI.panel(true, 22)
	var v := UI.vbox(12)
	card.add_child(v)
	var top := UI.hbox(18)
	var por := Portrait.make(d["look"], 120, 0.0)
	top.add_child(por)
	var iv := UI.vbox(8)
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	iv.add_child(UI.label("جلسة مع " + d["name"], 25, UI.TEXT, 700))
	var target: int = House.duel["target"]
	var asks := {"chat": "تسمع منه", "support": "صوّت مع الحكومة", "abstain": "غِب عن الجلسة"}
	iv.add_child(UI.label("طلبك: " + asks[House.duel["ask"]] + ("" if target == 0 else " · تحتاج مزاجه %s" % Game.ar(target)), 16, UI.GOLD))
	var mood := UI.bar(House.duel["mood"], UI.GREEN, 14)
	if target > 0:
		mood.marker = target / 100.0
	iv.add_child(mood)
	var trs := VBoxContainer.new()
	iv.add_child(trs)
	var round_lbl := UI.label("", 15, UI.TEXT2)
	iv.add_child(round_lbl)
	top.add_child(iv)
	v.add_child(top)
	var reaction := UI.label("يجلس %s في مضافته ويصبّ لك القهوة." % d["name"], 18, UI.TEXT, 400, true)
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
	var redraw := func(): pass
	redraw = func():
		UI.clear(grid)
		UI.clear(foot)
		UI.clear(trs)
		var row := UI.hbox(6)
		for t in d["traits"]:
			row.add_child(UI.chip(C.TRAITS[t]["name"] if d["known"].has(t) else "؟ طبع مجهول", UI.BLUE if d["known"].has(t) else UI.FAINT))
		trs.add_child(row)
		mood.value = House.duel["mood"] / 100.0
		mood.queue_redraw()
		por.set_mood(clampf((House.duel["mood"] - 45.0) / 35.0, -1, 1))
		var done: bool = House.duel["round"] >= House.duel["rounds"]
		round_lbl.text = "الجولة %s من %s" % [Game.ar(min(House.duel["round"] + 1, 3)), Game.ar(3)]
		if not done:
			for o in House.duel_options():
				var b := ModalHost.choice(o["name"] + ("" if o["used"] == 0 else " (أضعف الآن)"), o["desc"] if o["ok"] else o["why"], o["ok"], 62)
				b.custom_minimum_size.x = 340
				var aid: String = o["id"]
				b.pressed.connect(func():
					var e := House.duel_play(aid)
					var extra := ""
					if e["reveal"] != "":
						extra = "\nعرفت عنه: %s — %s." % [C.TRAITS[e["reveal"]]["name"], C.TRAITS[e["reveal"]]["hint"]]
					reaction.text = "%s  (%s%s)%s" % [e["text"], "+" if e["delta"] >= 0 else "−", Game.ar(int(abs(round(e["delta"])))), extra]
					Anim.pop_in(rp, 0.18)
					redraw.call())
				grid.add_child(b)
				Anim.cascade(grid, 0.02)
		var ok := House.duel_success_now()
		var st := UI.label("", 16, UI.GREEN if ok else UI.TEXT2, 600)
		if target > 0:
			st.text = "سيوافق إن انتهت الجلسة الآن" if ok else "لم يقتنع بعد"
		st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(st)
		if done or House.duel["round"] >= 1:
			var fin := UI.button("أنهِ الجلسة", "primary" if done else "", 16)
			fin.pressed.connect(func():
				var r := House.duel_finish()
				modals.close()
				_toast(r["text"]))
			foot.add_child(fin)
	redraw.call()
	modals.open(card, false, 760)


# ------------------------------------------------------------------ the vote

func _on_vote(roll: Array) -> void:
	voting = true
	vote_state = {}
	hemi.refresh()
	var card := UI.panel(true, 18)
	var v := UI.vbox(10)
	card.add_child(v)
	var title := UI.label("الجلسة: نداء الأسماء", 26, UI.TEXT, 700)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var who := UI.label("رئيس المجلس يقرأ الأسماء…", 20, UI.GOLD, 600)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(who)
	var score := UI.label("", 22, UI.TEXT, 700)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(score)
	card.position = Vector2(660, 880)
	card.size = Vector2(600, 0)
	card.custom_minimum_size = Vector2(600, 0)
	add_child(card)
	Anim.pop_in(card)
	var yes := 0
	var no := 0
	for r in roll:
		await get_tree().create_timer(0.32 if r["vote"] != "absent" else 0.12).timeout
		var d := House.dep(r["id"])
		vote_state[r["id"]] = r["vote"]
		match r["vote"]:
			"yes":
				yes += 1
				who.text = "%s: نعم" % d["name"]
				who.add_theme_color_override("font_color", UI.GREEN)
			"no":
				no += 1
				who.text = "%s: لا" % d["name"]
				who.add_theme_color_override("font_color", UI.RED)
			_:
				who.text = "%s: غائب" % d["name"]
				who.add_theme_color_override("font_color", UI.FAINT)
		score.text = "نعم %s — لا %s" % [Game.ar(yes), Game.ar(no)]
		hemi.flash(r["id"])
		hemi.refresh()
	await get_tree().create_timer(1.2).timeout
	card.queue_free()
	voting = false
	if not _pending_result.is_empty():
		_show_result(_pending_result)
		_pending_result = {}


func _on_ended(r: Dictionary) -> void:
	if voting:
		_pending_result = r
	else:
		await get_tree().create_timer(0.3).timeout
		_show_result(r)


func _show_result(r: Dictionary) -> void:
	var card := UI.panel(true, 26)
	var v := UI.vbox(14)
	card.add_child(v)
	var titles := {"passed": "المجلس يوافق على الحلف", "failed": "المجلس يرفض الحلف", "no_quorum": "لا نصاب: الجلسة لم تنعقد", "dismissed": "الملك يقيل الحكومة"}
	var good: bool = r["kind"] == "passed"
	v.add_child(UI.label(titles[r["kind"]], 34, UI.GREEN if good else UI.RED, 700))
	if r["kind"] in ["passed", "failed"]:
		v.add_child(UI.label("نعم %s — لا %s · الحاضرون %s" % [Game.ar(r["yes"]), Game.ar(r["no"]), Game.ar(r["present"])], 19, UI.TEXT, 600))
	var lines := []
	match r["kind"]:
		"passed":
			if r["street"] >= 70:
				lines.append("فزت بالتصويت… لكن الشارع انفجر. في الليلة نفسها تعمّ المظاهرات المدن، والملك يتردّد أمام الدم.")
				lines.append("في الصباح يستدعيك المجالي: «ربحنا المجلس وخسرنا البلد. الملك يريد أن يسمع منك.»")
			else:
				lines.append("الأردن عضو في حلف بغداد. المال البريطاني يتدفّق على الجيش، والقاهرة تعلن الحرب الإعلامية.")
				lines.append("اسمك يتردّد في القصر وفي السفارة: الرجل الذي جاء بالأغلبية.")
		"failed":
			lines.append("المجالي يقدّم استقالته في الليلة نفسها. الملك يقبلها.")
			lines.append("أنت خارج الحكومة… لكنك تعرف الآن أسماء من وعد ثم خان.")
		"no_quorum":
			lines.append("غاب أكثر مما ينبغي: لم يحضر ٢١ نائباً، فلا جلسة ولا تصويت. الحكومة تبدو عاجزة.")
		"dismissed":
			lines.append("الشارع اشتعل والملك فقد صبره: أقال الحكومة قبل أن تصل إلى الجلسة." if r.get("why", "") == "street" else "الملك فقد ثقته بالحكومة وأقالها قبل الجلسة.")
	if r.get("lied", false) and not good:
		lines.append("وعدت الملك بما لم تستطع تحقيقه. لن ينسى القصر ذلك.")
	for l in lines:
		v.add_child(UI.label("• " + l, 17, UI.TEXT, 400, true))
	v.add_child(UI.sep_line())
	v.add_child(UI.label("ما حدث فعلاً", 18, UI.GOLD, 700))
	v.add_child(UI.label("كُلّف هزّاع المجالي يوم ١٤ كانون الأول ١٩٥٥، واندلعت المظاهرات في الضفتين يوم ١٦، فاستقالت حكومته بعد أيام قليلة. لم ينضم الأردن إلى الحلف قط، وبعد أقل من ثلاثة أشهر أقال الملك الحسين غلوب باشا.", 16, UI.TEXT2, 400, true))
	var h := UI.hbox(10)
	var again := UI.button("حاول مجدداً", "primary", 18)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func():
		modals.close()
		start(randi()))
	h.add_child(again)
	var menu := UI.button("القائمة الرئيسية", "", 18)
	menu.pressed.connect(func():
		modals.close()
		back_to_menu.emit())
	h.add_child(menu)
	v.add_child(h)
	modals.open(card, false, 780)


func _confirm_menu() -> void:
	var card := UI.panel(true, 22)
	var v := UI.vbox(12)
	card.add_child(v)
	modals.header(v, "العودة إلى القائمة؟", "ستضيع مساعيك في هذا السيناريو.")
	var h := UI.hbox(10)
	var yes := UI.button("نعم، إلى القائمة", "danger", 16)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(func():
		modals.close()
		back_to_menu.emit())
	h.add_child(yes)
	var no := UI.button("ابقَ", "", 16)
	no.pressed.connect(modals.close)
	h.add_child(no)
	v.add_child(h)
	modals.open(card, true, 480)


# ------------------------------------------------------------------ drawn pieces

## The half-circle of seats. Seats are ordered by bloc from the opposition to the Bedouin seats.
class Hemicycle extends Control:
	var screen: PactScreen
	var seats := {}
	var _flash := {}

	func build() -> void:
		for c in get_children():
			c.queue_free()
		seats = {}
		var order := ["opposition", "west_indep", "west_notable", "east_urban", "east_tribal", "bedouin"]
		var list := House.deputies.duplicate()
		list.sort_custom(func(a, b):
			var ia := order.find(a["bloc"])
			var ib := order.find(b["bloc"])
			return ia < ib if ia != ib else a["stance"] < b["stance"])
		var rows := [7, 9, 11, 13] # seats per row grow with the radius, so the rows line up
		var radii := [200.0, 272.0, 344.0, 416.0]
		var center := Vector2(size.x / 2, size.y - 70)
		# fill seats row by row so each bloc forms a wedge: walk angle-major over all rows
		var slots := []
		for r in rows.size():
			for i in rows[r]:
				var ang: float = PI + PI * (i + 0.5) / rows[r]
				slots.append({"ang": ang, "r": radii[r]})
		slots.sort_custom(func(a, b): return a["ang"] < b["ang"])
		for i in list.size():
			var d: Dictionary = list[i]
			var s := Seat.new()
			s.dep_id = d["id"]
			s.screen = screen
			s.size = Vector2(54, 64)
			s.custom_minimum_size = s.size
			var p: Vector2 = center + Vector2(cos(slots[i]["ang"]), sin(slots[i]["ang"])) * slots[i]["r"]
			s.position = p - s.size / 2
			s.pivot_offset = s.size / 2
			add_child(s)
			seats[d["id"]] = s
			s.modulate.a = 0.0
			var t := s.create_tween()
			t.tween_interval(0.012 * i)
			t.tween_property(s, "modulate:a", 1.0, 0.25)
		queue_redraw()

	func refresh() -> void:
		for id in seats:
			seats[id].queue_redraw()
		queue_redraw()

	func flash(id: String) -> void:
		if seats.has(id):
			var s: Control = seats[id]
			var t := s.create_tween()
			t.tween_property(s, "scale", Vector2(1.35, 1.35), 0.12)
			t.tween_property(s, "scale", Vector2.ONE, 0.2)

	func _draw() -> void:
		var center := Vector2(size.x / 2, size.y - 70)
		for r in [150.0, 455.0]:
			draw_arc(center, r, PI, TAU, 96, Color(0.83, 0.66, 0.31, 0.18), 2.0, true)
		draw_rect(Rect2(center.x - 90, center.y - 10, 180, 54), Color("2a2116"))
		draw_rect(Rect2(center.x - 90, center.y - 10, 180, 54), Color(0.83, 0.66, 0.31, 0.5), false, 2.0)
		var f := UI.font(600)
		var t := "المنصّة"
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, 18).x
		draw_string(f, Vector2(center.x - w / 2, center.y + 24), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UI.GOLD)
		# needed votes marker on a small arc gauge above the podium
		var c := House.counts()
		var f2 := House.forecast()
		var frac := clampf(f2["yes"] / max(1.0, float(f2["present"])), 0, 1)
		draw_arc(center, 120, PI, PI + PI * frac, 48, Color("6fbf7f"), 10.0, true)
		draw_arc(center, 120, PI + PI * frac, TAU, 48, Color(0.82, 0.31, 0.25, 0.7), 10.0, true)
		var half := PI + PI * 0.5
		draw_line(center + Vector2(cos(half), sin(half)) * 108, center + Vector2(cos(half), sin(half)) * 132, Color.WHITE, 3.0)
		var lbl := "%s من %s" % [Game.ar(int(round(f2["yes"]))), Game.ar(c["needed"])]
		var lw := UI.font(700).get_string_size(lbl, HORIZONTAL_ALIGNMENT_CENTER, -1, 26).x
		draw_string(UI.font(700), Vector2(center.x - lw / 2, center.y - 46), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UI.TEXT)


class Seat extends Control:
	var dep_id := ""
	var screen: PactScreen
	var _por: Portrait
	var _hover := false

	func _ready() -> void:
		var d := House.dep(dep_id)
		_por = Portrait.make(d["look"], 42)
		_por.position = Vector2(6, 6)
		_por.border = Color(0, 0, 0, 0)
		add_child(_por)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func():
			_hover = true
			create_tween().tween_property(self, "scale", Vector2(1.18, 1.18), 0.12)
			queue_redraw())
		mouse_exited.connect(func():
			_hover = false
			create_tween().tween_property(self, "scale", Vector2.ONE, 0.15)
			queue_redraw())

	func _make_custom_tooltip(_t: String) -> Object:
		var d := House.dep(dep_id)
		var p := UI.panel(false, 10)
		var v := UI.vbox(2)
		p.add_child(v)
		v.add_child(UI.label(d["name"], 16, UI.TEXT, 700))
		v.add_child(UI.label("%s · %s" % [Game.town_name(d["town"]), PactScreen.CAT_NAME[House.category(d)]], 14, PactScreen.CAT_COLOR[House.category(d)]))
		if d["want_known"]:
			v.add_child(UI.label("يريد: " + H.WANTS[d["want"]]["short"], 13, UI.TEXT2))
		return p

	func _get_tooltip(_p: Vector2) -> String:
		return " "

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			screen.select(dep_id)
			accept_event()

	func _draw() -> void:
		var d := House.dep(dep_id)
		var cat := House.category(d)
		var col: Color = PactScreen.CAT_COLOR[cat]
		if screen.voting or not screen.vote_state.is_empty():
			var vs: String = screen.vote_state.get(dep_id, "")
			col = {"yes": Color("6fbf7f"), "no": Color("d0503f"), "absent": Color("3a414b")}.get(vs, Color(0.4, 0.42, 0.46, 0.5))
		var r := Rect2(Vector2(2, 2), Vector2(50, 56))
		draw_style_box(UI.box(Color("141920"), 9, col, 3), r)
		if screen.selected == dep_id:
			draw_style_box(UI.box(Color(0, 0, 0, 0), 11, UI.GOLD, 2), Rect2(Vector2(-2, -2), Vector2(58, 64)))
		if d["committed"]:
			draw_circle(Vector2(46, 52), 6, Color("6fbf7f"))
		if d["secret_known"]:
			draw_circle(Vector2(8, 52), 6, UI.RED)


## Stance shown as a bar from against (left, red) to for (right, green) with a needle.
class StanceBar extends Control:
	var value := 0.0

	func _draw() -> void:
		var w := size.x
		var h := size.y
		for i in 40:
			var t := i / 39.0
			var c := Color("d0503f").lerp(Color("9aa3ad"), clampf(t * 2, 0, 1)).lerp(Color("6fbf7f"), clampf(t * 2 - 1, 0, 1))
			draw_rect(Rect2(w * i / 40.0, 3, w / 40.0 + 1, h - 6), c * Color(1, 1, 1, 0.55))
		# right-to-left: "for" is on the right
		var x := w * (1.0 - (value + 100.0) / 200.0)
		draw_rect(Rect2(x - 2, 0, 4, h), Color.WHITE)


## A dark hall with faint arches behind everything.
class HallBackground extends Control:
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("10151b"))
		for i in 7:
			var x := size.x * (i + 0.5) / 7.0
			draw_arc(Vector2(x, size.y * 0.55), 150, PI, TAU, 40, Color(0.83, 0.66, 0.31, 0.05), 8.0)
			draw_rect(Rect2(x - 150, size.y * 0.55, 8, size.y), Color(0.83, 0.66, 0.31, 0.04))
			draw_rect(Rect2(x + 142, size.y * 0.55, 8, size.y), Color(0.83, 0.66, 0.31, 0.04))
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0))
		g.set_color(1, Color(0, 0, 0, 0.55))
