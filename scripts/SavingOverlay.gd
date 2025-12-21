extends CanvasLayer
class_name SavingOverlay

## 保存記憶時的遮罩提示界面

var panel: Panel
var status_label: Label
var progress_label: Label
var spinner: Label

var spinner_frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
var spinner_index = 0
var spinner_timer: Timer

func _init():
	"""初始化時創建所有UI元素"""
	# 創建半透明背景
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# 創建面板
	panel = Panel.new()
	panel.custom_minimum_size = Vector2(400, 200)
	add_child(panel)
	
	# 創建垂直容器
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)
	
	# 創建 Spinner 標籤
	spinner = Label.new()
	spinner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spinner.text = "⠋"
	vbox.add_child(spinner)
	
	# 創建狀態標籤
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.text = "處理中..."
	vbox.add_child(status_label)
	
	# 創建進度標籤
	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.text = "請稍候"
	vbox.add_child(progress_label)
	
	# 創建 spinner 計時器
	spinner_timer = Timer.new()
	spinner_timer.wait_time = 0.1
	spinner_timer.timeout.connect(_update_spinner)
	add_child(spinner_timer)

func _ready():
	"""準備完成後設置樣式和位置"""
	_setup_panel_style()
	_center_panel()
	hide()

func _setup_panel_style():
	"""設置面板樣式"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 0.95)
	style.border_color = Color(0.3, 0.5, 0.8, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	
	panel.add_theme_stylebox_override("panel", style)
	
	# 設置標籤樣式
	status_label.add_theme_font_size_override("font_size", 20)
	progress_label.add_theme_font_size_override("font_size", 14)
	spinner.add_theme_font_size_override("font_size", 24)

func _center_panel():
	"""居中面板"""
	var viewport_size = get_viewport().get_visible_rect().size
	panel.position = Vector2(
		(viewport_size.x - panel.custom_minimum_size.x) / 2,
		(viewport_size.y - panel.custom_minimum_size.y) / 2
	)

func _update_spinner():
	"""更新轉圈動畫"""
	spinner.text = spinner_frames[spinner_index]
	spinner_index = (spinner_index + 1) % spinner_frames.size()

func show_saving():
	"""顯示保存界面"""
	status_label.text = "💾 儲存長期記憶中..."
	progress_label.text = "請稍候，不要關閉程式"
	spinner.text = spinner_frames[0]
	spinner_index = 0
	
	show()
	spinner_timer.start()
	
	# 重新居中（以防視窗大小改變）
	_center_panel()

func update_progress(message: String):
	"""更新進度訊息"""
	progress_label.text = message

func show_success(dialogue_count: int, summary_count: int):
	"""顯示成功訊息"""
	spinner_timer.stop()
	spinner.text = "✓"
	status_label.text = "✅ 儲存完成"
	progress_label.text = "處理 %d 條對話，創建 %d 條總結" % [dialogue_count, summary_count]

func show_error(error_message: String):
	"""顯示錯誤訊息"""
	spinner_timer.stop()
	spinner.text = "✗"
	status_label.text = "⚠️ 儲存失敗"
	progress_label.text = error_message

func hide_overlay():
	"""隱藏界面"""
	spinner_timer.stop()
	hide()
