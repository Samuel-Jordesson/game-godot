extends CharacterBody3D

@export var walk_speed := 3.0
@export var run_speed := 7.0
@export var jump_velocity := 4.5
@export var camera_sensitivity := 0.003
@export var turn_speed := 10.0
@export var blend_time := 0.25 # Tempo de suavização entre as animações
@export var normal_cam_dist := 3.0
@export var aim_cam_dist := 1.2

@export_category("Ajustes da Arma")
@export var weapon_scale := Vector3(0.3, 0.3, 0.3) # Ajustado pelo seu teste
@export var hand_weapon_pos := Vector3(0.0, 0.0, 0.0) # Zerado para colar na mão de verdade
@export var hand_weapon_rot := Vector3(0.0, 96.0, 0.0)
@export var back_weapon_pos := Vector3(0, 0.2, 0.2)
@export var back_weapon_rot := Vector3(90, 0, 0)

@onready var spring_arm = $SpringArm3D
@onready var armature = $Armature
@onready var camera = $SpringArm3D/Camera3D

# Vamos usar apenas O PRIMEIRO MODELO para tudo (assim as transições ficam perfeitas)
@onready var model_idle = $"Armature/Warrior Idle"
var anim_player : AnimationPlayer
var anim_tree : AnimationTree

var current_state = "idle"
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var shoot_timer := 0.0
var time_since_last_shot := 0.0
var fire_rate := 0.1

var skeleton_ref: Skeleton3D
var spine_bones := []

# Sistema de inventário e arma
var has_weapon = false
var is_weapon_equipped = false
var weapon_back_attachment: BoneAttachment3D
var weapon_hand_attachment: BoneAttachment3D
var back_weapon_instance: Node3D
var hand_weapon_instance: Node3D
var inventory_ui
var crosshair: ColorRect

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Instancia a UI do inventário por código e adiciona
	inventory_ui = preload("res://InventoryUI.gd").new()
	inventory_ui.player_ref = self
	add_child(inventory_ui)
	
	skeleton_ref = find_skeleton(self)
	if skeleton_ref:
		for bone_name in ["mixamorig_Spine", "Spine", "mixamorig_Spine1", "Spine1", "mixamorig_Spine2", "Spine2"]:
			var idx = skeleton_ref.find_bone(bone_name)
			if idx != -1 and not spine_bones.has(idx):
				spine_bones.append(idx)
	
	# Criação da mira (ponto branco central)
	var canvas = CanvasLayer.new()
	add_child(canvas)
	crosshair = ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.8) # Branco levemente transparente
	crosshair.custom_minimum_size = Vector2(4, 4)
	canvas.add_child(crosshair)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	# Centraliza perfeitamente deslocando o offset pela metade do tamanho
	crosshair.offset_left = -2
	crosshair.offset_top = -2
	crosshair.offset_right = 2
	crosshair.offset_bottom = 2
	crosshair.hide()
	
	# Esconde os outros modelos, não vamos mais usá-los visualmente
	if $Armature.has_node("Walking"): $Armature/Walking.hide()
	if $Armature.has_node("Running"): $Armature/Running.hide()
	
	if model_idle and model_idle.has_node("AnimationPlayer"):
		anim_player = model_idle.get_node("AnimationPlayer")
		
		# 1. Puxar a animação do arquivo Walking
		var walk_scene = preload("res://Flavio/Walking.fbx").instantiate()
		var walk_anim = _extract_first_anim(walk_scene)
		
		# 2. Puxar a animação do arquivo Running
		var run_scene = preload("res://Flavio/Running.fbx").instantiate()
		var run_anim = _extract_first_anim(run_scene)
		
		# Puxar a animação de Idle atual
		var idle_anim = _extract_first_anim(model_idle)
		
		# Puxar as novas animações de tiro
		var aim_idle_scene = preload("res://Flavio/tiro/Rifle Aiming Idle.fbx").instantiate()
		var aim_idle_anim = _extract_first_anim(aim_idle_scene)
		
		var aim_walk_scene = preload("res://Flavio/tiro/Walking-mirando.fbx").instantiate()
		var aim_walk_anim = _extract_first_anim(aim_walk_scene)
		
		var shoot_scene = preload("res://Flavio/tiro/Gunplay.fbx").instantiate()
		var shoot_anim = _extract_first_anim(shoot_scene)
		
		# Vamos adicionar as animações de andar e correr na biblioteca do modelo principal
		var lib = anim_player.get_animation_library("")
		if not lib:
			lib = AnimationLibrary.new()
			anim_player.add_animation_library("", lib)
			
		if not lib.has_animation("walk") and walk_anim:
			lib.add_animation("walk", walk_anim)
		if not lib.has_animation("run") and run_anim:
			lib.add_animation("run", run_anim)
		if not lib.has_animation("idle") and idle_anim:
			lib.add_animation("idle", idle_anim)
		
		# Adiciona as de tiro
		if not lib.has_animation("aim_idle") and aim_idle_anim:
			lib.add_animation("aim_idle", aim_idle_anim)
		if not lib.has_animation("aim_walk") and aim_walk_anim:
			lib.add_animation("aim_walk", aim_walk_anim)
		if not lib.has_animation("shoot") and shoot_anim:
			lib.add_animation("shoot", shoot_anim)
			
		# Monta a árvore de animações dinâmica para misturar corpo perfeitamente
		_setup_animation_tree()
		
	# Prepara os nós de anexo de arma nos ossos do esqueleto
	_setup_weapon_attachments()

func _setup_animation_tree():
	anim_tree = AnimationTree.new()
	anim_tree.anim_player = anim_player.get_path()
	
	var blend_tree = AnimationNodeBlendTree.new()
	
	# Nó de transição para o movimento das pernas
	var state_transition = AnimationNodeTransition.new()
	state_transition.xfade_time = blend_time
	var anim_names = ["idle", "walk", "run", "aim_idle", "aim_walk"]
	
	blend_tree.add_node("state_transition", state_transition)
	
	for i in range(anim_names.size()):
		state_transition.add_input(str(i))
		var anim_node = AnimationNodeAnimation.new()
		anim_node.animation = anim_names[i]
		blend_tree.add_node(anim_names[i], anim_node)
		blend_tree.connect_node("state_transition", i, anim_names[i])
		

	
	# Nó para atirar (OneShot que só afeta tronco e braços)
	var oneshot = AnimationNodeOneShot.new()
	oneshot.fadein_time = 0.1
	oneshot.fadeout_time = 0.2
	oneshot.filter_enabled = true
	
	var skeleton = find_skeleton(self)
	if skeleton:
		var upper_bones = ["Spine", "Neck", "Head", "Shoulder", "Arm", "ForeArm", "Hand", "Fingers", "Thumb"]
		for i in range(skeleton.get_bone_count()):
			var bname = skeleton.get_bone_name(i)
			for u in upper_bones:
				if u in bname:
					oneshot.set_filter_path(NodePath(bname), true)
					break
					
	blend_tree.add_node("shoot_oneshot", oneshot)
	
	var shoot_anim_node = AnimationNodeAnimation.new()
	shoot_anim_node.animation = "shoot"
	blend_tree.add_node("shoot_anim", shoot_anim_node)
	
	# Conecta tudo
	blend_tree.connect_node("shoot_oneshot", 0, "state_transition")
	blend_tree.connect_node("shoot_oneshot", 1, "shoot_anim")
	blend_tree.connect_node("output", 0, "shoot_oneshot")
	
	anim_tree.tree_root = blend_tree
	anim_tree.active = true
	add_child(anim_tree)
	
	_switch_state("idle")

func _extract_first_anim(node) -> Animation:
	if not node.has_node("AnimationPlayer"): return null
	var ap = node.get_node("AnimationPlayer")
	for anim_name in ap.get_animation_list():
		if anim_name != "RESET":
			var anim = ap.get_animation(anim_name).duplicate()
			# Força a animação a ficar em Loop infinito
			anim.loop_mode = Animation.LOOP_LINEAR 
			
			# CORREÇÃO DO PULO PRA FRENTE: Zera o movimento X e Z (Root Motion), mantendo o Y (Bounce)
			for i in range(anim.get_track_count()):
				if anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
					var path = String(anim.track_get_path(i))
					# Procura o osso principal do Mixamo (Hips)
					if "Hips" in path or "Root" in path:
						for k in range(anim.track_get_key_count(i)):
							var pos = anim.track_get_key_value(i, k)
							# Remove o deslocamento pra frente/lados, trava no centro (X=0, Z=0)
							anim.track_set_key_value(i, k, Vector3(0, pos.y, 0))
							
			return anim
	return null
	
func _input(event):
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		spring_arm.rotate_y(-event.relative.x * camera_sensitivity)
		spring_arm.rotation.x -= event.relative.y * camera_sensitivity
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-80), deg_to_rad(60))
		
	# Tecla 1 para equipar/guardar a arma
	if event is InputEventKey and event.physical_keycode == KEY_1 and event.pressed and not event.echo:
		if has_weapon:
			toggle_weapon()
			
	# Tecla I para abrir o inventário
	if event is InputEventKey and event.physical_keycode == KEY_I and event.pressed and not event.echo:
		if inventory_ui:
			inventory_ui.toggle()

func _physics_process(delta):
	if crosshair:
		crosshair.visible = is_weapon_equipped

	# Atualiza a posição da arma em tempo real para ajudar nos ajustes
	if has_weapon:
		_update_weapon_transforms()
		
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Pega os inputs WSAD manualmente caso o ui_left/right não esteja configurado pra WASD
	var input_x = 0.0
	var input_y = 0.0
	if Input.is_physical_key_pressed(KEY_D): input_x += 1.0
	if Input.is_physical_key_pressed(KEY_A): input_x -= 1.0
	if Input.is_physical_key_pressed(KEY_S): input_y += 1.0
	if Input.is_physical_key_pressed(KEY_W): input_y -= 1.0
	
	var input_dir = Vector2(input_x, input_y).normalized()
	var direction = (spring_arm.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var is_aiming = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and is_weapon_equipped
	
	# Controle do tiro e metralhadora
	var holding_shoot = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and is_weapon_equipped
	if holding_shoot:
		shoot_timer = 0.4 # tempo que a animação de tiro fica forçada
	
	var is_shooting = false
	if shoot_timer > 0:
		shoot_timer -= delta
		is_shooting = true
	
	time_since_last_shot += delta
	if holding_shoot and time_since_last_shot >= fire_rate:
		time_since_last_shot = 0.0
		_fire_bullet()
	
	# Zoom da câmera suave e transição para o ombro (Over-the-shoulder)
	var target_length = aim_cam_dist if is_aiming else normal_cam_dist
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_length, delta * 10.0)
	
	# Usa h_offset para deslizar a lente da câmera sem brigar com o SpringArm
	var target_cam_offset = 1.0 if is_aiming else 0.0
	camera.h_offset = lerp(camera.h_offset, target_cam_offset, delta * 10.0)
	
	var is_running = Input.is_key_pressed(KEY_SHIFT) and not is_aiming and not is_shooting
	
	# Define a velocidade atual
	var current_speed = walk_speed
	if is_running:
		current_speed = run_speed
	elif is_aiming or is_shooting:
		current_speed = walk_speed * 0.6 # Anda mais devagar quando está mirando/atirando
	
	var is_moving = direction.length() > 0
	
	if is_moving:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	# Rotação do Personagem
	if is_aiming or is_shooting:
		# Força o personagem a virar de costas pra câmera e olhar para o alvo
		var cam_forward = -spring_arm.transform.basis.z
		var aim_angle = Vector2(cam_forward.z, cam_forward.x).angle()
		armature.rotation.y = lerp_angle(armature.rotation.y, aim_angle, delta * turn_speed * 1.5)
	elif is_moving:
		# Olha para a direção que está andando
		var look_direction = Vector2(velocity.z, velocity.x)
		armature.rotation.y = lerp_angle(armature.rotation.y, look_direction.angle(), delta * turn_speed)

	move_and_slide()
	
	# Dobrar o tronco para cima/baixo para acompanhar a mira (100% distribuído nos ossos da espinha)
	if skeleton_ref and spine_bones.size() > 0:
		if is_aiming or is_shooting:
			var pitch = spring_arm.rotation.x
			var axis = (skeleton_ref.global_transform.basis.inverse() * spring_arm.global_transform.basis.x).normalized()
			
			# Divide a inclinação da câmera por quantos ossos a espinha tem (geralmente 2 ou 3)
			var split_pitch = pitch / spine_bones.size()
			for idx in spine_bones:
				skeleton_ref.set_bone_global_pose_override(idx, Transform3D(), 0.0, false)
				var bone_pose = skeleton_ref.get_bone_global_pose(idx)
				bone_pose.basis = bone_pose.basis.rotated(axis, split_pitch)
				skeleton_ref.set_bone_global_pose_override(idx, bone_pose, 1.0, true)
		else:
			for idx in spine_bones:
				skeleton_ref.set_bone_global_pose_override(idx, Transform3D(), 0.0, true)
	
	# Máquina de estados das animações principais (pernas e corpo base)
	var new_state = "idle"
	
	if is_aiming or is_shooting:
		new_state = "aim_walk" if is_moving else "aim_idle"
	else:
		if is_moving:
			new_state = "run" if is_running else "walk"
		else:
			new_state = "idle"
		
	if new_state != current_state:
		_switch_state(new_state)
		
	# Máquina de atirar (mistura a parte de cima em tempo real)
	if is_shooting and anim_tree:
		# Dispara a animação de tiro (OneShot)
		if not anim_tree.get("parameters/shoot_oneshot/active"):
			anim_tree.set("parameters/shoot_oneshot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func _switch_state(new_state):
	current_state = new_state
	if anim_tree:
		var states = {"idle": 0, "walk": 1, "run": 2, "aim_idle": 3, "aim_walk": 4}
		if states.has(new_state):
			anim_tree.set("parameters/state_transition/transition_request", str(states[new_state]))

func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children():
		var res = find_skeleton(child)
		if res: return res
	return null

func _setup_weapon_attachments():
	var skeleton = find_skeleton(self)
	if not skeleton:
		print("Skeleton3D não encontrado para a arma!")
		return
		
	var spine_name = "mixamorig_Spine2"
	if skeleton.find_bone("Spine2") != -1: spine_name = "Spine2"
	elif skeleton.find_bone("Spine") != -1: spine_name = "Spine"
	
	var hand_name = "mixamorig_RightHand"
	if skeleton.find_bone("RightHand") != -1: hand_name = "RightHand"
	elif skeleton.find_bone("Hand.R") != -1: hand_name = "Hand.R"

	weapon_back_attachment = BoneAttachment3D.new()
	weapon_back_attachment.bone_name = spine_name
	skeleton.add_child(weapon_back_attachment)
	
	weapon_hand_attachment = BoneAttachment3D.new()
	weapon_hand_attachment.bone_name = hand_name
	skeleton.add_child(weapon_hand_attachment)
	
	# Agora carregamos a cena Weapon1.tscn, que contém a arma e o Marker3D Muzzle
	var weapon_scene = preload("res://armas/Weapon1.tscn")
	if weapon_scene:
		back_weapon_instance = weapon_scene.instantiate()
		weapon_back_attachment.add_child(back_weapon_instance)
		back_weapon_instance.hide()
		
		hand_weapon_instance = weapon_scene.instantiate()
		weapon_hand_attachment.add_child(hand_weapon_instance)
		hand_weapon_instance.hide()
		
		_update_weapon_transforms()

func _update_weapon_transforms():
	if back_weapon_instance:
		back_weapon_instance.scale = weapon_scale
		back_weapon_instance.position = back_weapon_pos
		back_weapon_instance.rotation_degrees = back_weapon_rot
	if hand_weapon_instance:
		hand_weapon_instance.scale = weapon_scale
		hand_weapon_instance.position = hand_weapon_pos
		hand_weapon_instance.rotation_degrees = hand_weapon_rot

func pickup_weapon():
	has_weapon = true
	is_weapon_equipped = false
	if back_weapon_instance:
		back_weapon_instance.show()
	if hand_weapon_instance:
		hand_weapon_instance.hide()
		
	if inventory_ui:
		inventory_ui.add_item("arma")
		
	print("Arma coletada e guardada nas costas!")

func drop_item(item_id: String):
	if item_id == "arma":
		has_weapon = false
		is_weapon_equipped = false
		if back_weapon_instance: back_weapon_instance.hide()
		if hand_weapon_instance: hand_weapon_instance.hide()
		
		# Spawna a arma no chão novamente
		var weapon_pickup = preload("res://WeaponItem.tscn").instantiate()
		get_parent().add_child(weapon_pickup)
		# Coloca um pouco na frente do jogador (no nível do chão)
		var drop_pos = global_position + (-global_transform.basis.z * 1.5)
		drop_pos.y = global_position.y
		weapon_pickup.global_position = drop_pos

func toggle_weapon():
	is_weapon_equipped = !is_weapon_equipped
	if is_weapon_equipped:
		if back_weapon_instance: back_weapon_instance.hide()
		if hand_weapon_instance: hand_weapon_instance.show()
		print("Arma em mãos!")
	else:
		if back_weapon_instance: back_weapon_instance.show()
		if hand_weapon_instance: hand_weapon_instance.hide()
		print("Arma guardada!")

func _fire_bullet():
	var bullet_scene = preload("res://Bullet.tscn")
	if not bullet_scene: return
	var bullet = bullet_scene.instantiate()
	get_tree().get_root().add_child(bullet)
	
	# Onde a câmera está olhando (alvo)
	var camera_center = camera.global_position
	var aim_dir = -camera.global_transform.basis.z
	var ray_target = camera_center + aim_dir * 1000.0
	
	# Origem do tiro: Muzzle (ponta da arma configurável na cena da arma)
	var spawn_pos = hand_weapon_instance.global_position
	var muzzle = hand_weapon_instance.find_child("Muzzle", true, false)
	
	if muzzle:
		# Pega a posição exata do Marker3D (que acompanha a rotação da arma automaticamente)
		spawn_pos = muzzle.global_position
	else:
		# Se a arma não tiver o Muzzle, atira um pouco pra frente
		var forward_dir = -camera.global_transform.basis.z
		spawn_pos += forward_dir * 1.2
	
	bullet.global_position = spawn_pos
	bullet.direction = (ray_target - spawn_pos).normalized()
	bullet.look_at(bullet.global_position + bullet.direction, Vector3.UP)
	
	# Aciona o efeito de fogo da arma (muzzle flash)
	if hand_weapon_instance.has_method("shoot"):
		hand_weapon_instance.shoot()
