class_name Card
extends RefCounted
## A single playing card. Rank is 2..14 (14 = ace).

enum Suit { CLUBS, DIAMONDS, HEARTS, SPADES }

var rank: int
var suit: Suit


func _init(p_rank: int, p_suit: Suit) -> void:
	rank = p_rank
	suit = p_suit


func is_red() -> bool:
	return suit == Suit.HEARTS or suit == Suit.DIAMONDS


func rank_name() -> String:
	match rank:
		11: return "J"
		12: return "Q"
		13: return "K"
		14: return "A"
		_: return str(rank)


func _to_string() -> String:
	return rank_name() + "cdhs"[suit]
