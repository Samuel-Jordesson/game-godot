extends CharacterBody3D

@export var speed := 3.5
@export var chase_distance := 15.0
@export var attack_distance := 1.5
@export var wander_interval := 10.0
@export var wander_radius := 5.0

var health := 10
var state = "idle" # idle, wander, chase, attack
var timer := 0.0
var wander_target := Vector3.ZERO
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var player: Node3D
var anim_player: AnimationPlayer
var model_instance: Node3D

func _ready():
	# Busca o jogador na cena
	player = get_tree().get_root().find_child("Player", true, false)
	
	_setup_model_and_animations()

func _setup_model_and_animations():
	# Pega o modelo base (Idle) que agora já está na cena pelo editor
	var idle_scene = $"Zombie Idle"
	model_instance = idle_scene
	
	anim_player = _get_animation_player(idle_scene)
	
	if anim_player:
		# Puxa a animação de Idle atual
		var idle_anim = _extract_first_anim(idle_scene)
		
		# Puxa a animação de Correndo
		var run_scene = preload("res://inimigo/Zombie Running.fbx").instantiate()
		var run_anim = _extract_first_anim(run_scene)
		
		# Puxa a animação de Ataque
		var attack_scene = preload("res://inimigo/Zombie Attack.fbx").instantiate()
		var attack_anim = _extract_first_anim(attack_scene)
		
		# Adiciona as animações na biblioteca do AnimationPlayer do modelo
		var lib = anim_player.get_animation_library("")
		if not lib:
			lib = AnimationLibrary.new()
			anim_player.add_animation_library("", lib)
			
		if idle_anim:
			idle_anim.loop_mode = Animation.LOOP_LINEAR
			if not lib.has_animation("idle"): lib.add_animation("idle", idle_anim)
		if run_anim:
			run_anim.loop_mode = Animation.LOOP_LINEAR
			if not lib.has_animation("run"): lib.add_animation("run", run_anim)
		if attack_anim:
			attack_anim.loop_mode = Animation.LOOP_LINEAR
			if not lib.has_animation("attack"): lib.add_animation("attack", attack_anim)
			
		anim_player.play("idle")

func _get_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for c in node.get_children():
		var ap = _get_animation_player(c)
		if ap: return ap
	return null

func _extract_first_anim(node: Node) -> Animation:
	var ap = _get_animation_player(node)
	if not ap: return null
	for anim_name in ap.get_animation_list():
		if anim_name != "RESET":
			var anim = ap.get_animation(anim_name).duplicate()
			# Remove movimento X/Z para as animações ficarem "in-place" e ele não escorregar
			for i in range(anim.get_track_count()):
				if anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
					var path = String(anim.track_get_path(i))
					if "Hips" in path or "Root" in path:
						for k in range(anim.track_get_key_count(i)):
							var pos = anim.track_get_key_value(i, k)
							anim.track_set_key_value(i, k, Vector3(0, pos.y, 0))
			return anim
	return null

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	timer += delta
	
	if not player:
		player = get_tree().get_root().find_child("Player", true, false)
		if not player:
			move_and_slide()
			return
		
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player <= attack_distance:
		_change_state("attack")
	elif distance_to_player <= chase_distance:
		_change_state("chase")
	elif state == "chase" or state == "attack":
		# Se o jogador fugiu pra muito longe, volta pra idle
		_change_state("idle")
		timer = 0.0 # Reseta o timer
		
	match state:
		"idle":
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)
			if timer >= wander_interval:
				_pick_wander_target()
				_change_state("wander")
				
		"wander":
			var dir = (wander_target - global_position)
			dir.y = 0
			if dir.length() < 0.5:
				_change_state("idle")
				timer = 0.0
			else:
				dir = dir.normalized()
				velocity.x = dir.x * speed
				velocity.z = dir.z * speed
				_look_at_dir(dir, delta)
				
				# Volta pra idle depois de tentar andar por 4 seg pra não ficar travado na parede
				if timer >= 4.0:
					_change_state("idle")
					timer = 0.0
				
		"chase":
			var dir = (player.global_position - global_position)
			dir.y = 0
			dir = dir.normalized()
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			_look_at_dir(dir, delta)
			
		"attack":
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)
			var dir = (player.global_position - global_position)
			dir.y = 0
			if dir.length() > 0.01:
				_look_at_dir(dir.normalized(), delta)

	move_and_slide()

func _pick_wander_target():
	var random_x = randf_range(-wander_radius, wander_radius)
	var random_z = randf_range(-wander_radius, wander_radius)
	wander_target = global_position + Vector3(random_x, 0, random_z)
	timer = 0.0

func _look_at_dir(dir: Vector3, delta: float):
	if model_instance and dir.length_squared() > 0.001:
		var target_angle = atan2(dir.x, dir.z)
		model_instance.rotation.y = lerp_angle(model_instance.rotation.y, target_angle, delta * 12.0)

func _change_state(new_state: String):
	if state == new_state: return
	
	state = new_state
	
	if not anim_player: return
	
	if state == "idle":
		anim_player.play("idle", 0.25)
	elif state == "wander" or state == "chase":
		anim_player.play("run", 0.25)
	elif state == "attack":
		anim_player.play("attack", 0.1)

func take_damage(amount: int = 1):
	health -= amount
	if health <= 0:
		queue_free()
