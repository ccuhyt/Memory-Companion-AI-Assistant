extends Window
class_name PersonalityManagerUI

## 個性管理界面 - 查看、編輯、刪除個性

signal personality_switched(personality_name: String)
signal refresh_requested

var python_bridge: PythonBridge
var personality_editor: PersonalityEditor

# UI 節點
var list_container: VBoxContainer
var scroll_container: ScrollContainer
var button_container: HBoxContainer

# 按鈕
var create_button: Button
var close_button: Button
var refresh_button: Button

# 數據
var personalities_data: Array = []

func _init():
	"""初始化視窗"""
	title = "個性管理"
	size = Vector2i(600, 500)
	min_size = Vector2i(500, 400)
	
	borderless = false
	always_on_top = false
	transient = true
	exclusive = false
	
	_build_ui()

func _ready():
	"""視窗準備完成"""
	close_requested.connect(_on_close_requested)
	position = (DisplayServer.screen_get_size() - size) / 2

func _build_ui():
	"""構建 UI"""
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_vbox)
	
	# === 標題區 ===
	var title_margin = MarginContainer.new()
	title_margin.add_theme_constant_override("margin_left", 15)
	title_margin.add_theme_constant_override("margin_right", 15)
	title_margin.add_theme_constant_override("margin_top", 15)
	title_margin.add_theme_constant_override("margin_bottom", 10)
	main_vbox.add_child(title_margin)
	
	var title_hbox = HBoxContainer.new()
	title_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_margin.add_child(title_hbox)
	
	var title_label = Label.new()
	title_label.text = "🎭 個性管理"
	title_label.add_theme_font_size_override("font_size", 24)
	title_hbox.add_child(title_label)
	
	# 分隔線
	var separator1 = HSeparator.new()
	main_vbox.add_child(separator1)
	
	# === 滾動區域 ===
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll_container)
	
	# 列表容器（帶邊距）
	var list_margin = MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 15)
	list_margin.add_theme_constant_override("margin_right", 15)
	list_margin.add_theme_constant_override("margin_top", 15)
	list_margin.add_theme_constant_override("margin_bottom", 15)
	list_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(list_margin)
	
	list_container = VBoxContainer.new()
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_container.add_theme_constant_override("separation", 10)
	list_margin.add_child(list_container)
	
	# 分隔線
	var separator2 = HSeparator.new()
	main_vbox.add_child(separator2)
	
	# === 底部按鈕區 ===
	var button_margin = MarginContainer.new()
	button_margin.add_theme_constant_override("margin_left", 15)
	button_margin.add_theme_constant_override("margin_right", 15)
	button_margin.add_theme_constant_override("margin_top", 10)
	button_margin.add_theme_constant_override("margin_bottom", 15)
	main_vbox.add_child(button_margin)
	
	button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 10)
	button_margin.add_child(button_container)
	
	create_button = Button.new()
	create_button.text = "➕ 創建新個性"
	create_button.pressed.connect(_on_create_pressed)
	button_container.add_child(create_button)
	
	refresh_button = Button.new()
	refresh_button.text = "🔄 重新整理"
	refresh_button.pressed.connect(_on_refresh_pressed)
	button_container.add_child(refresh_button)
	
	close_button = Button.new()
	close_button.text = "❌ 關閉"
	close_button.pressed.connect(_on_close_pressed)
	button_container.add_child(close_button)

func set_python_bridge(bridge: PythonBridge):
	"""設置 Python 橋接器"""
	python_bridge = bridge

func load_personalities():
	"""載入個性列表"""
	if not python_bridge:
		print("❌ Python bridge not set")
		return
	
	_show_loading()
	
	python_bridge.get_personalities(
		func(data):
			personalities_data = data.get("personalities", [])
			_display_personalities(),
		func(error):
			_show_error("載入失敗: " + str(error))
	)

func _show_loading():
	"""顯示載入中"""
	_clear_list()
	
	var loading_label = Label.new()
	loading_label.text = "載入中..."
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list_container.add_child(loading_label)

func _clear_list():
	"""清空列表"""
	for child in list_container.get_children():
		child.queue_free()

func _display_personalities():
	"""顯示個性列表"""
	_clear_list()
	
	if personalities_data.is_empty():
		var empty_label = Label.new()
		empty_label.text = "沒有個性資料"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_container.add_child(empty_label)
		return
	
	for p_data in personalities_data:
		var card = _create_personality_card(p_data)
		list_container.add_child(card)

func _create_personality_card(data: Dictionary) -> PanelContainer:
	"""創建個性卡片"""
	var card = PanelContainer.new()
	
	# 樣式
	var style = StyleBoxFlat.new()
	if data.get("is_current", false):
		# 當前個性 - 藍色邊框
		style.bg_color = Color(0.2, 0.25, 0.35, 0.3)
		style.border_color = Color(0.3, 0.5, 0.8, 1.0)
		style.set_border_width_all(2)
	else:
		# 普通個性
		style.bg_color = Color(0.15, 0.15, 0.18, 0.5)
		style.border_color = Color(0.3, 0.3, 0.35, 1.0)
		style.set_border_width_all(1)
	
	style.set_corner_radius_all(8)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	
	card.add_theme_stylebox_override("panel", style)
	
	# 內容
	var hbox = HBoxContainer.new()
	card.add_child(hbox)
	
	# 左側：信息
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)
	
	# 名稱
	var name_label = Label.new()
	var name_text = data.get("display_name", "未命名")
	if data.get("is_current", false):
		name_text = "✓ " + name_text + " (當前)"
	name_label.text = name_text
	name_label.add_theme_font_size_override("font_size", 18)
	info_vbox.add_child(name_label)
	
	# 說話風格
	var style_label = Label.new()
	style_label.text = "風格: " + data.get("speaking_style", "未設定")
	style_label.add_theme_font_size_override("font_size", 12)
	style_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_vbox.add_child(style_label)
	
	# 特徵
	var traits = data.get("traits", [])
	if not traits.is_empty():
		var traits_label = Label.new()
		traits_label.text = "特徵: " + ", ".join(traits)
		traits_label.add_theme_font_size_override("font_size", 12)
		traits_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		info_vbox.add_child(traits_label)
	
	# 右側：按鈕
	var button_vbox = VBoxContainer.new()
	button_vbox.add_theme_constant_override("separation", 5)
	hbox.add_child(button_vbox)
	
	# 切換按鈕
	if not data.get("is_current", false):
		var switch_btn = Button.new()
		switch_btn.text = "✓ 切換"
		switch_btn.custom_minimum_size = Vector2(80, 0)
		switch_btn.pressed.connect(func(): _on_switch_personality(data.get("name", "")))
		button_vbox.add_child(switch_btn)
	
	# 編輯按鈕
	var edit_btn = Button.new()
	edit_btn.text = "✏️ 編輯"
	edit_btn.custom_minimum_size = Vector2(80, 0)
	edit_btn.pressed.connect(func(): _on_edit_personality(data))
	button_vbox.add_child(edit_btn)
	
	# 刪除按鈕（預設個性不能刪除）
	var is_default = _is_default_personality(data.get("name", ""))
	if not is_default:
		var delete_btn = Button.new()
		delete_btn.text = "🗑️ 刪除"
		delete_btn.custom_minimum_size = Vector2(80, 0)
		delete_btn.pressed.connect(func(): _on_delete_personality(data))
		button_vbox.add_child(delete_btn)
	
	return card

func _is_default_personality(name: String) -> bool:
	"""檢查是否為預設個性"""
	var defaults = ["cute_cat", "cool_assistant", "cheerful_friend", "gentle_scholar"]
	return name in defaults

func _on_switch_personality(personality_name: String):
	"""切換個性"""
	if not python_bridge:
		return
	
	print("🎭 切換個性: ", personality_name)
	
	python_bridge.switch_personality(personality_name,
		func(_result):
			print("✅ 切換成功")
			personality_switched.emit(personality_name)
			load_personalities(),  # 重新載入列表
		func(error):
			_show_error("切換失敗: " + str(error))
	)

func _on_edit_personality(data: Dictionary):
	"""編輯個性"""
	if not personality_editor:
		personality_editor = PersonalityEditor.new()
		personality_editor.personality_saved.connect(_on_personality_saved)
		add_child(personality_editor)
	
	personality_editor.open_edit_mode(data)

func _on_delete_personality(data: Dictionary):
	"""刪除個性"""
	var name = data.get("name", "")
	var display_name = data.get("display_name", "")
	
	# 確認對話框
	var confirm = ConfirmationDialog.new()
	confirm.title = "確認刪除"
	confirm.dialog_text = "確定要刪除個性「%s」嗎？\n此操作無法復原。" % display_name
	add_child(confirm)
	
	confirm.confirmed.connect(func():
		_perform_delete(name)
		confirm.queue_free())
	
	confirm.canceled.connect(func():
		confirm.queue_free())
	
	confirm.popup_centered()

func _perform_delete(personality_name: String):
	"""執行刪除"""
	if not python_bridge:
		return
	
	print("🗑️ 刪除個性: ", personality_name)
	
	python_bridge.delete_personality(personality_name,
		func(_result):
			print("✅ 刪除成功")
			load_personalities(),
		func(error):
			_show_error("刪除失敗: " + str(error))
	)

func _on_create_pressed():
	"""創建新個性"""
	if not personality_editor:
		personality_editor = PersonalityEditor.new()
		personality_editor.personality_saved.connect(_on_personality_saved)
		add_child(personality_editor)
	
	personality_editor.open_create_mode()

func _on_personality_saved(personality_data: Dictionary):
	"""個性保存完成"""
	if not python_bridge:
		return
	
	var is_edit_mode = personality_data.get("is_edit_mode", false)
	
	# 🆕 根據模式選擇創建或更新
	if is_edit_mode:
		print("✏️ 更新個性: ", personality_data.get("name", ""))
		python_bridge.update_personality(personality_data,
			func(_result):
				print("✅ 更新成功")
				load_personalities(),
			func(error):
				_show_error("更新失敗: " + str(error))
		)
	else:
		print("💾 創建個性: ", personality_data.get("name", ""))
		python_bridge.create_personality(personality_data,
			func(_result):
				print("✅ 創建成功")
				load_personalities(),
			func(error):
				_show_error("創建失敗: " + str(error))
		)

func _on_refresh_pressed():
	"""重新整理"""
	load_personalities()

func _on_close_pressed():
	"""關閉按鈕"""
	hide()

func _on_close_requested():
	"""視窗關閉請求"""
	hide()

func _show_error(message: String):
	"""顯示錯誤"""
	var dialog = AcceptDialog.new()
	dialog.title = "❌ 錯誤"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func show_manager():
	"""顯示管理界面"""
	load_personalities()
	popup_centered()
