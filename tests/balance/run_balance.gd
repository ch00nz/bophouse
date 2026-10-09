extends SceneTree
## Economy balancing report (developer tool, headless):
##   godot --headless --path . --script res://tests/balance/run_balance.gd -- [strategies] [days] [seed]
## strategies: comma-separated (idle,casual,upgrades,recruitment,optimised) or "all" (default).
## Prints milestone times (game days and real minutes at 1x), daily finances, upgrade paybacks,
## debt/bankruptcy checks and late-game growth (runaway check).

const BalanceSim := preload("res://tests/balance/balance_sim.gd")
const SNAPSHOT_DAYS := [1, 2, 3, 5, 7, 10, 15, 20, 25, 30, 40, 50, 60]
const MILESTONES := [
	["first_upgrade", "First upgrade"], ["three_upgrades", "3 upgrades"], ["five_upgrades", "5 upgrades"],
	["cash_1000", "$1k cash"], ["cash_5000", "$5k cash"], ["second_creator", "2nd creator"],
	["house_expansion", "House expansion"], ["third_creator", "3rd creator"], ["fourth_creator", "4th creator"],
	["established", "Established house"],
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var names: Array = BalanceSim.STRATEGIES
	if args.size() > 0 and args[0] != "all":
		names = Array(args[0].split(","))
	var days := int(args[1]) if args.size() > 1 else 60
	var seed := int(args[2]) if args.size() > 2 else 1234
	var config := GameConfig.load_from_dir()
	var reports: Array = []
	for name in names:
		var sim = BalanceSim.new(config, str(name), seed)
		var started := Time.get_ticks_msec()
		reports.append(sim.run(days))
		print("simulated %s for %d days in %.1fs" % [name, days, (Time.get_ticks_msec() - started) / 1000.0])
	_print_milestones(reports, config)
	for report: Dictionary in reports:
		_print_strategy(report, config)
	quit()


func _real(config: GameConfig, hours: float) -> String:
	var minutes := hours * 60.0 / (config.tuning_f("time", "game_minutes_per_real_second", 2.0) * 60.0)
	return "%dh%02dm" % [int(minutes / 60.0), int(fmod(minutes, 60.0))] if minutes >= 60.0 else "%dm" % int(minutes)


func _print_milestones(reports: Array, config: GameConfig) -> void:
	print("\n=== MILESTONES (game day / real time at 1x) ===")
	var header := "%-18s" % ""
	for report: Dictionary in reports:
		header += "%-17s" % str(report["strategy"])
	print(header)
	for entry: Array in MILESTONES:
		var line := "%-18s" % str(entry[1])
		for report: Dictionary in reports:
			var hours: Variant = report["milestones"].get(entry[0])
			line += "%-17s" % ("-" if hours == null else "d%.1f %s" % [float(hours) / 24.0, _real(config, float(hours))])
		print(line)


func _print_strategy(report: Dictionary, config: GameConfig) -> void:
	print("\n=== %s ===" % str(report["strategy"]).to_upper())
	print("day     cash    gross    house  expenses      net  followers   subs  res upg")
	for row: Dictionary in report["daily"]:
		if int(row["day"]) in SNAPSHOT_DAYS:
			print("%3d %8d %8d %8d %9d %8d %10d %6d %4d %3d" % [row["day"], row["cash"], row["gross"], row["house"],
				row["expenses"], row["net"], row["followers"], row["subscribers"], row["residents"], row["upgrades"]])
	var daily: Array = report["daily"]
	if daily.size() >= 20:
		var late: Dictionary = daily[daily.size() - 1]
		var earlier: Dictionary = daily[daily.size() - 11]
		var growth := (float(late["net"]) - float(earlier["net"])) / maxf(absf(float(earlier["net"])), 1.0) / 10.0
		print("late net-profit growth: %+.1f%%/day over the last 10 days (runaway check)" % (growth * 100.0))
	print("min cash %d | hours in debt %d | photoshoots %d | final cash %d" % [report["min_cash"], report["hours_in_debt"], report["photoshoots"], report["final_cash"]])
	if not (report["log"] as Array).is_empty():
		print("purchases (day: what, price, estimated gain/day, payback days):")
		for entry: Dictionary in report["log"]:
			print("  d%5.1f %-11s %-16s %8d  %+7.0f/day  %s" % [float(entry["hour"]) / 24.0, entry["kind"], entry["id"], entry["price"],
				entry["gain_per_day"], "-" if float(entry["payback_days"]) == INF else "%.1f" % float(entry["payback_days"])])
