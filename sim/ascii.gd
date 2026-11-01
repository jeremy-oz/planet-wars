## ASCII renderer for debugging and headless inspection. Returns a String; never prints.
##
## Planets: `o` neutral, `1`..`8` owned. Fleets: `*` at their interpolated position. A legend
## below lists each planet and each player's totals.
extends RefCounted

const World := preload("res://sim/world.gd")


static func render(world: World, cols: int = 64, rows: int = 20, legend: bool = true) -> String:
	if world.planets.is_empty():
		return "(empty map)\n"
	var lo := world.planets[0].position
	var hi := world.planets[0].position
	for p in world.planets:
		lo = Vector2(minf(lo.x, p.position.x), minf(lo.y, p.position.y))
		hi = Vector2(maxf(hi.x, p.position.x), maxf(hi.y, p.position.y))
	var span := Vector2(maxf(hi.x - lo.x, 1.0), maxf(hi.y - lo.y, 1.0))
	var grid: Array[PackedStringArray] = []
	for r in range(rows):
		var row: PackedStringArray = []
		for c in range(cols):
			row.append(".")
		grid.append(row)
	for f in world.fleets:
		var a := world.planets[f.source].position
		var b := world.planets[f.destination].position
		var t := 1.0 - float(f.remaining) / float(maxi(f.trip_length, 1))
		var cell := _cell(a.lerp(b, t), lo, span, cols, rows)
		grid[cell.y][cell.x] = "*"
	for p in world.planets:
		var cell := _cell(p.position, lo, span, cols, rows)
		grid[cell.y][cell.x] = "o" if p.owner == 0 else str(p.owner)
	var out := PackedStringArray()
	for row in grid:
		out.append("".join(row))
	if legend:
		out.append("tick %d" % world.tick_count)
		for p in world.planets:
			out.append("  planet %2d  owner %d  ships %4d  growth %d" % [p.id, p.owner, p.ships, p.growth])
		for player in range(1, world.num_players + 1):
			out.append("  player %d  planets %2d  ships %4d  fleets %2d  +%d/tick%s" % [
				player, world.planet_count(player), world.total_ships(player), world.fleet_count(player),
				world.growth_rate(player), "" if world.is_alive(player) else "  (out)"])
	return "\n".join(out) + "\n"


static func _cell(pos: Vector2, lo: Vector2, span: Vector2, cols: int, rows: int) -> Vector2i:
	var x := int(roundf((pos.x - lo.x) / span.x * float(cols - 1)))
	var y := int(roundf((pos.y - lo.y) / span.y * float(rows - 1)))
	return Vector2i(clampi(x, 0, cols - 1), clampi(y, 0, rows - 1))
