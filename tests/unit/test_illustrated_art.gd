extends TestCase
## Milestone 5B painted art: extracted assets are clean and consistent, paintings are only used when
## they truthfully show a creator's look, poses and expressions map correctly, other creators keep
## the procedural renderer, and the art mode survives saving.

const ART := "res://assets/characters/ava/illustrated/illustrated.json"


func _ava(config: GameConfig) -> CreatorState:
	return GameState.new_game(config, 1).creators[0]


func _spec(creator: CreatorState, config: GameConfig) -> Dictionary:
	return Appearance.render_spec(creator, config)


func _with(creator: CreatorState, config: GameConfig, item_id: String) -> CreatorState:
	var copy := creator.clone()
	Appearance.apply_item(copy, config, config.look_item(item_id))
	return copy


func after_each() -> void:
	IllustratedArt.mode = "auto"


func test_extracted_assets_exist_with_transparent_backgrounds() -> void:
	var assets: Dictionary = IllustratedArt.manifest(ART).get("assets", {})
	assert_gt(assets.size(), 18, "every figure, bust and pose was extracted")
	for name: String in assets:
		var entry: Dictionary = assets[name]
		var files: Array = [str(entry["file"])]
		if entry.has("sprite"):
			files.append(str((entry["sprite"] as Dictionary)["file"]))
		for path: String in files:
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			assert_true(image != null and not image.is_empty(), "loads " + path)
			if image == null or image.is_empty():
				continue
			assert_true(image.detect_alpha() != Image.ALPHA_NONE, name + " has transparency")
			assert_almost(image.get_pixel(0, 0).a, 0.0, 0.01, name + " corner is transparent")
			assert_almost(image.get_pixel(image.get_width() - 1, image.get_height() - 1).a, 0.0, 0.01, name + " corner is transparent")
			var centre := image.get_pixel(image.get_width() / 2, int(image.get_height() * 0.35)) # torso / hair
			if str(entry["kind"]) == "full_body" or str(entry["kind"]) == "bust":
				assert_gt(centre.a, 0.9, name + " figure is opaque in the middle")


## Walks in from both sides of every third row to the first solid pixel and checks the edge isn't
## the paper colour (a light halo). Painted fabrics like the white cover-up are far from paper.
func test_cutout_edges_have_no_paper_halo() -> void:
	var paper := Color8(229, 220, 214)
	var assets: Dictionary = IllustratedArt.manifest(ART).get("assets", {})
	for name: String in assets:
		var entry: Dictionary = assets[name]
		if str(entry["kind"]) == "scene":
			continue
		for path: String in [str(entry["file"]), str((entry.get("sprite", entry) as Dictionary)["file"])]:
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			var edges := 0
			var halo := 0
			for y in range(0, image.get_height(), 3):
				for dir: int in [1, -1]:
					var x := 0 if dir > 0 else image.get_width() - 1
					while x >= 0 and x < image.get_width() and image.get_pixel(x, y).a < 0.5:
						x += dir
					if x < 0 or x >= image.get_width():
						continue
					edges += 1
					var c := image.get_pixel(x, y)
					var d := Vector3(c.r - paper.r, c.g - paper.g, c.b - paper.b).length() * 255.0
					var paper_hue := absf((c.r - c.g) - (paper.r - paper.g)) * 255.0 < 6.0 and c.b < c.g
					if d < 18.0 and paper_hue:
						halo += 1
			# Downscaled sprites average sheer fabric folds (grey) with highlights into beige-ish edge
			# pixels on the swimwear cover-up, so they get a looser limit than the full-size art.
			var limit := 0.03 if path.contains("/full/") or path.contains("/portrait/") else 0.08
			assert_lt(float(halo) / maxf(edges, 1.0), limit, "%s edge is clean (%d of %d paper-coloured)" % [path, halo, edges])


func test_figures_share_a_consistent_house_scale() -> void:
	var assets: Dictionary = IllustratedArt.manifest(ART).get("assets", {})
	for name in ["master_front", "turn_front", "outfit_casual", "pose_standing"]:
		var sprite: Dictionary = (assets[name] as Dictionary)["sprite"]
		var entry: Dictionary = assets[name]
		var height := float(entry["figure_height_px"]) * float(entry["units_per_px"])
		assert_almost(height, 124.0, 1.0, name + " stands as tall as a 168 cm procedural creator")
		assert_gt(float((sprite["anchor"] as Array)[1]), float((sprite["size"] as Array)[1]) - 10.0, name + " feet anchor near the bottom")
	var walking: Dictionary = assets["pose_walking"]
	var standing: Dictionary = assets["pose_standing"]
	assert_almost(float(walking["figure_height_px"]) / float(standing["figure_height_px"]), 1.0, 0.08, "poses keep one scale")


func test_every_referenced_painting_exists() -> void:
	var config := load_config()
	var assets: Dictionary = IllustratedArt.manifest(ART).get("assets", {})
	var def: Dictionary = config.illustrated["creators"]["ava"]
	for key in ["full_body", "expressions"]:
		for id in (def[key] as Dictionary):
			assert_true(assets.has(str(def[key][id])), "%s %s -> %s" % [key, id, def[key][id]])
	for outfit in (def["sprites"] as Dictionary):
		for anim in (def["sprites"][outfit] as Dictionary):
			assert_true(assets.has(str(def["sprites"][outfit][anim])), "sprite %s/%s" % [outfit, anim])
	for expression in CreatorMood.EXPRESSIONS:
		assert_true((def["expressions"] as Dictionary).has(expression), "painted " + expression)


func test_paintings_only_used_when_they_match_her_look() -> void:
	var config := load_config()
	var ava := _ava(config)
	assert_true(IllustratedArt.use_art(_spec(ava, config)), "new-game Ava matches her paintings")
	for item_id in ["makeup:glam", "outfit:fitness", "outfit:bikini", "outfit:glamour"]:
		assert_true(IllustratedArt.use_art(_spec(_with(ava, config, item_id), config)), item_id + " is painted")
	var cases := {
		"breast_augmentation": "Breast augmentation", "bbl": "Brazilian butt lift", "lip_filler": "Lip filler",
		"hair_color:blonde": "Platinum blonde", "hair_style:bob": "Shoulder bob", "outfit:lingerie": "Lace lingerie set",
		"rose_tattoo": "Rose thigh tattoo", "nose_piercing": "Nose stud", "makeup:smoky_alt": "Smoky alt",
	}
	for item_id: String in cases:
		var spec := _spec(_with(ava, config, item_id), config)
		var cover: Dictionary = spec["art_cover"]
		assert_false(IllustratedArt.use_art(spec), item_id + " falls back to the procedural renderer")
		assert_true((cover["missing"] as Array).has(cases[item_id]), "%s listed as not painted: %s" % [item_id, cover["missing"]])


func test_art_modes() -> void:
	var config := load_config()
	var augmented := _spec(_with(_ava(config), config, "breast_augmentation"), config)
	IllustratedArt.mode = "always"
	assert_true(IllustratedArt.use_art(augmented), "always shows the painting for review")
	IllustratedArt.mode = "off"
	assert_false(IllustratedArt.use_art(_spec(_ava(config), config)), "off uses the procedural renderer")


func test_other_creators_are_unaffected() -> void:
	var config := load_config()
	IllustratedArt.mode = "always"
	for template_id in config.creator_order:
		if template_id == "ava":
			continue
		var spec := _spec(CreatorSetup.create(config.creator_templates[template_id], config), config)
		assert_false(IllustratedArt.has_art(spec), template_id + " has no paintings")
		assert_false(IllustratedArt.use_art(spec), template_id + " keeps procedural art even in 'always'")
		assert_gt(CreatorRenderer.record(spec, "idle", 0.0).size(), 60, template_id + " still renders")


func test_house_poses_map_to_paintings() -> void:
	var config := load_config()
	var spec := _spec(_ava(config), config)
	assert_eq(str(IllustratedArt.sprite(spec, "idle")["name"]), "pose_standing")
	assert_eq(str(IllustratedArt.sprite(spec, "walk")["name"]), "pose_walking")
	assert_eq(str(IllustratedArt.sprite(spec, "walk", true)["name"]), "turn_back", "back view on the stairs")
	assert_eq(str(IllustratedArt.sprite(spec, "film")["name"]), "pose_filming")
	assert_eq(str(IllustratedArt.sprite(spec, "selfie")["name"]), "pose_selfie")
	assert_eq(str(IllustratedArt.sprite(spec, "sleep")["name"]), "pose_lying", "painted sleeper on the bed")
	assert_eq(str(IllustratedArt.sprite(spec, "sleep")["kind"]), "lying")
	assert_true(IllustratedArt.sprite(spec, "recline").is_empty(), "recline keeps the procedural animation")
	var glamour := _spec(_with(_ava(config), config, "outfit:glamour"), config)
	assert_true(IllustratedArt.sprite(glamour, "sleep").is_empty(), "a standing outfit painting is never laid on the bed")
	var fitness := _spec(_with(_ava(config), config, "outfit:fitness"), config)
	assert_eq(str(IllustratedArt.sprite(fitness, "film")["name"]), "outfit_fitness", "painted outfit stands in for unpainted poses")


func test_wardrobe_preview_never_changes_state() -> void:
	var config := load_config()
	var ava := _ava(config)
	var before := JSON.stringify(ava.look) + JSON.stringify(ava.owned_styles)
	var spec := _spec(ava, config)
	for entry: Array in IllustratedArt.outfits(spec):
		assert_false(IllustratedArt.full_body(spec, str(entry[0])).is_empty(), "preview " + str(entry[0]))
	assert_eq(IllustratedArt.outfits(spec).size(), 4, "casual, glamour, fitness and swimwear")
	assert_eq(JSON.stringify(ava.look) + JSON.stringify(ava.owned_styles), before, "look and purchases untouched")


func test_mood_drives_expressions() -> void:
	var config := load_config()
	var ava := _ava(config)
	ava.activity_id = "idle"
	ava.mood = 80.0
	assert_eq(CreatorMood.expression(ava, 0.0), "happy")
	ava.mood = 60.0
	assert_eq(CreatorMood.expression(ava, 0.0), "confident")
	ava.mood = 20.0
	assert_eq(CreatorMood.expression(ava, 0.0), "sad")
	ava.mood = 35.0
	ava.stats["drama"] = 80.0
	assert_eq(CreatorMood.expression(ava, 0.0), "angry", "low mood + dramatic = angry")
	ava.mood = 60.0
	ava.activity_id = CreatorBrain.WORK
	assert_eq(CreatorMood.expression(ava, 0.0), "playful", "on camera")
	ava.reaction = {"kind": "negative", "anim": "argue", "until": 100.0}
	assert_eq(CreatorMood.expression(ava, 10.0), "angry", "bickering")
	ava.reaction = {"kind": "positive", "anim": "celebrate", "until": 100.0}
	assert_eq(CreatorMood.expression(ava, 10.0), "happy", "celebrating")
	assert_eq(CreatorMood.procedural("sad", "smile"), "sad")
	assert_eq(CreatorMood.procedural("confident", "sultry"), "sultry", "procedural creators keep their signature")
	for name: String in CreatorMood.PROCEDURAL:
		var mapped := CreatorMood.procedural(name, "smile")
		assert_true(FacePainter.EXPRESSIONS.has(mapped), name + " has a procedural face")


func test_art_mode_survives_save_and_old_saves_default_to_auto() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 1)
	state.settings["illustrated_art"] = "off"
	var loaded := SaveSystem.from_save_dict(JSON.parse_string(JSON.stringify(SaveSystem.to_save_dict(state, 1000.0))))
	assert_eq(str(loaded.settings.get("illustrated_art", "")), "off")
	var old := GameState.new_game(config, 1)
	old.settings.erase("illustrated_art")
	var reloaded := SaveSystem.from_save_dict(JSON.parse_string(JSON.stringify(SaveSystem.to_save_dict(old, 1000.0))))
	assert_eq(str(reloaded.settings.get("illustrated_art", "auto")), "auto", "missing setting means auto")
	assert_true(Appearance.illustrated_coverage(reloaded.creators[0], config)["ok"], "a reloaded Ava still matches")
