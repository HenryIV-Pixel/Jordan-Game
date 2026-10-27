class_name Anim
extends RefCounted
## Motion for the interface, in the Paradox style: windows pop in, panels slide, lists cascade, numbers count.
## Containers own their children's positions, so items inside containers animate with scale and fade only.


static func pop_in(c: Control, dur := 0.22) -> void:
	c.modulate.a = 0.0
	c.scale = Vector2(0.94, 0.94)
	var set_pivot := func(): c.pivot_offset = c.size / 2.0
	c.resized.connect(set_pivot)
	set_pivot.call()
	var t := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "scale", Vector2.ONE, dur)
	t.tween_property(c, "modulate:a", 1.0, dur * 0.8).set_trans(Tween.TRANS_SINE)


static func fade_in(c: CanvasItem, dur := 0.18, delay := 0.0) -> void:
	c.modulate.a = 0.0
	c.create_tween().tween_property(c, "modulate:a", 1.0, dur).set_delay(delay)


## Slides a free-standing control (not inside a container) in from an offset.
static func slide_in(c: Control, offset: Vector2, dur := 0.38, delay := 0.0) -> void:
	var home := c.position
	c.position = home + offset
	c.modulate.a = 0.0
	var t := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "position", home, dur).set_delay(delay)
	t.tween_property(c, "modulate:a", 1.0, dur * 0.7).set_delay(delay)


## Cascades the children of a container: each fades and grows in a moment after the previous one.
static func cascade(box: Container, step := 0.035, dur := 0.2) -> void:
	var i := 0
	for ch in box.get_children():
		if ch is Control:
			var c: Control = ch
			c.modulate.a = 0.0
			var t := c.create_tween()
			t.tween_interval(i * step)
			t.tween_property(c, "modulate:a", 1.0, dur)
			i += 1


static func pulse(c: CanvasItem, strength := 0.25, period := 1.2) -> Tween:
	var t := c.create_tween().set_loops()
	t.tween_property(c, "modulate", Color(1 + strength, 1 + strength, 1 + strength), period / 2).set_trans(Tween.TRANS_SINE)
	t.tween_property(c, "modulate", Color.WHITE, period / 2).set_trans(Tween.TRANS_SINE)
	return t


## A label that counts from its old value to a new one, and flashes green or red on the way.
class CountLabel extends Label:
	var value := 0.0
	var fmt := func(v: float) -> String: return Game.ar(int(round(v)))
	var _tw: Tween

	func set_value(v: float, animate := true) -> void:
		if is_equal_approx(v, value) and text != "":
			return
		var from := value
		value = v
		if not animate or text == "":
			text = fmt.call(v)
			return
		if _tw:
			_tw.kill()
		_tw = create_tween()
		_tw.tween_method(func(x): text = fmt.call(x), from, v, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var flash := UI.GREEN if v > from else UI.RED
		add_theme_color_override("font_color", flash)
		_tw.tween_callback(func(): remove_theme_color_override("font_color"))


## A row of tabs whose gold underline slides to the selected one.
class TabStrip extends Control:
	signal selected(index: int)
	var labels: Array = []
	var current := 0
	var _row: HBoxContainer
	var _line: ColorRect
	var _buttons: Array = []

	func _init(names: Array) -> void:
		labels = names
		custom_minimum_size = Vector2(0, 52)

	func _ready() -> void:
		_row = UI.hbox(4)
		_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_row)
		for i in labels.size():
			var b := Button.new()
			b.text = labels[i]
			b.flat = true
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_override("font", UI.font(600))
			b.add_theme_font_size_override("font_size", 17)
			b.add_theme_color_override("font_color", UI.TEXT2)
			b.add_theme_color_override("font_hover_color", UI.TEXT)
			b.add_theme_color_override("font_pressed_color", UI.GOLD)
			b.custom_minimum_size = Vector2(120, 48)
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var idx := i
			b.pressed.connect(func(): select(idx))
			_row.add_child(b)
			_buttons.append(b)
		_line = ColorRect.new()
		_line.color = UI.GOLD
		_line.size = Vector2(80, 3)
		add_child(_line)
		await get_tree().process_frame
		_place(false)

	func select(i: int, emit := true) -> void:
		current = i
		_place(true)
		if emit:
			selected.emit(i)

	func _place(animate: bool) -> void:
		if _buttons.is_empty():
			return
		for j in _buttons.size():
			_buttons[j].add_theme_color_override("font_color", UI.GOLD if j == current else UI.TEXT2)
		var b: Button = _buttons[current]
		var r := Rect2(b.position + Vector2(18, b.size.y - 4), Vector2(b.size.x - 36, 3))
		if animate:
			var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			t.tween_property(_line, "position", r.position, 0.28)
			t.tween_property(_line, "size", r.size, 0.28)
		else:
			_line.position = r.position
			_line.size = r.size


## Round alert icons stacked on the side of the screen, like Paradox event icons.
class AlertStack extends VBoxContainer:
	var _items := {}

	func _init() -> void:
		add_theme_constant_override("separation", 10)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## alerts: Array of {id, glyph, tip, color, on_click(Callable)}
	func show_alerts(alerts: Array) -> void:
		var wanted := {}
		for a in alerts:
			wanted[a["id"]] = a
		for id in _items.keys():
			if not wanted.has(id):
				var old: Control = _items[id]
				_items.erase(id)
				var t := old.create_tween()
				t.tween_property(old, "modulate:a", 0.0, 0.2)
				t.tween_callback(old.queue_free)
		for a in alerts:
			if _items.has(a["id"]):
				var ex: AlertIcon = _items[a["id"]]
				ex.tooltip_text = a["tip"]
				continue
			var ic := AlertIcon.new()
			ic.glyph = a["glyph"]
			ic.color = a.get("color", UI.GOLD)
			ic.tooltip_text = a["tip"]
			ic.custom_minimum_size = Vector2(54, 54)
			if a.has("on_click"):
				ic.clicked.connect(a["on_click"])
			add_child(ic)
			_items[a["id"]] = ic
			Anim.pop_in(ic, 0.3)


class AlertIcon extends Control:
	signal clicked
	var glyph := "!"
	var color := UI.GOLD
	var _t := 0.0

	func _ready() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit()
			accept_event()

	func _draw() -> void:
		var c := size / 2
		var r := size.x / 2 - 3
		var glow := 0.25 + 0.15 * sin(_t * 3.0)
		draw_circle(c, r + 3, Color(color.r, color.g, color.b, glow))
		draw_circle(c, r, Color("141920"))
		draw_arc(c, r, 0, TAU, 40, color, 2.5, true)
		var f := UI.font(700)
		var sz := 22
		var w := f.get_string_size(glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, sz).x
		draw_string(f, Vector2(c.x - w / 2, c.y + 8), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, color)
