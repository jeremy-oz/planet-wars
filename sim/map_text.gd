## Map file format (docs/SPEC.md §7): the 2010 text format, plus optional `# players: N`.
## Parsing takes a String and returns a World; nothing here touches the filesystem.
extends RefCounted

const World := preload("res://sim/world.gd")

## Why the last parse() returned null. Empty after a successful parse.
static var last_error: String = ""


## Returns a World, or null with `last_error` set, if the text is malformed.
static func parse(text: String, seed: int = 0) -> World:
	last_error = ""
	var world := World.new(seed)
	var declared_players := 0
	var line_no := 0
	for raw_line in text.split("\n"):
		line_no += 1
		var line := raw_line.strip_edges()
		if line.is_empty():
			continue
		if line.begins_with("#"):
			var header := line.substr(1).strip_edges()
			if header.begins_with("players:"):
				declared_players = header.substr(8).strip_edges().to_int()
			continue
		var parts := line.split(" ", false)
		match parts[0]:
			"P":
				if parts.size() != 6:
					return _fail("line %d: P needs 5 fields, got %d" % [line_no, parts.size() - 1])
				world.add_planet(Vector2(parts[1].to_float(), parts[2].to_float()), parts[3].to_int(), parts[4].to_int(), parts[5].to_int())
			"F":
				if parts.size() != 7:
					return _fail("line %d: F needs 6 fields, got %d" % [line_no, parts.size() - 1])
				world.add_fleet(parts[1].to_int(), parts[2].to_int(), parts[3].to_int(), parts[4].to_int(), parts[5].to_int(), parts[6].to_int())
			_:
				return _fail("line %d: unknown record '%s'" % [line_no, parts[0]])
	if declared_players > world.num_players:
		world.num_players = declared_players
	for f in world.fleets:
		if f.source >= world.planets.size() or f.destination >= world.planets.size():
			return _fail("fleet refers to a planet that does not exist")
	return world


static func _fail(message: String) -> World:
	last_error = message
	return null


## Inverse of parse(): a complete mid-game state in the same format. Positions use one decimal.
static func serialize(world: World) -> String:
	var lines: PackedStringArray = []
	lines.append("# players: %d" % world.num_players)
	lines.append("# P x y owner ships growth")
	for p in world.planets:
		lines.append("P %.1f %.1f %d %d %d" % [p.position.x, p.position.y, p.owner, p.ships, p.growth])
	if not world.fleets.is_empty():
		lines.append("# F owner ships source destination trip_length remaining")
		for f in world.fleets:
			lines.append("F %d %d %d %d %d %d" % [f.owner, f.ships, f.source, f.destination, f.trip_length, f.remaining])
	return "\n".join(lines) + "\n"
