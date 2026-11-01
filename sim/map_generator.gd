## Seeded random map generator (docs/SPEC.md §8). Returns map text; the seed fully identifies the map.
##
## Iteration 1 fairness is minimal and always succeeds: home planets sit evenly on a ring around
## the centre (rotated by the seed), neutrals fill the rest with a minimum spacing of 2 units.
## Mirror symmetry and chokepoints come in Iteration 4.
extends RefCounted

const MIN_SPACING := 2.0
const HOME_SHIPS := 100
const HOME_GROWTH := 5
const MAX_TRIES := 200


static func generate(seed: int, players: int, planet_count: int, size: Vector2 = Vector2(30.0, 20.0)) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	players = clampi(players, 1, 8)
	planet_count = maxi(planet_count, players)
	var positions: Array[Vector2] = []
	var centre := size * 0.5
	var ring := minf(size.x, size.y) * 0.4
	var rotation := rng.randf() * TAU
	for i in range(players):
		var angle := rotation + TAU * float(i) / float(players)
		positions.append(_quantize(centre + Vector2(cos(angle), sin(angle)) * ring))
	var lines: PackedStringArray = []
	lines.append("# players: %d" % players)
	lines.append("# seed: %d" % seed)
	lines.append("# P x y owner ships growth")
	for i in range(players):
		lines.append("P %.1f %.1f %d %d %d" % [positions[i].x, positions[i].y, i + 1, HOME_SHIPS, HOME_GROWTH])
	var placed := players
	var tries := 0
	while placed < planet_count and tries < MAX_TRIES * planet_count:
		tries += 1
		var candidate := _quantize(Vector2(1.0 + rng.randf() * (size.x - 2.0), 1.0 + rng.randf() * (size.y - 2.0)))
		var ok := true
		for p in positions:
			if p.distance_to(candidate) < MIN_SPACING:
				ok = false
				break
		if not ok:
			continue
		positions.append(candidate)
		var ships := rng.randi_range(1, 100)
		var growth := rng.randi_range(1, 5)
		lines.append("P %.1f %.1f 0 %d %d" % [candidate.x, candidate.y, ships, growth])
		placed += 1
	return "\n".join(lines) + "\n"


## Half-unit grid so the text form is short and the float round-trip is exact.
static func _quantize(v: Vector2) -> Vector2:
	return Vector2(floorf(v.x * 2.0) / 2.0, floorf(v.y * 2.0) / 2.0)
