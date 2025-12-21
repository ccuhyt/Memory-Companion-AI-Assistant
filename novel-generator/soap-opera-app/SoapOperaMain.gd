extends Control

# ============================================
# 1. 節點引用 (UI 元件)
# ============================================

# --- 顯示與輸入區 ---
@onready var story_text = $MarginContainer/ScrollContainer/VBoxContainer/StoryPanel/MarginContainer/ScrollContainer/StoryText
@onready var input_text = $MarginContainer/ScrollContainer/VBoxContainer/InputPanel/InputText

# --- 主要功能按鈕 ---
@onready var generate_btn = $MarginContainer/ScrollContainer/VBoxContainer/GenerateBtn
@onready var inspire_btn = $MarginContainer/ScrollContainer/VBoxContainer/InspireBtn
@onready var length_select = $MarginContainer/ScrollContainer/VBoxContainer/LengthSelect
@onready var save_btn = $MarginContainer/ScrollContainer/VBoxContainer/EndButtons/SaveBtn
@onready var sequel_btn = $MarginContainer/ScrollContainer/VBoxContainer/EndButtons/SequelBtn

# --- 聲音區 ---
@onready var play_btn = $MarginContainer/ScrollContainer/VBoxContainer/AudioControls/PlayBtn
@onready var stop_btn = $MarginContainer/ScrollContainer/VBoxContainer/AudioControls/StopBtn
@onready var audio_player = $AudioPlayer

# --- 類型按鈕 ---
@onready var type_buttons = $MarginContainer/ScrollContainer/VBoxContainer/TypeButtons
@onready var btn_rebirth = $MarginContainer/ScrollContainer/VBoxContainer/TypeButtons/BtnRebirth
@onready var btn_fake = $MarginContainer/ScrollContainer/VBoxContainer/TypeButtons/BtnFake
@onready var btn_ceo = $MarginContainer/ScrollContainer/VBoxContainer/TypeButtons/BtnCEO
@onready var btn_inlaw = $MarginContainer/ScrollContainer/VBoxContainer/TypeButtons/BtnInLaw
@onready var btn_legacy = $MarginContainer/ScrollContainer/VBoxContainer/TypeButtons/BtnLegacy
@onready var btn_cheat = $MarginContainer/ScrollContainer/VBoxContainer/TypeButtons/BtnCheat
@onready var btn_amnesia = $MarginContainer/ScrollContainer/VBoxContainer/TypeButtons/BtnAmnesia
@onready var btn_local = $MarginContainer/ScrollContainer/VBoxContainer/TypeButtons/BtnLocal
@onready var btn_random = $MarginContainer/ScrollContainer/VBoxContainer/TypeButtons/BtnRandom

# --- 風格按鈕 ---
@onready var tone_buttons = $MarginContainer/ScrollContainer/VBoxContainer/ToneButtons
@onready var btn_dogblood = $MarginContainer/ScrollContainer/VBoxContainer/ToneButtons/BtnDogBlood
@onready var btn_cool = $MarginContainer/ScrollContainer/VBoxContainer/ToneButtons/BtnCool
@onready var btn_sad = $MarginContainer/ScrollContainer/VBoxContainer/ToneButtons/BtnSad
@onready var btn_funny = $MarginContainer/ScrollContainer/VBoxContainer/ToneButtons/BtnFunny
@onready var btn_warm = $MarginContainer/ScrollContainer/VBoxContainer/ToneButtons/BtnWarm

# ============================================
# 2. 變數設定
# ============================================

var api_url = "http://localhost:5000"
# [新增] 串流專用設定
var api_host = "127.0.0.1" 
var api_port = 5000

var current_story = ""
var current_episode = 1
var current_length = "medium"  # 當前選擇的長度
var max_episodes = 4  # 最大集數（根據長度動態設定）
var selected_type = "重生逆襲"
var selected_tone = "狗血"

# [修改] 這裡加入了 HTTPClient 來做即時生成
var http_client: HTTPClient = HTTPClient.new()
var is_generating = false # 這裡兼做 is_streaming 的用途
var stream_buffer = ""    # 用來緩衝切斷的 JSON 資料

# [新增] TTS 分段播放系統
var tts_buffer_string = ""  # 暫存還沒講的文字
var audio_queue: Array = []  # 播放清單：存著一堆 AudioStreamMP3
var tts_request_queue: Array = []  # 確保依序請求 TTS
var is_requesting_tts = false
var auto_play_tts = false  # 是否自動播放 TTS（預設關閉）

# 按鈕樣式
var style_selected: StyleBoxFlat
var style_normal: StyleBoxFlat

# 網路請求員 (TTS 與 靈感 仍使用舊的 HTTPRequest)
var http_generate = HTTPRequest.new() # 保留變數但不使用，避免報錯
var http_tts = HTTPRequest.new()
var http_suggestion = HTTPRequest.new()
var http_tts_quick = HTTPRequest.new()  # 專門用來處理快速 TTS 請求

# ============================================
# 3. 初始化與啟動
# ============================================

func _ready():
	print("🎬 全功能八點檔生成器啟動!")
	
	# 添加 HTTP 請求節點
	add_child(http_generate)
	add_child(http_tts)
	add_child(http_suggestion)
	add_child(http_tts_quick)
	
	# 初始化按鈕樣式
	_init_button_styles()
	
	# 初始化長度選單
	if length_select:
		length_select.clear() # 確保清空預設
		length_select.add_item("中篇 (推薦)", 0)
		length_select.add_item("短篇 (快速)", 1)
		length_select.add_item("長篇 (詳細)", 2)
		length_select.set_item_metadata(0, "medium")
		length_select.set_item_metadata(1, "short")
		length_select.set_item_metadata(2, "long")
	
	# 連接按鈕
	_connect_buttons()
	
	generate_btn.pressed.connect(_on_generate_pressed)
	play_btn.pressed.connect(_on_play_pressed)
	stop_btn.pressed.connect(_on_stop_pressed)
	if inspire_btn: inspire_btn.pressed.connect(_on_inspire_pressed)
	if save_btn: save_btn.pressed.connect(_on_save_pressed)
	if sequel_btn: sequel_btn.pressed.connect(_on_sequel_pressed)
	
	# 連接 HTTP 回應 (非串流部分)
	http_tts.request_completed.connect(_on_tts_completed)
	http_suggestion.request_completed.connect(_on_suggestion_completed)
	http_tts_quick.request_completed.connect(_on_quick_tts_completed)
	
	# 連接播放器的 finished 信號，播完一首自動播下一首
	audio_player.finished.connect(_play_next_in_queue)
	
	# 初始 UI 狀態
	play_btn.disabled = true
	stop_btn.disabled = true
	sequel_btn.disabled = true
	story_text.text = "[center][color=#999999]請選擇故事類型和風格\n然後點擊下方紅色大按鈕生成故事[/color][/center]"
	
	# 預設選中
	_select_type_button(btn_rebirth, "重生逆襲")
	_select_tone_button(btn_dogblood, "狗血")

# ============================================
# [關鍵修改] 4. Process 每一幀監聽數據 (即時生成核心)
# ============================================

func _process(delta):
	# 如果沒有在生成(串流)，就什麼都不做
	if not is_generating:
		return
		
	# 1. 更新連線狀態
	http_client.poll()
	var status = http_client.get_status()
	
	# 2. 如果有資料進來 (Body chunk)
	if status == HTTPClient.STATUS_BODY:
		var chunk = http_client.read_response_body_chunk()
		if chunk.size() > 0:
			var text_chunk = chunk.get_string_from_utf8()
			_parse_stream_data(text_chunk)
			
	# 3. 如果連線結束或斷開
	elif status != HTTPClient.STATUS_CONNECTED and status != HTTPClient.STATUS_REQUESTING:
		_finish_streaming()

func _parse_stream_data(text_chunk):
	stream_buffer += text_chunk
	
	# 處理 SSE 格式 (data: {...}\n\n)
	while "\n" in stream_buffer:
		var split_index = stream_buffer.find("\n")
		var line = stream_buffer.substr(0, split_index).strip_edges()
		stream_buffer = stream_buffer.substr(split_index + 1)
		
		if line.begins_with("data: "):
			var json_str = line.substr(6)
			var json_data = JSON.parse_string(json_str)
			
			if json_data:
				if "text" in json_data:
					var new_word = json_data["text"]
					current_story += new_word
					# [重要] 使用 append_text 效能較好且能達成打字機效果
					story_text.append_text(new_word)
					# [新增] 處理 TTS 緩衝
					_process_tts_buffer(new_word)
				elif "error" in json_data:
					story_text.append_text("\n[color=red]錯誤: " + json_data["error"] + "[/color]")

func _finish_streaming():
	is_generating = false
	http_client.close()
	_disable_buttons(false)
	
	# 檢查是否已達最大集數
	if current_episode >= max_episodes:
		sequel_btn.disabled = true
		story_text.append_text("\n\n[center][color=#F39C12]🎬 [全劇終] （共 " + str(max_episodes) + " 集）[/color][/center]")
	else:
		sequel_btn.disabled = false
	
	# 如果最後還有一點點文字沒湊成一句 (例如沒有句號結尾)
	if tts_buffer_string.strip_edges() != "":
		tts_request_queue.append(tts_buffer_string)
		tts_buffer_string = ""
		_process_tts_request_queue()
	
	print("✅ 生成結束")

# ============================================
# [關鍵修改] 5. 啟動串流請求 (取代原本的 HTTPRequest)
# ============================================

func _start_stream_request(endpoint: String, data: Dictionary):
	if is_generating: return
	
	_disable_buttons(true)
	is_generating = true
	stream_buffer = ""
	
	# 1. 連接伺服器
	print("🔌 嘗試連接: %s:%d" % [api_host, api_port])
	var err = http_client.connect_to_host(api_host, api_port)
	if err != OK:
		var error_msg = "\n[color=red]❌ 無法連接伺服器[/color]\n"
		error_msg += "[color=#999999]請確認:\n"
		error_msg += "1. Python API 伺服器是否已啟動?\n"
		error_msg += "   執行: python api_server.py\n"
		error_msg += "2. 伺服器位址: http://%s:%d\n" % [api_host, api_port]
		error_msg += "3. 防火牆是否阻擋連線?[/color]"
		story_text.append_text(error_msg)
		is_generating = false
		_disable_buttons(false)
		print("❌ 連接錯誤碼: ", err)
		return
	
	# 等待連接 (非阻塞式等待，最多等 5 秒)
	var timeout = 50  # 5 秒 (50 * 0.1秒)
	var wait_count = 0
	
	while http_client.get_status() == HTTPClient.STATUS_CONNECTING or http_client.get_status() == HTTPClient.STATUS_RESOLVING:
		http_client.poll()
		await get_tree().process_frame
		wait_count += 1
		
		if wait_count > timeout:
			var error_msg = "\n[color=red]❌ 連接逾時[/color]\n"
			error_msg += "[color=#999999]伺服器沒有回應，請檢查:\n"
			error_msg += "• API 伺服器是否正在運行\n"
			error_msg += "• 網路連線是否正常[/color]"
			story_text.append_text(error_msg)
			is_generating = false
			_disable_buttons(false)
			http_client.close()
			print("❌ 連接逾時")
			return
	
	var status = http_client.get_status()
	print("📡 連接狀態: ", status)
	
	if status != HTTPClient.STATUS_CONNECTED:
		var error_msg = "\n[color=red]❌ 連接失敗[/color]\n"
		error_msg += "[color=#999999]狀態碼: %d\n" % status
		error_msg += "可能原因:\n"
		error_msg += "• Python API 伺服器未啟動\n"
		error_msg += "• 伺服器位址錯誤\n"
		error_msg += "• 埠號 %d 被佔用[/color]" % api_port
		story_text.append_text(error_msg)
		is_generating = false
		_disable_buttons(false)
		http_client.close()
		return
	
	print("✅ 已連接到伺服器")
		
	# 2. 發送 POST 請求
	var json_body = JSON.stringify(data)
	var headers = ["Content-Type: application/json"]
	print("📤 發送請求: ", endpoint)
	http_client.request(HTTPClient.METHOD_POST, endpoint, headers, json_body)

# ============================================
# 6. 生成按鈕觸發 (修改為呼叫串流函式)
# ============================================

func _on_generate_pressed():
	if is_generating: return # 防止重複點擊
	
	current_episode = 1
	current_story = ""
	
	# 讀取長度
	var len_code = "medium"
	if length_select:
		len_code = length_select.get_selected_metadata()
	
	# 根據長度設定最大集數
	current_length = len_code
	max_episodes = {
		"short": 2,
		"medium": 4,
		"long": 6
	}.get(len_code, 4)
	
	var user_input = input_text.text.strip_edges()
	if user_input == "": user_input = "請自由發揮"

	var data = {
		"story_type": selected_type,
		"user_preference": user_input,
		"tone": selected_tone,
		"length": len_code
	}
	
	# [修正] 使用 clear() 強制清空，並用 append_text 加入提示
	story_text.clear()
	story_text.append_text("[center][color=#4A90E2]⏳ 第一集生成中...[/color][/center]\n\n")
	
	print("🎬 開始生成 (串流): ", data)
	_start_stream_request("/api/generate", data)

func _on_sequel_pressed():
	if current_story == "": return
	
	# 檢查是否已達集數上限
	if current_episode >= max_episodes:
		story_text.append_text("\n\n[center][color=#E74C3C]❌ 故事已完結！（共 " + str(max_episodes) + " 集）[/color][/center]")
		return
	
	current_episode += 1
	var direction = input_text.text
	if direction == "": direction = "劇情更加衝突"
	
	var data = {
		"prev_story": current_story,
		"episode_no": current_episode,
		"max_episodes": max_episodes,
		"direction": direction
	}
	
	# [修正] 改用 append_text，避免 text += 導致的效能問題和閃爍
	story_text.append_text("\n\n[center][color=#E74C3C]⏳ 第 " + str(current_episode) + " 集生成中...[/color][/center]\n\n")
	
	# 為了避免文字黏在一起，先手動在變數加換行
	current_story += "\n\n" 
	
	_start_stream_request("/api/sequel", data)

# [注意] 原本的 _on_generate_completed 已不再被生成按鈕使用
# 但為了避免信號報錯或以後要用，我們保留它，不做修改
func _on_generate_completed(result, code, headers, body):
	pass 

# ============================================
# 7. 其他原有功能 (完全保留未動)
# ============================================

func _init_button_styles():
	style_selected = StyleBoxFlat.new()
	style_selected.bg_color = Color("#E74C3C")
	style_selected.border_width_left = 3; style_selected.border_width_right = 3
	style_selected.border_width_top = 3; style_selected.border_width_bottom = 3
	style_selected.border_color = Color("#C0392B")
	style_selected.corner_radius_top_left = 5; style_selected.corner_radius_top_right = 5
	style_selected.corner_radius_bottom_left = 5; style_selected.corner_radius_bottom_right = 5
	
	style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color("#4A90E2")
	style_normal.corner_radius_top_left = 5; style_normal.corner_radius_top_right = 5
	style_normal.corner_radius_bottom_left = 5; style_normal.corner_radius_bottom_right = 5

func _connect_buttons():
	btn_rebirth.pressed.connect(func(): _on_type_selected(btn_rebirth, "重生逆襲"))
	btn_fake.pressed.connect(func(): _on_type_selected(btn_fake, "真假千金"))
	btn_ceo.pressed.connect(func(): _on_type_selected(btn_ceo, "霸道總裁"))
	btn_inlaw.pressed.connect(func(): _on_type_selected(btn_inlaw, "婆媳大戰"))
	btn_legacy.pressed.connect(func(): _on_type_selected(btn_legacy, "遺產爭奪"))
	btn_cheat.pressed.connect(func(): _on_type_selected(btn_cheat, "出軌復仇"))
	btn_amnesia.pressed.connect(func(): _on_type_selected(btn_amnesia, "失憶梗"))
	btn_local.pressed.connect(func(): _on_type_selected(btn_local, "鄉土溫馨"))
	btn_random.pressed.connect(_on_random_type)
	
	btn_dogblood.pressed.connect(func(): _on_tone_selected(btn_dogblood, "狗血"))
	btn_cool.pressed.connect(func(): _on_tone_selected(btn_cool, "爽文"))
	btn_sad.pressed.connect(func(): _on_tone_selected(btn_sad, "虐心"))
	btn_funny.pressed.connect(func(): _on_tone_selected(btn_funny, "搞笑"))
	btn_warm.pressed.connect(func(): _on_tone_selected(btn_warm, "溫馨"))

func _on_type_selected(button: Button, type_name: String):
	selected_type = type_name
	_select_type_button(button, type_name)

func _select_type_button(button: Button, type_name: String):
	for btn in type_buttons.get_children():
		if btn is Button:
			btn.add_theme_stylebox_override("normal", style_normal.duplicate())
	button.add_theme_stylebox_override("normal", style_selected.duplicate())

func _on_tone_selected(button: Button, tone_name: String):
	selected_tone = tone_name
	_select_tone_button(button, tone_name)

func _select_tone_button(button: Button, tone_name: String):
	for btn in tone_buttons.get_children():
		if btn is Button:
			btn.add_theme_stylebox_override("normal", style_normal.duplicate())
	button.add_theme_stylebox_override("normal", style_selected.duplicate())

func _on_random_type():
	var types = ["重生逆襲", "真假千金", "霸道總裁", "婆媳大戰", "遺產爭奪", "出軌復仇", "失憶梗", "鄉土溫馨"]
	var random_type = types[randi() % types.size()]
	var buttons = [btn_rebirth, btn_fake, btn_ceo, btn_inlaw, btn_legacy, btn_cheat, btn_amnesia, btn_local]
	var index = types.find(random_type)
	_on_type_selected(buttons[index], random_type)

func _disable_buttons(disabled: bool):
	is_generating = disabled
	generate_btn.disabled = disabled
	sequel_btn.disabled = disabled
	play_btn.disabled = disabled
	if inspire_btn: inspire_btn.disabled = disabled

# --- 靈感與存檔 ---

func _on_inspire_pressed():
	if is_generating: return
	inspire_btn.disabled = true
	input_text.text = "🔮 正在感應天意..."
	var error = http_suggestion.request(api_url + "/api/suggestions")
	if error != OK:
		input_text.text = "無法連線"
		inspire_btn.disabled = false

func _on_suggestion_completed(result, code, headers, body):
	inspire_btn.disabled = false
	if code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and "suggestions" in json:
			var all_types = json["suggestions"].keys()
			var random_type = all_types[randi() % all_types.size()]
			var ideas = json["suggestions"][random_type]
			var random_idea = ideas[randi() % ideas.size()]
			input_text.text = random_idea
			var type_map = {
				"重生逆襲": btn_rebirth, "真假千金": btn_fake, "霸道總裁": btn_ceo,
				"婆媳大戰": btn_inlaw, "遺產爭奪": btn_legacy, "出軌復仇": btn_cheat,
				"失憶梗": btn_amnesia, "鄉土溫馨": btn_local
			}
			if type_map.has(random_type):
				_on_type_selected(type_map[random_type], random_type)
	else:
		input_text.text = "靈感枯竭 (伺服器錯誤)"

func _on_save_pressed():
	if current_story == "": return
	var time = Time.get_datetime_dict_from_system()
	var filename = "Story_%02d%02d_%02d%02d.txt" % [time.month, time.day, time.hour, time.minute]
	var file = FileAccess.open("user://" + filename, FileAccess.WRITE)
	file.store_string(current_story)
	file.close()
	story_text.append_text("\n\n[center][color=green]✅ 故事已儲存![/color][/center]")
	OS.shell_open(ProjectSettings.globalize_path("user://"))

# --- 語音播放 ---

func _on_play_pressed():
	if current_story == "": return
	
	# 啟用自動播放模式
	auto_play_tts = true
	play_btn.disabled = true
	stop_btn.disabled = false
	
	# 如果佇列中已經有音訊，直接播放
	if not audio_queue.is_empty():
		if not audio_player.playing:
			_play_next_in_queue()
		story_text.append_text("\n\n[center][color=#27AE60]▶️ 播放中...[/color][/center]")
	else:
		# 如果還沒有音訊，顯示等待訊息
		story_text.append_text("\n\n[center][color=#4A90E2]🔊 等待語音生成...[/color][/center]")

func _on_tts_completed(result, code, headers, body):
	if code == 200:
		var stream = AudioStreamMP3.new()
		stream.data = body
		audio_player.stream = stream
		audio_player.play()
		story_text.append_text("\n[center][color=#27AE60]▶️ 播放中...[/color][/center]")
		if not audio_player.finished.is_connected(_on_audio_finished):
			audio_player.finished.connect(_on_audio_finished)
	else:
		play_btn.disabled = false
		story_text.append_text("\n[center][color=red]❌ 語音生成失敗[/color][/center]")

func _on_audio_finished():
	play_btn.disabled = false
	stop_btn.disabled = true

func _on_stop_pressed():
	auto_play_tts = false  # 關閉自動播放
	audio_player.stop()
	play_btn.disabled = false
	stop_btn.disabled = true

# ============================================
# 8. TTS 分段處理系統
# ============================================

func _process_tts_buffer(new_text: String):
	tts_buffer_string += new_text
	
	# 檢查有沒有標點符號
	var end_chars = ["。", "！", "？", "\n", "!", "?", "."]
	
	var found_split = false
	var split_index = -1
	
	for char in end_chars:
		var idx = tts_buffer_string.find(char)
		if idx != -1:
			# 找到最早結束的標點
			if split_index == -1 or idx < split_index:
				split_index = idx
				found_split = true
	
	if found_split:
		# 切割出第一句 (包含標點)
		var sentence = tts_buffer_string.substr(0, split_index + 1)
		# 剩下的留給下一句
		tts_buffer_string = tts_buffer_string.substr(split_index + 1)
		
		# 加入請求佇列
		if sentence.strip_edges() != "":
			tts_request_queue.append(sentence)
			_process_tts_request_queue()
			
		# 遞迴檢查：因為可能一次傳回來兩句話 "你好。我是誰。"
		if tts_buffer_string.length() > 0:
			_process_tts_buffer("")

func _process_tts_request_queue():
	# 如果正在請求中，或者沒東西可請求，就跳過
	if is_requesting_tts or tts_request_queue.is_empty():
		return
		
	is_requesting_tts = true
	var sentence = tts_request_queue.pop_front()
	
	# 發送請求到快速 TTS 端點
	var data = {"text": sentence}
	var headers = ["Content-Type: application/json"]
	http_tts_quick.request(api_url + "/api/tts_quick", headers, HTTPClient.METHOD_POST, JSON.stringify(data))

func _on_quick_tts_completed(result, code, headers, body):
	is_requesting_tts = false # 解鎖，允許下一個請求
	
	if code == 200:
		var stream = AudioStreamMP3.new()
		stream.data = body
		audio_queue.append(stream)
		
		# 只有在啟用自動播放時才自動播放
		if auto_play_tts and not audio_player.playing:
			_play_next_in_queue()
			
	# 無論成功失敗，嘗試處理下一個請求
	_process_tts_request_queue()

func _play_next_in_queue():
	if audio_queue.is_empty():
		return
		
	var next_stream = audio_queue.pop_front()
	audio_player.stream = next_stream
	audio_player.play()
