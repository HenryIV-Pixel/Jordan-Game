class_name ModalHost
extends Control
## Stacks pop-up windows over the screen: a dimmed backdrop that fades in and a card that pops in.

var stack: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func open(content: Control, closable := true, width := 760) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_meta("closable", closable)
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.05, 0.62)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Anim.fade_in(dim, 0.2)
	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.custom_minimum_size.x = width
	center.add_child(content)
	Anim.pop_in(content)
	stack.append(root)
	return root


func close() -> void:
	if stack.is_empty():
		return
	var root: Control = stack.pop_back()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := root.create_tween()
	t.tween_property(root, "modulate:a", 0.0, 0.12)
	t.tween_callback(root.queue_free)


func top_closable() -> bool:
	return not stack.is_empty() and stack[-1].get_meta("closable", false)


func header(v: VBoxContainer, title: String, subtitle := "", closable := true) -> void:
	var h := UI.hbox(10)
	h.add_child(UI.label(title, 26, UI.TEXT, 700))
	h.add_child(UI.spacer())
	if closable:
		var x := UI.button("✕", "", 16)
		x.custom_minimum_size = Vector2(40, 40)
		x.pressed.connect(close)
		h.add_child(x)
	v.add_child(h)
	if subtitle != "":
		v.add_child(UI.label(subtitle, 15, UI.TEXT2, 400, true))


## A button with a bold title and a smaller note underneath (used for choices).
static func choice(title: String, note: String, enabled := true, height := 58) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(0, height)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var bv := UI.vbox(0)
	bv.set_anchors_preset(Control.PRESET_FULL_RECT)
	bv.offset_left = 16
	bv.offset_right = -16
	bv.offset_top = 6
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.add_child(UI.label(title, 17, UI.TEXT if enabled else UI.FAINT, 700))
	if note != "":
		bv.add_child(UI.label(note, 13, UI.TEXT2))
	b.add_child(bv)
	return b
