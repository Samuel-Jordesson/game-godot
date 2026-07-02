extends Node3D

var flash: Sprite3D
var flash_textures = []
var flash_timer := 0.0

func _ready():
	# Busca o nó Flash diretamente como filho principal
	flash = find_child("Flash", true, false)
	
	flash_textures.append(preload("res://armas/flash/1.png"))
	flash_textures.append(preload("res://armas/flash/2.png"))
	flash_textures.append(preload("res://armas/flash/3.png"))
	
	if flash:
		# Cria um material customizado (Overlay/ADD) para fazer o fundo preto sumir
		var mat = StandardMaterial3D.new()
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.no_depth_test = true # Faz o fogo renderizar "por cima" de tudo, ignorando colisão visual com o chão/paredes
		flash.material_override = mat

func _process(delta):
	if flash_timer > 0:
		flash_timer -= delta
		if flash_timer <= 0 and flash:
			flash.hide()

func shoot():
	if not flash: return
	var tex = flash_textures.pick_random()
	
	# Aplica a textura no material override que tem o efeito ADD
	if flash.material_override:
		flash.material_override.albedo_texture = tex
	
	flash.texture = tex # Mantém aqui pra garantir
	flash.show()
	flash.rotation_degrees.z = randf_range(0, 360) # Giro aleatório pro fogo não ficar repetitivo
	flash_timer = 0.05
