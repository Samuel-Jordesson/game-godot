extends Area3D

var rotation_speed = 1.0
var can_interact = false

func _ready():
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Coloca a arma deitada no chão
	if has_node("arma"):
		$arma.position = Vector3(0, 0.05, 0)
		$arma.rotation_degrees = Vector3(90, 0, 0)

func _process(delta):
	# (Removida a rotação para a arma ficar deitada no chão)
		
	if can_interact and Input.is_physical_key_pressed(KEY_E):
		# Previne múltiplos pickups no mesmo frame
		can_interact = false
		for body in get_overlapping_bodies():
			if body.name == "Player" and body.has_method("pickup_weapon"):
				body.pickup_weapon()
				queue_free()
				break

func _on_body_entered(body):
	if body.name == "Player":
		can_interact = true

func _on_body_exited(body):
	if body.name == "Player":
		can_interact = false
