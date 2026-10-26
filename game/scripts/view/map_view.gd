class_name MapView
extends Node2D
## The living map: terrain, roads, rail, towns, day and night, tokens and crisis effects. Coordinates are map units
## (the same units as the first version's map data, about 0.675 km each).

signal town_clicked(id: String)

const ZMIN := 0.75
const ZMAX := 7.0

var cam: Camera2D
var terrain: Sprite2D
var vectors: VectorLayer
var glows: GlowLayer
var marks: MarkLayer
var tint: CanvasModulate
var polylines := {}
var buildings := {}
var hover := ""
var _drag := false
var _drag_from := Vector2.ZERO
var _moved := 0.0
var _last_zoom := -1.0
var _glow_tex: Texture2D
var _t := 0.0
var _focus_tween: Tween


func _ready() -> void:
	var tj: Dictionary = JSON.parse_string(FileAccess.open("res://data/terrain.json", FileAccess.READ).get_as_text())
	terrain = Sprite2D.new()
	terrain.texture = load("res://data/terrain.jpg")
	terrain.centered = false
	terrain.position = Vector2(tj["x0"], tj["y0"])
	terrain.scale = Vector2.ONE / float(tj["s"])
	terrain.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(terrain)
	for layer in ["roads", "rail", "rivers", "districts", "border"]:
		var arr := []
		for pl in Game.map[layer]:
			var pts := PackedVector2Array()
			for i in range(0, pl.size() - 1, 2):
				pts.append(Vector2(pl[i], pl[i + 1]))
			arr.append(pts)
		polylines[layer] = arr
	for id in Game.towns:
		buildings[id] = _make_buildings(Game.towns[id])
	vectors = VectorLayer.new()
	vectors.map = self
	add_child(vectors)
	tint = CanvasModulate.new()
	add_child(tint)
	var overlay := CanvasLayer.new()
	overlay.layer = 1
	overlay.follow_viewport_enabled = true
	add_child(overlay)
	glows = GlowLayer.new()
	glows.map = self
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glows.material = mat
	overlay.add_child(glows)
	marks = MarkLayer.new()
	marks.map = self
	overlay.add_child(marks)
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.78, 0.45, 1))
	g.set_color(1, Color(1, 0.55, 0.2, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	_glow_tex = gt
	cam = Camera2D.new()
	add_child(cam)
	cam.position = Game.town_pos("salt") + Vector2(10, 4)
	cam.zoom = Vector2(3.2, 3.2)


func _make_buildings(t: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(t["id"])
	var n: int = [0, 14, 30, 55, 90, 150][int(t["size"])]
	var r: float = 1.4 + t["size"] * 1.0
	var out := []
	var c := Vector2(t["pos"][0], t["pos"][1])
	for i in n:
		var a := rng.randf() * TAU
		var d := pow(rng.randf(), 0.7) * r
		out.append({"p": c + Vector2(cos(a) * d * 1.15, sin(a) * d), "w": 0.5 + rng.randf() * 0.5, "h": 0.4 + rng.randf() * 0.45, "lit": rng.randf(), "tone": rng.randf()})
	return out


func zoom() -> float:
	return cam.zoom.x


func focus(p: Vector2, z := -1.0) -> void:
	if _focus_tween:
		_focus_tween.kill()
	_focus_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_focus_tween.tween_property(cam, "position", p, 0.8)
	if z > 0:
		_focus_tween.parallel().tween_property(cam, "zoom", Vector2(z, z), 0.8)


func _process(delta: float) -> void:
	_t += delta
	var kb := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if kb != Vector2.ZERO:
		cam.position += kb * 700.0 * delta / zoom()
	if not is_equal_approx(_last_zoom, zoom()):
		_last_zoom = zoom()
		vectors.queue_redraw()
	# day and night tint
	var day := Game.daylight()
	var night := Color(0.33, 0.37, 0.52)
	var c := night.lerp(Color.WHITE, day)
	var h := Game.hourf()
	var golden: float = max(0.0, 1.0 - abs(h - 18.4) / 1.6) + max(0.0, 1.0 - abs(h - 6.3) / 1.2)
	c = c * Color(1.0, 1.0 - golden * 0.12, 1.0 - golden * 0.25)
	tint.color = c
	glows.queue_redraw()
	marks.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				var before := get_global_mouse_position()
				var z := clampf(zoom() * (1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), ZMIN, ZMAX)
				cam.zoom = Vector2(z, z)
				cam.position += before - get_global_mouse_position()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_drag = true
				_drag_from = mb.position
				_moved = 0.0
			else:
				_drag = false
				if _moved < 6 and mb.button_index == MOUSE_BUTTON_LEFT:
					var t := town_at(mb.position)
					if t != "":
						town_clicked.emit(t)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _drag:
			cam.position -= mm.relative / zoom()
			_moved += mm.relative.length()
		hover = town_at(mm.position)
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hover != "" else Input.CURSOR_ARROW)


func town_at(screen: Vector2) -> String:
	var world := get_canvas_transform().affine_inverse() * screen
	var best := ""
	var best_d := 18.0 / zoom()
	for id in Game.towns:
		if not town_visible(Game.towns[id]):
			continue
		var d := world.distance_to(Game.town_pos(id))
		if d < best_d:
			best_d = d
			best = id
	return best


func town_visible(t: Dictionary) -> bool:
	var s: int = t["size"]
	var z := zoom()
	return s >= 3 or (s == 2 and z >= 1.25) or z >= 2.0


## World layer: roads, rail, rivers, districts, the kingdom border and town buildings.
class VectorLayer extends Node2D:
	var map: MapView

	func _draw() -> void:
		var z := map.zoom()
		var px := 1.0 / z
		for pl in map.polylines["districts"]:
			draw_polyline(pl, Color(1, 0.96, 0.86, 0.14), 1.0 * px, true)
		for pl in map.polylines["rivers"]:
			draw_polyline(pl, Color(0.36, 0.62, 0.74, 0.95), max(1.4 * px, 0.35), true)
		var rw := clampf(1.2 * px, 0.18, 0.7)
		for pl in map.polylines["roads"]:
			draw_polyline(pl, Color(0.98, 0.93, 0.8, 0.42), rw, true)
		for pl in map.polylines["rail"]:
			draw_polyline(pl, Color(0.16, 0.12, 0.1, 0.85), rw * 2.0, true)
			_dashed(pl, Color(0.94, 0.88, 0.75, 0.8), rw * 0.8, rw * 3.0)
		for pl in map.polylines["border"]:
			draw_polyline(pl, Color(0.83, 0.66, 0.31, 0.22), 7.0 * px, true)
			draw_polyline(pl, Color(0.91, 0.77, 0.48, 0.95), 1.7 * px, true)
		var show := clampf((z - 2.4) / 1.4, 0.0, 1.0)
		if show > 0:
			for id in map.buildings:
				for b in map.buildings[id]:
					var c: float = 0.78 + b["tone"] * 0.16
					draw_rect(Rect2(b["p"] + Vector2(0.07, 0.07), Vector2(b["w"], b["h"])), Color(0.12, 0.09, 0.07, 0.35 * show))
					draw_rect(Rect2(b["p"], Vector2(b["w"], b["h"])), Color(c, c - 0.05, c - 0.16, show))

	func _dashed(pl: PackedVector2Array, c: Color, w: float, dash: float) -> void:
		var on := true
		var left := dash
		for i in range(1, pl.size()):
			var a := pl[i - 1]
			var b := pl[i]
			var seg := a.distance_to(b)
			var pos := 0.0
			while pos < seg:
				var step: float = min(left, seg - pos)
				if on:
					draw_line(a.lerp(b, pos / seg), a.lerp(b, (pos + step) / seg), c, w)
				pos += step
				left -= step
				if left <= 0.0001:
					on = not on
					left = dash


## Additive light: town lights at night and fire glow.
class GlowLayer extends Node2D:
	var map: MapView

	func _draw() -> void:
		var night := 1.0 - Game.daylight()
		var z := map.zoom()
		if night > 0.05:
			for id in Game.towns:
				var t: Dictionary = Game.towns[id]
				var r: float = (5.0 + t["size"] * 5.0) * (0.75 if t["kind"] == "nb" else 1.0) / pow(z, 0.35)
				var p := Game.town_pos(id)
				draw_texture_rect(map._glow_tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2), false, Color(1, 1, 1, 0.55 * night))
				if z > 2.6:
					for b in map.buildings[id]:
						if b["lit"] < 0.5:
							var fl := 0.75 + 0.25 * sin(map._t * 3.0 + b["tone"] * 20.0)
							draw_rect(Rect2(b["p"] + Vector2(b["w"], b["h"]) * 0.35, Vector2(b["w"], b["h"]) * 0.3), Color(1, 0.84, 0.55, 0.9 * night * fl))
		# fire and anger at Salt when the water crisis boils over
		var w: Dictionary = Game.water
		if w["solved_by"] == "" and w["severity"] >= 70:
			var p := Game.town_pos("salt") + Vector2(1.5, 1)
			var fl := 0.8 + 0.2 * sin(map._t * 13.0) * sin(map._t * 5.3)
			var r := 7.0 / pow(z, 0.3)
			draw_texture_rect(map._glow_tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2), false, Color(1, 0.55, 0.3, 0.6 * fl))


## Normal-blend overlay: town dots and labels at constant screen size, tokens, routes, crisis rings.
class MarkLayer extends Node2D:
	var map: MapView

	func _draw() -> void:
		var z := map.zoom()
		var inv := 1.0 / z
		var font := UI.font(600)
		var bold := UI.font(700)
		var t := map._t
		# crisis rings over Salt
		var w: Dictionary = Game.water
		if w["solved_by"] == "" and w["severity"] >= 50:
			var p := Game.town_pos("salt")
			for k in 3:
				var ph := fmod(t * 0.7 + k / 3.0, 1.0)
				var col := Color(0.88, 0.32, 0.24, (1.0 - ph) * (0.9 if w["severity"] >= 70 else 0.55))
				draw_arc(p, (10.0 + ph * 50.0) * inv, 0, TAU, 48, col, 2.5 * inv, true)
			if w["severity"] >= 70:
				for i in 14:
					var life := fmod(t * 0.3 + i / 14.0, 1.0)
					var sp := p + Vector2(4.0 * inv - life * 26.0 * inv + sin(i * 3.0 + t) * 3.0 * inv, -6.0 * inv - life * 70.0 * inv)
					draw_circle(sp, (5.0 + life * 16.0) * inv, Color(0.24, 0.23, 0.23, 0.32 * (1.0 - life)))
		# rival route and token
		var rv: Dictionary = Game.rival
		if Game.rival_visible():
			var rp := Game.rival_pos()
			if rp.distance_to(Game.player_pos()) < 30.0 * inv:
				rp += Vector2(-34, -10) * inv # stand beside you, not on top of you
			_token(rp, Color("e0705c"), "عيسى", inv, font)
		# player route
		var tr: Dictionary = Game.player["travel"]
		if not tr.is_empty():
			var path: Array = tr["path"]
			var pts := PackedVector2Array()
			for id in path:
				pts.append(Game.town_pos(id))
			_dashed_route(pts, inv, t)
		# towns
		for id in Game.towns:
			var town: Dictionary = Game.towns[id]
			if not map.town_visible(town):
				continue
			var p := Game.town_pos(id)
			var s: int = town["size"]
			var faded: bool = town["kind"] == "nb"
			draw_set_transform(p, 0, Vector2(inv, inv))
			var r := 2.5 + s * 0.8
			var hovered: bool = id == map.hover
			if z < 3.0 or hovered:
				draw_circle(Vector2.ZERO, r + 1.6, Color(0.08, 0.06, 0.05, 0.95))
				draw_circle(Vector2.ZERO, r, Color("f4e2b4") if not faded else Color(0.78, 0.78, 0.78))
			if hovered:
				draw_arc(Vector2.ZERO, r + 7, 0, TAU, 32, UI.GOLD, 2.0, true)
			var fs := 22 if s >= 4 else 19 if s == 3 else 16
			if z >= 3.0:
				fs = int(fs * 1.15)
			var f := bold if s >= 3 else font
			var label: String = town["name"]
			var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			var ly := -(r + 8.0) if z < 3.0 else -(r + 16.0 + s * 4.0)
			var a := 0.72 if faded else 1.0
			draw_string_outline(f, Vector2(-tw / 2, ly), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0.07, 0.06, 0.05, 0.8 * a))
			draw_string(f, Vector2(-tw / 2, ly), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.98, 0.94, 0.84, a) if not faded else Color(0.85, 0.85, 0.85, a))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		# the player
		var pp := Game.player_pos()
		_token(pp, UI.GOLD, "أنت", inv, font)

	func _token(p: Vector2, c: Color, label: String, inv: float, font: Font) -> void:
		draw_set_transform(p, 0, Vector2(inv, inv))
		var pulse := 1.0 + 0.08 * sin(map._t * 3.0)
		draw_circle(Vector2(0, 2), 15 * pulse, Color(0, 0, 0, 0.35))
		draw_circle(Vector2.ZERO, 14 * pulse, Color(0.08, 0.09, 0.11))
		draw_arc(Vector2.ZERO, 14 * pulse, 0, TAU, 40, c, 3.0, true)
		draw_circle(Vector2(0, -3), 4.5, c.lightened(0.2))
		draw_colored_polygon(PackedVector2Array([Vector2(-8, 9), Vector2(-6, 3), Vector2(0, 1), Vector2(6, 3), Vector2(8, 9)]), c.lightened(0.2))
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 15).x
		draw_string_outline(font, Vector2(-tw / 2, 32), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(-tw / 2, 32), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, c.lightened(0.3))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	func _dashed_route(pts: PackedVector2Array, inv: float, t: float) -> void:
		var dash := 8.0 * inv
		var off := fmod(t * 20.0 * inv, dash * 2)
		for i in range(1, pts.size()):
			var a := pts[i - 1]
			var b := pts[i]
			var seg := a.distance_to(b)
			var pos := -off
			while pos < seg:
				var s0: float = max(pos, 0.0)
				var s1: float = min(pos + dash, seg)
				if s1 > s0:
					draw_line(a.lerp(b, s0 / seg), a.lerp(b, s1 / seg), Color(0.95, 0.8, 0.45, 0.95), 3.0 * inv)
				pos += dash * 2
