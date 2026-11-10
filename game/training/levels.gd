## Training: our solar system (owner survey, iteration 2). Nine short levels flying outward from
## Earth; each starts small and calm and adds one idea. You always launch from Earth; the enemy
## holds the world the level is named after. The full constellation campaign is Iteration 5.
##
## A level is a Session config plus presentation and a short lesson (game/training/coach.gd).
## Stars: 1 for a win, 2 within `par[0]` seconds of game time, 3 within `par[1]`.
##
## Tuned for a person, not a bot. tests/game/test_training.gd plays every world by following the
## coach's advice with one move every two seconds (a relaxed human pace) and must win. Pars come
## from those runs at the calm pace: 3 stars ≈ 1.6× the coach's best time at one move every 1, 1.5
## or 2 s, + 15 s; 2 stars ≈ 1.5× the slower of the 2 s and 2.5 s runs + 30 s (at least 1.3× the
## 3-star par). Maps are symmetric formations (formations.gd); harder worlds give you a
## `head_start` instead of a lopsided map, the way Auralux's early levels lean your way.
extends RefCounted

const Formations := preload("res://game/training/formations.gd")

## Training commanders move like a person: one fleet per decision (see Session "bot_moves").
const BOT_MOVES := 1
## The easier retry: one notch slower thinking and a bigger home fleet.
const EASIER := {"sharp": "normal", "normal": "relaxed", "relaxed": "gentle", "gentle": "easy", "easy": "easy"}
const ASSIST_HEAD_START := 1.5
const ASSIST_LOSSES := 2  ## losses in a row on a world before the easier retry is offered

static var LEVELS: Array[Dictionary] = [
	{
		"id": "moon", "body": "moon", "title": "The Moon",
		"lesson": [
			{"text": "This is {home}, your home. The number under a planet is its ships. Yours grow every second.", "wait": "ok", "focus": ["home"]},
			{"text": "Drag from {home} to {near} to send half your ships. Grey planets are neutral: they don't fight back.", "wait": "send", "arrow": ["home", "near"]},
			{"text": "The orange planet is the enemy. Take every planet to win. Stuck? Press H or HINT and the coach shows a good move.", "wait": "ok", "focus": ["enemy"]},
		],
		"brief": "Send ships, take planets. Take them all to win.",
		"bots": ["random"], "difficulty": "relaxed", "seed": 1, "par": [65, 50],
		"map_text": "# players: 2\nP 5 10 1 30 3\nP 10 6 0 6 1\nP 10 14 0 6 1\nP 15 10 0 12 2\nP 22 10 2 10 1\n",
	},
	{
		"id": "mercury", "body": "mercury", "title": "Mercury",
		"lesson": [
			{"text": "The dots around {big} show its level. Five dots grow five times faster than one, but it costs more to take.", "wait": "ok", "focus": ["big"]},
			{"text": "Start cheap: take {cheap} first, then save up for the big one.", "wait": "send", "arrow": ["home", "cheap"]},
			{"text": "Each dot also holds 30 ships. A full planet stops growing and its number turns gold. Drag more ships onto a full planet of yours and the extra makes it grow a dot: watch the gold ring fill.", "wait": "ok", "focus": ["home"]},
		],
		"brief": "More dots = more ships grown and more room. Feed a full planet of yours and it grows a dot.",
		"bots": ["random"], "difficulty": "relaxed", "seed": 2, "par": [115, 90],
		"map_text": Formations.build(2, [[-10, 0, 30, 3, true], [-6, -4, 6, 1], [-6, 4, 6, 1]], [[0, 0, 30, 5]]),
	},
	{
		"id": "venus", "body": "venus", "title": "Venus",
		"lesson": [
			{"text": "Every planet you own has a shield: 5 ships for each level dot. Attackers must break it before they hit your ships. One big attack beats several small ones: each one meets the shield again.", "wait": "ok", "focus": ["home"]},
			{"text": "Keys 1–4 (or the buttons at the bottom) choose how much to send: a quarter, half, three quarters or all.", "wait": "ok", "focus": ["enemy"]},
			{"text": "Press 1 to send just a quarter, and keep the rest home.", "wait": "fraction"},
		],
		"brief": "Venus fights back. Your planets are shielded — keys 1–4 send part and keep some home.",
		"bots": ["nearest"], "difficulty": "gentle", "seed": 3, "par": [140, 105],
		"map_text": Formations.build(2, [[-11, 0, 40, 3, true], [-6, -4, 8, 2], [-6, 4, 8, 2]], [[0, 0, 25, 4]]),
	},
	{
		"id": "mars", "body": "mars", "title": "Mars",
		"lesson": [
			{"text": "Mars is quick. Take two planets near {home} first.", "wait": "send", "arrow": ["home", "near"]},
			{"text": "You have two planets now. Drag a box around both (or shift-click each), then click a target: they launch together.", "wait": "select_many", "after": "own:2"},
		],
		"brief": "Drag a box or shift-click to send from several planets at once.",
		"bots": ["nearest"], "difficulty": "gentle", "seed": 404, "par": [125, 95],
		"map_text": Formations.build(2, [[-11, 0, 40, 3, true], [-7, -4, 6, 1], [-7, 4, 6, 1]], [[0, -3.5, 18, 3], [0, 3.5, 18, 3]]),
	},
	{
		"id": "jupiter", "body": "jupiter", "title": "Jupiter",
		"lesson": [
			{"text": "Jupiter's commander hunts the cheapest planet in reach. When the coach warns you, reinforce the planet under attack.", "wait": "ok", "focus": ["enemy"]},
		],
		"brief": "Jupiter's commander hunts the cheapest planet in reach. Don't leave one empty.",
		"bots": ["greedy"], "difficulty": "gentle", "seed": 4507, "head_start": 1.3, "par": [190, 145],
		"map_text": Formations.build(2, [[-10, 0, 40, 3, true], [-6.5, -4.6, 10, 2], [-6.5, 4.6, 10, 2]], [[0, -6.4, 15, 2], [0, 6.4, 15, 2], [0, 0, 30, 5]]),
	},
	{
		"id": "saturn", "body": "saturn", "title": "Saturn",
		"lesson": [
			{"text": "Two opponents, and they fight each other too. Grow quietly, let them trade ships, then take what's left.", "wait": "ok"},
		],
		"brief": "Two opponents. Let them fight each other, then take what's left.",
		"bots": ["nearest", "random"], "difficulty": "relaxed", "seed": 5137, "par": [145, 110],
		"map_text": Formations.build(3, [[-10, 0, 40, 3, true], [-6, 3, 8, 2], [-3.5, -6.06, 15, 3]], [[0, 0, 25, 4]], "rotate", Vector2(0.85, 0.85)),
	},
	{
		"id": "uranus", "body": "uranus", "title": "Uranus",
		"lesson": [
			{"text": "Hold your front line: planets close to the enemy keep their ships. Planets behind them send theirs forward.", "wait": "ok", "focus": ["enemy"]},
		],
		"brief": "A sharper commander. Hold your front line and grow behind it.",
		"bots": ["greedy"], "difficulty": "relaxed", "seed": 6100, "head_start": 1.2, "par": [235, 180],
		"map_text": Formations.build(2, [[-11, 0, 40, 3, true], [-11, -5, 8, 2], [-11, 5, 8, 2], [-5, -4, 12, 2], [-5, 4, 12, 2]], [[0, 0, 30, 5]]),
	},
	{
		"id": "neptune", "body": "neptune", "title": "Neptune",
		"lesson": [
			{"text": "A wide map and two commanders. When you're ahead, press + to speed the game up.", "wait": "speed"},
		],
		"brief": "Two greedy commanders on a wide map. Speed up with + when you're winning.",
		"bots": ["greedy", "greedy"], "difficulty": "gentle", "seed": 7137, "head_start": 1.45, "par": [350, 270],
		"map_text": Formations.build(3, [[-11, 0, 40, 3, true], [-7, 0, 8, 2], [-3.5, 0, 15, 3], [-4.5, -7.79, 12, 3]], [[0, 0, 30, 5]], "rotate"),
	},
	{
		"id": "pluto", "body": "pluto", "title": "Pluto",
		"quiet_coach": true,
		"lesson": [
			{"text": "The edge of the solar system. From here the coach only speaks up when a planet is in danger. H still asks for a hint.", "wait": "ok"},
		],
		"brief": "The edge of the solar system: two sharp commanders. Everything you've learned.",
		"bots": ["greedy", "greedy"], "difficulty": "gentle", "seed": 8433, "head_start": 1.15, "par": [455, 350],
		"map_text": Formations.build(3, [[-11, 0, 40, 3, true], [-7.5, 3, 8, 2], [-4.5, -7.79, 15, 3], [-4, 0, 12, 2]], [[0, 0, 30, 5]], "rotate"),
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
## `assist` is the easier retry offered after two losses: the enemy thinks half as often and you
## start with half as many ships again. A win still opens the next world but earns one star.
static func config(i: int, assist: bool = false) -> Dictionary:
	var lv: Dictionary = LEVELS[i]
	var c := {
		"level": lv["id"],
		"seed": lv["seed"],
		"bot": lv["bots"][0],
		"bots": lv["bots"],
		"opponents": lv["bots"].size(),
		"difficulty": EASIER.get(lv["difficulty"], lv["difficulty"]) if assist else lv["difficulty"],
		"bot_moves": BOT_MOVES,
		# Training commanders never grow their planets: growing is your edge to learn, and bots
		# that grow turned the late worlds into stand-offs (sweep, round 8).
		"bot_grow": 0.0,
		"backdrop": ["pillars-webb", "carina", "cosmic-cliffs", "pillars-hubble", "whirlpool"][i % 5],
		"homes": {2: lv["body"]},
	}
	# Symmetric maps are a coin flip against an equal bot; like Auralux's early levels, training
	# tilts them your way with a bigger starting fleet on the harder worlds.
	var head: float = float(lv.get("head_start", 1.0))
	if assist:
		c["assist"] = true
		head *= ASSIST_HEAD_START
	if head != 1.0:
		c["head_start"] = head
	if lv.has("map_text"):
		c["map_text"] = lv["map_text"]
	else:
		c["planets"] = lv["planets"]
		c["map"] = "custom"
	return c


## 0 for a loss; 1 for a win (always 1 with the easier retry); 2 within par[0] seconds; 3 within par[1].
static func stars_for(i: int, won: bool, seconds: float, assist: bool = false) -> int:
	if not won:
		return 0
	if assist:
		return 1
	var par: Array = LEVELS[i]["par"]
	if seconds <= float(par[1]):
		return 3
	if seconds <= float(par[0]):
		return 2
	return 1
