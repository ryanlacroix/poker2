class_name HandEvaluator
extends RefCounted
## Scores the best 5-card hand out of 5-7 cards. A score is
## [category, tiebreak1, tiebreak2, ...]; compare scores with [method compare].

enum Category {
	HIGH_CARD,
	PAIR,
	TWO_PAIR,
	THREE_OF_A_KIND,
	STRAIGHT,
	FLUSH,
	FULL_HOUSE,
	FOUR_OF_A_KIND,
	STRAIGHT_FLUSH,
}

const CATEGORY_NAMES: Array[String] = [
	"High Card", "Pair", "Two Pair", "Three of a Kind", "Straight",
	"Flush", "Full House", "Four of a Kind", "Straight Flush",
]


static func evaluate(cards: Array[Card]) -> Array[int]:
	var counts := PackedInt32Array()
	counts.resize(15)
	var suit_counts := PackedInt32Array([0, 0, 0, 0])
	for c in cards:
		counts[c.rank] += 1
		suit_counts[c.suit] += 1

	var flush_suit := -1
	for s in 4:
		if suit_counts[s] >= 5:
			flush_suit = s
	var flush: Array[int] = []
	if flush_suit >= 0:
		var flush_mask := 0
		for c in cards:
			if c.suit == flush_suit:
				flush.append(c.rank)
				flush_mask |= 1 << c.rank
		flush.sort()
		flush.reverse()
		var sf_high := _straight_high(flush_mask)
		if sf_high > 0:
			return _score([Category.STRAIGHT_FLUSH, sf_high])

	var quads: Array[int] = []
	var trips: Array[int] = []
	var pairs: Array[int] = []
	var present: Array[int] = []
	var present_mask := 0
	for r in range(14, 1, -1):
		var n := counts[r]
		if n > 0:
			present.append(r)
			present_mask |= 1 << r
		if n == 4:
			quads.append(r)
		elif n == 3:
			trips.append(r)
		elif n == 2:
			pairs.append(r)

	if not quads.is_empty():
		return _score([Category.FOUR_OF_A_KIND, quads[0]], _kickers(present, 1, [quads[0]]))

	if not trips.is_empty() and (trips.size() >= 2 or not pairs.is_empty()):
		var pair_rank := trips[1] if trips.size() >= 2 else 0
		if not pairs.is_empty():
			pair_rank = maxi(pair_rank, pairs[0])
		return _score([Category.FULL_HOUSE, trips[0], pair_rank])

	if not flush.is_empty():
		return _score([Category.FLUSH], flush.slice(0, 5))

	var straight_high := _straight_high(present_mask)
	if straight_high > 0:
		return _score([Category.STRAIGHT, straight_high])

	if not trips.is_empty():
		return _score([Category.THREE_OF_A_KIND, trips[0]], _kickers(present, 2, [trips[0]]))

	if pairs.size() >= 2:
		return _score([Category.TWO_PAIR, pairs[0], pairs[1]], _kickers(present, 1, [pairs[0], pairs[1]]))

	if pairs.size() == 1:
		return _score([Category.PAIR, pairs[0]], _kickers(present, 3, [pairs[0]]))

	return _score([Category.HIGH_CARD], present.slice(0, 5))


## 1 if a beats b, -1 if b beats a, 0 on a tie.
static func compare(a: Array[int], b: Array[int]) -> int:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return 1 if a[i] > b[i] else -1
	return 0


static func describe(score: Array[int]) -> String:
	return CATEGORY_NAMES[score[0]]


## The five cards (out of 5-7) that make up the best hand, kickers included.
static func best_five(cards: Array[Card]) -> Array[Card]:
	var target := evaluate(cards)
	var n := cards.size()
	var five: Array[Card] = [null, null, null, null, null]
	for a in n:
		for b in range(a + 1, n):
			for c in range(b + 1, n):
				for d in range(c + 1, n):
					for e in range(d + 1, n):
						five[0] = cards[a]; five[1] = cards[b]; five[2] = cards[c]; five[3] = cards[d]; five[4] = cards[e]
						if compare(evaluate(five), target) == 0:
							return five
	return cards.slice(0, 5)


## The cards in [param five] that make its hand, leaving out kickers: the matched ranks for
## pairs, trips and quads, the top card for a high card, and all five otherwise.
static func scoring_cards(five: Array[Card]) -> Array[Card]:
	match evaluate(five)[0]:
		Category.PAIR, Category.TWO_PAIR, Category.THREE_OF_A_KIND, Category.FOUR_OF_A_KIND:
			return five.filter(func(c: Card) -> bool:
				return five.filter(func(o: Card) -> bool: return o.rank == c.rank).size() >= 2)
		Category.HIGH_CARD:
			var top := five[0]
			for c in five:
				if c.rank > top.rank:
					top = c
			return [top]
		_:
			return five.duplicate()


## Highest card of a 5-card run, or 0, given a bitmask of the ranks present (bit r for rank r).
## Handles the A-2-3-4-5 wheel.
static func _straight_high(rank_mask: int) -> int:
	if rank_mask & (1 << 14):
		rank_mask |= 1 << 1 # the ace also plays low
	for high in range(14, 4, -1):
		if (rank_mask >> (high - 4)) & 0x1F == 0x1F:
			return high
	return 0


## Builds a score from its leading entries plus [param tail].
static func _score(head: Array, tail: Array[int] = []) -> Array[int]:
	var score: Array[int] = []
	score.assign(head)
	score.append_array(tail)
	return score


static func _kickers(present: Array[int], n: int, exclude: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for r in present:
		if result.size() == n:
			break
		if r not in exclude:
			result.append(r)
	return result
