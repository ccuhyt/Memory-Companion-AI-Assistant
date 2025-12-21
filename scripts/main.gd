extends Node2D

@onready var pet = $DesktopPet
var python_bridge: PythonBridge
var chat_dialog: Control
var chat_dialog_scene = preload("res://scenes/ChatDialog.tscn")
# 1. 預先載入八點檔的場景
var soap_opera_scene = preload("res://novel-generator/soap-opera-app/SoapOperaMain.tscn")
var soap_opera_window: Window = null # 用來存儲視窗實例

# 2. 存儲 Python Server 的 Process ID，以便關閉時殺掉
var server_pid: int = -1

# 保存提示界面
var saving_overlay: CanvasLayer

# 個性管理
var personality_manager_ui: PersonalityManagerUI

var is_saving = false
var should_quit_after_save = false

func _ready():
	# --- 啟動 Python API Server ---
	start_api_server()
	# 初始化 Python 橋接
	python_bridge = PythonBridge.new()
	add_child(python_bridge)
	
	# 初始化保存提示界面（程式化創建，無需場景文件）
	saving_overlay = SavingOverlay.new()
	add_child(saving_overlay)
	
	# 初始化個性管理界面
	personality_manager_ui = PersonalityManagerUI.new()
	personality_manager_ui.set_python_bridge(python_bridge)
	personality_manager_ui.personality_switched.connect(_on_personality_switched)
	add_child(personality_manager_ui)
	
	# 連接桌寵信號
	pet.pet_right_clicked.connect(_on_pet_right_clicked)
	
	print("✅ 系統初始化完成")
	print("📝 短期記憶將即時保存到文件")
	print("💾 關閉程式時會自動轉存到長期記憶")

func _notification(what):
	"""處理系統關閉事件（點擊視窗 X 按鈕）"""
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not is_saving:
			initiate_save_and_quit()
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)

func initiate_save_and_quit():
	"""啟動保存並退出的流程"""
	if is_saving:
		return
	
	is_saving = true
	should_quit_after_save = true
	
	print("\n" + "=".repeat(50))
	print("🔄 開始保存長期記憶流程...")
	print("=".repeat(50))
	
	saving_overlay.show_saving()
	get_tree().root.set_disable_input(true)
	
	if chat_dialog and chat_dialog.visible:
		chat_dialog.hide()
	
	_perform_save()

func _perform_save():
	"""執行實際的保存操作"""
	saving_overlay.update_progress("正在處理對話記錄...")
	
	var timeout_timer = get_tree().create_timer(15.0)
	timeout_timer.timeout.connect(_on_save_timeout)
	
	python_bridge.end_session(
		func(data):
			_on_save_success(data),
		func(error):
			_on_save_error(error)
	)

func _on_save_success(data):
	"""保存成功"""
	print("\n✅ 保存成功！")
	
	if data is Dictionary:
		var dialogue_count = data.get("dialogue_count", 0)
		var summaries_created = data.get("summaries_created", 0)
		
		print("📊 保存統計:")
		print("   • 處理對話數: ", dialogue_count)
		print("   • 創建總結數: ", summaries_created)
		
		if data.has("errors") and data["errors"] != null:
			print("\n⚠️ 保存時發生部分錯誤:")
			for error in data["errors"]:
				print("   ⚠️ ", error)
		
		saving_overlay.show_success(dialogue_count, summaries_created)
	else:
		saving_overlay.show_success(0, 0)
	
	print("=".repeat(50))
	
	await get_tree().create_timer(1.5).timeout
	
	if should_quit_after_save:
		print("👋 程式正常退出\n")
		get_tree().quit()
	else:
		_restore_normal_state()

func _on_save_error(error):
	"""保存失敗"""
	print("\n❌ 保存失敗: ", error)
	print("=".repeat(50))
	
	saving_overlay.show_error("保存失敗: " + str(error))
	
	await get_tree().create_timer(2.0).timeout
	
	if should_quit_after_save:
		print("⚠️ 儘管保存失敗，程式仍將退出\n")
		get_tree().quit()
	else:
		_restore_normal_state()

func _on_save_timeout():
	"""保存超時"""
	if not is_saving:
		return
	
	print("\n⏱️ 保存超時（15秒）")
	print("=".repeat(50))
	
	saving_overlay.show_error("保存超時，程式將強制退出")
	
	await get_tree().create_timer(1.0).timeout
	
	if should_quit_after_save:
		print("⚠️ 強制退出\n")
		get_tree().quit()

func _restore_normal_state():
	"""恢復正常狀態"""
	is_saving = false
	should_quit_after_save = false
	saving_overlay.hide_overlay()
	get_tree().root.set_disable_input(false)
	print("✅ 已恢復正常狀態")

func start_api_server():
	"""自動啟動 Python Flask Server"""
	print("正在啟動 API Server...")
	
	# 判斷是在編輯器執行還是在匯出後執行
	var output = []
	var path = ""
	
	if OS.has_feature("editor"):
		# 編輯器模式：直接指到 python 腳本位置
		# api_server.py 在專案根目錄的 python_scripts 資料夾
		path = ProjectSettings.globalize_path("res://python_scripts/api_server.py")
		# 這裡假設你的系統有 python 指令
		server_pid = OS.create_process("python", [path], true)
	else:
		# 匯出模式：通常會打包成 exe，或者你需要把 python 環境包進去
		# 這裡暫時示範呼叫同一層目錄下的 python
		pass 
		
	print("📡 Server PID: ", server_pid)

func _exit_tree():
	"""程式關閉時，記得關掉 Python Server"""
	if server_pid != -1:
		print("正在關閉 API Server...")
		OS.kill(server_pid)
		
func _on_pet_right_clicked():
	"""顯示右鍵選單"""
	show_context_menu()

func show_context_menu():
	"""顯示右鍵選單"""
	var menu = PopupMenu.new()
	add_child(menu)
	
	menu.add_item("💬 與桌寵對話", 0)
	menu.add_separator()
	menu.add_item("🎭 個性管理", 1)
	menu.add_item("📊 記憶統計", 2)
	menu.add_item("🗑️ 清空短期記憶", 3)
	menu.add_item("💾 立即保存記憶", 4)
	menu.add_item("📺 八點檔生成", 6)
	menu.add_separator()
	menu.add_item("❌ 退出", 5)
	
	menu.id_pressed.connect(_on_menu_item_selected)
	menu.position = get_global_mouse_position()
	menu.popup()
	
	menu.popup_hide.connect(func():
		menu.queue_free()
	)

func _on_menu_item_selected(id: int):
	"""處理選單選擇"""
	match id:
		0:
			show_chat_dialog()
		1:
			show_personality_manager()
		2:
			show_memory_stats()
		3:
			clear_session_memory()
		4:
			save_memory_now()
		5:
			quit_application()
		6:
			show_soap_opera() # 6. 處理點擊事件

func quit_application():
	"""用戶選擇退出"""
	initiate_save_and_quit()

func save_memory_now():
	"""立即保存記憶（不退出）"""
	if is_saving:
		show_notification("正在保存中，請稍候...")
		return
	
	is_saving = true
	should_quit_after_save = false
	
	print("\n💾 用戶手動觸發保存...")
	
	saving_overlay.show_saving()
	saving_overlay.update_progress("手動保存中...")
	
	python_bridge.end_session(
		func(data):
			print("✅ 手動保存成功")
			if data is Dictionary:
				var dialogue_count = data.get("dialogue_count", 0)
				var summaries_created = data.get("summaries_created", 0)
				saving_overlay.show_success(dialogue_count, summaries_created)
			await get_tree().create_timer(2.0).timeout
			_restore_normal_state()
			show_notification("記憶已保存！"),
		func(error):
			print("❌ 手動保存失敗: ", error)
			saving_overlay.show_error(str(error))
			await get_tree().create_timer(2.0).timeout
			_restore_normal_state()
			show_notification("保存失敗: " + str(error))
	)

func show_chat_dialog():
	"""顯示對話視窗"""
	print("🗨️ 準備顯示對話視窗...")
	
	if chat_dialog == null:
		print("📦 載入 ChatDialog 場景...")
		chat_dialog = chat_dialog_scene.instantiate()
		add_child(chat_dialog)
		
		chat_dialog.message_sent.connect(_on_message_sent)
		chat_dialog.dialog_closed.connect(_on_dialog_closed)
		
		print("✅ ChatDialog 已創建")
	
	_update_chat_dialog_personality()
	chat_dialog.show_dialog()
	print("✅ ChatDialog 已顯示")

func _on_dialog_closed():
	"""對話視窗關閉"""
	print("🚪 對話視窗已關閉")

func _on_message_sent(message: String):
	"""處理用戶發送的訊息"""
	print("📤 發送訊息: ", message)
	
	chat_dialog.add_system_message("思考中...")
	chat_dialog.set_input_enabled(false)
	
	python_bridge.send_chat_message(message,
		func(response):
			print("📥 收到回應: ", response.substr(0, 50), "...")
			chat_dialog.add_pet_message(response)
			chat_dialog.set_input_enabled(true),
		func(error):
			print("❌ 錯誤: ", error)
			chat_dialog.add_error_message(error)
			chat_dialog.set_input_enabled(true)
	)

func show_personality_manager():
	"""顯示個性管理界面"""
	print("🎭 開啟個性管理...")
	personality_manager_ui.show_manager()

func _on_personality_switched(personality_name: String):
	"""個性切換完成"""
	show_notification("已切換個性")
	print("✅ 個性已切換: ", personality_name)
	
	if chat_dialog != null and chat_dialog.visible:
		_update_chat_dialog_personality()

func _update_chat_dialog_personality():
	"""更新對話視窗的個性信息"""
	if chat_dialog == null:
		return
	
	print("🔄 更新對話視窗個性信息...")
	
	python_bridge.get_current_personality(
		func(data):
			if data is Dictionary and data.has("personality"):
				var personality = data["personality"]
				var display_name = personality.get("display_name", "桌寵")
				var avatar_path = personality.get("avatar_path", "")
				
				print("📝 個性名稱: ", display_name)
				print("🖼️ 頭像路徑: ", avatar_path)
				
				chat_dialog.set_personality_info(display_name, avatar_path)
			else:
				print("⚠️ 無法獲取個性信息"),
		func(error):
			print("❌ 獲取個性失敗: ", error)
	)

func show_memory_stats():
	"""顯示記憶統計"""
	print("📊 獲取記憶統計...")
	
	python_bridge.get_memory_stats(
		func(data):
			var stats = data.get("stats", {})
			var text = "記憶統計\n\n"
			text += "短期記憶對話數: %d\n" % stats.get("session_dialogues", 0)
			text += "長期記憶總結數: %d\n" % stats.get("total_summaries", 0)
			text += "\n💡 提示:\n"
			text += "• 短期記憶會在程式關閉時自動轉存\n"
			text += "• 也可以手動點選「立即保存記憶」"
			
			var dialog = AcceptDialog.new()
			dialog.title = "記憶統計"
			dialog.dialog_text = text
			add_child(dialog)
			dialog.popup_centered()
			dialog.confirmed.connect(func():
				dialog.queue_free()
			),
		func(error):
			print("❌ 獲取統計失敗: ", error)
			show_error_dialog("獲取統計失敗", error))
				
func show_soap_opera():
	"""顯示八點檔生成視窗"""
	if soap_opera_window == null or not is_instance_valid(soap_opera_window):
		# 實例化場景
		var instance = soap_opera_scene.instantiate()
		
		# 建議將八點檔做成一個獨立的 Window 節點，這樣可以拖來拖去
		soap_opera_window = Window.new()
		soap_opera_window.title = "八點檔生成器"
		soap_opera_window.size = Vector2(1280, 720) # 設定大小
		soap_opera_window.close_requested.connect(func(): soap_opera_window.queue_free())
		
		# 將場景加到 Window 裡
		soap_opera_window.add_child(instance)
		add_child(soap_opera_window)
		# instance.set_anchors_preset(Control.PRESET_FULL_RECT) #填滿視窗
		
		# 置中顯示
		soap_opera_window.move_to_center()
		soap_opera_window.show()
	else:
		# 如果已經開了，就把它抓到最上層
		soap_opera_window.grab_focus()

func clear_session_memory():
	"""清空短期記憶"""
	var confirm = ConfirmationDialog.new()
	confirm.title = "清空短期記憶"
	confirm.dialog_text = "確定要清空本次對話的短期記憶嗎？\n（不影響長期記憶）"
	add_child(confirm)
	
	confirm.confirmed.connect(func():
		python_bridge.clear_session_memory(
			func(_data):
				print("✅ 短期記憶已清空")
				show_notification("短期記憶已清空"),
			func(error):
				print("❌ 清空失敗: ", error)
				show_error_dialog("清空失敗", error)
		)
		confirm.queue_free()
	)
	
	confirm.canceled.connect(func():
		confirm.queue_free()
	)
	
	confirm.popup_centered()

func show_notification(text: String):
	"""顯示通知訊息"""
	var notif = Label.new()
	notif.text = text
	notif.position = get_global_mouse_position()
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25, 0.95)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	
	notif.add_theme_stylebox_override("normal", style)
	notif.add_theme_color_override("font_color", Color.WHITE)
	
	add_child(notif)
	
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(notif):
		notif.queue_free()

func show_error_dialog(title: String, error: String):
	"""顯示錯誤對話框"""
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = error
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		dialog.queue_free()
	)
	
