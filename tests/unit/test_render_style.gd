extends TestCase
## Refined renderer prototype (RenderStyle): applies only to the prototype creators, can be switched
## off, renders every pose for every look, keeps geometry and measurements, and never shares cached
## layers with the classic style.

const ANIMS := ["idle", "walk", "film", "selfie", "stream", "socialise", "chat", "celebrate", "argue", "sleep", "recline",
	"showcase", "sit", "sit_phone", "sit_chat"]


func _spec(config: GameConfig, template_id: String, style: String = "") -> Dictionary:
	var spec := Appearance.render_spec(CreatorSetup.create(config.creator_templates[template_id], config), config)
	if not style.is_empty():
		spec["render_style"] = style
	return spec


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


func _extent(commands: Array, y0: float, y1: float) -> float:
	var lo := INF
	var hi := -INF
	for command: Array in commands:
		for p: Vector2 in (command[1] as PackedVector2Array):
			if p.y >= y0 and p.y <= y1:
				lo = minf(lo, p.x)
				hi = maxf(hi, p.x)
	return hi - lo


func test_prototype_applies_only_to_mia() -> void:
	var config := load_config()
	assert_true(RenderStyle.refined(_spec(config, "mia")), "Mia uses the refined prototype")
	for id in ["roxy", "ava", "chloe"]:
		assert_eq(RenderStyle.of(_spec(config, id)), RenderStyle.CLASSIC, "%s keeps the classic renderer" % id)


func test_toggle_and_forced_style() -> void:
	var config := load_config()
	var mia := _spec(config, "mia")
	RenderStyle.enabled = false
	assert_eq(RenderStyle.of(mia), RenderStyle.CLASSIC, "the developer toggle switches the prototype off")
	RenderStyle.enabled = true
	mia["render_style"] = RenderStyle.CLASSIC
	assert_eq(RenderStyle.of(mia), RenderStyle.CLASSIC, "a spec can force classic (comparison sheets)")
	var roxy := _spec(config, "roxy", RenderStyle.REFINED)
	assert_true(RenderStyle.refined(roxy), "a spec can force refined")


func test_refined_renders_every_pose_for_every_creator() -> void:
	var config := load_config()
	for template_id in config.creator_order:
		var spec := _spec(config, template_id, RenderStyle.REFINED)
		for anim: String in ANIMS:
			for scale in [1.0, 3.0]:
				var commands := CreatorRenderer.record(spec, anim, 1.3, scale)
				assert_gt(commands.size(), 60, "%s draws %s refined at %.0fx" % [template_id, anim, scale])


func test_refined_supports_arbitrary_colours_and_styling() -> void:
	var config := load_config()
	var creator := CreatorSetup.create(config.creator_templates["mia"], config)
	for item_id in ["hair_style:curls", "makeup:glam", "outfit:glamour"]:
		var item := config.look_item(item_id)
		if not item.is_empty():
			Appearance.apply_item(creator, config, item)
	var spec := Appearance.render_spec(creator, config)
	spec["hair_color"] = "#22d3a6"
	spec["skin"] = "#5a3423"
	spec["eyes"] = "#c03aa0"
	spec["piercings"] = ["nose", "belly"]
	spec["tattoos"] = ["rose_thigh", "arm_sleeve"]
	assert_true(RenderStyle.refined(spec), "still the prototype creator")
	var commands := CreatorRenderer.record(spec, "film", 0.4, 3.0)
	assert_gt(commands.size(), 200, "custom colours and styling render")
	var hair_seen := false
	for command: Array in commands:
		var colours: PackedColorArray = command[2] if command[2] is PackedColorArray else PackedColorArray([command[2]])
		for colour in colours:
			if colour.a > 0.5 and absf(colour.h - Color("#22d3a6").h) < 0.03 and colour.s > 0.4:
				hair_seen = true
	assert_true(hair_seen, "an arbitrary hair colour is used for the hair")


func test_refined_keeps_size_and_pose_geometry() -> void:
	var config := load_config()
	for anim in ["idle", "walk", "sit_chat", "sleep"]:
		var classic := _bounds(CreatorRenderer.record(_spec(config, "mia", RenderStyle.CLASSIC), anim, 0.5, 1.0))
		var refined := _bounds(CreatorRenderer.record(_spec(config, "mia", RenderStyle.REFINED), anim, 0.5, 1.0))
		assert_almost(refined.size.y, classic.size.y, classic.size.y * 0.03, "%s: same height" % anim)
		assert_almost(refined.end.y, classic.end.y, 1.0, "%s: feet in the same place" % anim)
		assert_almost(refined.size.x, classic.size.x, classic.size.x * 0.12, "%s: about the same width" % anim)


func test_refined_preserves_measurements() -> void:
	var config := load_config()
	var spec := _spec(config, "mia", RenderStyle.REFINED)
	var refined := FigureModel.for_spec(spec)
	var classic := FigureModel.for_spec(_spec(config, "mia", RenderStyle.CLASSIC))
	assert_true(refined.refined and not classic.refined, "separate cached models per style")
	for y in [-69.5, -64.0, -59.5, -55.0, -51.0]:
		assert_almost(refined.near_x(y), classic.near_x(y), 0.001, "waist/hip contour unchanged at %.1f" % y)
		assert_almost(refined.far_x(y), classic.far_x(y), 0.001, "waist/seat contour unchanged at %.1f" % y)
	assert_eq(refined.hip_joints, classic.hip_joints, "same hip joints")
	assert_eq(refined.shoulder_joints, classic.shoulder_joints, "same shoulder joints")
	# Body differences between creators survive the refined style.
	var chloe := CreatorRenderer.record(_spec(config, "chloe", RenderStyle.REFINED), "idle", 0.0, 1.0)
	var mia := CreatorRenderer.record(spec, "idle", 0.0, 1.0)
	var chloe_hs := float(_spec(config, "chloe").get("height_scale", 1.0))
	var mia_hs := float(spec.get("height_scale", 1.0))
	assert_gt(_extent(chloe, -86.0 * chloe_hs, -80.0 * chloe_hs) / chloe_hs, _extent(mia, -86.0 * mia_hs, -80.0 * mia_hs) / mia_hs,
		"the enhanced bust still reads wider in the refined style")


func test_styles_never_share_cached_layers() -> void:
	var config := load_config()
	CreatorRenderer.clear_cache()
	var classic := CreatorRenderer.record(_spec(config, "mia", RenderStyle.CLASSIC), "idle", 0.5, 3.0)
	var refined := CreatorRenderer.record(_spec(config, "mia", RenderStyle.REFINED), "idle", 0.5, 3.0)
	assert_true(classic.size() != refined.size() or str(classic) != str(refined), "refined output differs from classic")
	var classic_again := CreatorRenderer.record(_spec(config, "mia", RenderStyle.CLASSIC), "idle", 0.5, 3.0)
	assert_eq(classic_again.size(), classic.size(), "classic output is unaffected by refined layers in the cache")
