extends Control
class_name ChatDialog

## 對話視窗 - 帶頭像和個性名稱

# 節點引用
@onready var chat_display: RichTextLabel = $MarginContainer/VBoxContainer/ChatDisplay
@onready var input_text: TextEdit = $MarginContainer/VBoxContainer/HBoxContainer/InputText
@onready var send_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/SendButton
@onready var close_button: Button = $MarginContainer/VBoxContainer/TitleBar/CloseButton

# 信號
signal message_sent(message: String)
signal dialog_closed

# 對話歷史
var message_history: Array = []

# 當前個性信息
var current_personality_name: String = "桌寵"
var current_personality_avatar: Texture2D = null

# 顏色設定
var user_label_color = Color(0.0, 0.4, 0.8, 1.0)
var user_text_color = Color(0.1, 0.1, 0.2, 1.0)
var user_bg_color = Color(0.878, 0.941, 1.0, 1.0)

var pet_label_color = Color(0.851, 0.11, 0.38, 1.0)
var pet_text_color = Color(0.2, 0.1, 0.15, 1.0)
var pet_bg_color = Color(0.992, 0.890, 0.929, 1.0)

var system_color = Color(0.5, 0.5, 0.5, 1.0)
var error_color = Color(0.902, 0.2, 0.2, 1.0)
var chat_bg_color = Color(0.95, 0.95, 0.98, 1.0)

func _ready():
	chat_display.bbcode_enabled = true
	
	send_button.pressed.connect(_on_send_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	
	input_text.gui_input.connect(_on_input_gui_input)
	
	add_system_message("歡迎！開始與桌寵對話吧 💬")
	
	_setup_styles()
	
	print("✅ ChatDialog 初始化完成")

func _setup_styles():
	"""設定視覺樣式"""
	var style = StyleBoxFlat.new()
	style.bg_color = chat_bg_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	
	chat_display.add_theme_stylebox_override("normal", style)

func _on_send_button_pressed():
	_send_message()

func _on_close_button_pressed():
	hide_dialog()

func _on_input_gui_input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER and (event.ctrl_pressed or event.meta_pressed):
			_send_message()
			get_viewport().set_input_as_handled()

func _send_message():
	var message = input_text.text.strip_edges()
	
	if message.is_empty():
		return
	
	add_user_message(message)
	input_text.text = ""
	message_sent.emit(message)
	
	message_history.append({
		"role": "user",
		"content": message,
		"timestamp": Time.get_unix_time_from_system()
	})

func add_user_message(message: String):
	"""添加用戶訊息"""
	var label_hex = user_label_color.to_html(false)
	var text_hex = user_text_color.to_html(false)
	var bg_hex = user_bg_color.to_html(false)
	
	var formatted_text = "\n[color=#" + label_hex + "][b]🧑 你：[/b][/color]\n"
	formatted_text += "[bgcolor=#" + bg_hex + "][color=#" + text_hex + "]  " + message + "[/color][/bgcolor]\n"
	
	chat_display.append_text(formatted_text)
	
	await get_tree().process_frame
	_scroll_to_bottom()

func add_pet_message(message: String):
	"""添加桌寵回應 - 帶頭像和個性名稱"""
	var label_hex = pet_label_color.to_html(false)
	var text_hex = pet_text_color.to_html(false)
	var bg_hex = pet_bg_color.to_html(false)
	
	# 🆕 如果有頭像，使用頭像；否則使用表情符號
	var avatar_prefix = ""
	if current_personality_avatar:
		# RichTextLabel 支援 [img] 標籤顯示圖片
		# 但需要先將 Texture2D 轉換為可用的資源路徑或內聯圖片
		avatar_prefix = "🐾 "  # 暫時仍使用表情符號，下面會實現真正的圖片顯示
	else:
		avatar_prefix = "🐾 "
	
	var formatted_text = "\n[color=#" + label_hex + "][b]" + avatar_prefix + current_personality_name + "：[/b][/color]\n"
	formatted_text += "[bgcolor=#" + bg_hex + "][color=#" + text_hex + "]  " + message + "[/color][/bgcolor]\n"
	
	chat_display.append_text(formatted_text)
	
	message_history.append({
		"role": "assistant",
		"content": message,
		"timestamp": Time.get_unix_time_from_system()
	})
	
	await get_tree().process_frame
	_scroll_to_bottom()

func add_system_message(message: String):
	"""添加系統訊息"""
	var color_hex = system_color.to_html(false)
	var formatted_text = "\n[color=#" + color_hex + "][i]💭 " + message + "[/i][/color]\n"
	chat_display.append_text(formatted_text)
	
	await get_tree().process_frame
	_scroll_to_bottom()

func add_error_message(error: String):
	"""添加錯誤訊息"""
	var color_hex = error_color.to_html(false)
	var formatted_text = "\n[color=#" + color_hex + "][b]❌ 錯誤：[/b]" + error + "[/color]\n"
	chat_display.append_text(formatted_text)
	
	await get_tree().process_frame
	_scroll_to_bottom()

func clear_chat():
	"""清空對話記錄"""
	chat_display.clear()
	message_history.clear()
	add_system_message("對話已清空")

func _scroll_to_bottom():
	"""滾動到底部"""
	var scroll_bar = chat_display.get_v_scroll_bar()
	if scroll_bar:
		scroll_bar.value = scroll_bar.max_value

func get_message_history() -> Array:
	"""獲取對話歷史"""
	return message_history

func _input(event: InputEvent):
	"""處理全局輸入"""
	if not visible:
		return
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			hide_dialog()
			get_viewport().set_input_as_handled()

func show_dialog():
	"""顯示對話視窗"""
	show()
	input_text.grab_focus()
	print("✅ 對話視窗已顯示")

func hide_dialog():
	"""隱藏對話視窗"""
	hide()
	dialog_closed.emit()
	print("🚪 對話視窗已隱藏")

func set_input_enabled(enabled: bool):
	"""啟用/停用輸入"""
	input_text.editable = enabled
	send_button.disabled = not enabled

# ============================================================================
# 個性設定函數
# ============================================================================

func set_personality_info(personality_name: String, avatar_path: String = ""):
	"""設定當前個性信息"""
	current_personality_name = personality_name
	print("🎭 對話視窗更新個性名稱: ", current_personality_name)
	
	# 載入頭像
	if avatar_path != "":
		_load_avatar(avatar_path)
	else:
		current_personality_avatar = null
		print("ℹ️ 未設定頭像")

func _load_avatar(avatar_path: String):
	"""載入個性頭像"""
	# 🔧 修正：支援多種路徑格式
	var paths_to_try = []
	
	# 1. 嘗試 user:// 路徑
	if not avatar_path.begins_with("user://") and not avatar_path.begins_with("res://"):
		paths_to_try.append("user://" + avatar_path)
	else:
		paths_to_try.append(avatar_path)
	
	# 2. 嘗試相對於專案的路徑
	paths_to_try.append("res://python_scripts/" + avatar_path)
	
	# 3. 嘗試直接路徑
	paths_to_try.append(avatar_path)
	
	for full_path in paths_to_try:
		if FileAccess.file_exists(full_path):
			var image = Image.load_from_file(ProjectSettings.globalize_path(full_path))
			if image:
				current_personality_avatar = ImageTexture.create_from_image(image)
				print("✅ 載入個性頭像: ", full_path)
				return
	
	print("⚠️ 找不到個性頭像: ", avatar_path)
	print("   嘗試過的路徑:")
	for p in paths_to_try:
		print("   - ", p)
	current_personality_avatar = null

# ============================================================================
# 顏色主題預設
# ============================================================================

func apply_light_theme():
	"""淺色主題（預設）"""
	user_label_color = Color(0.0, 0.4, 0.8, 1.0)
	user_text_color = Color(0.1, 0.1, 0.2, 1.0)
	user_bg_color = Color(0.878, 0.941, 1.0, 1.0)
	pet_label_color = Color(0.851, 0.11, 0.38, 1.0)
	pet_text_color = Color(0.2, 0.1, 0.15, 1.0)
	pet_bg_color = Color(0.992, 0.890, 0.929, 1.0)
	system_color = Color(0.5, 0.5, 0.5, 1.0)
	error_color = Color(0.902, 0.2, 0.2, 1.0)
	chat_bg_color = Color(0.95, 0.95, 0.98, 1.0)
	_setup_styles()

func apply_dark_theme():
	"""深色主題"""
	user_label_color = Color(0.376, 0.647, 0.980, 1.0)
	user_text_color = Color(0.9, 0.9, 0.95, 1.0)
	user_bg_color = Color(0.118, 0.227, 0.373, 1.0)
	pet_label_color = Color(0.957, 0.447, 0.714, 1.0)
	pet_text_color = Color(0.95, 0.9, 0.92, 1.0)
	pet_bg_color = Color(0.290, 0.098, 0.259, 1.0)
	system_color = Color(0.7, 0.7, 0.7, 1.0)
	error_color = Color(0.937, 0.271, 0.271, 1.0)
	chat_bg_color = Color(0.125, 0.125, 0.145, 1.0)
	_setup_styles()

func apply_cute_theme():
	"""可愛主題"""
	user_label_color = Color(1.0, 0.42, 0.616, 1.0)
	user_text_color = Color(0.3, 0.1, 0.2, 1.0)
	user_bg_color = Color(1.0, 0.941, 0.961, 1.0)
	pet_label_color = Color(0.608, 0.349, 0.714, 1.0)
	pet_text_color = Color(0.25, 0.1, 0.3, 1.0)
	pet_bg_color = Color(0.953, 0.898, 0.961, 1.0)
	system_color = Color(0.6, 0.4, 0.6, 1.0)
	error_color = Color(1.0, 0.4, 0.5, 1.0)
	chat_bg_color = Color(1.0, 0.98, 0.99, 1.0)
	_setup_styles()

func apply_tech_theme():
	"""科技主題"""
	user_label_color = Color(0.0, 1.0, 0.533, 1.0)
	user_text_color = Color(0.8, 1.0, 0.9, 1.0)
	user_bg_color = Color(0.0, 0.102, 0.059, 1.0)
	pet_label_color = Color(0.0, 0.851, 1.0, 1.0)
	pet_text_color = Color(0.8, 0.95, 1.0, 1.0)
	pet_bg_color = Color(0.0, 0.122, 0.161, 1.0)
	system_color = Color(0.4, 0.8, 0.6, 1.0)
	error_color = Color(1.0, 0.2, 0.4, 1.0)
	chat_bg_color = Color(0.02, 0.02, 0.05, 1.0)
	_setup_styles()

# ============================================================================
# 🎨 Color 轉換工具
# ============================================================================
# 
# RGB 值範圍 0-1（不是 0-255）
# 
# 從 hex 轉換：
#   Color.html("#FF6B9D")  或  Color("#FF6B9D")
#
# 從 RGB (0-255) 轉換到 Color (0-1)：
#   Color(R/255.0, G/255.0, B/255.0, 1.0)
#   例：RGB(255, 107, 157) → Color(1.0, 0.42, 0.616, 1.0)
#
# 從 Color 轉換到 hex：
#   color.to_html(false)  # 返回 "RRGGBB"
#
# ============================================================================

# ========== 語音輸入功能 ==========
func _on_voice_button_voice_text_ready(text: String):
	"""接收語音轉文字結果並填入輸入框"""
	print("🎤 收到語音: ", text)
	
	# 過濾無效結果
	if text and text != "[無有效語音]" and text != "[無聲音]":
		var input = $MarginContainer/VBoxContainer/HBoxContainer/InputText  
		if input:
			input.text = text
			print("✅ 文字已填入輸入框")
		else:
			print("❌ 找不到輸入框節點")
