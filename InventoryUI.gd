extends CanvasLayer

class InventorySlot extends ColorRect:
	var item_id = ""
	var icon_tex: TextureRect
	var label: Label
	
	func _init(hotbar_num = -1):
		custom_minimum_size = Vector2(80, 80)
		color = Color(0.1, 0.1, 0.1, 0.8)
		
		icon_tex = TextureRect.new()
		icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(icon_tex)
		
		if hotbar_num > 0:
			label = Label.new()
			label.text = str(hotbar_num)
			label.position = Vector2(5, 5)
			label.add_theme_color_override("font_color", Color(1, 1, 0, 1)) # Texto amarelo
			add_child(label)
		
	func set_item(id: String):
		item_id = id
		if item_id == "arma":
			icon_tex.texture = preload("res://armas/img-arma-ak47.png")
		else:
			icon_tex.texture = null
			
	func _get_drag_data(at_position):
		if item_id == "": return null
		
		var preview = TextureRect.new()
		preview.texture = icon_tex.texture
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.custom_minimum_size = Vector2(60, 60)
		preview.modulate = Color(1, 1, 1, 0.5)
		
		set_drag_preview(preview)
		return {"type": "item", "id": item_id, "source": self}

	func _can_drop_data(at_position, data):
		return data is Dictionary and data.has("type") and data["type"] == "item"
		
	func _drop_data(at_position, data):
		var source_slot = data["source"]
		var temp_id = item_id
		set_item(data["id"])
		source_slot.set_item(temp_id)

class DropZone extends Control:
	var player_ref = null
	func _can_drop_data(at_position, data):
		return data is Dictionary and data.has("type") and data["type"] == "item"
		
	func _drop_data(at_position, data):
		if player_ref:
			player_ref.drop_item(data["id"])
		data["source"].set_item("")

var ui_root: Control
var hotbar_root: Control
var inventory_slots: Array = []
var hotbar_slots: Array = []
var player_ref = null

func _init():
	layer = 10

func _ready():
	# HOTBAR (Sempre visível, 4 quadrados embaixo)
	hotbar_root = Control.new()
	hotbar_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hotbar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hotbar_root)
	
	var hotbar_hbox = HBoxContainer.new()
	hotbar_hbox.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar_hbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hotbar_hbox.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hotbar_hbox.offset_bottom = -20
	hotbar_hbox.add_theme_constant_override("separation", 15)
	hotbar_root.add_child(hotbar_hbox)
	
	for i in range(4):
		var slot = InventorySlot.new(i + 1)
		hotbar_hbox.add_child(slot)
		hotbar_slots.append(slot)

	# INVENTÁRIO PRINCIPAL (Oculto, lado direito)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.hide()
	add_child(ui_root)
	
	var drop_zone = DropZone.new()
	drop_zone.player_ref = player_ref
	drop_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(drop_zone)
	
	var panel = PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -250
	panel.offset_right = 0
	ui_root.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	margin.add_child(grid)
	
	for i in range(10):
		var slot = InventorySlot.new()
		grid.add_child(slot)
		inventory_slots.append(slot)

func toggle():
	if ui_root.visible:
		ui_root.hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		ui_root.show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func add_item(id: String) -> bool:
	# Tenta colocar no acesso rapido primeiro
	for slot in hotbar_slots:
		if slot.item_id == "":
			slot.set_item(id)
			return true
	# Se a barra de acesso rapido estiver cheia, coloca no inventario normal
	for slot in inventory_slots:
		if slot.item_id == "":
			slot.set_item(id)
			return true
	return false
	
func get_hotbar_item(index: int) -> String:
	if index >= 0 and index < hotbar_slots.size():
		return hotbar_slots[index].item_id
	return ""
	
func remove_item(id: String):
	for slot in hotbar_slots:
		if slot.item_id == id:
			slot.set_item("")
			return
	for slot in inventory_slots:
		if slot.item_id == id:
			slot.set_item("")
			return

func has_item(id: String) -> bool:
	for slot in hotbar_slots:
		if slot.item_id == id:
			return true
	for slot in inventory_slots:
		if slot.item_id == id:
			return true
	return false
