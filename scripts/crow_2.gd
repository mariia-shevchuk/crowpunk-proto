extends CharacterBody2D

const GRAVITY = 900.0
const MAX_FALL_SPEED = 800.0
const FLAP_FORCE = 300.0 #strength of the upward lift is when flapping
const SPEED = 300.0
const JUMP_VELOCITY = -250.0
const AIR_CONTROL = 0.05 # factor how quickly crow reacts to air movement changes (inertia)
const GLIDE_GRAVITY_MULTIPLIER = 0.3 # factor reduces gravity while gliding—used to simulate “floating descent”
const AIR_DRAG = 170.0


# State names
enum PlayerState { GROUND, JUMPING, FLYING }
# Current state
var state = PlayerState.GROUND
var can_double_jump = false

func _ready():
	print("Crow is ready")

func _physics_process(delta: float) -> void:
	handle_state_transitions()
	handle_movement(delta)
	update_animation()
	move_and_slide()
	
func handle_state_transitions() -> void:
	var on_ground = is_on_floor()
	
	match state:
		PlayerState.GROUND:
			can_double_jump = false 
			if Input.is_action_just_pressed("jump"):
				velocity.y = JUMP_VELOCITY
				can_double_jump = true  # allow double jump
				state = PlayerState.JUMPING
			elif Input.is_action_just_pressed("fly"):
				state = PlayerState.FLYING
			elif not on_ground:
				state = PlayerState.FLYING  # fell off edge
				
		PlayerState.JUMPING:
			if Input.is_action_just_pressed("jump") and can_double_jump:
				velocity.y = -FLAP_FORCE * 0.7
				state = PlayerState.FLYING
				can_double_jump = false
			elif on_ground:
				state = PlayerState.GROUND

		PlayerState.FLYING:
			if on_ground:
				state = PlayerState.GROUND

func handle_movement(delta: float) -> void:
	match state:
		PlayerState.GROUND:
			handle_ground_movement(delta)
		PlayerState.JUMPING:
			handle_jumping_movement(delta)
		PlayerState.FLYING:
			handle_flying_movement(delta)
			
func handle_ground_movement(delta: float) -> void:
	var direction = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	velocity.x = direction * SPEED
	velocity.y += GRAVITY * delta
	velocity.y = clamp(velocity.y, -300, MAX_FALL_SPEED)

func handle_jumping_movement(delta: float) -> void:
	var direction = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	velocity.x = direction * SPEED
	velocity.y += GRAVITY * delta
	velocity.y = clamp(velocity.y, -300, MAX_FALL_SPEED)

func handle_flying_movement(delta: float) -> void:
	var direction = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")

	# Horizontal: inertia-based control in air
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * SPEED, AIR_DRAG * delta)
	else:
		# No input → gradually slow down
		velocity.x = move_toward(velocity.x, direction * SPEED, AIR_DRAG * delta)
	# Vertical: flapping vs gliding
	if Input.is_action_pressed("fly"):
		velocity.y -= FLAP_FORCE * delta
	else:
		velocity.y += GRAVITY * GLIDE_GRAVITY_MULTIPLIER * delta
	velocity.y = clamp(velocity.y, -300, MAX_FALL_SPEED)

func update_animation() -> void:
	match state:
		PlayerState.GROUND:
			if abs(velocity.x) > 0:
				$AnimationPlayer.play("walk")
			else:
				$AnimationPlayer.play("idle")
		#PlayerState.JUMPING:
			#sprite.play("jump")
		#PlayerState.FLYING:
			#if Input.is_action_pressed("fly"):
				#sprite.play("flap")
			#else:
				#sprite.play("glide")
