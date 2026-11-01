## The palette and drawing primitives from docs/STYLE_GUIDE.md.
##
## Pure constants and static helpers so that design mocks, the real game and
## tools all draw a planet the same way. Preload by path:
##   const Palette := preload("res://game/theme/palette.gd")
extends RefCounted

const VOID := Color("#070A14")
const DEEP := Color("#0F1424")
const SLATE := Color("#171D33")
const RIM := Color("#2A3352")
const ICE := Color("#ECF1FA")
const MIST := Color("#9AA6C0")
const DUSK := Color("#5E6A86")
const ASH := Color("#8D97AB")
const EMBER := Color("#FF6B5C")

## Index 0 is neutral; 1..8 are players.
const PLAYERS: Array[Color] = [
	Color("#8D97AB"),  # 0 neutral: Ash
	Color("#56B4E9"),  # 1 Sky
	Color("#E69F00"),  # 2 Amber
	Color("#CC79A7"),  # 3 Orchid
	Color("#1FBF95"),  # 4 Mint
	Color("#F0E442"),  # 5 Okabe–Ito yellow
	Color("#D55E00"),  # 6 vermilion
	Color("#0072B2"),  # 7 blue
	Color("#B8A9E8"),  # 8 lilac
]

const PLAYER_NAMES := ["Neutral", "Sky", "Amber", "Orchid", "Mint", "Sun", "Vermilion", "Blue", "Lilac"]


static func player_color(owner: int) -> Color:
	return PLAYERS[clampi(owner, 0, PLAYERS.size() - 1)]


## Planet radius in px at 1× zoom, from docs/STYLE_GUIDE.md §4.
static func planet_radius(growth: int) -> float:
	return 18.0 + 6.0 * growth


## Soft halo: concentric discs with a falling alpha ramp. `strength` is peak alpha.
static func draw_glow(ci: CanvasItem, pos: Vector2, radius: float, color: Color, strength: float = 0.35, spread: float = 2.0, steps: int = 14) -> void:
	for i in range(steps):
		var t := float(i) / float(steps)  # 0 = outermost
		var r := lerpf(radius * spread, radius, t)
		var a := strength * (t * t) / float(steps) * 3.0
		ci.draw_circle(pos, r, Color(color.r, color.g, color.b, a))


## A full planet: halo (owned only), disc, inner rim, growth arc, optional selection/hover rings.
static func draw_planet(ci: CanvasItem, pos: Vector2, growth: int, owner: int, growth_progress: float = 0.0, selected: bool = false, hovered: bool = false) -> void:
	var r := planet_radius(growth)
	var c := player_color(owner)
	if owner != 0:
		draw_glow(ci, pos, r, c, 0.38, 2.1)
	elif hovered:
		draw_glow(ci, pos, r, c, 0.18, 1.8)
	ci.draw_circle(pos, r, c.darkened(0.35) if owner == 0 else c.darkened(0.08))
	ci.draw_arc(pos, r - 1.0, 0.0, TAU, 64, c, 2.0, true)
	if owner != 0 and growth_progress > 0.0:
		ci.draw_arc(pos, r + 6.0, -PI / 2.0, -PI / 2.0 + TAU * growth_progress, 64, Color(c.r, c.g, c.b, 0.9), 3.0, true)
	if hovered and not selected:
		ci.draw_arc(pos, r + 6.0, 0.0, TAU, 64, Color(ICE.r, ICE.g, ICE.b, 0.5), 2.0, true)
	if selected:
		ci.draw_arc(pos, r + 6.0, 0.0, TAU, 64, ICE, 2.0, true)
		ci.draw_arc(pos, r + 12.0, 0.0, TAU, 64, Color(ICE.r, ICE.g, ICE.b, 0.25), 1.0, true)


## Fleet as a stream of dots along a gentle curve from `from` to `to`, head at `progress` (0..1).
## Density and length grow with `ships`; dots fade and shrink toward the tail. Additive-looking
## by stacking a faint wide disc under each dot (no shaders needed in a static mock).
static func draw_fleet(ci: CanvasItem, from: Vector2, to: Vector2, ships: int, owner: int, progress: float, rng_seed: int = 1) -> void:
	var c := player_color(owner)
	var dir := (to - from)
	var normal := Vector2(-dir.y, dir.x).normalized()
	var n := clampi(ships, 12, 160)
	var length := clampf(0.10 + ships / 500.0, 0.10, 0.30)  # stream length as a share of the trip
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var head_pos := from.lerp(to, progress) + normal * sin(progress * PI) * 24.0
	draw_glow(ci, head_pos, 10.0, c, 0.30, 2.4, 10)
	for i in range(n):
		var u := rng.randf()
		var t := progress - length * u * u  # cluster toward the head
		if t < 0.0 or t > 1.0:
			continue
		var bulge := sin(t * PI) * 24.0
		var spread := 4.0 + 10.0 * u
		var p := from.lerp(to, t) + normal * (bulge + rng.randf_range(-spread, spread))
		var k := 1.0 - u  # 1 at head, 0 at tail
		ci.draw_circle(p, 5.0 * k + 2.0, Color(c.r, c.g, c.b, 0.10 * k))
		ci.draw_circle(p, 1.3 + 1.6 * k, Color(c.r, c.g, c.b, 0.30 + 0.70 * k))
