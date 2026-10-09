extends TestCase
## Milestone 5A character art: the modular renderer responds to measurements, procedures and
## styling, every pose renders, outfits are valid data, and creators never share look state.
## Rendering is checked headlessly by recording draw commands (CreatorRenderer.record).

const ANIMS := ["idle", "walk", "film", "selfie", "stream", "socialise", "chat", "celebrate", "argue", "sleep", "recline", "showcase"]
const KNOWN_KINDS := ["top", "dress", "skirt", "briefs", "bra"]


func _creator(config: GameConfig, template_id: String) -> CreatorState:
	return CreatorSetup.create(config.creator_templates[template_id], config)


## Bounds of every recorded point (canvas units, feet at the origin).
func _bounds(commands: Array) -> Rect2:
	var rect := Rect2()
	var first := true
	for command: Array in commands:
		for p: Vector2 in (command[1] as PackedVector2Array):
			if first:
				rect = Rect2(p, Vector2.ZERO)
				first = false
			else:
				rect = rect.expand(p)
	return rect


## Widest x of the figure within a horizontal band (model units, scale 1).
func _extent(commands: Array, y0: float, y1: float) -> Vector2:
	var lo := INF
	var hi := -INF
	for command: Array in commands:
		for p: Vector2 in (command[1] as PackedVector2Array):
			if p.y >= y0 and p.y <= y1:
				lo = minf(lo, p.x)
				hi = maxf(hi, p.x)
	return Vector2(lo, hi)


func test_every_pose_renders_for_every_creator() -> void:
	var config := load_config()
	for template_id in config.creator_order:
		var spec := Appearance.render_spec(_creator(config, template_id), config)
		for anim: String in ANIMS:
			var commands := CreatorRenderer.record(spec, anim, 1.3)
			assert_gt(commands.size(), 60, "%s draws %s" % [template_id, anim])


func test_figure_height_follows_measurements() -> void:
	var config := load_config()
	var lily := Appearance.render_spec(_creator(config, "lily"), config) # 155 cm
	var sienna := Appearance.render_spec(_creator(config, "sienna"), config) # 175 cm
	var short_h := _bounds(CreatorRenderer.record(lily, "idle", 0.0, 1.0)).size.y
	var tall_h := _bounds(CreatorRenderer.record(sienna, "idle", 0.0, 1.0)).size.y
	assert_gt(tall_h, short_h * 1.08, "the taller creator is drawn visibly taller")


func test_breast_augmentation_and_bbl_change_the_silhouette() -> void:
	var config := load_config()
	var ava := _creator(config, "ava")
	var base := FigureModel.for_spec(Appearance.render_spec(ava, config))
	var augmented := FigureModel.for_spec(Appearance.render_spec(Appearance.preview(ava, config, "breast_augmentation"), config))
	var bbl := FigureModel.for_spec(Appearance.render_spec(Appearance.preview(ava, config, "bbl"), config))
	var near_breast := func(model: FigureModel) -> float:
		var b: Array = model.breasts[1]
		return (b[0] as Vector2).x + (b[1] as Vector2).x
	assert_gt(near_breast.call(augmented), near_breast.call(base) + 2.0, "augmented bust projects further")
	assert_lt(bbl.far_x(-55.0), base.far_x(-55.0) - 2.0, "BBL seat curve sticks out further")
	assert_gt(bbl.near_x(-55.0), base.near_x(-55.0) + 1.0, "BBL hips are wider")
	assert_almost(bbl.near_x(-83.0), base.near_x(-83.0), 0.01, "BBL leaves the chest alone")


func test_garments_follow_the_body() -> void:
	var config := load_config()
	var ava := _creator(config, "ava")
	Appearance.apply_item(ava, config, config.look_item("outfit:glamour"))
	var dress_extent := func(creator: CreatorState) -> Vector2:
		var spec := Appearance.render_spec(creator, config)
		var rec := InkPen.new().recorder()
		rec.px = 3.0
		OutfitPainter.draw_torso_garments(rec, FigureModel.for_spec(spec), spec["outfit"], Color.WHITE)
		return _extent(rec.commands(), -86.0, -80.0)
	var before: Vector2 = dress_extent.call(ava)
	Appearance.apply_item(ava, config, config.look_item("breast_augmentation"))
	var after: Vector2 = dress_extent.call(ava)
	assert_gt(after.y, before.y + 1.5, "the dress grows with the bust")


func test_waist_and_hips_shape_the_torso() -> void:
	var config := load_config()
	var chloe := FigureModel.for_spec(Appearance.render_spec(_creator(config, "chloe"), config)) # 61 cm waist
	var roxy := FigureModel.for_spec(Appearance.render_spec(_creator(config, "roxy"), config)) # 68 cm waist, 104 hips
	var lily := FigureModel.for_spec(Appearance.render_spec(_creator(config, "lily"), config)) # 86 cm hips
	assert_lt(chloe.near_x(-69.5) - chloe.far_x(-69.5), roxy.near_x(-69.5) - roxy.far_x(-69.5), "slimmer waist is narrower")
	assert_gt(roxy.near_x(-55.0) - roxy.far_x(-55.0), lily.near_x(-55.0) - lily.far_x(-55.0) + 3.0, "curvier hips are wider")


func test_outfit_data_is_complete() -> void:
	var config := load_config()
	var options: Dictionary = config.look_options["outfit"]
	assert_true(options.has("bikini"), "swimwear exists")
	assert_false(config.look_item("outfit:bikini").is_empty(), "swimwear can be bought")
	for outfit_id in options:
		var outfit: Dictionary = options[outfit_id]
		var pieces := OutfitPainter.pieces(outfit)
		assert_gt(pieces.size(), 0, outfit_id + " has garments")
		var covers_chest := false
		for piece: Dictionary in pieces:
			var kind := str(piece.get("kind", ""))
			assert_true(KNOWN_KINDS.has(kind), "%s: known garment kind %s" % [outfit_id, kind])
			if kind in ["top", "dress", "bra"]:
				covers_chest = true
		assert_true(covers_chest, outfit_id + " covers the chest (non-explicit)")
		assert_true(outfit.has("shoes"), outfit_id + " has shoes")


func test_legacy_top_bottom_outfit_data_still_renders() -> void:
	var config := load_config()
	var spec := Appearance.render_spec(_creator(config, "ava"), config)
	spec["outfit"] = {"id": "old", "top": {"from": -89, "to": -71, "color": "#ff7ab8"}, "bottom": {"from": -64, "to": -45, "color": "#5b7db1"}}
	assert_eq(OutfitPainter.pieces(spec["outfit"]).size(), 2, "top + bottom become pieces")
	assert_gt(CreatorRenderer.record(spec, "idle", 0.0).size(), 60, "renders")


func test_styling_changes_the_render() -> void:
	var config := load_config()
	var ava := _creator(config, "ava")
	var base := CreatorRenderer.record(Appearance.render_spec(ava, config), "idle", 0.0)
	for item_id in ["hair_style:bob", "hair_color:pink", "makeup:glam", "outfit:lingerie", "outfit:bikini", "rose_tattoo", "arm_sleeve", "nose_piercing"]:
		var changed := Appearance.preview(ava, config, item_id)
		var commands := CreatorRenderer.record(Appearance.render_spec(changed, config), "idle", 0.0)
		assert_true(str(commands) != str(base), item_id + " changes the drawing")


func test_tattoos_follow_the_pose() -> void:
	var config := load_config()
	var jade := _creator(config, "jade") # rose thigh tattoo, fishnets
	var spec := Appearance.render_spec(jade, config)
	var rose := Color(0.8, 0.1, 0.26)
	var find := func(commands: Array) -> Vector2:
		for command: Array in commands:
			var colour: Variant = command[2] if command.size() > 2 else null
			if colour is PackedColorArray and not (colour as PackedColorArray).is_empty():
				colour = (colour as PackedColorArray)[0]
			if colour is Color and (colour as Color).is_equal_approx(rose):
				var points: PackedVector2Array = command[1]
				return points[0]
		return Vector2.INF
	var standing: Vector2 = find.call(CreatorRenderer.record(spec, "idle", 0.0, 3.0)) / 3.0
	var stepping: Vector2 = find.call(CreatorRenderer.record(spec, "walk", 0.17, 3.0)) / 3.0
	assert_true(standing != Vector2.INF and stepping != Vector2.INF, "the rose is drawn")
	assert_gt(standing.distance_to(stepping), 0.5, "the tattoo moves with the leg")
	assert_gt(standing.y, -50.0, "on the thigh")


func test_creators_have_independent_looks_and_rhythm() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 1)
	var ava := state.creators[0]
	var mia := CreatorSetup.create(config.creator_templates["mia"], config, state)
	var mia_before := Appearance.render_spec(mia, config)
	state.cash = 100000.0
	Appearance.purchase(state, config, ava, "outfit:bikini")
	Appearance.purchase(state, config, ava, "breast_augmentation")
	assert_eq(Appearance.render_spec(mia, config), mia_before, "Mia's look is untouched")
	assert_true(float(Appearance.render_spec(ava, config)["seed"]) != float(mia_before["seed"]), "creators blink and sway out of sync")
	assert_eq(str(Appearance.render_spec(ava, config)["expression"]), "smile", "Ava's signature expression")
	assert_eq(str(Appearance.render_spec(_creator(config, "chloe"), config)["expression"]), "sultry", "bombshell expression")


func test_every_expression_resolves() -> void:
	for name: String in FacePainter.EXPRESSIONS:
		var expr := FacePainter.expression(name, 1.0, 0.0)
		assert_true(str(expr["key"]).begins_with(str(expr["mouth"])), name + " has a cache key")
	assert_eq(FacePainter.expression("sleep", 0.0, 0.0)["lids"], [0.0, 0.0], "sleeping eyes are closed")
