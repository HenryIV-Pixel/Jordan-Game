class_name Portrait
extends Control
## A placeholder portrait assembled from parts (headwear, skin, beard) whose expression follows a mood (-1 angry .. 1 pleased).

const SKIN := [Color("d9b08c"), Color("c09068"), Color("9a6d48"), Color("6e4a30")]

var look := {}
var mood := 0.0
var border := UI.GOLD_LINE
var you := false

static var _photos := {}


## A downloaded photo for a real person: first from a "portraits" folder next to the game's .exe
## (so photos can be added without rebuilding), then from the game's own res://portraits.
static func photo(id: String) -> Texture2D:
	if id == "":
		return null
	if _photos.has(id):
		return _photos[id]
	var tex: Texture2D = null
	var beside := OS.get_executable_path().get_base_dir().path_join("portraits").path_join(id + ".jpg")
	if FileAccess.file_exists(beside):
		var img := Image.load_from_file(beside)
		if img:
			tex = ImageTexture.create_from_image(img)
	elif ResourceLoader.exists("res://portraits/%s.jpg" % id):
		tex = load("res://portraits/%s.jpg" % id)
	_photos[id] = tex
	return tex


static func make(look_in: Dictionary, size_px: float, mood_in := 0.0) -> Portrait:
	var p := Portrait.new()
	p.look = look_in
	p.mood = mood_in
	p.custom_minimum_size = Vector2(size_px, size_px * 1.2)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func set_mood(m: float) -> void:
	mood = m
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var s := w / 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("222a33")
	bg.set_corner_radius_all(int(10 * s))
	bg.border_color = border
	bg.set_border_width_all(max(1, int(1.6 * s)))
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	var tex := Portrait.photo(look.get("photo", ""))
	if tex:
		var inset := Rect2(Vector2.ONE * 2 * s, size - Vector2.ONE * 4 * s)
		draw_texture_rect(tex, inset, false, Color(1, 0.97, 0.9))
		var frame := StyleBoxFlat.new()
		frame.draw_center = false
		frame.set_corner_radius_all(int(10 * s))
		frame.border_color = border
		frame.set_border_width_all(max(1, int(1.6 * s)))
		draw_style_box(frame, Rect2(Vector2.ZERO, size))
		return
	var skin: Color = SKIN[int(look.get("skin", 1)) % SKIN.size()]
	var hw: int = look.get("hw", -1)
	var cx := w * 0.5
	var fy := h * 0.44
	# shoulders and clothing
	var cloth := Color("3d4855") if not look.get("uniform", false) else Color("4b5a3a")
	if you:
		cloth = Color("3a4a5c")
	_poly([Vector2(cx - 36 * s, h - 2 * s), Vector2(cx - 30 * s, h * 0.78), Vector2(cx, h * 0.72), Vector2(cx + 30 * s, h * 0.78), Vector2(cx + 36 * s, h - 2 * s)], cloth)
	draw_line(Vector2(cx - 10 * s, h * 0.74), Vector2(cx, h * 0.88), Color("d9d2c2"), 1.6 * s)
	draw_line(Vector2(cx + 10 * s, h * 0.74), Vector2(cx, h * 0.88), Color("d9d2c2"), 1.6 * s)
	# neck and face
	draw_rect(Rect2(cx - 7 * s, fy + 14 * s, 14 * s, 14 * s), skin.darkened(0.08))
	_ellipse(Vector2(cx, fy), 17 * s, 21 * s, skin)
	# headwear
	match hw:
		0: # white kufiya with black agal
			_poly([Vector2(cx - 20 * s, fy - 2 * s), Vector2(cx - 18 * s, fy - 18 * s), Vector2(cx, fy - 26 * s), Vector2(cx + 18 * s, fy - 18 * s), Vector2(cx + 20 * s, fy - 2 * s),
				Vector2(cx + 26 * s, fy + 30 * s), Vector2(cx + 15 * s, fy + 22 * s), Vector2(cx + 16 * s, fy - 6 * s), Vector2(cx - 16 * s, fy - 6 * s), Vector2(cx - 15 * s, fy + 22 * s), Vector2(cx - 26 * s, fy + 30 * s)], Color("ece6d8"))
			draw_arc(Vector2(cx, fy - 4 * s), 19 * s, PI * 1.08, PI * 1.92, 16, Color("15191e"), 3.2 * s)
			draw_arc(Vector2(cx, fy - 1 * s), 19 * s, PI * 1.08, PI * 1.92, 16, Color("15191e"), 2.6 * s)
		1: # red tarboush
			_poly([Vector2(cx - 14 * s, fy - 12 * s), Vector2(cx - 12 * s, fy - 30 * s), Vector2(cx + 12 * s, fy - 30 * s), Vector2(cx + 14 * s, fy - 12 * s)], Color("8e2b1e"))
			draw_line(Vector2(cx + 4 * s, fy - 30 * s), Vector2(cx + 13 * s, fy - 20 * s), Color("15191e"), 1.6 * s)
		2: # grey hair
			_ellipse(Vector2(cx, fy - 14 * s), 17 * s, 9 * s, Color("8a8a86"))
		_: # dark hair
			_ellipse(Vector2(cx, fy - 14 * s), 17 * s, 9 * s, Color("2a2116"))
	if look.get("uniform", false):
		_poly([Vector2(cx - 17 * s, fy - 12 * s), Vector2(cx - 15 * s, fy - 26 * s), Vector2(cx + 15 * s, fy - 26 * s), Vector2(cx + 19 * s, fy - 12 * s)], Color("4b5a3a"))
		draw_rect(Rect2(cx - 4 * s, fy - 24 * s, 8 * s, 5 * s), UI.GOLD)
	# eyes and brows follow the mood
	var brow := -mood * 2.0 * s
	draw_circle(Vector2(cx - 7 * s, fy - 1 * s), 1.6 * s, Color("2a2116"))
	draw_circle(Vector2(cx + 7 * s, fy - 1 * s), 1.6 * s, Color("2a2116"))
	draw_line(Vector2(cx - 11 * s, fy - 6 * s + brow), Vector2(cx - 4 * s, fy - 6 * s - brow), Color("2a2116"), 1.4 * s)
	draw_line(Vector2(cx + 4 * s, fy - 6 * s - brow), Vector2(cx + 11 * s, fy - 6 * s + brow), Color("2a2116"), 1.4 * s)
	# moustache / beard
	var beard: int = look.get("beard", 1)
	var hair := Color("8a8a86") if look.get("old", false) else Color("2a2116")
	if beard == 0:
		_poly([Vector2(cx - 15 * s, fy + 6 * s), Vector2(cx + 15 * s, fy + 6 * s), Vector2(cx + 11 * s, fy + 20 * s), Vector2(cx, fy + 25 * s), Vector2(cx - 11 * s, fy + 20 * s)], hair)
	if beard <= 1:
		draw_line(Vector2(cx - 7 * s, fy + 8 * s), Vector2(cx + 7 * s, fy + 8 * s), hair, 2.6 * s)
	# mouth
	var curve := mood * 3.5 * s
	var pts := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		pts.append(Vector2(cx - 6 * s + 12 * s * t, fy + 13 * s + curve * (1.0 - pow(2.0 * t - 1.0, 2))))
	draw_polyline(pts, Color("5a2e22") if beard != 0 else Color("e8d8c8"), 1.4 * s)


func _poly(points: Array, c: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), c)


func _ellipse(center: Vector2, rx: float, ry: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, c)
