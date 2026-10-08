class_name TestCase
extends RefCounted
## Minimal dependency-free test base class. Methods named test_* are run by tests/run_tests.gd.

var failures: Array[String] = []
var current_test: String = ""


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func fail(message: String) -> void:
	failures.append(message)


func assert_true(condition: bool, message: String = "expected true") -> void:
	if not condition:
		fail(message)


func assert_false(condition: bool, message: String = "expected false") -> void:
	if condition:
		fail(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		fail("%s expected <%s> got <%s>" % [message, str(expected), str(actual)])


func assert_almost(actual: float, expected: float, tolerance: float = 0.001, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		fail("%s expected ~%f got %f" % [message, expected, actual])


func assert_gt(actual: float, threshold: float, message: String = "") -> void:
	if not actual > threshold:
		fail("%s expected > %f got %f" % [message, threshold, actual])


func assert_lt(actual: float, threshold: float, message: String = "") -> void:
	if not actual < threshold:
		fail("%s expected < %f got %f" % [message, threshold, actual])


## Real game data; tests assert relationships rather than exact tuned numbers where possible.
func load_config() -> GameConfig:
	return GameConfig.load_from_dir("res://data")


## A deterministic config independent of tuning, for exact-value assertions.
func fixture_config() -> GameConfig:
	var config := load_config()
	config.balance["economy"] = {
		"starting_cash": 100,
		"appeal_weights": {"looks": 1.0},
		"stat_baseline": 50,
		"audience_exponent": 1.0,
		"subscriber_conversion": 0.1,
		"subscription_cash_per_sub_hour": 1.0,
		"min_energy_efficiency": 0.5,
		"min_mood_efficiency": 1.0,
		"stamina_drain_base": 1.5,
	}
	return config
