extends CanvasLayer

class InventorySlot extends ColorRect:
	var item_id = ""
	var icon_tex: TextureRect
	
	func _init():
		custom_minimum_size = Vector2(80, 80)
		color = Color(0.1, 0.1, 0.1, 0.8)
		
		icon_tex = TextureRect.new()
		icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(icon_tex)
		
	func set_item(id: String):
		item_id = id
		if item_id == "arma":
			# Usando o ícone do Godot como placeholder visual para a arma
			icon_tex.texture = preload("res://icon.svg")
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
var slots: Array = []
var player_ref = null

func _init():
	layer = 10

func _ready():
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.hide()
	add_child(ui_root)
	
	# Dropzone que pega a tela inteira por trás do inventário
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
	
	# Criar 10 slots
	for i in range(10):
		var slot = InventorySlot.new()
		grid.add_child(slot)
		slots.append(slot)

func toggle():
	if ui_root.visible:
		ui_root.hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		ui_root.show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func add_item(id: String) -> bool:
	for slot in slots:
		if slot.item_id == "":
			slot.set_item(id)
			return true
	return false
	
func remove_item(id: String):
	for slot in slots:
		if slot.item_id == id:
			slot.set_item("")
			break

func has_item(id: String) -> bool:
	for slot in slots:
		if slot.item_id == id:
			return true
	return false
