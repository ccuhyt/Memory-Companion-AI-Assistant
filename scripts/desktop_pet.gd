extends CharacterBody2D
class_name DesktopPet

## 桌面寵物主控制器
## 處理動畫、拖曳、移動、物理效果

@onready var sprite = $AnimatedSprite2D
@onready var drag_area = $DragArea

enum State {
	IDLE,
	WALK,
	TAKE,
	FALL
}

var current_state = State.IDLE
var previous_state = State.IDLE

var is_dragging = false
var drag_offset = Vector2.ZERO

var is_walking = false
var walk_speed = 200.0
var walk_direction = -1

var is_falling = false
var fall_velocity = 0.0
const GRAVITY = 1500.0
const MAX_FALL_SPEED = 1000.0

var screen_size = Vector2.ZERO
var ground_y = 0.0
var sprite_height = 0.0  # 新增：儲存精靈圖高度

signal state_changed(new_state)
signal pet_clicked
signal pet_right_clicked

func _ready():
	screen_size = get_viewport_rect().size
	
	_load_animations()
	
	# 等待一幀讓精靈圖載入完成
	await get_tree().process_frame
	
	# 獲取精靈圖實際高度
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		var first_frame = sprite.sprite_frames.get_frame_texture("idle", 0)
		if first_frame:
			sprite_height = first_frame.get_height() * sprite.scale.y
	
	# 計算地面高度（視窗底部減去精靈圖高度的一半）
	# 這樣角色的底部就會剛好對齊視窗底部
	ground_y = screen_size.y - (sprite_height / 2)
	
	_setup_initial_position()
	
	drag_area.input_event.connect(_on_drag_area_input)
	
	change_state(State.IDLE)
	
	sprite.play("idle")
	sprite.visible = true
	visible = true
	
	print("🐾 桌寵已初始化")
	print("📍 位置: ", global_position)
	print("📏 精靈圖高度: ", sprite_height)
	print("🎬 地面高度: ", ground_y)

func _setup_initial_position():
	"""設置初始位置（視窗底部中央）"""
	global_position = Vector2(screen_size.x / 2, ground_y)
	print("📍 桌寵初始位置: ", global_position)

func _load_animations():
	"""載入所有動畫幀"""
	sprite.sprite_frames = SpriteFrames.new()
	
	_load_animation_from_folder("idle", "res://assets/animations/Idle")
	
	if DirAccess.dir_exists_absolute("res://assets/animations/Walk"):
		_load_animation_from_folder("walk", "res://assets/animations/Walk")
	
	if DirAccess.dir_exists_absolute("res://assets/animations/Take"):
		_load_animation_from_folder("take", "res://assets/animations/Take")
	
	sprite.sprite_frames.set_animation_speed("idle", 8.0)
	if sprite.sprite_frames.has_animation("walk"):
		sprite.sprite_frames.set_animation_speed("walk", 10.0)
	if sprite.sprite_frames.has_animation("take"):
		sprite.sprite_frames.set_animation_speed("take", 15.0)

func _load_animation_from_folder(anim_name: String, folder_path: String):
	"""從資料夾載入動畫幀"""
	sprite.sprite_frames.add_animation(anim_name)
	
	var dir = DirAccess.open(folder_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var frames = []
		
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.ends_with(".png") or file_name.ends_with(".jpg"):
					frames.append(file_name)
			file_name = dir.get_next()
		
		frames.sort()
		for frame_file in frames:
			var texture = load(folder_path + "/" + frame_file)
			if texture:
				sprite.sprite_frames.add_frame(anim_name, texture)
		
		dir.list_dir_end()
		print("✅ 載入動畫: %s (%d 幀)" % [anim_name, frames.size()])
	else:
		print("⚠️ 無法開啟資料夾: %s" % folder_path)

func _physics_process(_delta):
	"""物理更新"""
	match current_state:
		State.WALK:
			_process_walking()
		State.FALL:
			_process_falling()

func _process_walking():
	"""處理行走邏輯"""
	if is_walking:
		velocity.x = walk_speed * walk_direction
		
		if global_position.x < -50:
			global_position.x = screen_size.x + 50
		elif global_position.x > screen_size.x + 50:
			global_position.x = -50
		
		move_and_slide()

func _process_falling():
	"""處理下落邏輯"""
	fall_velocity += GRAVITY * get_physics_process_delta_time()
	fall_velocity = min(fall_velocity, MAX_FALL_SPEED)
	
	velocity.y = fall_velocity
	move_and_slide()
	
	if global_position.y >= ground_y:
		global_position.y = ground_y
		# 落地後總是回到 IDLE 或 WALK，不回到 TAKE
		if previous_state == State.WALK:
			change_state(State.WALK)
		else:
			change_state(State.IDLE)

func _input(event):
	"""處理輸入事件"""
	if is_dragging and event is InputEventMouseMotion:
		global_position = get_global_mouse_position() - drag_offset
		global_position.x = clamp(global_position.x, 0, screen_size.x)
		global_position.y = clamp(global_position.y, 0, screen_size.y)

func _on_drag_area_input(_viewport, event, _shape_idx):
	"""處理拖曳區域輸入"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_offset = get_global_mouse_position() - global_position
				change_state(State.TAKE)
				pet_clicked.emit()
			else:
				is_dragging = false
				if global_position.y < ground_y - 10:
					change_state(State.FALL)
				else:
					change_state(State.IDLE)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			pet_right_clicked.emit()

func change_state(new_state: State):
	"""切換狀態"""
	if new_state == current_state:
		return
	
	previous_state = current_state
	current_state = new_state
	
	velocity = Vector2.ZERO
	fall_velocity = 0.0
	is_walking = false
	is_falling = false
	
	match current_state:
		State.IDLE:
			sprite.play("idle")
			print("🏠 狀態: 待機")
		State.WALK:
			if sprite.sprite_frames.has_animation("walk"):
				sprite.play("walk")
				is_walking = true
				print("🚶 狀態: 行走")
			else:
				print("⚠️ 沒有行走動畫")
				change_state(State.IDLE)
				return
		State.TAKE:
			if sprite.sprite_frames.has_animation("take"):
				sprite.play("take")
				print("✋ 狀態: 被拖曳")
			else:
				sprite.play("idle")
		State.FALL:
			sprite.play("idle")
			is_falling = true
			print("⬇️ 狀態: 下落")
	
	state_changed.emit(new_state)

func set_idle():
	"""設置為待機狀態"""
	change_state(State.IDLE)

func set_walking(direction: int = -1):
	"""設置為行走狀態"""
	walk_direction = direction
	change_state(State.WALK)

func toggle_walk():
	"""切換行走狀態"""
	if current_state == State.WALK:
		change_state(State.IDLE)
	else:
		change_state(State.WALK)

func flip_direction():
	"""翻轉行走方向"""
	walk_direction *= -1
	sprite.flip_h = walk_direction > 0

func get_current_state_name() -> String:
	"""獲取當前狀態名稱"""
	match current_state:
		State.IDLE: return "待機"
		State.WALK: return "行走"
		State.TAKE: return "被拖曳"
		State.FALL: return "下落"
	return "未知"
