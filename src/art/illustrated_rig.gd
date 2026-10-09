class_name IllustratedRig
extends Node2D
## Skeletal animation for a painted pose (milestone 5C proof of concept), built entirely from data:
##   Skeleton2D + Bone2D hierarchy  joints from data/illustrated_rigs.json
##   Polygon2D                      a grid mesh over the painting's opaque pixels, skinned to the bones
##                                  (each pixel follows the bone whose region contains it; weights are
##                                  smoothed across the mesh so joints bend instead of tearing)
##   AnimationPlayer                looping sine tracks on bone rotation/position/scale, with blending
## Local coordinates are sprite pixels with the feet anchor at the origin; the owner scales the node.
##
## Flattened paintings have nothing painted behind the limbs, so motions stay small (breathing, arm
## and lower-leg swings, waves, bobs). Layered body-part art drops into the same structure later:
## each part becomes its own Polygon2D bound to the same bones.

const CELL := 4 # mesh cell size in sprite pixels
const KEYS_PER_LOOP := 24
const BLEND_TIME := 0.2
const RIGS_PATH := "res://data/illustrated_rigs.json"

static var _rig_data: Dictionary = {}
static var _meshes: Dictionary = {} # asset name -> {points, uvs, triangles, weights}

var asset_name: String = ""
var _skeleton: Skeleton2D
var _mesh: Polygon2D
var _player: AnimationPlayer
var _bone_paths: Dictionary = {} # bone name -> path from this node
var _default_animation: String = ""


## Rig definition for a painted asset, or {} when it has none.
static func definition(asset: String) -> Dictionary:
	if _rig_data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RIGS_PATH)) if FileAccess.file_exists(RIGS_PATH) else null
		_rig_data = parsed if parsed is Dictionary else {"rigs": {}}
	return (_rig_data.get("rigs", {}) as Dictionary).get(asset, {})


static func has_rig(asset: String) -> bool:
	return not definition(asset).is_empty()


## Builds a rig for a painted sprite. `art` comes from IllustratedArt.sprite() (texture, anchor);
## `full_size` is the full-resolution cut-out size the rig coordinates refer to.
static func create(art: Dictionary, full_size: Vector2) -> IllustratedRig:
	var rig := IllustratedRig.new()
	rig.asset_name = str(art["name"])
	rig.name = "Rig_" + rig.asset_name
	rig._build(art, full_size)
	return rig


## Plays a rig animation by name (falls back to the rig's own default motion), blending from the
## current one. `speed` scales playback (e.g. game speed for walking; 0 pauses).
func play(animation: String, speed: float = 1.0) -> void:
	var anim_name := animation if _player.has_animation(animation) else _default_animation
	if _player.current_animation != anim_name:
		_player.play(anim_name, BLEND_TIME)
	_player.speed_scale = speed


## Freezes the rig at `time` seconds into an animation (review sheets and tests).
func pose_at(animation: String, time: float) -> void:
	var anim_name := animation if _player.has_animation(animation) else _default_animation
	_player.play(anim_name)
	_player.seek(time, true)
	_player.pause()


## Tints the mesh by bone ownership (debugging rig regions).
func show_weights(enabled: bool) -> void:
	if not enabled:
		_mesh.vertex_colors = PackedColorArray()
		return
	var colours := PackedColorArray()
	colours.resize(_mesh.polygon.size())
	colours.fill(Color.WHITE)
	var palette := [Color(1, 0.4, 0.4), Color(0.4, 1, 0.4), Color(0.4, 0.6, 1), Color(1, 1, 0.3), Color(1, 0.4, 1), Color(0.3, 1, 1), Color(1, 0.7, 0.3), Color(0.7, 0.5, 1), Color(0.6, 1, 0.7)]
	for b in _mesh.get_bone_count():
		var weights := _mesh.get_bone_weights(b)
		for v in weights.size():
			if weights[v] > 0.5:
				colours[v] = palette[b % palette.size()]
	_mesh.vertex_colors = colours


func current_animation() -> String:
	return _player.current_animation


func animation_names() -> PackedStringArray:
	return _player.get_animation_list()


## Bone node by name (tests and debugging).
func bone(bone_name: String) -> Bone2D:
	return get_node_or_null(NodePath(str(_bone_paths.get(bone_name, "")))) as Bone2D


func _build(art: Dictionary, full_size: Vector2) -> void:
	var def := definition(asset_name)
	var texture: Texture2D = art["texture"]
	var anchor: Vector2 = art["anchor"]
	var k := Vector2(texture.get_width(), texture.get_height()) / full_size # full px -> sprite px
	var bones_def: Array = def.get("bones", [])

	_skeleton = Skeleton2D.new()
	_skeleton.name = "Skeleton"
	add_child(_skeleton)
	var nodes := {}
	var pivots := {}
	for entry: Dictionary in bones_def:
		var b := Bone2D.new()
		b.name = str(entry["name"])
		b.set_autocalculate_length_and_angle(false)
		b.set_length(12.0)
		nodes[b.name] = b
		pivots[b.name] = Vector2(float(entry["at"][0]), float(entry["at"][1])) * k - anchor
	# Parent-first attachment (data lists bones in region priority order, not hierarchy order).
	var attached := {}
	var remaining := bones_def.duplicate()
	while not remaining.is_empty():
		var progressed := false
		for entry: Dictionary in remaining.duplicate():
			var parent_name := str(entry.get("parent", ""))
			if parent_name.is_empty() or attached.has(parent_name):
				var b: Bone2D = nodes[str(entry["name"])]
				var parent: Node = _skeleton if parent_name.is_empty() else nodes[parent_name]
				var parent_pivot: Vector2 = Vector2.ZERO if parent_name.is_empty() else pivots[parent_name]
				parent.add_child(b)
				b.position = (pivots[b.name] as Vector2) - parent_pivot
				b.rest = b.transform
				attached[b.name] = true
				remaining.erase(entry)
				progressed = true
		if not progressed:
			push_error("IllustratedRig %s: bone hierarchy has a cycle or missing parent" % asset_name)
			break
	for bone_name: String in nodes:
		_bone_paths[bone_name] = _relative_path(nodes[bone_name])

	var mesh := _mesh_for(texture, anchor, k, bones_def)
	_mesh = Polygon2D.new()
	_mesh.name = "Mesh"
	_mesh.texture = texture
	_mesh.polygon = mesh["points"]
	_mesh.uv = mesh["uvs"]
	_mesh.polygons = mesh["triangles"]
	add_child(_mesh)
	move_child(_mesh, 0)
	_mesh.skeleton = NodePath("../Skeleton")
	var weights: Dictionary = mesh["weights"]
	for bone_name: String in nodes:
		_mesh.add_bone(NodePath(_relative_path(nodes[bone_name]).trim_prefix("Skeleton/")), weights[bone_name])

	_player = AnimationPlayer.new()
	_player.name = "Player"
	add_child(_player)
	var library := AnimationLibrary.new()
	var animations: Dictionary = def.get("animations", {})
	for anim_name: String in animations:
		library.add_animation(anim_name, _animation(animations[anim_name], nodes, k))
		if _default_animation.is_empty():
			_default_animation = anim_name
	_player.add_animation_library("", library)
	if not _default_animation.is_empty():
		_player.play(_default_animation)


func _relative_path(node: Node) -> String:
	var parts: Array[String] = []
	var current := node
	while current != null and current != self:
		parts.push_front(str(current.name))
		current = current.get_parent()
	return "/".join(parts)


## Looping animation: each track adds amp * sin(2pi * freq * t / length + phase) to the bone's rest.
func _animation(def: Dictionary, nodes: Dictionary, k: Vector2) -> Animation:
	var animation := Animation.new()
	var length := float(def.get("length", 1.0))
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR
	for track_def: Dictionary in def.get("tracks", []):
		var b: Bone2D = nodes.get(str(track_def["bone"]))
		if b == null:
			continue
		var prop := str(track_def.get("prop", "rotation"))
		var property: String = {"rotation": "rotation", "x": "position:x", "y": "position:y", "scale_y": "scale:y"}.get(prop, "rotation")
		var path := _relative_path(b) + ":" + property
		var rest := 0.0
		var amp := float(track_def.get("amp", 0.0))
		match prop:
			"x":
				rest = b.position.x
				amp *= k.x
			"y":
				rest = b.position.y
				amp *= k.y
			"scale_y":
				rest = b.scale.y
			_:
				rest = b.rotation
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath(path))
		animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
		var freq := float(track_def.get("freq", 1.0))
		var phase := float(track_def.get("phase", 0.0))
		var use_abs := bool(track_def.get("abs", false))
		for i in KEYS_PER_LOOP + 1:
			var t := length * i / KEYS_PER_LOOP
			var s := sin(TAU * freq * t / length + phase)
			animation.track_insert_key(track, t, rest + amp * (absf(s) if use_abs else s))
	return animation


## Grid mesh over the opaque pixels with smoothed per-bone weights (cached per asset).
static func _mesh_for(texture: Texture2D, anchor: Vector2, k: Vector2, bones_def: Array) -> Dictionary:
	var key := "%s|%d" % [texture.resource_path, bones_def.hash()]
	if _meshes.has(key):
		return _meshes[key]
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	var w := image.get_width()
	var h := image.get_height()
	var cols := ceili(float(w) / CELL)
	var rows := ceili(float(h) / CELL)
	var index := {} # grid point -> vertex index
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var triangles: Array = []
	for gy in rows:
		for gx in cols:
			if not _cell_visible(image, gx * CELL, gy * CELL, w, h):
				continue
			var corners: Array[int] = []
			for corner: Vector2i in [Vector2i(gx, gy), Vector2i(gx + 1, gy), Vector2i(gx + 1, gy + 1), Vector2i(gx, gy + 1)]:
				if not index.has(corner):
					var uv := Vector2(mini(corner.x * CELL, w), mini(corner.y * CELL, h))
					index[corner] = points.size()
					points.append(uv - anchor)
					uvs.append(uv)
				corners.append(int(index[corner]))
			triangles.append(PackedInt32Array([corners[0], corners[1], corners[2]]))
			triangles.append(PackedInt32Array([corners[0], corners[2], corners[3]]))
	# Owner bone per vertex: the first bone whose region (full-size px) contains it; else the root.
	var root := ""
	var regions: Array = []
	for entry: Dictionary in bones_def:
		if str(entry.get("parent", "")).is_empty() and root.is_empty():
			root = str(entry["name"])
		if entry.has("region"):
			var poly := PackedVector2Array()
			for p: Array in entry["region"]:
				poly.append(Vector2(float(p[0]), float(p[1])))
			regions.append([str(entry["name"]), poly])
	var owners := PackedStringArray()
	owners.resize(points.size())
	for v in points.size():
		var full := uvs[v] / k
		owners[v] = root
		for region: Array in regions:
			if Geometry2D.is_point_in_polygon(full, region[1]):
				owners[v] = region[0]
				break
	var weights := {}
	for entry: Dictionary in bones_def:
		var bone_name := str(entry["name"])
		var arr := PackedFloat32Array()
		arr.resize(points.size())
		for v in points.size():
			arr[v] = 1.0 if owners[v] == bone_name else 0.0
		weights[bone_name] = arr
	# Smooth across mesh edges (never across empty space between limbs).
	var neighbours: Array = []
	neighbours.resize(points.size())
	for v in points.size():
		neighbours[v] = PackedInt32Array()
	for tri: PackedInt32Array in triangles:
		for a in 3:
			var n: PackedInt32Array = neighbours[tri[a]]
			for b in 3:
				if a != b and not n.has(tri[b]):
					n.append(tri[b])
			neighbours[tri[a]] = n
	for _pass in 3:
		for bone_name: String in weights:
			var src: PackedFloat32Array = weights[bone_name]
			var dst := src.duplicate()
			for v in points.size():
				var n: PackedInt32Array = neighbours[v]
				if n.is_empty():
					continue
				var sum := 0.0
				for u in n:
					sum += src[u]
				dst[v] = src[v] * 0.5 + sum / n.size() * 0.5
			weights[bone_name] = dst
	var totals := PackedFloat32Array()
	totals.resize(points.size())
	for bone_name: String in weights:
		var arr: PackedFloat32Array = weights[bone_name]
		for v in points.size():
			totals[v] += arr[v]
	for bone_name: String in weights:
		var arr: PackedFloat32Array = weights[bone_name]
		for v in points.size():
			if totals[v] > 0.0:
				arr[v] /= totals[v]
		weights[bone_name] = arr
	var mesh := {"points": points, "uvs": uvs, "triangles": triangles, "weights": weights}
	_meshes[key] = mesh
	return mesh


static func _cell_visible(image: Image, x0: int, y0: int, w: int, h: int) -> bool:
	for y in range(y0, mini(y0 + CELL, h)):
		for x in range(x0, mini(x0 + CELL, w)):
			if image.get_pixel(x, y).a > 0.03:
				return true
	return false
