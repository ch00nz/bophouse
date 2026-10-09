class_name TimeControl
extends RefCounted
## Converts real frame time into game minutes. Kept pure so speed handling is testable.


static func frame_minutes(real_delta: float, speed: int, paused: bool, config: GameConfig) -> float:
	if paused:
		return 0.0
	var clamped := minf(maxf(real_delta, 0.0), config.tuning_f("time", "max_frame_delta_seconds", 0.25))
	return clamped * config.tuning_f("time", "game_minutes_per_real_second", 2.0) * maxi(speed, 1)
