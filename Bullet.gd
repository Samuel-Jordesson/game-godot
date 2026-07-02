extends Area3D

var speed := 150.0
var direction := Vector3.ZERO
var damage := 1

func _ready():
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _physics_process(delta):
	global_position += direction * speed * delta

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(damage)
	# Ignora o player para que a bala nao exploda nele mesmo
	if body.name != "Player":
		queue_free()
