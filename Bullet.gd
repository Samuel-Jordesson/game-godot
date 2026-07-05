extends Area3D

var speed := 200.0
var direction := Vector3.ZERO
var damage := 5

func _ready():
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _physics_process(delta):
	global_position += direction * speed * delta

func _on_body_entered(body):
	# O tiro agora é puramente visual! O dano é aplicado instantaneamente pelo RayCast da câmera
	if body.name != "Player":
		queue_free()
