class_name BumpQuestions

## Easy icebreakers to ask each other out loud after bumping phones. Both phones pick the
## same one without talking to each other: it comes from the two friend codes (sorted, so
## it doesn't matter who's who) and today's date, so the same two people get a new one
## on another day. Add to the list freely; keep them short, light and safe for anyone.

const QUESTIONS: PackedStringArray = [
	"what would you order here?",
	"pancakes or waffles?",
	"what's your go-to snack?",
	"best thing you ate this week?",
	"worst thing you've ever cooked?",
	"what's your favourite pizza topping?",
	"sweet or salty?",
	"what's a food you just can't stand?",
	"what's your favourite drink?",
	"breakfast for dinner: yes or no?",
	"what's the best dessert ever?",
	"what would your restaurant be called?",
	"what's your comfort food?",
	"spicy food: love it or nope?",
	"what's your favourite ice cream flavour?",
	"what did you have for breakfast?",
	"fries or onion rings?",
	"what's a food you'd eat every day?",
	"cats or dogs?",
	"what's your favourite animal?",
	"what's your favourite song right now?",
	"what's the last thing that made you laugh?",
	"what's your favourite game?",
	"what's your favourite movie?",
	"what's a show you'd recommend?",
	"morning person or night owl?",
	"beach or mountains?",
	"summer or winter?",
	"what's your favourite colour?",
	"what's the best birthday you've had?",
	"what superpower would you pick?",
	"where would you go on a dream trip?",
	"what's something you're good at?",
	"what's a hobby you'd like to try?",
	"what's your favourite season?",
	"what's the best gift you've ever got?",
	"what did you want to be as a kid?",
	"what's a song you know every word to?",
	"what would you do with a free day?",
	"what's your favourite holiday?",
	"what's the weirdest food you've tried?",
	"what's your favourite word?",
	"what's your favourite smell?",
	"what's a talent nobody knows you have?",
	"what's your favourite book or comic?",
	"if you were a sandwich, what would be in it?",
	"what's your favourite place in town?",
	"what's something that always cheers you up?",
	"what's a small thing you love?",
	"what's your favourite emoji?",
	"what's your favourite thing about today?",
	"what are you looking forward to?",
	"what's the best advice you've been given?",
	"what's your dream pet?",
	"what's a game you were great at as a kid?",
	"tea, coffee or neither?",
	"what's your favourite fruit?",
	"if you had a theme song, what would it be?",
	"what would you name a pet goldfish?",
	"what's the funniest thing you've seen online?",
]


## The question for these two friends today.
static func for_pair(code_a: String, code_b: String) -> String:
	var codes := [code_a, code_b]
	codes.sort()
	var today := Time.get_date_string_from_system()
	return QUESTIONS[_hash("%s|%s|%s" % [codes[0], codes[1], today]) % QUESTIONS.size()]


## FNV-1a, spelled out so every phone (and every Godot version) agrees on it, unlike
## String.hash().
static func _hash(text: String) -> int:
	var result := 2166136261
	for byte in text.to_utf8_buffer():
		result = ((result ^ byte) * 16777619) & 0xFFFFFFFF
	return result
