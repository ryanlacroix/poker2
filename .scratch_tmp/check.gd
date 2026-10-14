extends SceneTree
func _initialize() -> void:
	var scene: Node = load("res://scenes/table.tscn").instantiate()
	root.add_child(scene)
	var table: PokerTable = scene._table
	var human := table.players[0]
	await table.item_turn_started
	while not scene._human_item_turn:
		await table.item_turn_started
	for p in table.players:
		if p.item == Item.Kind.SHIELD: p.item = Item.NONE
	scene._debug_give_hex(Hex.Effect.SHIELD_OVERLOAD)
	print("USE visible=%s text=%s" % [scene._use_item_button.visible, scene._use_item_button.text])
	scene._use_item()
	var btns: Array = scene._hex_modal.find_children("*", "Button", true, false)
	print("MODAL buttons=%s" % [btns.map(func(b): return b.text)])
	var dropped := [false]
	table.item_dropped.connect(func(p, item): dropped[0] = p == human and item == Item.Kind.HEX)
	btns[0].pressed.emit()
	await create_timer(0.3).timeout
	print("DROPPED=%s item=%d" % [dropped[0], human.item])
	quit()
