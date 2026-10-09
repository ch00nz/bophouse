class_name RoomStaging
extends RefCounted
## How the creators physically in a room are shown in its detailed Room View (pure presentation
## logic, no nodes, never changes game state):
##   present()  who is in the room right now, including anyone walking through it
##   seats()    seats derived from the room's furniture (data/room_interiors.json "seating")
##   plan()     per creator: where to stand or sit, which pose, and which way to face
## Relaxing creators (activities listed in the room's "sit_anims") share out the seats, spread along
## the furniture in their simulated left-to-right order, if they can sit (extra people stand). Working creators stay at their simulated spot doing their real
## activity. Conversation partners face each other; others face the nearest housemate.


static func interior_def(config: GameConfig, room_type: String) -> Dictionary:
	return (config.interiors.get("rooms", {}) as Dictionary).get(room_type, {})


## Whether this room type has a detailed Room View.
static func supports(config: GameConfig, room: RoomState) -> bool:
	return room != null and bool(interior_def(config, room.type_id).get("enabled", false))


## Whether a creator's position is inside the room (same storey, within its columns).
static func is_inside(creator: CreatorState, room: RoomState) -> bool:
	var p := creator.position
	return absf(p.y - room.storey) < 0.02 and p.x >= room.column - 0.001 and p.x <= room.column + room.width + 0.001


static func present(state: GameState, room: RoomState) -> Array[CreatorState]:
	var result: Array[CreatorState] = []
	for creator in state.creators:
		if is_inside(creator, room):
			result.append(creator)
	return result


## Seats from the room's current furniture: [{x (fraction of room width), seat_h (fraction of the
## interior height), kind}], left to right.
static func seats(config: GameConfig, room: RoomState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seating: Dictionary = config.interiors.get("seating", {})
	for item: Dictionary in config.room_level_def(room.type_id, room.level).get("furniture", []):
		var kind := str(item.get("kind", ""))
		if not seating.has(kind) or bool(item.get("wall", false)):
			continue
		var rule: Dictionary = seating[kind]
		var x := float(item.get("x", 0.0))
		var w := float(item.get("w", 0.1))
		var margin := w * float(rule.get("margin", 0.0))
		var usable := w - margin * 2.0
		var count := int(rule.get("seats", 0))
		if count <= 0:
			count = maxi(1, roundi(usable / maxf(float(rule.get("seat_spacing", 0.12)), 0.01)))
		for i in count:
			result.append({"x": x + margin + usable * (i + 0.5) / count, "seat_h": float(rule.get("seat_h", 0.12)), "kind": kind})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["x"]) < float(b["x"]))
	return result


## Staging for everyone present: creator id -> {x (fraction of room width), anim ("" = simulated),
## seat_h (fraction of interior height, seated poses), face (+1/-1/0), seat (index or -1)}.
## `can_sit`: creator id -> bool (painted creators without a sitting painting can't sit).
static func plan(state: GameState, config: GameConfig, room: RoomState, can_sit: Dictionary) -> Dictionary:
	var def := interior_def(config, room.type_id)
	var sit_anims: Dictionary = def.get("sit_anims", {})
	var room_seats := seats(config, room)
	var result := {}
	var people := present(state, room)
	var sitters: Array[CreatorState] = []
	for creator in people:
		var x := (creator.position.x - room.column) / maxf(room.width, 1.0)
		result[creator.id] = {"x": x, "anim": "", "seat_h": 0.0, "face": 0.0, "seat": -1}
		var anim := CreatorView.simulated_anim(creator, state, config)
		if not creator.is_travelling() and sit_anims.has(anim) and bool(can_sit.get(creator.id, false)):
			sitters.append(creator)
	# Seats are shared out together: spread evenly along the furniture (so people turned toward each
	# other have room for their legs), keeping the sitters' simulated left-to-right order.
	sitters.sort_custom(func(a: CreatorState, b: CreatorState) -> bool: return a.position.x < b.position.x)
	var count := mini(sitters.size(), room_seats.size())
	var chosen: Array[int] = []
	if count == 1:
		var x := float(result[sitters[0].id]["x"])
		var best := 0
		for i in room_seats.size():
			if absf(float(room_seats[i]["x"]) - x) < absf(float(room_seats[best]["x"]) - x):
				best = i
		chosen.append(best)
	else:
		for i in count:
			chosen.append(roundi(float(i) * (room_seats.size() - 1) / (count - 1)))
	for i in count:
		var creator := sitters[i]
		var seat: Dictionary = room_seats[chosen[i]]
		var entry: Dictionary = result[creator.id]
		entry["x"] = float(seat["x"])
		entry["seat_h"] = float(seat["seat_h"])
		entry["anim"] = str(sit_anims[CreatorView.simulated_anim(creator, state, config)])
		entry["seat"] = chosen[i]
	# Facing: conversation partners face each other; anyone else relaxing faces the nearest housemate.
	for creator in people:
		var entry: Dictionary = result[creator.id]
		if creator.is_travelling():
			continue
		var partner_id := str(creator.reaction.get("with", "")) if creator.has_reaction(state.game_minutes) else ""
		var target_x := INF
		if result.has(partner_id):
			target_x = float(result[partner_id]["x"])
		elif int(entry["seat"]) >= 0:
			var nearest := INF
			for other_id: String in result:
				if other_id != creator.id and absf(float(result[other_id]["x"]) - float(entry["x"])) < nearest:
					nearest = absf(float(result[other_id]["x"]) - float(entry["x"]))
					target_x = float(result[other_id]["x"])
		if target_x != INF and absf(target_x - float(entry["x"])) > 0.001:
			entry["face"] = signf(target_x - float(entry["x"]))
	return result
