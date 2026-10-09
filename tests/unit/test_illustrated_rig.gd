extends TestCase
## Milestone 5C skeletal rigs for painted poses: data is consistent, meshes are skinned sensibly,
## animations really move the limbs, and the feet stay planted (the root bone never animates).


func _spec() -> Dictionary:
	var config := load_config()
	return Appearance.render_spec(GameState.new_game(config, 1).creators[0], config)


func _rig(anim: String) -> IllustratedRig:
	var art := IllustratedArt.sprite(_spec(), anim)
	var rig := IllustratedRig.create(art, art["full_size"])
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	return rig


func test_rig_data_is_consistent() -> void:
	var manifest: Dictionary = IllustratedArt.manifest("res://assets/characters/ava/illustrated/illustrated.json").get("assets", {})
	for asset in ["pose_standing", "pose_walking", "pose_filming", "pose_selfie"]:
		var def := IllustratedRig.definition(asset)
		assert_false(def.is_empty(), asset + " has a rig")
		assert_true(manifest.has(asset), asset + " is an extracted painting")
		var names := {}
		var roots := 0
		for bone: Dictionary in def["bones"]:
			assert_false(names.has(bone["name"]), "unique bone " + str(bone["name"]))
			names[bone["name"]] = bone
			if str(bone.get("parent", "")).is_empty():
				roots += 1
		assert_eq(roots, 1, asset + " has one root bone")
		for bone: Dictionary in def["bones"]:
			var parent := str(bone.get("parent", ""))
			assert_true(parent.is_empty() or names.has(parent), "%s parent %s exists" % [bone["name"], parent])
		for anim_name: String in def["animations"]:
			for track: Dictionary in def["animations"][anim_name]["tracks"]:
				assert_true(names.has(track["bone"]), "%s/%s animates a real bone" % [asset, anim_name])
				assert_false(str(track["bone"]) == "pelvis", "%s/%s never moves the root (feet stay planted)" % [asset, anim_name])


func test_rig_builds_a_skinned_mesh() -> void:
	for anim in ["idle", "walk", "film", "selfie"]:
		var rig := _rig(anim)
		var mesh: Polygon2D = rig.get_node("Mesh")
		assert_gt(mesh.polygon.size(), 200, anim + " mesh covers the painting")
		assert_eq(mesh.get_bone_count(), (IllustratedRig.definition(rig.asset_name)["bones"] as Array).size(), anim + " every bone skinned")
		for v in range(0, mesh.polygon.size(), 7):
			var total := 0.0
			for b in mesh.get_bone_count():
				total += mesh.get_bone_weights(b)[v]
			assert_almost(total, 1.0, 0.01, "%s vertex %d weights sum to 1" % [anim, v])
		for b in mesh.get_bone_count():
			var weights := mesh.get_bone_weights(b)
			var owned := 0
			for w in weights:
				if w > 0.5:
					owned += 1
			assert_gt(owned, 3, "%s bone %s moves part of the painting" % [anim, mesh.get_bone_path(b)])
		rig.queue_free()


func test_walk_animation_alternates_the_legs() -> void:
	var rig := _rig("walk")
	assert_true(rig.animation_names().has("walk"))
	rig.pose_at("walk", 0.175) # a quarter of the 0.7 s cycle
	var left_a := rig.bone("shin_l").rotation
	var right_a := rig.bone("shin_r").rotation
	var pelvis_a := rig.bone("pelvis").transform
	rig.pose_at("walk", 0.525) # three quarters
	assert_gt(absf(rig.bone("shin_l").rotation - left_a), 0.2, "left lower leg swings")
	assert_gt(absf(rig.bone("shin_r").rotation - right_a), 0.2, "right lower leg swings")
	assert_lt((rig.bone("shin_l").rotation - left_a) * (rig.bone("shin_r").rotation - right_a), 0.0, "legs move in opposite directions")
	assert_true(rig.bone("pelvis").transform.is_equal_approx(pelvis_a), "feet stay planted")
	rig.queue_free()


func test_activity_animations_move() -> void:
	for entry: Array in [["idle", "idle", "chest"], ["film", "film", "wave_fore"], ["stream", "stream", "wave_fore"], ["selfie", "selfie", "peace_fore"]]:
		var rig := _rig(str(entry[0]))
		rig.pose_at(str(entry[1]), 0.0)
		var before := rig.bone(str(entry[2])).transform
		rig.pose_at(str(entry[1]), 0.2)
		assert_false(rig.bone(str(entry[2])).transform.is_equal_approx(before), "%s moves %s" % [entry[1], entry[2]])
		rig.queue_free()


func test_every_game_animation_maps_to_a_rig_motion() -> void:
	var view_script: GDScript = load("res://src/views/creator_view.gd")
	var map: Dictionary = view_script.get("RIG_ANIMS")
	for anim in ["idle", "walk", "film", "stream", "selfie", "socialise", "chat", "argue", "celebrate"]:
		assert_true(map.has(anim), anim + " has a rig motion")
