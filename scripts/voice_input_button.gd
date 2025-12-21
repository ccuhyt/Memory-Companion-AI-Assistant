extends Button
# 完整版語音按鈕 - 包含所有保護機制

signal voice_text_ready(text: String)

var is_recording = false
var python_pid = -1

# 使用相對路徑（自動從專案根目錄計算）
var python_path = "python"  # 使用系統的 Python，或改為專案內的虛擬環境路徑
var script_path = ProjectSettings.globalize_path("res://python_scripts/record_audio.py")
var audio_file_path = ProjectSettings.globalize_path("res://audio/recording.wav")
var lock_file_path = ProjectSettings.globalize_path("res://audio/recording.lock")

func _ready():
	print("==================================================")
	print("🔧 語音按鈕初始化")
	print("Python: ", python_path)
	print("腳本: ", script_path)
	print("音檔: ", audio_file_path)
	
	# 檢查檔案
	print("\n📂 檔案檢查:")
	print("  Python 存在? ", FileAccess.file_exists(python_path))
	print("  腳本存在? ", FileAccess.file_exists(script_path))
	print("  Audio 資料夾存在? ", DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://audio")))
	print("==================================================")
	
	button_down.connect(_on_button_pressed)
	button_up.connect(_on_button_released)
	
	text = "🎤"
	tooltip_text = "按住說話"
	
	# 清理殘留檔案
	if FileAccess.file_exists(lock_file_path):
		DirAccess.remove_absolute(lock_file_path)

func _on_button_pressed():
	if is_recording: 
		return
	
	print("\n🎙️ [1/4] 準備錄音...")
	text = "⏳"
	tooltip_text = "準備中..."
	
	# 建立鎖定檔案
	var file = FileAccess.open(lock_file_path, FileAccess.WRITE)
	if file == null:
		print("❌ 無法創建鎖定檔案!")
		text = "❌"
		return
	file.store_string("recording")
	file.close()
	print("✅ 鎖定檔案已創建")
	
	# 啟動 Python
	var args = [script_path, audio_file_path, lock_file_path]
	print("🐍 [2/4] 啟動 Python...")
	print("   指令: ", python_path)
	print("   參數: ", args)
	
	python_pid = OS.create_process(python_path, args)
	
	if python_pid == -1:
		print("❌ 無法啟動 Python!")
		text = "❌"
		tooltip_text = "Python 啟動失敗"
		return
	
	print("✅ Python PID: ", python_pid)
	
	# 等待 Python 初始化 (0.8秒)
	print("⏳ [3/4] 等待 Python 初始化 (0.8秒)...")
	await get_tree().create_timer(0.8).timeout
	
	# 檢查按鈕是否還被按住
	if not button_pressed:
		print("⚠️ 按鈕提前放開 - 錄音太短")
		text = "⚠️"
		tooltip_text = "錄音太短"
		
		# 清理
		if FileAccess.file_exists(lock_file_path):
			DirAccess.remove_absolute(lock_file_path)
		await get_tree().create_timer(0.2).timeout
		
		if OS.is_process_running(python_pid):
			OS.kill(python_pid)
			print("🔪 已終止 Python 進程")
		
		python_pid = -1
		disabled = false
		
		# 2秒後恢復
		await get_tree().create_timer(2.0).timeout
		text = "🎤"
		tooltip_text = "按住說話"
		return
	
	# 現在才正式開始錄音!
	is_recording = true
	text = "🔴"
	tooltip_text = "正在錄音... (放開結束)"
	print("✅ [4/4] 開始錄音!")

func _on_button_released():
	if not is_recording: 
		print("⚠️ is_recording = false, 忽略放開事件")
		return
	
	print("\n⏹️ [1/5] 停止錄音...")
	text = "⏳"
	tooltip_text = "處理中..."
	disabled = true
	
	# 刪除鎖定檔案 (通知 Python 停止)
	if FileAccess.file_exists(lock_file_path):
		DirAccess.remove_absolute(lock_file_path)
		print("✅ [2/5] 鎖定檔案已刪除")
	
	# 等待 Python 存檔
	print("⏳ [3/5] 等待 Python 存檔 (0.5秒)...")
	await get_tree().create_timer(0.5).timeout
	
	# 確保 Python 退出
	if OS.is_process_running(python_pid):
		print("🔪 [4/5] 強制終止 Python")
		OS.kill(python_pid)
	else:
		print("✅ [4/5] Python 已正常退出")
	
	is_recording = false
	python_pid = -1
	
	# 檢查錄音檔
	print("📁 [5/5] 檢查錄音檔...")
	print("   路徑: ", audio_file_path)
	print("   存在? ", FileAccess.file_exists(audio_file_path))
	
	if FileAccess.file_exists(audio_file_path):
		var file_size = FileAccess.get_file_as_bytes(audio_file_path).size()
		print("✅ 錄音檔存在! 大小: ", file_size, " bytes")
		
		if file_size < 1000:
			print("⚠️ 檔案太小,可能錄音失敗")
			text = "⚠️"
			tooltip_text = "錄音檔太小"
			disabled = false
			await get_tree().create_timer(2.0).timeout
			text = "🎤"
			tooltip_text = "按住說話"
		else:
			_start_transcribe()
	else:
		print("❌ 錄音檔不存在!")
		text = "❌"
		tooltip_text = "錄音失敗"
		disabled = false
		
		await get_tree().create_timer(2.0).timeout
		text = "🎤"
		tooltip_text = "按住說話"

func _start_transcribe():
	print("\n🔄 開始轉錄...")
	text = "🔄"
	tooltip_text = "轉錄中..."
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_stt_response)
	
	var audio_file = FileAccess.open(audio_file_path, FileAccess.READ)
	if not audio_file:
		print("❌ 無法讀取錄音檔")
		text = "❌"
		disabled = false
		return
	
	var audio_bytes = audio_file.get_buffer(audio_file.get_length())
	audio_file.close()
	print("✅ 已讀取 ", audio_bytes.size(), " bytes")
	
	var boundary = "GodotUploadBoundary12345"
	var body = PackedByteArray()
	
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array('Content-Disposition: form-data; name="language"\r\n\r\n'.to_utf8_buffer())
	body.append_array("zh\r\n".to_utf8_buffer())
	
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array('Content-Disposition: form-data; name="file"; filename="recording.wav"\r\n'.to_utf8_buffer())
	body.append_array("Content-Type: audio/wav\r\n\r\n".to_utf8_buffer())
	body.append_array(audio_bytes)
	body.append_array(("\r\n--" + boundary + "--\r\n").to_utf8_buffer())
	
	var headers = [
		"Content-Type: multipart/form-data; boundary=" + boundary
	]
	
	print("📤 發送 HTTP 請求到 http://127.0.0.1:5000/api/stt ...")
	var error = http.request_raw(
		"http://127.0.0.1:5000/api/stt",
		headers,
		HTTPClient.METHOD_POST,
		body
	)
	
	if error != OK:
		print("❌ HTTP 請求失敗! 錯誤: ", error)
		text = "❌"
		disabled = false

func _on_stt_response(result, response_code, headers, body):
	print("\n📥 收到 STT 回應")
	print("   狀態碼: ", response_code)
	
	if response_code != 200:
		print("❌ STT API 錯誤")
		var error_text = body.get_string_from_utf8()
		print("   錯誤內容: ", error_text)
		text = "❌"
		tooltip_text = "轉錄失敗"
		disabled = false
		return
	
	var response_text = body.get_string_from_utf8()
	print("   回應: ", response_text)
	
	var json = JSON.parse_string(response_text)
	if json == null:
		print("❌ JSON 解析失敗")
		text = "❌"
		disabled = false
		return
	
	var transcribed_text = json.get("text", "")
	print("✅ 轉錄結果: '", transcribed_text, "'")
	
	# 過濾無效結果
	if transcribed_text == "" or transcribed_text == "[無有效語音]" or transcribed_text == "[無聲音]":
		print("⚠️ 無有效語音")
		text = "🔇"
		tooltip_text = "未偵測到語音"
	else:
		# 發送信號給對話框
		emit_signal("voice_text_ready", transcribed_text)
		text = "✅"
		tooltip_text = "轉錄完成"
	
	disabled = false
	
	# 1秒後恢復按鈕
	await get_tree().create_timer(1.0).timeout
	text = "🎤"
	tooltip_text = "按住說話"
