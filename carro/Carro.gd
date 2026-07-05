extends CharacterBody3D

@export var max_speed = 30.0
@export var acceleration = 15.0
@export var braking = 25.0
@export var steer_speed = 2.5
@export var traction_fast = 0.5   # Quanto derrapa em alta velocidade
@export var traction_slow = 2.0   # Quanto derrapa em baixa velocidade
@export var camera_sensitivity = 0.003

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_driven = false
var player_ref = null
var current_speed = 0.0

@onready var spring_arm = $SpringArm3D
@onready var camera = $SpringArm3D/Camera3D
@onready var mesh = $DerbyCar

var wheel_fl = null
var wheel_fr = null
var wheel_rl = null
var wheel_rr = null
var wheel_roll = 0.0

var init_fl = Basis()
var init_fr = Basis()
var init_rl = Basis()
var init_rr = Basis()

func _ready():
	if mesh:
		wheel_fl = mesh.find_child("*Wheel_FL*", true, false)
		wheel_fr = mesh.find_child("*Wheel_FR*", true, false)
		wheel_rl = mesh.find_child("*Wheel_RL*", true, false)
		wheel_rr = mesh.find_child("*Wheel_RR*", true, false)
		
		if wheel_fl: init_fl = wheel_fl.transform.basis
		if wheel_fr: init_fr = wheel_fr.transform.basis
		if wheel_rl: init_rl = wheel_rl.transform.basis
		if wheel_rr: init_rr = wheel_rr.transform.basis

func _physics_process(delta):
	# Envia a posição do carro para a água para criar as ondas
	var water_mat = load("res://water_material.tres")
	if water_mat:
		water_mat.set_shader_parameter("car_pos", global_position)
		
	if not is_driven:
		# Aplica gravidade se ninguém estiver dirigindo
		if not is_on_floor():
			velocity.y -= gravity * delta
		current_speed = 0.0
		velocity = velocity.lerp(Vector3.ZERO, delta * 3.0) # Para o carro suavemente
		move_and_slide()
		return
		
	# Lógica de controle WASD manual
	var gas = 0.0
	var steer = 0.0
	
	if Input.is_physical_key_pressed(KEY_W):
		gas += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		gas -= 1.0
		
	if Input.is_physical_key_pressed(KEY_A):
		steer += 1.0
	if Input.is_physical_key_pressed(KEY_D):
		steer -= 1.0

	# Aplica aceleração ou freio
	if gas > 0:
		current_speed = move_toward(current_speed, max_speed, acceleration * delta)
	elif gas < 0:
		current_speed = move_toward(current_speed, -max_speed / 2.0, braking * delta)
	else:
		current_speed = move_toward(current_speed, 0, braking * 0.5 * delta)

	# Rotação (vira mais devagar quando está parando, inverte quando dá ré)
	var speed_factor = clamp(abs(current_speed) / 5.0, 0.0, 1.0)
	var turn = steer * steer_speed * delta * speed_factor
	if current_speed < 0:
		turn = -turn
	rotate_y(turn)

	# Calcula vetor de movimento baseado pra onde o carro está olhando (transform.basis.z é pra trás)
	var forward = -transform.basis.z
	var target_velocity = forward * current_speed
	
	# Tração para criar efeito de drift (menor tração = mais drift)
	var traction = traction_slow
	if abs(current_speed) > max_speed * 0.5:
		traction = traction_fast
		
	velocity.x = lerp(velocity.x, target_velocity.x, traction * delta)
	velocity.z = lerp(velocity.z, target_velocity.z, traction * delta)
	
	# Aplica gravidade
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Movimento final
	move_and_slide()
	
	# Roda visualmente o chassi do carro um pouco pro lado ao virar (pra dar peso)
	if mesh:
		var tilt = steer * speed_factor * 0.05
		mesh.rotation.z = lerp(mesh.rotation.z, tilt, delta * 5.0)
		
		# Animação das rodas (mantendo a rotação inicial do modelo, calculando a partir do eixo do carro)
		wheel_roll -= current_speed * delta * 1.5 # Gira as rodas dependendo da velocidade
		
		# Base de esterçamento (vira a roda em torno do eixo Y do carro)
		var steer_basis = Basis(Vector3.UP, steer * 0.5)
		
		# O eixo de rotação da roda (o eixo X do carro, virado pelo esterçamento)
		var steered_x = steer_basis * Vector3.RIGHT
		
		# Base de rolagem (gira a roda em torno do eixo X esterçado)
		var roll_basis = Basis(steered_x, wheel_roll)
		
		if wheel_fl:
			wheel_fl.transform.basis = roll_basis * steer_basis * init_fl
		if wheel_fr:
			wheel_fr.transform.basis = roll_basis * steer_basis * init_fr
		
		# Rodas traseiras não esterçam, só rolam no eixo X normal do carro
		var back_roll_basis = Basis(Vector3.RIGHT, wheel_roll)
		if wheel_rl:
			wheel_rl.transform.basis = back_roll_basis * init_rl
		if wheel_rr:
			wheel_rr.transform.basis = back_roll_basis * init_rr

func _input(event):
	if is_driven:
		# Mover a câmera com o mouse
		if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			spring_arm.rotation.y -= event.relative.x * camera_sensitivity
			spring_arm.rotation.x -= event.relative.y * camera_sensitivity
			spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-60), deg_to_rad(10))
			
		# Sair do carro
		if event is InputEventKey and event.physical_keycode == KEY_E and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			exit_car()

func enter_car(player):
	if is_driven: return
	player_ref = player
	is_driven = true
	player_ref.set_physics_process(false)
	player_ref.hide()
	
	# Configura a câmera para trás do carro
	spring_arm.rotation = Vector3(deg_to_rad(-15), 0, 0)
	camera.make_current()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func exit_car():
	if player_ref:
		is_driven = false
		player_ref.set_physics_process(true)
		player_ref.show()
		player_ref.global_position = global_position + transform.basis.x * 2.5 # Sai pela porta esquerda
		
		# Volta para a câmera do player
		var p_camera = player_ref.get_node_or_null("SpringArm3D/Camera3D")
		if p_camera:
			p_camera.make_current()
			
		player_ref = null
