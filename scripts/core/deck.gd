class_name Deck
extends RefCounted
## A standard 52-card deck.

var _cards: Array[Card] = []
var _next := 0


func _init() -> void:
	for suit: Card.Suit in Card.Suit.values():
		for rank in range(2, 15):
			_cards.append(Card.new(rank, suit))
	reset()


## Put all cards back and shuffle.
func reset() -> void:
	_cards.shuffle()
	_next = 0


func draw() -> Card:
	_next += 1
	return _cards[_next - 1]


func remaining() -> int:
	return _cards.size() - _next
