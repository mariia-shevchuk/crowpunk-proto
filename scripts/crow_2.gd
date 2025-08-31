extends CharacterBody2D

@export var WALK_SPEED: float = 120.0
@export var MAX_AIR_SPEED: float = 140.0
@export var ACCEL_GROUND: float = 900.0
@export var FRICTION_GROUND: float = 1200.0
@export var ACCEL_AIR: float = 600.0
@export var DRAG_AIR: float = 300.0

@export var GRAVITY: float = 900.0
@export var MAX_FALL_SPEED: float = 600.0
@export var APEX_VEL: float = 30.0 

@export var HOP_VEL: float = -170.0      # ~16 px hop 
@export var FLAP_IMPULSE: float = -180.0 # one-time kick on press
@export var FLAP_HOLD_FORCE: float = -280.0 # gentle climb per second while holding
@export var FLAP_COOLDOWN: float = 0.12
@export var MAX_RISE_SPEED: float = 260.0 

@export var GLIDE_GRAVITY_MULT: float = 0.35
@export var DIVE_GRAVITY_MULT: float = 2.4
@export var DIVE_FORWARD_BOOST: float = 80.0

@export var COYOTE_TIME: float = 0.10
@export var HOP_BUFFER: float = 0.12  

@onready var visual_root: Node2D = $Rig
var flip_pivot_x: float = 42.0 
var facing_left := false
var was_walking: bool = false
enum PlayerState { GROUND, AIR, FLYING, DIVING }
var state: int = PlayerState.GROUND

var hop_anim_timer: float = 0.0
var coyote_timer := 0.0
var hop_buffer_timer := 0.0
var flap_timer := 0.0
 
@onready var anim: AnimationPlayer = $AnimationPlayer

func _physics_process(delta: float) -> void:
	# Timers
	if coyote_timer > 0.0: coyote_timer -= delta
	if hop_buffer_timer > 0.0: hop_buffer_timer -= delta
	if flap_timer > 0.0: flap_timer -= delta
	if hop_anim_timer > 0.0: hop_anim_timer -= delta

	# Read input
	var dir := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var pressing_fly := Input.is_action_pressed("fly")
	var pressed_fly := Input.is_action_just_pressed("fly")
	var pressed_hop := Input.is_action_just_pressed("hop")
	var pressing_dive := Input.is_action_pressed("dive")
	
	var g := GRAVITY
	var on_floor := is_on_floor()

	if pressed_hop:
		hop_buffer_timer = HOP_BUFFER
	if on_floor:
		coyote_timer = COYOTE_TIME
		
	if dir != 0:
		set_facing(dir < 0.0)

	if abs(velocity.y) < APEX_VEL:
		g *= 0.7

	if state == PlayerState.FLYING:
		if velocity.y > 0.0 and not pressing_dive:
			g *= GLIDE_GRAVITY_MULT
	elif state == PlayerState.DIVING:
		g *= DIVE_GRAVITY_MULT

	velocity.y += g * delta
	velocity.y = clamp(velocity.y, -MAX_RISE_SPEED, MAX_FALL_SPEED)

	match state:
		PlayerState.GROUND:
			if try_consume_hop():
				velocity.y = HOP_VEL

				if pressing_fly:

					do_flap()
					state = PlayerState.FLYING
					hop_anim_timer = 0.0
					if anim.has_animation("flap"):
						anim.play("flap")
				else:
					hop_anim_timer = 0.15
					if anim.has_animation("hop"):
						anim.play("hop")
					state = PlayerState.AIR

			elif pressed_fly:
				do_flap()
				state = PlayerState.FLYING

		PlayerState.AIR:
			if pressing_fly and flap_timer <= 0.0 and Input.is_action_just_pressed("fly"):
				do_flap()
				state = PlayerState.FLYING
			elif pressing_dive:
				state = PlayerState.DIVING
			elif on_floor:
				state = PlayerState.GROUND

		PlayerState.FLYING:
			if pressing_dive:
				state = PlayerState.DIVING
			elif not pressing_fly and velocity.y > 0.0:
				# stop holding → glide down
				pass
			if on_floor:
				state = PlayerState.GROUND

		PlayerState.DIVING:
			if not pressing_dive:
				state = PlayerState.FLYING if not on_floor else PlayerState.GROUND
			if on_floor:
				state = PlayerState.GROUND

	var target_speed := dir * (WALK_SPEED if state == PlayerState.GROUND else MAX_AIR_SPEED)

	if state == PlayerState.GROUND:
		velocity.x = move_toward(velocity.x, target_speed, ACCEL_GROUND * delta)
		if dir == 0:
			velocity.x = move_toward(velocity.x, 0.0, FRICTION_GROUND * delta)
	else:
		velocity.x = move_toward(velocity.x, target_speed, ACCEL_AIR * delta)
		if dir == 0:
			velocity.x = move_toward(velocity.x, 0.0, DRAG_AIR * delta)

	if state == PlayerState.FLYING:
		if pressing_fly:
			velocity.y += FLAP_HOLD_FORCE * delta 
		velocity.y = clamp(velocity.y, -MAX_RISE_SPEED, MAX_FALL_SPEED)

	if state == PlayerState.DIVING:
		var boost_dir: float
		if dir == 0:
			boost_dir = float(sign(velocity.x))
		else:
			boost_dir = float(sign(dir))

		var dive_target: float = dir * MAX_AIR_SPEED + boost_dir * DIVE_FORWARD_BOOST
		velocity.x = move_toward(velocity.x, dive_target, ACCEL_AIR * delta)

	move_and_slide()
	update_animation()

func try_consume_hop() -> bool:
	if coyote_timer > 0.0 and hop_buffer_timer > 0.0:
		hop_buffer_timer = 0.0
		return true
	return false

func do_flap() -> void:
	velocity.y = min(velocity.y, 0.0) 
	velocity.y += FLAP_IMPULSE
	flap_timer = FLAP_COOLDOWN

func update_animation() -> void:
	if hop_anim_timer > 0.0:
		return

	match state:
		PlayerState.GROUND:
			var speed: float = absf(velocity.x)
			if speed > 5.0:
				if anim.current_animation != "walk":
					anim.play("walk")
				var rate: float = clamp(speed / WALK_SPEED, 0.6, 1.6)
				anim.speed_scale = rate
				was_walking = true
			else:
				if was_walking:
					anim.play("RESET")
					anim.play("idle")
					was_walking = false
				else:
					if anim.current_animation != "idle":
						anim.play("idle")
				anim.speed_scale = 1.0

		PlayerState.AIR:
			if anim.current_animation != "blink":
				anim.play("blink")     # or your “air” pose
			anim.speed_scale = 1.0

		PlayerState.FLYING:
			if Input.is_action_pressed("fly"):
				if anim.current_animation != "flap":
					anim.play("flap")
			else:
				if anim.current_animation != "breathe":  # your glide pose
					anim.play("breathe")
			anim.speed_scale = 1.0

		PlayerState.DIVING:
			if anim.current_animation != "dive":
				anim.play("dive")
			anim.speed_scale = 1.0


func set_facing(left: bool) -> void:
	if facing_left == left:
		return
	facing_left = left

	var p := visual_root.position
	p.x = 2.0 * flip_pivot_x - p.x
	visual_root.position = p

	var base = abs(visual_root.scale.x)
	if left:
		visual_root.scale.x = -base
	else:
		visual_root.scale.x = base
