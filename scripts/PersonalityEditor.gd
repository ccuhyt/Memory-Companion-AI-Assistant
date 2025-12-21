extends Window
class_name PersonalityEditor

## 個性編輯器 - 讓用戶自訂桌寵個性（含頭像上傳）

signal personality_saved(personality_data: Dictionary)
signal editor_closed

# UI 節點
var scroll_container: ScrollContainer
var form_container: VBoxContainer

# 表單欄位
var name_input: LineEdit
var display_name_input: LineEdit
var system_prompt_input: TextEdit
var speaking_style_input: LineEdit
var traits_input: LineEdit
var emoji_frequency_option: OptionButton
var greeting_input: TextEdit

# 🆕 頭像相關
var avatar_preview: TextureRect
var upload_button: Button
var clear_avatar_button: Button
var current_avatar_path: String = ""
var avatar_file_dialog: FileDialog

# 按鈕
var save_button: Button
var cancel_button: Button
var preview_button: Button

# 模式
enum Mode { CREATE, EDIT }
var current_mode = Mode.CREATE
var editing_personality_name = ""

func _init():
	title = "個性編輯器"
	size = Vector2i(700, 850)  # 🆕 調整高度
	min_size = Vector2i(600, 600)  # 🆕 確保最小高度足夠
	max_size = Vector2i(800, 1000)  # 🆕 設定最大尺寸
	borderless = false
	always_on_top = false
	transient = true
	exclusive = false
	_build_ui()

func _ready():
	close_requested.connect(_on_close_requested)
	# 🆕 確保視窗居中並且完全可見
	var screen_size = DisplayServer.screen_get_size()
	var window_size = size
	position = (screen_size - window_size) / 2
	
	# 🆕 如果視窗太高，調整到適合螢幕
	if window_size.y > screen_size.y - 100:
		size.y = screen_size.y - 100
		position.y = 50

func _build_ui():
	"""構建 UI"""
	# 主容器
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_vbox)
	
	# === 標題區 ===
	var title_margin = MarginContainer.new()
	title_margin.add_theme_constant_override("margin_left", 20)
	title_margin.add_theme_constant_override("margin_right", 20)
	title_margin.add_theme_constant_override("margin_top", 20)
	title_margin.add_theme_constant_override("margin_bottom", 10)
	main_vbox.add_child(title_margin)
	
	var title_label = Label.new()
	title_label.text = "✨ 創建自訂個性"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_margin.add_child(title_label)
	
	# 分隔線
	var separator1 = HSeparator.new()
	main_vbox.add_child(separator1)
	
	# === 滾動區域 ===
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED  # 🆕 禁用橫向滾動
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO  # 🆕 啟用縱向滾動
	main_vbox.add_child(scroll_container)
	
	# 表單容器（帶邊距）
	var form_margin = MarginContainer.new()
	form_margin.add_theme_constant_override("margin_left", 20)
	form_margin.add_theme_constant_override("margin_right", 20)
	form_margin.add_theme_constant_override("margin_top", 20)
	form_margin.add_theme_constant_override("margin_bottom", 20)
	form_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN  # 🆕 不要填充，只佔用需要的空間
	scroll_container.add_child(form_margin)
	
	form_container = VBoxContainer.new()
	form_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN  # 🆕 不要填充
	form_container.add_theme_constant_override("separation", 15)
	form_margin.add_child(form_container)
	
	# 建立表單欄位
	_build_form()
	
	# 分隔線
	var separator2 = HSeparator.new()
	main_vbox.add_child(separator2)
	
	# === 按鈕區 ===
	var button_margin = MarginContainer.new()
	button_margin.add_theme_constant_override("margin_left", 20)
	button_margin.add_theme_constant_override("margin_right", 20)
	button_margin.add_theme_constant_override("margin_top", 15)
	button_margin.add_theme_constant_override("margin_bottom", 25)
	button_margin.custom_minimum_size = Vector2(0, 80)  # 🆕 設定最小高度，確保按鈕區域可見
	button_margin.size_flags_vertical = Control.SIZE_SHRINK_END
	main_vbox.add_child(button_margin)
	
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_hbox.add_theme_constant_override("separation", 10)
	button_margin.add_child(button_hbox)
	
	preview_button = Button.new()
	preview_button.text = "👀 預覽提示詞"
	preview_button.custom_minimum_size = Vector2(120, 40)  # 🆕 加大按鈕
	preview_button.pressed.connect(_on_preview_pressed)
	button_hbox.add_child(preview_button)
	
	cancel_button = Button.new()
	cancel_button.text = "❌ 取消"
	cancel_button.custom_minimum_size = Vector2(100, 40)  # 🆕 加大按鈕
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_hbox.add_child(cancel_button)
	
	save_button = Button.new()
	save_button.text = "💾 保存個性"
	save_button.custom_minimum_size = Vector2(120, 40)  # 🆕 加大按鈕
	save_button.pressed.connect(_on_save_pressed)
	button_hbox.add_child(save_button)
	
	# 🆕 不再在 _build_ui 中創建 FileDialog
	# FileDialog 將在需要時動態創建

func _build_form():
	"""建立表單欄位"""
	
	# 🆕 0. 頭像設定區
	_add_avatar_section()
	
	# 1. 內部名稱
	_add_form_field(
		"內部名稱 (英文，不可重複)*",
		"例如: my_custom_pet",
		func():
			name_input = LineEdit.new()
			name_input.placeholder_text = "my_custom_pet"
			return name_input
	)
	
	# 2. 顯示名稱
	_add_form_field(
		"顯示名稱 (選單中顯示)*",
		"例如: 我的專屬小貓 🐱",
		func():
			display_name_input = LineEdit.new()
			display_name_input.placeholder_text = "我的專屬小貓 🐱"
			return display_name_input
	)
	
	# 3. 系統提示詞
	_add_form_field(
		"系統提示詞 (定義角色)*",
		"描述桌寵的身份、個性、說話方式等",
		func():
			system_prompt_input = TextEdit.new()
			system_prompt_input.custom_minimum_size = Vector2(0, 150)
			system_prompt_input.placeholder_text = "你是一隻可愛的小貓，名叫咪咪...\n個性活潑、好奇、貼心...\n說話溫柔，喜歡用疊詞..."
			system_prompt_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			return system_prompt_input
	)
	
	# 4. 說話風格
	_add_form_field(
		"說話風格",
		"例如: 溫柔可愛，使用疊詞",
		func():
			speaking_style_input = LineEdit.new()
			speaking_style_input.placeholder_text = "溫柔可愛，使用疊詞"
			speaking_style_input.text = "友善自然"
			return speaking_style_input
	)
	
	# 5. 性格特徵
	_add_form_field(
		"性格特徵 (用逗號分隔)",
		"例如: 活潑,好奇,貼心,溫柔",
		func():
			traits_input = LineEdit.new()
			traits_input.placeholder_text = "活潑,好奇,貼心,溫柔"
			return traits_input
	)
	
	# 6. 表情符號頻率
	_add_form_field(
		"表情符號使用頻率",
		"控制回應中表情符號的數量",
		func():
			emoji_frequency_option = OptionButton.new()
			emoji_frequency_option.add_item("🚫 不使用 (none)", 0)
			emoji_frequency_option.add_item("⭐ 偶爾使用 (low)", 1)
			emoji_frequency_option.add_item("⭐⭐ 適度使用 (medium)", 2)
			emoji_frequency_option.add_item("⭐⭐⭐ 經常使用 (high)", 3)
			emoji_frequency_option.selected = 2
			return emoji_frequency_option
	)
	
	# 7. 招呼語
	_add_form_field(
		"招呼語",
		"切換到這個個性時的問候語",
		func():
			greeting_input = TextEdit.new()
			greeting_input.custom_minimum_size = Vector2(0, 80)
			greeting_input.placeholder_text = "你好！我是你的新夥伴~ 💕"
			greeting_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			greeting_input.text = "你好！"
			return greeting_input
	)
	
	# 提示標籤
	var hint_label = Label.new()
	hint_label.text = "💡 提示: 標記 * 的欄位為必填項"
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	form_container.add_child(hint_label)

func _add_avatar_section():
	"""添加頭像設定區域"""
	var avatar_container = VBoxContainer.new()
	avatar_container.add_theme_constant_override("separation", 10)
	
	# 標籤
	var label = Label.new()
	label.text = "🎨 頭像設定"
	label.add_theme_font_size_override("font_size", 16)
	avatar_container.add_child(label)
	
	var desc_label = Label.new()
	desc_label.text = "上傳自訂頭像（建議尺寸: 256x256）"
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	avatar_container.add_child(desc_label)
	
	# 頭像預覽
	var preview_container = HBoxContainer.new()
	preview_container.alignment = BoxContainer.ALIGNMENT_CENTER
	avatar_container.add_child(preview_container)
	
	# 預覽框
	var preview_panel = PanelContainer.new()
	var preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.2, 0.2, 0.25, 0.5)
	preview_style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	preview_style.set_border_width_all(2)
	preview_style.set_corner_radius_all(8)
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	preview_container.add_child(preview_panel)
	
	avatar_preview = TextureRect.new()
	avatar_preview.custom_minimum_size = Vector2(128, 128)
	avatar_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	avatar_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_panel.add_child(avatar_preview)
	
	# 按鈕區
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_hbox.add_theme_constant_override("separation", 10)
	avatar_container.add_child(button_hbox)
	
	upload_button = Button.new()
	upload_button.text = "📁 選擇圖片"
	upload_button.pressed.connect(_on_upload_avatar_pressed)
	button_hbox.add_child(upload_button)
	
	clear_avatar_button = Button.new()
	clear_avatar_button.text = "🗑️ 清除頭像"
	clear_avatar_button.pressed.connect(_on_clear_avatar_pressed)
	clear_avatar_button.disabled = true
	button_hbox.add_child(clear_avatar_button)
	
	form_container.add_child(avatar_container)

func _on_upload_avatar_pressed():
	"""點擊上傳頭像按鈕"""
	print("📂 開啟文件選擇器...")
	
	# 🆕 每次都創建新的 FileDialog
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.png ; PNG Images", "*.jpg ; JPEG Images", "*.jpeg ; JPEG Images"])
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.size = Vector2i(700, 500)
	
	# 選擇文件後處理
	file_dialog.file_selected.connect(func(path: String):
		_handle_avatar_file_selected(path)
		file_dialog.queue_free()  # 立即清理
	)
	
	# 取消或關閉後清理
	file_dialog.canceled.connect(func():
		print("❌ 取消選擇頭像")
		file_dialog.queue_free()
	)
	
	file_dialog.close_requested.connect(func():
		file_dialog.queue_free()
	)
	
	# 添加到場景並顯示
	add_child(file_dialog)
	file_dialog.popup_centered()

func _handle_avatar_file_selected(path: String):
	"""處理選擇的頭像文件"""
	print("📷 選擇頭像: ", path)
	
	# 載入圖片
	var image = Image.load_from_file(path)
	if image == null:
		_show_error("無法載入圖片，請選擇有效的 PNG 或 JPG 文件")
		return
	
	# 縮放到 256x256
	image.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	
	# 生成唯一文件名
	var timestamp = str(Time.get_unix_time_from_system())
	var filename = "custom_avatar_" + timestamp + ".png"
	
	# 保存到用戶目錄
	var user_avatar_dir = "user://avatars/custom/"
	DirAccess.make_dir_recursive_absolute(user_avatar_dir)
	var save_path = user_avatar_dir + filename
	var error = image.save_png(ProjectSettings.globalize_path(save_path))
	
	if error != OK:
		_show_error("保存頭像失敗")
		return
	
	# 記錄路徑（相對路徑，用於保存到 JSON）
	current_avatar_path = "avatars/custom/" + filename
	
	# 更新預覽
	var texture = ImageTexture.create_from_image(image)
	avatar_preview.texture = texture
	clear_avatar_button.disabled = false
	
	print("✅ 頭像已保存: ", current_avatar_path)

func _on_clear_avatar_pressed():
	"""清除頭像"""
	current_avatar_path = ""
	avatar_preview.texture = null
	clear_avatar_button.disabled = true
	print("🗑️ 頭像已清除")

func _add_form_field(label_text: String, description: String, create_control: Callable):
	"""添加表單欄位"""
	var field_container = VBoxContainer.new()
	field_container.add_theme_constant_override("separation", 5)
	
	# 標籤
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 16)
	field_container.add_child(label)
	
	# 描述
	if description != "":
		var desc_label = Label.new()
		desc_label.text = description
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		field_container.add_child(desc_label)
	
	# 控制項
	var control = create_control.call()
	field_container.add_child(control)
	
	form_container.add_child(field_container)

func _on_save_pressed():
	"""保存按鈕"""
	var validation = _validate_input()
	if not validation.valid:
		_show_error(validation.error)
		return
	
	var personality_data = _collect_data()
	
	# 🆕 標記是創建還是編輯模式
	personality_data["is_edit_mode"] = (current_mode == Mode.EDIT)
	
	personality_saved.emit(personality_data)
	hide()

func _on_cancel_pressed():
	"""取消按鈕"""
	hide()

func _on_preview_pressed():
	"""預覽按鈕"""
	var prompt = system_prompt_input.text.strip_edges()
	if prompt.is_empty():
		_show_error("請先填寫系統提示詞")
		return
	
	var dialog = AcceptDialog.new()
	dialog.title = "📖 系統提示詞預覽"
	dialog.dialog_text = prompt
	dialog.size = Vector2i(500, 400)
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _on_close_requested():
	"""關閉視窗"""
	hide()
	editor_closed.emit()

func _validate_input() -> Dictionary:
	"""驗證輸入"""
	var name = name_input.text.strip_edges()
	if name.is_empty():
		return {"valid": false, "error": "請填寫內部名稱"}
	
	var regex = RegEx.new()
	regex.compile("^[a-z0-9_]+$")
	if not regex.search(name):
		return {"valid": false, "error": "內部名稱只能包含小寫英文、數字和下劃線"}
	
	if display_name_input.text.strip_edges().is_empty():
		return {"valid": false, "error": "請填寫顯示名稱"}
	
	if system_prompt_input.text.strip_edges().is_empty():
		return {"valid": false, "error": "請填寫系統提示詞"}
	
	return {"valid": true}

func _collect_data() -> Dictionary:
	"""收集表單數據"""
	var traits_text = traits_input.text.strip_edges()
	var traits = []
	if not traits_text.is_empty():
		var trait_list = traits_text.split(",")
		for i in range(trait_list.size()):
			var t = trait_list[i].strip_edges()
			if not t.is_empty():
				traits.append(t)
	
	var emoji_freq_map = ["none", "low", "medium", "high"]
	var emoji_frequency = emoji_freq_map[emoji_frequency_option.selected]
	
	return {
		"name": name_input.text.strip_edges(),
		"display_name": display_name_input.text.strip_edges(),
		"system_prompt": system_prompt_input.text.strip_edges(),
		"speaking_style": speaking_style_input.text.strip_edges(),
		"traits": traits,
		"emoji_frequency": emoji_frequency,
		"greeting": greeting_input.text.strip_edges(),
		"avatar_folder": "Idle",
		"avatar_path": current_avatar_path  # 🆕 包含頭像路徑
	}

func _show_error(message: String):
	"""顯示錯誤對話框"""
	var dialog = AcceptDialog.new()
	dialog.title = "⚠️ 輸入錯誤"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func open_create_mode():
	"""打開創建模式"""
	current_mode = Mode.CREATE
	title = "✨ 創建新個性"
	_clear_form()
	popup_centered()

func open_edit_mode(personality_data: Dictionary):
	"""打開編輯模式"""
	current_mode = Mode.EDIT
	editing_personality_name = personality_data.get("name", "")
	title = "✏️ 編輯個性: " + personality_data.get("display_name", "")
	_load_data(personality_data)
	popup_centered()

func _clear_form():
	"""清空表單"""
	name_input.text = ""
	display_name_input.text = ""
	system_prompt_input.text = ""
	speaking_style_input.text = "友善自然"
	traits_input.text = ""
	emoji_frequency_option.selected = 2
	greeting_input.text = "你好！"
	name_input.editable = true
	
	# 清除頭像
	current_avatar_path = ""
	avatar_preview.texture = null
	clear_avatar_button.disabled = true

func _load_data(data: Dictionary):
	"""載入數據到表單"""
	name_input.text = data.get("name", "")
	display_name_input.text = data.get("display_name", "")
	system_prompt_input.text = data.get("system_prompt", "")
	speaking_style_input.text = data.get("speaking_style", "")
	
	var traits = data.get("traits", [])
	traits_input.text = ",".join(traits)
	
	var emoji_map = {"none": 0, "low": 1, "medium": 2, "high": 3}
	var emoji_freq = data.get("emoji_frequency", "medium")
	emoji_frequency_option.selected = emoji_map.get(emoji_freq, 2)
	
	greeting_input.text = data.get("greeting", "")
	name_input.editable = false
	
	# 載入頭像
	current_avatar_path = data.get("avatar_path", "")
	if current_avatar_path != "":
		_load_avatar_preview(current_avatar_path)

func _load_avatar_preview(avatar_path: String):
	"""載入頭像預覽"""
	# 嘗試從 user:// 載入
	var full_path = "user://" + avatar_path
	if FileAccess.file_exists(full_path):
		var image = Image.load_from_file(ProjectSettings.globalize_path(full_path))
		if image:
			var texture = ImageTexture.create_from_image(image)
			avatar_preview.texture = texture
			clear_avatar_button.disabled = false
			print("✅ 載入頭像預覽: ", avatar_path)
			return
	
	print("⚠️ 找不到頭像: ", avatar_path)
	current_avatar_path = ""
	clear_avatar_button.disabled = true
