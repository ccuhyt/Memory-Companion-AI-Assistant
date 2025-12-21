extends Node
class_name PythonBridge

## Python 橋接器 - venv 在 workspace 層，腳本在專案內

var python_path = ""
var scripts_base_path = ""

signal response_received(response: Dictionary)
signal error_occurred(error: String)

func _ready():
	_setup_paths()
	_check_python_available()

func _setup_paths():
	"""設置路徑 - venv 在外層，腳本在專案內"""
	var project_root = ""
	
	if OS.has_feature("editor"):
		project_root = ProjectSettings.globalize_path("res://")
	else:
		project_root = OS.get_executable_path().get_base_dir()
	
	print("📁 Godot 專案根目錄: ", project_root)
	
	# 腳本路徑在專案內（確保沒有雙斜線）
	if project_root.ends_with("/"):
		scripts_base_path = project_root + "python_scripts/"
	else:
		scripts_base_path = project_root + "/python_scripts/"
	print("📁 Python 腳本路徑: ", scripts_base_path)
	
	# 檢查腳本目錄是否存在
	if not DirAccess.dir_exists_absolute(scripts_base_path):
		push_error("❌ 找不到 python_scripts 資料夾！")
		push_error("   預期路徑: " + scripts_base_path)
		return
	
	# workspace 根目錄（往上找，可能需要找多層）
	var workspace_root = project_root.get_base_dir()
	print("📁 Workspace 根目錄 (上一層): ", workspace_root)
	
	# 如果專案名稱在路徑中，可能需要再往上一層
	var parent_root = workspace_root
	if project_root.contains("smart-desktop-pet"):
		parent_root = workspace_root.get_base_dir()
		print("📁 父層目錄 (上兩層): ", parent_root)
	
	# 嘗試找到虛擬環境
	var venv_paths = []
	
	if OS.get_name() == "Windows":
		venv_paths = [
			# 往上兩層（文件/）
			parent_root + "/venv/Scripts/python.exe",
			parent_root + "/env/Scripts/python.exe",
			# 往上一層（smart-desktop-pet/）
			workspace_root + "/venv/Scripts/python.exe",
			workspace_root + "/env/Scripts/python.exe",
			# 專案內（最後備用）
			project_root + "/venv/Scripts/python.exe",
			project_root + "/env/Scripts/python.exe",
			# 系統 Python
			"python",
		]
	else:  # macOS/Linux
		venv_paths = [
			# 往上兩層
			parent_root + "/venv/bin/python3",
			parent_root + "/env/bin/python3",
			parent_root + "/venv/bin/python",
			parent_root + "/env/bin/python",
			# 往上一層
			workspace_root + "/venv/bin/python3",
			workspace_root + "/env/bin/python3",
			workspace_root + "/venv/bin/python",
			workspace_root + "/env/bin/python",
			# 專案內
			project_root + "/venv/bin/python3",
			project_root + "/env/bin/python3",
			project_root + "/venv/bin/python",
			project_root + "/env/bin/python",
			# 系統 Python
			"python3",
		]
	
	# 檢查哪個路徑可用
	for path in venv_paths:
		print("🔍 嘗試 Python 路徑: ", path)
		
		# 檢查文件是否存在
		if not path in ["python", "python3"]:
			if FileAccess.file_exists(path):
				print("  ✅ 文件存在，測試執行...")
				var output = []
				var exit_code = OS.execute(path, ["--version"], output, true)
				if exit_code == 0:
					python_path = path
					if path.begins_with(workspace_root) and not path.begins_with(project_root):
						print("✅ 使用外層虛擬環境: ", python_path)
					else:
						print("✅ 使用專案內虛擬環境: ", python_path)
					if output.size() > 0:
						print("   版本: ", output[0].strip_edges())
					return
				else:
					print("  ❌ 執行失敗")
			else:
				print("  ⏭️ 文件不存在")
		else:
			# 系統 Python
			var output = []
			var exit_code = OS.execute(path, ["--version"], output, true)
			if exit_code == 0:
				python_path = path
				print("⚠️ 使用系統 Python: ", python_path)
				print("   建議: 建立虛擬環境以避免依賴問題")
				if output.size() > 0:
					print("   版本: ", output[0].strip_edges())
				return
	
	# 都找不到
	push_error("❌ 無法找到可用的 Python")
	push_error("   請在 workspace 或專案中設置虛擬環境")
	python_path = "python"

func _check_python_available():
	"""檢查 Python 環境"""
	print("\n🔍 檢查 Python 環境...")
	
	var output = []
	var exit_code = OS.execute(python_path, ["--version"], output, true)
	
	if exit_code == 0:
		var version = output[0] if output.size() > 0 else "未知版本"
		print("✅ Python 可用: ", version.strip_edges())
		
		# 檢查關鍵套件
		print("\n📦 檢查 Python 套件:")
		_check_package("sentence_transformers")
		_check_package("faiss")
		_check_package("requests")
		_check_package("dotenv")
		
		# 檢查 .env 文件
		_check_env_file()
		
		# 檢查關鍵腳本
		print("\n📄 檢查 Python 腳本:")
		_check_script("chat_handler.py")
		_check_script("personality_handler.py")
		_check_script("memory_handler.py")
		_check_script("dual_memory_system.py")
		
		print("\n" + "=".repeat(50))
	else:
		print("❌ 警告: Python 不可用")
		push_warning("Python not found at: " + python_path)

func _check_package(package_name: String):
	"""檢查 Python 套件"""
	var output = []
	var args = ["-c", "import " + package_name + "; print('OK')"]
	var exit_code = OS.execute(python_path, args, output, true)
	
	if exit_code == 0:
		print("  ✅ ", package_name)
	else:
		print("  ❌ ", package_name, " (未安裝)")
		push_warning("缺少套件: " + package_name)

func _check_env_file():
	"""檢查 .env 文件"""
	print("\n🔐 檢查環境配置:")
	var env_path = ProjectSettings.globalize_path("res://") + ".env"
	if FileAccess.file_exists(env_path):
		print("  ✅ .env 文件存在")
	else:
		print("  ⚠️ .env 文件不存在")
		push_warning("請創建 .env 文件並設置 LLM_API_KEY")

func _check_script(script_name: String):
	"""檢查腳本文件"""
	var script_path = scripts_base_path + script_name
	if FileAccess.file_exists(script_path):
		print("  ✅ ", script_name)
	else:
		print("  ❌ ", script_name, " (不存在)")
		push_warning("缺少腳本: " + script_name)

func send_chat_message(user_input: String, on_success: Callable, on_error: Callable = func(_e): pass):
	var script_path = _get_script_path("chat_handler.py")
	
	if not FileAccess.file_exists(script_path):
		var error_msg = "找不到腳本: " + script_path
		print("❌ ", error_msg)
		on_error.call(error_msg)
		return
	
	var temp_file = "user://chat_response.json"
	var temp_path = ProjectSettings.globalize_path(temp_file)
	
	var args = [script_path, user_input, temp_path]
	print("💬 發送訊息: ", user_input)
	
	_execute_python_async(args, func(result):
		_read_result_file(temp_path, on_success, on_error)
	, on_error)

func get_personalities(on_success: Callable, on_error: Callable = func(_e): pass):
	"""獲取個性列表 - 使用文件傳輸"""
	var script_path = _get_script_path("personality_handler.py")
	var temp_file = "user://personalities.json"
	var temp_path = ProjectSettings.globalize_path(temp_file)
	
	var args = [script_path, "--action", "list", "--output", temp_path]
	print("🎭 獲取個性列表...")
	
	_execute_python_async(args, func(result):
		# Python 執行成功，讀取文件
		_read_result_file(temp_path, func(data):
			if data is Dictionary and data.has("personalities"):
				print("✅ 成功獲取 ", data["personalities"].size(), " 個個性")
				on_success.call(data)
			else:
				on_error.call("個性列表格式錯誤")
		, on_error)
	, on_error)

func switch_personality(name: String, on_success: Callable, on_error: Callable = func(_e): pass):
	"""切換個性 - 使用文件傳輸"""
	var script_path = _get_script_path("personality_handler.py")
	var temp_file = "user://personality_switch.json"
	var temp_path = ProjectSettings.globalize_path(temp_file)
	
	var args = [script_path, "--action", "switch", "--name", name, "--output", temp_path]
	print("🎭 切換個性: ", name)
	
	_execute_python_async(args, func(result):
		_read_result_file(temp_path, func(data):
			if data is Dictionary and data.get("success", false):
				print("✅ 切換個性成功")
				on_success.call(data)
			else:
				on_error.call("切換個性失敗")
		, on_error)
	, on_error)

func get_current_personality(on_success: Callable, on_error: Callable = func(_e): pass):
	"""獲取當前個性 - 使用文件傳輸"""
	var script_path = _get_script_path("personality_handler.py")
	var temp_file = "user://current_personality.json"
	var temp_path = ProjectSettings.globalize_path(temp_file)
	
	var args = [script_path, "--action", "current", "--output", temp_path]
	
	_execute_python_async(args, func(result):
		_read_result_file(temp_path, on_success, on_error)
	, on_error)

func get_memory_stats(on_success: Callable, on_error: Callable = func(_e): pass):
	"""獲取記憶統計 - 使用文件傳輸"""
	var script_path = _get_script_path("memory_handler.py")
	var temp_file = "user://memory_stats.json"
	var temp_path = ProjectSettings.globalize_path(temp_file)
	
	var args = [script_path, "--action", "stats", "--output", temp_path]
	
	_execute_python_async(args, func(result):
		_read_result_file(temp_path, on_success, on_error)
	, on_error)

func clear_session_memory(on_success: Callable, on_error: Callable = func(_e): pass):
	"""清空記憶 - 使用文件傳輸"""
	var script_path = _get_script_path("memory_handler.py")
	var temp_file = "user://memory_clear.json"
	var temp_path = ProjectSettings.globalize_path(temp_file)
	
	var args = [script_path, "--action", "clear", "--output", temp_path]
	
	_execute_python_async(args, func(result):
		_read_result_file(temp_path, on_success, on_error)
	, on_error)

func end_session(on_success: Callable, on_error: Callable = func(_e): pass):
	"""結束會話 - 使用文件傳輸"""
	var script_path = _get_script_path("memory_handler.py")
	var temp_file = "user://session_end.json"
	var temp_path = ProjectSettings.globalize_path(temp_file)
	
	var args = [script_path, "--action", "end", "--output", temp_path]
	
	_execute_python_async(args, func(result):
		_read_result_file(temp_path, on_success, on_error)
	, on_error)

func search_memories(query: String, on_success: Callable, on_error: Callable = func(_e): pass):
	"""搜尋記憶 - 使用文件傳輸"""
	var script_path = _get_script_path("memory_handler.py")
	var temp_file = "user://memory_search.json"
	var temp_path = ProjectSettings.globalize_path(temp_file)
	
	var args = [script_path, "--action", "search", "--query", query, "--output", temp_path]
	
	_execute_python_async(args, func(result):
		_read_result_file(temp_path, on_success, on_error)
	, on_error)

func _execute_python_async(args: Array, on_success: Callable, on_error: Callable):
	var thread = Thread.new()
	var callable = func():
		_execute_python_in_thread(args, on_success, on_error)
	thread.start(callable)

func _execute_python_in_thread(args: Array, on_success: Callable, on_error: Callable):
	var output = []
	var exit_code = OS.execute(python_path, args, output, true, false)
	call_deferred("_handle_python_result", exit_code, output, on_success, on_error)

func _handle_python_result(exit_code: int, output: Array, on_success: Callable, on_error: Callable):
	if exit_code != 0:
		var error_msg = "Python 執行失敗 (exit code: " + str(exit_code) + ")"
		if output.size() > 0:
			error_msg += "\n輸出: " + str(output[0])
		print("❌ ", error_msg)
		on_error.call(error_msg)
		return
	
	if output.size() == 0:
		print("❌ Python 無輸出")
		on_error.call("Python 無輸出")
		return
	
	var output_text = str(output[0]).strip_edges()
	print("📄 Python 狀態: ", output_text.substr(0, 100))
	
	var json = JSON.new()
	var parse_result = json.parse(output_text)
	
	if parse_result != OK:
		print("❌ JSON 解析失敗: ", json.get_error_message())
		on_error.call("JSON 解析失敗: " + json.get_error_message())
		return
	
	var data = json.data
	
	if data is Dictionary and data.has("status") and data["status"] == "ok":
		print("✅ Python 執行成功")
		on_success.call(data)
	else:
		print("❌ Python 返回錯誤")
		on_error.call("Python 返回錯誤")

func _read_result_file(file_path: String, on_success: Callable, on_error: Callable):
	"""讀取 Python 寫入的結果文件"""
	if not FileAccess.file_exists(file_path):
		print("❌ 結果文件不存在: ", file_path)
		on_error.call("結果文件不存在")
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("❌ 無法打開結果文件")
		on_error.call("無法打開結果文件")
		return
	
	var content = file.get_as_text()
	file.close()
	
	# 顯示前 200 個字符用於調試
	print("📄 讀取回應 (前200字): ", content.substr(0, 200))
	
	var json = JSON.new()
	var parse_result = json.parse(content)
	
	if parse_result != OK:
		print("❌ JSON 解析失敗: ", json.get_error_message())
		print("   原始內容: ", content.substr(0, 500))
		on_error.call("JSON 解析失敗: " + json.get_error_message())
		return
	
	var data = json.data
	
	if data is Dictionary:
		# 檢查是聊天回應還是其他操作
		if data.has("response"):
			# 聊天回應
			if data.get("success", false):
				print("✅ 成功獲取聊天回應")
				on_success.call(data.get("response", ""))
			else:
				var error = data.get("error", "未知錯誤")
				print("❌ 聊天操作失敗: ", error)
				on_error.call(error)
		else:
			# 其他操作（個性、記憶等）
			if data.get("success", false):
				print("✅ 操作成功")
				on_success.call(data)
			else:
				var error = data.get("error", "未知錯誤")
				print("❌ 操作失敗: ", error)
				on_error.call(error)
	else:
		print("❌ 返回格式錯誤，期望 Dictionary，得到: ", typeof(data))
		on_error.call("返回格式錯誤")

func _get_script_path(script_name: String) -> String:
	return scripts_base_path + script_name

func execute_python_sync(script_name: String, args: Array = []) -> Dictionary:
	var script_path = _get_script_path(script_name)
	var full_args = [script_path] + args
	var output = []
	var exit_code = OS.execute(python_path, full_args, output, true, false)
	
	if exit_code != 0:
		return {"error": "執行失敗", "exit_code": exit_code}
	
	if output.size() == 0:
		return {"error": "無輸出"}
	
	var output_text = str(output[0]).strip_edges()
	
	var json = JSON.new()
	var parse_result = json.parse(output_text)
	
	if parse_result != OK:
		return {"error": "JSON 解析失敗", "raw": output_text.substr(0, 200)}
	
	return json.data

func set_python_path(path: String):
	"""手動設置 Python 路徑"""
	python_path = path
	print("🔧 Python 路徑已設定為: ", python_path)

func get_python_path() -> String:
	return python_path

func get_scripts_path() -> String:
	return scripts_base_path

func test_connection() -> bool:
	var output = []
	var exit_code = OS.execute(python_path, ["--version"], output, true)
	return exit_code == 0

func create_personality(personality_data: Dictionary, on_success: Callable, on_error: Callable = func(_e): pass):
	"""創建自訂個性 - 使用文件傳輸"""
	var script_path = _get_script_path("personality_handler.py")
	var temp_file = "user://personality_create.json"
	var temp_path = ProjectSettings.globalize_path(temp_file)
	
	# 🔧 關鍵修復：先將數據寫入臨時文件，讓 Python 讀取
	var data_temp_file = "user://personality_data.json"
	var data_temp_path = ProjectSettings.globalize_path(data_temp_file)
	
	# 將個性數據寫入文件
	var data_file = FileAccess.open(data_temp_path, FileAccess.WRITE)
	if data_file == null:
		print("❌ 無法創建數據文件")
		on_error.call("無法創建數據文件")
		return
	
	data_file.store_string(JSON.stringify(personality_data))
	data_file.close()
	
	print("✨ 創建個性: ", personality_data.get("display_name", ""))
	print("📝 數據已寫入: ", data_temp_path)
	
	# 使用文件路徑而不是 JSON 字符串
	var args = [
		script_path, 
		"--action", "create",
		"--data", "@" + data_temp_path,  # @ 前綴表示這是文件路徑
		"--output", temp_path
	]
	
	_execute_python_async(args, func(result):
		_read_result_file(temp_path, func(data):
			if data is Dictionary and data.get("success", false):
				print("✅ 創建個性成功")
				on_success.call(data)
			else:
				var error = data.get("error", "創建個性失敗")
				on_error.call(error)
		, on_error)
	, on_error)

func update_personality(personality_data: Dictionary, on_success: Callable, on_error: Callable = func(_e): pass):
	"""🆕 更新現有個性 - 使用文件傳輸"""
	var script_path = _get_script_path("personality_handler.py")
	var temp_file = "user://personality_update.json"
	var temp_path = ProjectSettings.globalize_path(temp_file)
	
	# 先將數據寫入臨時文件
	var data_temp_file = "user://personality_data_update.json"
	var data_temp_path = ProjectSettings.globalize_path(data_temp_file)
	
	var data_file = FileAccess.open(data_temp_path, FileAccess.WRITE)
	if data_file == null:
		print("❌ 無法創建數據文件")
		on_error.call("無法創建數據文件")
		return
	
	data_file.store_string(JSON.stringify(personality_data))
	data_file.close()
	
	print("✏️ 更新個性: ", personality_data.get("display_name", ""))
	print("📝 數據已寫入: ", data_temp_path)
	
	var args = [
		script_path, 
		"--action", "update",
		"--data", "@" + data_temp_path,
		"--output", temp_path
	]
	
	_execute_python_async(args, func(result):
		_read_result_file(temp_path, func(data):
			if data is Dictionary and data.get("success", false):
				print("✅ 更新個性成功")
				on_success.call(data)
			else:
				var error = data.get("error", "更新個性失敗")
				on_error.call(error)
		, on_error)
	, on_error)

func delete_personality(personality_name: String, on_success: Callable, on_error: Callable = func(_e): pass):
	"""刪除個性 - 使用文件傳輸"""
	var script_path = _get_script_path("personality_handler.py")
	var temp_file = "user://personality_delete.json"
	var temp_path = ProjectSettings.globalize_path(temp_file)
	
	var args = [
		script_path,
		"--action", "delete",
		"--name", personality_name,
		"--output", temp_path
	]
	print("🗑️ 刪除個性: ", personality_name)
	
	_execute_python_async(args, func(result):
		_read_result_file(temp_path, func(data):
			if data is Dictionary and data.get("success", false):
				print("✅ 刪除個性成功")
				on_success.call(data)
			else:
				on_error.call("刪除個性失敗")
		, on_error)
	, on_error)
