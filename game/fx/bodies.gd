## The real worlds planets are drawn as: NASA surface maps in game/art/bodies/ (see CREDITS.md),
## packed into one Texture2DArray for game/fx/planet.gdshader. Which world a planet shows is
## cosmetic only; the sim never sees it.
extends RefCounted

## Layer order of the texture array. Append only: saved levels refer to bodies by name.
const NAMES: PackedStringArray = [
	"earth", "mars", "jupiter", "neptune", "venus", "saturn", "uranus", "mercury", "moon",
	"phobos", "io", "europa", "ganymede", "callisto", "rhea", "iapetus", "pluto", "charon",
]
const TITLES := {
	"earth": "Earth", "mars": "Mars", "jupiter": "Jupiter", "neptune": "Neptune", "venus": "Venus",
	"saturn": "Saturn", "uranus": "Uranus", "mercury": "Mercury", "moon": "the Moon", "phobos": "Phobos",
	"io": "Io", "europa": "Europa", "ganymede": "Ganymede", "callisto": "Callisto", "rhea": "Rhea",
	"iapetus": "Iapetus", "pluto": "Pluto", "charon": "Charon",
}
## Home worlds by seat: you are always Earth.
const HOMES: PackedStringArray = ["earth", "mars", "jupiter", "neptune", "venus", "saturn", "uranus", "mercury"]
## Neutral worlds by level: big levels are planets, small ones are moons.
const BIG: PackedStringArray = ["venus", "mercury", "uranus", "neptune", "mars", "io", "ganymede", "saturn"]
const SMALL: PackedStringArray = ["moon", "phobos", "callisto", "europa", "iapetus", "rhea", "charon", "pluto"]
const WIDTH := 1024

static var _array: Texture2DArray


static func layer(body_name: String) -> int:
	return maxi(NAMES.find(body_name), 0)


## Body layer for every planet of `world`. `homes` maps seat -> body name for that seat's
## starting planet (training levels put the enemy on the world the level is named after).
static func assign(world: RefCounted, homes: Dictionary = {}) -> PackedInt32Array:
	var out := PackedInt32Array()
	for p in world.planets:
		var body_name: String
		if p.owner > 0 and homes.has(p.owner):
			body_name = str(homes[p.owner])
		elif p.owner > 0:
			body_name = HOMES[(p.owner - 1) % HOMES.size()]
		else:
			var pool := BIG if p.growth >= 4 else SMALL
			body_name = pool[(p.id * 7 + p.growth * 3) % pool.size()]
		out.append(layer(body_name))
	return out


static func texture() -> Texture2DArray:
	if _array == null:
		var images: Array[Image] = []
		for n in NAMES:
			var tex: Texture2D = load("res://game/art/bodies/%s.jpg" % n)
			var img := tex.get_image()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			if img.get_width() != WIDTH or img.get_height() != WIDTH / 2:
				img.resize(WIDTH, WIDTH / 2, Image.INTERPOLATE_LANCZOS)
			img.generate_mipmaps()
			images.append(img)
		_array = Texture2DArray.new()
		_array.create_from_images(images)
	return _array


static func release() -> void:
	_array = null
