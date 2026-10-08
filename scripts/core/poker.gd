class_name Poker
extends RefCounted
## Shared poker enums and text.

enum Action { FOLD, CHECK, CALL, RAISE }

enum Street { PREFLOP, FLOP, TURN, RIVER, SHOWDOWN }


static func street_name(s: Street) -> String:
	match s:
		Street.PREFLOP: return "PRE-FLOP"
		Street.FLOP: return "FLOP"
		Street.TURN: return "TURN"
		Street.RIVER: return "RIVER"
		_: return "SHOWDOWN"
