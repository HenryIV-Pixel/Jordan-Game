class_name MainMenu
extends Control
## The title screen over the living map: choose a scenario.

signal chosen(mode: String)

var modals: ModalHost


func _ready() -> void:
	theme = UI.theme()
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1920, 1080)
	var shade := Shade.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var title := UI.label("المملكة", 128, UI.GOLD, 700)
	title.position = Vector2(140, 120)
	title.size = Vector2(700, 160)
	add_child(title)
	var sub := UI.label("الأردن من ١٩٥٣ — لعبة استراتيجية كبرى", 26, UI.TEXT, 400)
	sub.position = Vector2(140, 290)
	sub.size = Vector2(700, 40)
	add_child(sub)
	Anim.slide_in(title, Vector2(0, -40), 0.7)
	Anim.slide_in(sub, Vector2(0, -20), 0.7, 0.15)
	var cards := [
		{"mode": "salt", "title": "الطريق إلى المجلس", "when": "السلط · أيار وحزيران ١٩٥٣", "text": "كاتب شاب في بلدية السلط يريد مقعداً في مجلسها. ستة أسابيع من اللقاءات والدسائس، ومنافس لا ينام، وعيون تجفّ مع الصيف.", "tag": "مسيرة · نحو ٢٠ دقيقة"},
		{"mode": "pact", "title": "الحلف", "when": "عمّان · كانون الأول ١٩٥٥", "text": "رئيس الوزراء يريد إدخال الأردن حلف بغداد، وأنت رجله في الكواليس. ستة أيام لتجمع أغلبية من أربعين نائباً، والشارع يغلي وإذاعة القاهرة لا تهدأ.", "tag": "مجلس النواب · نحو ١٥ دقيقة"},
	]
	for i in cards.size():
		var c: Dictionary = cards[i]
		var card := _card(c)
		card.position = Vector2(140, 390 + i * 250)
		card.size = Vector2(560, 0)
		add_child(card)
		card.resized.connect(func(): card.size.y = card.get_combined_minimum_size().y)
		Anim.slide_in(card, Vector2(0, 60), 0.6, 0.3 + i * 0.12)
	var foot := UI.hbox(10)
	foot.position = Vector2(140, 920)
	foot.size = Vector2(560, 48)
	var credits := UI.button("الصور ومصادرها", "", 15)
	credits.pressed.connect(_credits)
	foot.add_child(credits)
	var quit := UI.button("خروج", "", 15)
	quit.pressed.connect(func(): get_tree().quit())
	foot.add_child(quit)
	add_child(foot)
	Anim.fade_in(foot, 0.4, 0.7)
	var ver := UI.label("شريحة تجريبية · Godot", 13, UI.FAINT)
	ver.position = Vector2(1490, 1040)
	ver.size = Vector2(400, 24)
	add_child(ver)
	modals = ModalHost.new()
	add_child(modals)


func _card(c: Dictionary) -> Control:
	var p := UI.panel(true, 20)
	var v := UI.vbox(8)
	p.add_child(v)
	var h := UI.hbox(10)
	h.add_child(UI.label(c["title"], 30, UI.TEXT, 700))
	h.add_child(UI.spacer())
	h.add_child(UI.chip(c["tag"], UI.GOLD, UI.GOLD_SOFT))
	v.add_child(h)
	v.add_child(UI.label(c["when"], 16, UI.GOLD))
	var desc := UI.label(c["text"], 16, UI.TEXT2, 400, true)
	desc.custom_minimum_size.x = 510 # a real width up front, so the card measures its height correctly
	v.add_child(desc)
	var b := UI.button("ابدأ", "primary", 18)
	b.custom_minimum_size.y = 46
	var mode: String = c["mode"]
	b.pressed.connect(func(): chosen.emit(mode))
	v.add_child(b)
	p.mouse_entered.connect(func():
		p.pivot_offset = p.size / 2
		p.create_tween().tween_property(p, "scale", Vector2(1.02, 1.02), 0.15))
	p.mouse_exited.connect(func(): p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.15))
	return p


func _credits() -> void:
	var card := UI.panel(true, 22)
	var v := UI.vbox(10)
	card.add_child(v)
	modals.header(v, "الصور ومصادرها", "صور الشخصيات التاريخية من ويكيميديا كومنز، كلٌّ برخصته. الوجوه الأخرى مرسومة في اللعبة.")
	var credits := {}
	for path in [OS.get_executable_path().get_base_dir().path_join("portraits/credits.json"), "res://portraits/credits.json"]:
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
			if parsed is Dictionary and not parsed.is_empty():
				credits = parsed
				break
	if credits.is_empty():
		v.add_child(UI.label("لم تُضف صور بعد. شغّل أداة تنزيل الصور (tools/fetch_portraits.py) ثم ضع مجلد portraits بجانب اللعبة.", 15, UI.TEXT2, 400, true))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 420 if not credits.is_empty() else 0)
	var lv := UI.vbox(6)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(lv)
	for id in credits:
		var c: Dictionary = credits[id]
		var l := Label.new()
		l.text = "%s — %s — %s" % [c.get("name", id), c.get("artist", "?"), c.get("licence", "?")]
		l.layout_direction = Control.LAYOUT_DIRECTION_LTR
		l.add_theme_font_size_override("font_size", 14)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lv.add_child(l)
	v.add_child(sc)
	modals.open(card, true, 720)


## Darkens the map behind the menu, more on the right where the text sits.
class Shade extends TextureRect:
	func _ready() -> void:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(0.04, 0.05, 0.07, 0.12), Color(0.04, 0.05, 0.07, 0.35), Color(0.04, 0.05, 0.07, 0.86)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.width = 256
		gt.height = 4
		texture = gt
		stretch_mode = TextureRect.STRETCH_SCALE
