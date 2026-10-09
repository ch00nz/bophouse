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
	theme.set_stylebox("panel", "TooltipPanel", box(Color("1d1330"), 8, 8, GOLD.darkened(0.3), 1))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_font_size("font_size", "TooltipLabel", 13)
	return theme


## Adds a hover tooltip. Labels ignore the mouse by default, so let events through.
static func tip(control: Control, text: String) -> Control:
	control.tooltip_text = text
	if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		control.mouse_filter = Control.MOUSE_FILTER_PASS
	return control


static func header(text: String) -> Label:
	var l := label(text.to_upper(), 12, GOLD)
	return l


## A rounded card with a vertical layout; returns the card (content goes in card.get_child(0)).
static func card(bg: Color = PANEL_LIGHT, border: Color = Color.TRANSPARENT) -> PanelContainer:
	var panel := PanelContainer.new()
	# PanelContainer defaults to MOUSE_FILTER_STOP, which would swallow scroll-wheel events.
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", box(bg, 10, 10, border, 2 if border.a > 0.0 else 0))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	panel.add_child(content)
	return panel


## Small coloured pill (traits, appeal tags). Passes mouse events so tooltips work and lists scroll.
static func chip(text: String, colour: Color, tooltip: String = "") -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", box(colour.darkened(0.62), 6, 3, colour.darkened(0.2), 1))
	panel.add_child(label(text, 12, colour.lightened(0.15)))
	if not tooltip.is_empty():
		panel.tooltip_text = tooltip
	return panel


## Segmented tab button.
static func tab_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 30)
	b.add_theme_font_size_override("font_size", 13)
	b.clip_text = true
	b.add_theme_stylebox_override("normal", box(PANEL_LIGHT, 8, 4))
	b.add_theme_stylebox_override("hover", box(PANEL_LIGHT.lightened(0.15), 8, 4))
	return b


## Right-aligned value label for breakdown rows.
static func value_label(text: String = "", font_color: Color = TEXT, size: int = 14) -> Label:
	var l := label(text, size, font_color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


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
	b.mouse_filter = Control.MOUSE_FILTER_PASS # don't swallow scroll-wheel events in the sidebar
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
