class_name Fmt
extends RefCounted
## Number / time formatting helpers shared by UI code.


static func money(value: float) -> String:
	if absf(value) >= 1_000_000.0:
		return "$" + compact(value)
	return ("-$" if value < 0.0 else "$") + _thousands(int(floor(absf(value))))


static func compact(value: float) -> String:
	var v := absf(value)
	var prefix := "-" if value < 0.0 else ""
	if v >= 1_000_000_000.0:
		return prefix + "%.2fB" % (v / 1_000_000_000.0)
	if v >= 1_000_000.0:
		return prefix + "%.2fM" % (v / 1_000_000.0)
	if v >= 10_000.0:
		return prefix + "%.1fK" % (v / 1000.0)
	return prefix + _thousands(int(floor(v)))


static func duration(seconds: float) -> String:
	var s := int(maxf(seconds, 0.0))
	var hours := s / 3600
	var minutes := (s % 3600) / 60
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	if minutes > 0:
		return "%dm %ds" % [minutes, s % 60]
	return "%ds" % s


static func clock(state: GameState) -> String:
	return "Day %d  %02d:%02d" % [state.day(), state.hour_of_day(), state.minute_of_hour()]


static func _thousands(n: int) -> String:
	var digits := str(n)
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out
