@tool
extends Path3D

@export_category("Road Texture Settings")

## Ajusta a escala da textura na largura da rua (Eixo X)
@export var textura_largura: float = 1.0:
	set(value):
		textura_largura = value
		_update_texture()

## Ajusta a repetição da textura ao longo da rua (Eixo Z/Path)
@export var textura_comprimento: float = 6.0:
	set(value):
		textura_comprimento = value
		_update_texture()

func _ready() -> void:
	_update_texture()

func _update_texture() -> void:
	var csg = get_node_or_null("CSGPolygon3D")
	if csg:
		# Atualiza a distância ao longo do path
		csg.path_u_distance = textura_comprimento
		
		# Atualiza a largura na escala do UV do material
		if csg.material is StandardMaterial3D:
			csg.material.uv1_scale = Vector3(textura_largura, 1.0, 1.0)
