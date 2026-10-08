class_name Completion
extends RefCounted
## A one-shot result that a coroutine can wait for (like a TaskCompletionSource). Unlike waiting
## on a bare signal, a result set before [method wait] is called isn't lost.

signal _completed

var _done := false
var _value: Variant


## Sets the result and wakes the waiter. Does nothing if a result was already set.
func set_result(value: Variant = null) -> void:
	if _done:
		return
	_done = true
	_value = value
	_completed.emit()


## The result, once set. Use with [code]await[/code].
func wait() -> Variant:
	if not _done:
		await _completed
	return _value
