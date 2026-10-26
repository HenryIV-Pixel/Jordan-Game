class_name UI
extends RefCounted
## Shared look: colours, fonts and small factory functions for building the interface in code (mockup B2 style).

const BG := Color("0f1318")
const PANEL := Color(0.09, 0.11, 0.14, 0.93)
const RAISED := Color("1e252e")
const RAISED2 := Color("262f3a")
const LINE := Color(1, 1, 1, 0.08)
const GOLD := Color("d4a94e")
const GOLD_SOFT := Color(0.83, 0.66, 0.31, 0.16)
const GOLD_LINE := Color(0.83, 0.66, 0.31, 0.55)
const TEXT := Color("f0ebe0")
const TEXT2 := Color("aab0b8")
const FAINT := Color("6b7580")
const GREEN := Color("7cc48f")
const RED := Color("e0705c")
const BLUE := Color("8fb6c9")

static var _fonts := {}


static func font(weight := 400) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var ar: FontFile = load("res://fonts/ibm-plex-sans-arabic-arabic-%d-normal.woff2" % weight)
	var la: FontFile = load("res://fonts/ibm-plex-sans-arabic-latin-%d-normal.woff2" % weight)
	var f := FontVariation.new()
	f.base_font = ar
	f.fallbacks = [la]
	_fonts[weight] = f
	return f


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(400)
	t.default_font_size = 17
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", FAINT)
	t.set_stylebox("normal", "Button", box(RAISED, 9, LINE))
	t.set_stylebox("hover", "Button", box(RAISED2, 9, Color(1, 1, 1, 0.16)))
	t.set_stylebox("pressed", "Button", box(GOLD_SOFT, 9, GOLD_LINE))
	t.set_stylebox("disabled", "Button", box(Color(0.12, 0.14, 0.17, 0.7), 9, Color(1, 1, 1, 0.04)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 14, LINE))
	t.set_stylebox("panel", "TooltipPanel", box(Color(0.06, 0.07, 0.09, 0.97), 8, GOLD_LINE))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font("font", "TooltipLabel", font(400))
	t.set_font_size("font_size", "TooltipLabel", 15)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.12)
	sb.set_corner_radius_all(3)
	t.set_stylebox("grabber", "VScrollBar", sb)
	t.set_stylebox("grabber_highlight", "VScrollBar", sb)
	t.set_stylebox("grabber_pressed", "VScrollBar", sb)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	return t


static func box(bg: Color, radius := 12, border := Color(0, 0, 0, 0), bw := 1, pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border.a > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.75
	s.content_margin_bottom = pad * 0.75
	s.anti_aliasing = true
	return s


static func panel(gold := false, pad := 16) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(PANEL, 14, GOLD_LINE if gold else LINE, 1, pad))
	return p


static func label(text: String, size := 17, color := TEXT, weight := 400, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if weight != 400:
		l.add_theme_font_override("font", font(weight))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 10
	return l


static func button(text: String, kind := "", size := 16) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", font(600))
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	match kind:
		"primary":
			b.add_theme_stylebox_override("normal", box(GOLD, 9))
			b.add_theme_stylebox_override("hover", box(GOLD.lightened(0.12), 9))
			b.add_theme_stylebox_override("pressed", box(GOLD.darkened(0.1), 9))
			b.add_theme_color_override("font_color", Color("15110a"))
			b.add_theme_color_override("font_hover_color", Color("15110a"))
			b.add_theme_color_override("font_pressed_color", Color("15110a"))
		"gold":
			b.add_theme_stylebox_override("normal", box(GOLD_SOFT, 9, GOLD_LINE))
			b.add_theme_stylebox_override("hover", box(Color(0.83, 0.66, 0.31, 0.26), 9, GOLD))
			b.add_theme_color_override("font_color", Color("e8c47a"))
			b.add_theme_color_override("font_hover_color", Color("f3d590"))
		"danger":
			b.add_theme_stylebox_override("normal", box(Color(0.5, 0.18, 0.14, 0.35), 9, Color(0.88, 0.44, 0.36, 0.6)))
			b.add_theme_stylebox_override("hover", box(Color(0.6, 0.2, 0.15, 0.5), 9, RED))
			b.add_theme_color_override("font_color", Color("f4c2b6"))
	return b


static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func sep_line() -> ColorRect:
	var r := ColorRect.new()
	r.color = LINE
	r.custom_minimum_size = Vector2(0, 1)
	return r


static func bar(value: float, color: Color, height := 8, max_v := 100.0) -> Control:
	var c := BarControl.new()
	c.value = value / max_v
	c.color = color
	c.custom_minimum_size = Vector2(40, height)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func chip(text: String, color := TEXT2, bg := RAISED) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, 8, Color(0, 0, 0, 0), 1, 8))
	var l := label(text, 14, color, 600)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


## A thin horizontal bar drawn right-to-left (fills from the right).
class BarControl extends Control:
	var value := 0.5
	var color := Color.WHITE
	var marker := -1.0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(1, 1, 1, 0.08), true)
		var w := size.x * clampf(value, 0.0, 1.0)
		draw_rect(Rect2(size.x - w, 0, w, size.y), color, true)
		if marker >= 0:
			var x := size.x - size.x * marker
			draw_rect(Rect2(x - 1, -3, 2, size.y + 6), Color.WHITE, true)
