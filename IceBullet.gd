extends Area3D

var speed := 25.0
var direction := Vector3.ZERO

func _ready():
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _physics_process(delta):
	global_position += direction * speed * delta
	# Roda o floco de neve
	if has_node("Sprite3D"):
		$Sprite3D.rotate_z(delta * 5.0)

func _on_body_entered(body):
	if body.name != "Player":
		queue_free()
