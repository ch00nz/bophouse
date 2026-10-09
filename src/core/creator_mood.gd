class_name CreatorMood
extends RefCounted
## Which face a creator shows in portraits, from her state (pure logic, no rendering):
##   angry      bickering with a housemate, or low mood with a dramatic personality
##   happy      celebrating / a good chat, or in a great mood
##   sad        low mood, exhausted, or recovering and feeling it
##   playful    working on camera
##   confident  her default
##   surprised  transient (a makeover reveal); set by the UI, never derived here
## Illustrated creators show the matching painted bust; procedural creators map these onto
## FacePainter expressions (see PROCEDURAL).

const EXPRESSIONS: Array[String] = ["confident", "happy", "sad", "angry", "surprised", "playful"]
const PROCEDURAL := {
	"confident": "", "happy": "grin", "sad": "sad", "angry": "annoyed", "surprised": "surprised", "playful": "wink",
}
const HAPPY_MOOD := 72.0
const LOW_MOOD := 30.0
const UPSET_MOOD := 40.0
const EXHAUSTED_ENERGY := 12.0


static func expression(creator: CreatorState, game_minutes: float) -> String:
	if creator.has_reaction(game_minutes):
		var anim := str(creator.reaction.get("anim", ""))
		if anim == "argue":
			return "angry"
		if str(creator.reaction.get("kind", "")) == "positive":
			return "happy"
	if creator.is_recovering():
		return "sad" if creator.mood < 55.0 else "confident"
	if creator.mood < LOW_MOOD or creator.energy < EXHAUSTED_ENERGY:
		return "sad"
	if creator.mood < UPSET_MOOD:
		return "angry" if creator.stat("drama") >= 50.0 else "sad"
	if creator.activity_id == CreatorBrain.WORK and not creator.is_travelling():
		return "playful"
	if creator.mood >= HAPPY_MOOD:
		return "happy"
	return "confident"


## Procedural face for a mood expression ("" = her signature expression).
static func procedural(mood_expression: String, signature: String) -> String:
	var mapped := str(PROCEDURAL.get(mood_expression, ""))
	return signature if mapped.is_empty() else mapped
