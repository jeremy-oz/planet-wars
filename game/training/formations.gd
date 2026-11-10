## Designed, symmetric training maps ("formations") instead of random scatters.
##
## A formation is drawn once for the human's side; `build` copies it for every other seat by
## mirroring (2 players, left/right) or rotating (any count), so every seat sees the same map.
## Planets listed in `shared` sit on the axis or centre and appear once. Coordinates are map
## units relative to the centre; the output is the SPEC §7 map text the sim already reads.
extends RefCounted

const CENTRE := Vector2(15, 10)


## `side`: [x, y, ships, growth, home?] for the human's half (home = true for the start planet).
## `shared`: [x, y, ships, growth] neutrals placed once. `mode`: "mirror" or "rotate".
## The human (player 1) starts on the left / at angle 180°.
## `squash` scales every offset (x, y): three-seat triangles are as tall as they are wide, so they
## are drawn a little tighter to keep planets large on a wide screen.
static func build(players: int, side: Array, shared: Array = [], mode: String = "mirror", squash: Vector2 = Vector2.ONE) -> String:
	var lines := PackedStringArray(["# players: %d" % players])
	var homes: Array = []
	var neutrals: Array = []
	for seat in range(players):
		for p: Array in side:
			var pos := CENTRE + (_place(Vector2(p[0], p[1]), seat, players, mode) - CENTRE) * squash
			var entry := [pos, p[2], p[3]]
			if p.size() > 4 and p[4]:
				homes.append([pos, seat + 1, p[2], p[3]])
			else:
				neutrals.append(entry)
	for p: Array in shared:
		neutrals.append([CENTRE + Vector2(p[0], p[1]) * squash, p[2], p[3]])
	# homes first, in seat order, so player 1's home is planet 0 like the other training maps
	for h: Array in homes:
		lines.append(_line(h[0], h[1], h[2], h[3]))
	for n: Array in neutrals:
		lines.append(_line(n[0], 0, n[1], n[2]))
	return "\n".join(lines) + "\n"


static func _place(v: Vector2, seat: int, players: int, mode: String) -> Vector2:
	if seat == 0:
		return CENTRE + v
	if mode == "mirror" and players == 2:
		return CENTRE + Vector2(-v.x, v.y)
	return CENTRE + v.rotated(TAU * seat / players)


static func _line(pos: Vector2, owner: int, ships: int, growth: int) -> String:
	return "P %s %s %d %d %d" % [_num(pos.x), _num(pos.y), owner, ships, growth]


static func _num(x: float) -> String:
	return str(snappedf(x, 0.01))
