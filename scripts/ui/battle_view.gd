class_name BattleView
extends Control
## Two armies at war, played out over the table. The men draw swords, then fight [member rounds]
## of duels as the table decided them (see [signal PokerTable.battle_started]): each round, every
## man left on the smaller side is paired with one from the other, each pair runs together and
## clashes until one falls. Once a side is wiped out the survivors jump for joy, then [signal
## finished] hands them back to go home, and the view frees itself. Full-screen and
## click-through; set [member sides] and [member rounds] before adding it.

## [param winner] is the side left standing; [param survivors] are its men's top-left corners.
signal finished(winner: int, survivors: Array[Vector2])

enum Phase { ARMING, FIGHTING, BETWEEN_ROUNDS, CELEBRATING }

const PX := ArmyView.PX
const COLOR := ArmyView.COLOR
const BLADE := Color("dfe4ec")
const HILT := Color("b08a3a")
const SPARK := Color("fff6c0")
## A fallen man, lying on his side.
const FALLEN: Array[String] = [".X..X", "XXXX.", ".X..X"]
## How long the men stand with swords drawn before the first charge.
const ARM_SECONDS := 0.7
## How long a pair clashes once they meet, give or take [constant CLASH_JITTER].
const CLASH_SECONDS := 0.8
const CLASH_JITTER := 0.3
## Each swing of a clash: the two men take turns.
const SWING_SECONDS := 0.12
## How long the fallen take to fade away.
const DIE_SECONDS := 0.8
## Pause between rounds of duels.
const ROUND_PAUSE := 0.25
## The survivors' cheer: how long, how high and how often they jump.
const CELEBRATE_SECONDS := 1.2
const JUMP_HEIGHT := 4.0
const JUMP_SECONDS := 0.3
## Each round's duels are laid out in a grid round the middle of the battlefield, this far apart
## (each give or take [constant MEET_JITTER]).
const DUEL_SPACING := Vector2(26, 15)
const MEET_JITTER := 2.0
## Gap between a pair's bodies as they clash.
const DUEL_GAP := 4.0

## Each side's men, as Array[Vector2] of top-left corners (local coordinates).
var sides: Array = []
## Rounds of duels: each an Array of bools, true where side 0's man wins.
var rounds: Array = []

var _phase := Phase.ARMING
var _clock := 0.0 # seconds into the phase
var _age := 0.0
var _round := -1
var _fighters: Array[Fighter] = []
var _duels: Array[Duel] = []


class Fighter:
	var side: int
	var at: Vector2
	var target: Vector2
	var facing := 1 # 1: right, -1: left
	var stride_age := 0.0
	var duel: Duel # his duel this round, while it lasts
	var fell_at := -1.0 # [member BattleView._age] when he fell; -1 while he stands


class Duel:
	var men: Array[Fighter] # one from each side, side 0 first
	var side_0_wins: bool
	var seconds: float # how long the clash lasts
	var clashing := -1.0 # seconds into the clash; -1 until both are there


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	for side in sides.size():
		for point: Vector2 in sides[side]:
			var fighter := Fighter.new()
			fighter.side = side
			fighter.at = point
			fighter.target = point
			_fighters.append(fighter)
	# Everyone faces the other side.
	var centers := [_standing_center(0), _standing_center(1)]
	for fighter in _fighters:
		fighter.facing = 1 if centers[1 - fighter.side].x >= fighter.at.x else -1


## The middle of where [param side]'s standing men are.
func _standing_center(side: int) -> Vector2:
	var men := _standing(side)
	var sum := Vector2.ZERO
	for fighter in men:
		sum += fighter.at
	return sum / maxi(men.size(), 1)


## Where every man still standing is: top-left corners in the parent's coordinates.
func standing_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for fighter in _fighters:
		if fighter.fell_at < 0:
			points.append(position + fighter.at)
	return points


func _standing(side: int) -> Array[Fighter]:
	var men: Array[Fighter] = []
	men.assign(_fighters.filter(func(f: Fighter) -> bool: return f.side == side and f.fell_at < 0))
	return men


func _process(delta: float) -> void:
	_age += delta
	_clock += delta
	for fighter in _fighters:
		if fighter.fell_at >= 0:
			continue
		fighter.at = fighter.at.move_toward(fighter.target, ArmyView.RUN_SPEED * delta)
		fighter.stride_age = fighter.stride_age + delta if fighter.at != fighter.target else 0.0

	match _phase:
		Phase.ARMING:
			if _clock >= ARM_SECONDS:
				_start_round(0)
		Phase.FIGHTING:
			_fight(delta)
		Phase.BETWEEN_ROUNDS:
			if _clock >= ROUND_PAUSE:
				_start_round(_round + 1)
		Phase.CELEBRATING:
			if _clock >= CELEBRATE_SECONDS:
				var winner := 0 if not _standing(0).is_empty() else 1
				var survivors: Array[Vector2] = []
				for fighter in _standing(winner):
					survivors.append(fighter.at)
				finished.emit(winner, survivors)
				queue_free()
	queue_redraw()


## Pairs up the men for round [param r] and sends each pair running together; past the last
## round, the survivors celebrate.
func _start_round(r: int) -> void:
	_round = r
	_clock = 0
	_duels.clear()
	if r >= rounds.size():
		_phase = Phase.CELEBRATING
		return
	_phase = Phase.FIGHTING
	# Paired top to bottom, so pairs cross each other's paths as little as they can.
	var by_height := func(x: Fighter, y: Fighter) -> bool: return x.at.y < y.at.y
	var ranks: Array = [_standing(0), _standing(1)]
	for men: Array[Fighter] in ranks:
		men.sort_custom(by_height)
	var duels: Array = rounds[r]
	# The grid: a little taller than it is wide, centred between the two sides.
	var grid_rows := ceili(sqrt(duels.size() * 2.0))
	@warning_ignore("integer_division")
	var grid_size := Vector2((duels.size() + grid_rows - 1) / grid_rows, mini(grid_rows, duels.size()))
	var middle := (_standing_center(0) + _standing_center(1)) / 2 + ArmyView.MAN_SIZE / 2
	for i in duels.size():
		var duel := Duel.new()
		duel.men.assign([ranks[0][i], ranks[1][i]])
		duel.side_0_wins = duels[i]
		duel.seconds = CLASH_SECONDS + randf_range(-CLASH_JITTER, CLASH_JITTER)
		_duels.append(duel)
		# They meet about halfway, side by side and facing each other.
		var left: Fighter = duel.men[0] if duel.men[0].at.x <= duel.men[1].at.x else duel.men[1]
		var right: Fighter = duel.men[1] if left == duel.men[0] else duel.men[0]
		@warning_ignore("integer_division")
		var cell := Vector2(i / grid_rows, i % grid_rows)
		var meet := middle + (cell - (grid_size - Vector2.ONE) / 2) * DUEL_SPACING \
			+ Vector2(randf_range(-1, 1), randf_range(-1, 1)) * MEET_JITTER
		var bounds := Rect2(Vector2.ZERO, size - ArmyView.MAN_SIZE)
		left.target = (meet - Vector2(ArmyView.MAN_SIZE.x + DUEL_GAP / 2, 0)).clamp(bounds.position, bounds.end).floor()
		right.target = (left.target + Vector2(ArmyView.MAN_SIZE.x + DUEL_GAP, 0)).floor()
		left.facing = 1
		right.facing = -1
		for fighter in duel.men:
			fighter.duel = duel


## Clashes go on once both men are there; when one ends, the loser falls. When every duel's
## over, a pause before the next round.
func _fight(delta: float) -> void:
	var fighting := false
	for duel in _duels:
		if duel.men[0].duel != duel:
			continue
		fighting = true
		if duel.clashing < 0:
			if duel.men.all(func(f: Fighter) -> bool: return f.at == f.target):
				duel.clashing = 0
			continue
		duel.clashing += delta
		if duel.clashing >= duel.seconds:
			duel.men[1 if duel.side_0_wins else 0].fell_at = _age
			for fighter in duel.men:
				fighter.duel = null
	if not fighting:
		_phase = Phase.BETWEEN_ROUNDS
		_clock = 0


func _draw() -> void:
	# Further back (higher up) first, so nearer men stand in front.
	var men := _fighters.duplicate()
	men.sort_custom(func(x: Fighter, y: Fighter) -> bool: return x.at.y < y.at.y)
	for fighter: Fighter in men:
		if fighter.fell_at >= 0:
			var fade := (_age - fighter.fell_at) / DIE_SECONDS
			if fade < 1:
				# Lying where he stood, feet on the same ground.
				var lying := fighter.at + Vector2(-PX, ArmyView.MAN_SIZE.y - FALLEN.size() * PX)
				PixelArt.draw(self, FALLEN, lying.floor(), PX, Color(COLOR, 1 - fade))
			continue
		_draw_fighter(fighter)
	for duel in _duels:
		if duel.clashing >= 0 and duel.men[0].duel == duel and _swing(duel) >= 0:
			_draw_spark(duel)


func _draw_fighter(fighter: Fighter) -> void:
	var at := fighter.at.floor()
	var swinging := fighter.duel != null and _swing(fighter.duel) == fighter.duel.men.find(fighter)
	if fighter.at != fighter.target:
		var frame := int(fighter.stride_age / ArmyView.RUN_FRAME_SECONDS) % ArmyView.STRIDE.size()
		at.y -= PX if frame == 0 else 0
		PixelArt.draw(self, ArmyView.STRIDE[frame], at, PX, COLOR)
	else:
		if _phase == Phase.CELEBRATING:
			at.y -= roundf(absf(sin(_clock / JUMP_SECONDS * PI)) * JUMP_HEIGHT)
		PixelArt.draw(self, ArmyView.STAND, at, PX, COLOR)
	_draw_sword(at, fighter.facing, swinging)


## Which of a clashing duel's men is mid-swing (0 or 1), or -1 if they haven't met yet.
func _swing(duel: Duel) -> int:
	if duel.clashing < 0:
		return -1
	return int(duel.clashing / SWING_SECONDS) % 2


## A sword in the hand at the end of the arm on the [param facing] side: held up, or swung
## out level when [param swinging].
func _draw_sword(at: Vector2, facing: int, swinging: bool) -> void:
	var hand := Vector2(3 if facing > 0 else -1, 1)
	_cell(at, hand, HILT)
	for i in range(1, 4):
		_cell(at, hand + (Vector2(facing * i, 0) if swinging else Vector2(0, -i)), BLADE)


## A few bright pixels where two blades meet.
func _draw_spark(duel: Duel) -> void:
	var middle := ((duel.men[0].at + duel.men[1].at) / 2 + Vector2(ArmyView.MAN_SIZE.x / 2, PX)).floor()
	for i in 3:
		draw_rect(Rect2(middle + Vector2(randi_range(-2, 2), randi_range(-2, 2)), Vector2.ONE * PX / 2.0), SPARK)


func _cell(at: Vector2, cell: Vector2, color: Color) -> void:
	draw_rect(Rect2(at + cell * PX, Vector2.ONE * PX), color)
