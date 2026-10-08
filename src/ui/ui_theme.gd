class_name UiTheme
extends RefCounted
## Central UI palette and Theme. Swap this (or a .tres theme) to restyle the whole game.

const PANEL := Color(0.165, 0.114, 0.239, 0.94)
const PANEL_LIGHT := Color("3b2a55")
const ACCENT := Color("ff5fa2")
const GOLD := Color("ffd166")
const GOOD := Color("7ae582")
const BAD := Color("ff6b6b")
const TEXT := Color("fff4fb")
const MUTED := Color("c9b8e8")


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	theme.set_stylebox("panel", "PanelContainer", box(PANEL, 14, 12, ACCENT.darkened(0.2), 2))
	theme.set_stylebox("panel", "Panel", box(PANEL, 14, 12))

	theme.set_stylebox("normal", "Button", box(ACCENT.darkened(0.1), 10, 6))
	theme.set_stylebox("hover", "Button", box(ACCENT.lightened(0.1), 10, 6))
	theme.set_stylebox("pressed", "Button", box(GOLD.darkened(0.15), 10, 6))
	theme.set_stylebox("hover_pressed", "Button", box(GOLD, 10, 6))
	theme.set_stylebox("disabled", "Button", box(Color(0.4, 0.36, 0.45), 10, 6))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", Color.WHITE)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color("2b1d3f"))
	theme.set_color("font_hover_pressed_color", "Button", Color("2b1d3f"))
	theme.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.55))

	theme.set_color("font_color", "Label", TEXT)
	theme.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.35), 5, 0))
	theme.set_stylebox("fill", "ProgressBar", box(ACCENT, 5, 0))
	theme.set_stylebox("separator", "HSeparator", line_box(Color(1, 1, 1, 0.15)))
	return theme


static func box(bg: Color, radius: int, margin: int, border: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	if border_width > 0:
		style.border_color = border
		style.set_border_width_all(border_width)
	return style


static func line_box(line_color: Color) -> StyleBoxLine:
	var style := StyleBoxLine.new()
	style.color = line_color
	style.thickness = 1
	return style


static func label(text: String, size: int = 15, font_color: Color = TEXT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", font_color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func bar(value: float, fill: Color = ACCENT, height: float = 12.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0
	b.max_value = 100
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_stylebox_override("fill", box(fill, 5, 0))
	return b


## A captioned value row: "Caption ........ value".
static func row(caption: String, value_label: Label) -> HBoxContainer:
	var h := HBoxContainer.new()
	var cap := label(caption, 14, MUTED)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(cap)
	h.add_child(value_label)
	return h
