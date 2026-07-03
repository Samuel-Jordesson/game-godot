extends CharacterBody3D

const SPEED = 20.0
const ACCELERATION = 5.0
const STEER_SPEED = 2.0
const FRICTION = 3.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_driven = false
var player_ref = null

@onready var camera = $Camera3D

func _physics_process(delta):
	if not is_driven:
		# Aplica gravidade se ninguém estiver dirigindo
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return
		
	# Lógica de direção
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var move_dir = -transform.basis.z * input_dir.y
	
	if input_dir.y != 0:
		velocity.x = lerp(velocity.x, move_dir.x * SPEED, ACCELERATION * delta)
		velocity.z = lerp(velocity.z, move_dir.z * SPEED, ACCELERATION * delta)
		# Só vira se estiver indo para frente/trás
		var turn = -input_dir.x * STEER_SPEED * delta
		if input_dir.y > 0: # Dando ré inverte a direção
			turn = -turn
		rotate_y(turn)
	else:
		# Fricção
		velocity.x = lerp(velocity.x, 0.0, FRICTION * delta)
		velocity.z = lerp(velocity.z, 0.0, FRICTION * delta)
		
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	move_and_slide()

func _input(event):
	if is_driven and event is InputEventKey and event.physical_keycode == KEY_E and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		exit_car()

func enter_car(player):
	player_ref = player
	is_driven = true
	player_ref.set_physics_process(false)
	player_ref.hide()
	camera.make_current()

func exit_car():
	if player_ref:
		is_driven = false
		player_ref.set_physics_process(true)
		player_ref.show()
		player_ref.global_position = global_position + transform.basis.x * 2.0 # Sai do lado do carro
		player_ref.get_node("Camera3D").make_current() # Supõe que o player tem um Camera3D
		player_ref = null
