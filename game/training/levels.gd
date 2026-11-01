## Training: our solar system (owner survey, iteration 2). Nine short levels flying outward from
## Earth; each starts small and calm and adds one idea. You always launch from Earth; the enemy
## holds the world the level is named after. The full constellation campaign is Iteration 5.
##
## A level is a Session config plus presentation. Stars: 1 for a win, 2 within `par[0]` seconds of
## game time, 3 within `par[1]`. Pars are set from a Greedy bot playing your seat (it reacts every
## tick, so it is far faster than a person): 3 stars ≈ 3.5× its time + 10 s, 2 stars ≈ 6× + 20 s.
## tests/game/test_training.gd checks that bot still wins every level, inside the 3-star par.
extends RefCounted

const LEVELS: Array[Dictionary] = [
	{
		"id": "moon", "body": "moon", "title": "The Moon",
		"brief": "Drag from Earth to a grey moon to send ships. Take every planet to win.",
		"bots": ["random"], "difficulty": "relaxed", "seed": 1, "par": [90, 50],
		"map_text": "# players: 2\nP 5 10 1 30 3\nP 10 6 0 6 1\nP 10 14 0 6 1\nP 15 10 0 12 2\nP 22 10 2 10 1\n",
	},
	{
		"id": "mercury", "body": "mercury", "title": "Mercury",
		"brief": "More dots around a planet = higher level = more ships grown. Big ones cost more to take.",
		"bots": ["random"], "difficulty": "relaxed", "seed": 2, "par": [130, 75],
		"map_text": "# players: 2\nP 5 10 1 30 3\nP 9 5 0 5 1\nP 9 15 0 5 1\nP 14 10 0 30 5\nP 19 5 0 10 2\nP 19 15 0 10 2\nP 25 10 2 20 2\n",
	},
	{
		"id": "venus", "body": "venus", "title": "Venus",
		"brief": "Venus fights back. Keys 1–4 send a quarter, half, three quarters or all — keep some home.",
		"bots": ["nearest"], "difficulty": "relaxed", "seed": 3, "par": [140, 80],
		"map_text": "# players: 2\nP 4 10 1 40 3\nP 26 10 2 40 3\nP 9 5 0 8 2\nP 9 15 0 8 2\nP 21 5 0 8 2\nP 21 15 0 8 2\nP 15 7 0 25 4\nP 15 13 0 25 4\n",
	},
	{
		"id": "mars", "body": "mars", "title": "Mars",
		"brief": "Drag a box or shift-click to send from several planets at once.",
		"bots": ["nearest"], "difficulty": "normal", "seed": 404, "planets": 10, "par": [110, 65],
	},
	{
		"id": "jupiter", "body": "jupiter", "title": "Jupiter",
		"brief": "Jupiter's commander hunts the cheapest planet in reach. Don't leave one empty.",
		"bots": ["greedy"], "difficulty": "relaxed", "seed": 505, "planets": 12, "par": [210, 120],
	},
	{
		"id": "saturn", "body": "saturn", "title": "Saturn",
		"brief": "Two opponents. Let them fight each other, then take what's left.",
		"bots": ["nearest", "random"], "difficulty": "normal", "seed": 606, "planets": 14, "par": [225, 130],
	},
	{
		"id": "uranus", "body": "uranus", "title": "Uranus",
		"brief": "A sharper commander. Hold your front line and grow behind it.",
		"bots": ["greedy"], "difficulty": "normal", "seed": 712, "planets": 16, "par": [250, 145],
	},
	{
		"id": "neptune", "body": "neptune", "title": "Neptune",
		"brief": "Two greedy commanders on a wide map. Speed up with + when you're winning.",
		"bots": ["greedy", "greedy"], "difficulty": "normal", "seed": 808, "planets": 20, "par": [375, 215],
	},
	{
		"id": "pluto", "body": "pluto", "title": "Pluto",
		"brief": "The edge of the solar system: two sharp commanders. Everything you've learned.",
		"bots": ["greedy", "greedy"], "difficulty": "sharp", "seed": 707, "planets": 24, "par": [640, 370],
	},
]


static func count() -> int:
	return LEVELS.size()


static func index_of(id: String) -> int:
	for i in range(LEVELS.size()):
		if LEVELS[i]["id"] == id:
			return i
	return -1


## The Session/GameScreen config for level `i`.
static func config(i: int) -> Dictionary:
	var lv: Dictionary = LEVELS[i]
	var c := {
		"level": lv["id"],
		"seed": lv["seed"],
		"bot": lv["bots"][0],
		"bots": lv["bots"],
		"opponents": lv["bots"].size(),
		"difficulty": lv["difficulty"],
		"backdrop": ["pillars-webb", "carina", "cosmic-cliffs", "pillars-hubble", "whirlpool"][i % 5],
		"homes": {2: lv["body"]},
	}
	if lv.has("map_text"):
		c["map_text"] = lv["map_text"]
	else:
		c["planets"] = lv["planets"]
		c["map"] = "custom"
	return c


## 0 for a loss; 1 for a win; 2 within par[0] seconds; 3 within par[1].
static func stars_for(i: int, won: bool, seconds: float) -> int:
	if not won:
		return 0
	var par: Array = LEVELS[i]["par"]
	if seconds <= float(par[1]):
		return 3
	if seconds <= float(par[0]):
		return 2
	return 1
