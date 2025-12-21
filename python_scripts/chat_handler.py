#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
對話處理器
修正：移除所有 stdout 中文輸出
"""

import sys
import json
import os
import logging
from datetime import datetime
from dotenv import load_dotenv
try:
    import ai_calendar
except ImportError:
    logging.warning("找不到 ai_calendar.py，將無法使用日曆功能")
    ai_calendar = None

# 禁用所有標準輸出（避免編碼問題）
class SilentOutput:
    def write(self, *args, **kwargs):
        pass
    def flush(self):
        pass

# 暫時禁用輸出
_original_stdout = sys.stdout
_original_stderr = sys.stderr
sys.stdout = SilentOutput()
sys.stderr = SilentOutput()

# 載入環境變數
load_dotenv()

# 設置日誌（寫入文件）
log_dir = "logs"
os.makedirs(log_dir, exist_ok=True)
log_file = os.path.join(log_dir, f"chat_{datetime.now().strftime('%Y%m%d')}.log")

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(log_file, encoding='utf-8'),
    ]
)
logger = logging.getLogger(__name__)

# 導入模組
try:
    from dual_memory_system import DualMemorySystem
    from personality_manager import PersonalityManager
except ImportError as e:
    sys.path.append(os.path.dirname(os.path.dirname(__file__)))
    from dual_memory_system import DualMemorySystem
    from personality_manager import PersonalityManager

# 全局單例
_memory_system = None
_personality_manager = None

def get_memory_system():
    global _memory_system
    if _memory_system is None:
        _memory_system = DualMemorySystem()
    return _memory_system

PENDING_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pending_event.json")

def save_pending_event(summary, time_str):
    """儲存待確認的行程"""
    try:
        with open(PENDING_FILE, 'w', encoding='utf-8') as f:
            json.dump({
                "summary": summary,
                "time": time_str,
                "timestamp": datetime.now().timestamp()
            }, f)
        return True
    except Exception as e:
        logger.error(f"儲存暫存檔失敗: {e}")
        return False

def load_and_clear_pending_event():
    """讀取並清除待確認的行程"""
    if not os.path.exists(PENDING_FILE):
        return None
    
    try:
        with open(PENDING_FILE, 'r', encoding='utf-8') as f:
            data = json.load(f)
        # 讀取後刪除檔案，避免重複觸發
        os.remove(PENDING_FILE)
        return data
    except Exception as e:
        logger.error(f"讀取暫存檔失敗: {e}")
        return None
    
def get_personality_manager():
    global _personality_manager
    if _personality_manager is None:
        _personality_manager = PersonalityManager()
    return _personality_manager

def call_llm_sync(context: str) -> dict:
    """同步調用 LLM"""
    import requests
    
    API_KEY = os.getenv("LLM_API_KEY")
    if not API_KEY:
        logger.error("LLM_API_KEY not set")
        return {"success": False, "error": "LLM_API_KEY not set"}
    
    url = "https://openrouter.ai/api/v1/chat/completions"
    
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "HTTP-Referer": "https://github.com/desktop-pet/app",
        "X-Title": "Smart Desktop Pet",
        "Content-Type": "application/json"
    }
    
    models = ["z-ai/glm-4.5-air:free"]
    last_error = None
    
    for model in models:
        data = {
            "model": model,
            "messages": [{"role": "user", "content": context}],
            "max_tokens": 500
        }
        
        try:
            logger.info(f"Trying model: {model}")
            resp = requests.post(url, headers=headers, json=data, timeout=30)
            
            if resp.status_code == 200:
                response_text = resp.json()["choices"][0]["message"]["content"]
                logger.info(f"Success with model: {model}")
                return {"success": True, "response": response_text}
            else:
                try:
                    error_data = resp.json()
                    error_msg = error_data.get("error", {}).get("message", "Unknown error")
                    last_error = f"{resp.status_code}: {error_msg}"
                    logger.warning(f"Model {model} failed: {last_error}")
                except:
                    last_error = f"{resp.status_code}: {resp.text[:100]}"
                    logger.warning(f"Model {model} failed")
                
                if resp.status_code != 429:
                    return {"success": False, "error": last_error}
                continue
        
        except requests.exceptions.Timeout:
            last_error = "Request timeout"
            logger.warning(f"Model {model} timeout")
            continue
        except requests.exceptions.RequestException as e:
            last_error = f"Network error: {str(e)}"
            logger.warning(f"Model {model} network error: {e}")
            continue
        except Exception as e:
            last_error = f"Unknown error: {str(e)}"
            logger.error(f"Model {model} unknown error: {e}")
            continue
    
    error_msg = f"All models failed. Last error: {last_error}"
    logger.error(error_msg)
    return {"success": False, "error": error_msg}

def handle_chat(user_input: str) -> dict:
    """處理對話請求"""
    try:
        logger.info(f"Message received: {user_input[:50]}...")
        
        memory_system = get_memory_system()
        personality_manager = get_personality_manager()
        
        # 1. 先檢查是否有「待確認」的行程
        pending_event = load_and_clear_pending_event()
        
        if pending_event:
            # 判斷使用者的回答是否為「同意」
            # 這裡做簡單的關鍵字判斷
            agree_keywords = ["好", "是", "ok", "yes", "確認", "沒錯", "可以"]
            if any(k in user_input.lower() for k in agree_keywords):
                # === 使用者同意，執行加入 ===
                if ai_calendar:
                    result_msg = ai_calendar.add_event_to_google(
                        pending_event["summary"], 
                        pending_event["time"]
                    )
                    # 記錄到記憶
                    memory_system.add_dialogue(user_input, result_msg)
                    return {"success": True, "response": result_msg}
                else:
                    return {"success": True, "response": "❌ 發生錯誤：找不到日曆模組。"}
            else:
                # === 使用者不同意或是說別的 ===
                # 取消該行程，並將使用者的話當作普通聊天繼續往下處理
                cancel_msg = "已取消加入行事曆。"
                # 這裡可以選擇直接回傳取消，或者讓它繼續跟 LLM 聊天
                # 為了體驗好，我們把「已取消」加到 User input 前面，讓 LLM 知道發生什麼事
                user_input = f"(使用者取消了行程) {user_input}"

        # 2. 日曆意圖偵測 (原本的邏輯，但改為不直接執行)
        if ai_calendar:
            try:
                intent = ai_calendar.ai_process_intent(user_input)
                
                if intent.get("action") == "add_event":
                    summary = intent.get("summary")
                    time_str = intent.get("time")
                    
                    # === 修改點：不執行 add_event_to_google，改為儲存並詢問 ===
                    save_pending_event(summary, time_str)
                    
                    confirm_msg = f"是否要幫您新增行程：\n【{summary}】\n時間：{time_str}\n\n請問要加入 google 日曆嗎？(是/否)"
                    
                    # 這裡不寫入長期記憶，避免汙染對話歷史
                    return {"success": True, "response": confirm_msg}
            except Exception as cal_error:
                logger.error(f"日曆處理發生錯誤 (降級為普通聊天): {cal_error}")
                # 如果日曆出錯，不要讓程式掛掉，繼續往下走原本的聊天邏輯

        # 構建上下文
        # 記錄當前個性
        current = personality_manager.get_current_personality()
        if current:
            logger.info(f"Using personality: {current.display_name}")
        
        personality_prompt = personality_manager.get_system_prompt()
        context = memory_system.build_context_for_llm(user_input, personality_prompt)
        
        result = call_llm_sync(context)
        
        if result["success"]:
            memory_system.add_dialogue(user_input, result["response"])
            logger.info("Dialogue recorded")
        
        return result
    
    except Exception as e:
        logger.error(f"Error handling chat: {e}", exc_info=True)
        return {
            "success": False,
            "error": f"Error: {str(e)}"
        }

def main():
    """主函數"""
    logger.info("=== chat_handler started ===")
    
    if len(sys.argv) < 3:
        result = {"success": False, "error": "Missing arguments"}
        logger.error("Missing arguments")
        
        # 恢復 stdout
        sys.stdout = _original_stdout
        print(json.dumps(result, ensure_ascii=True))
        sys.stdout.flush()
        return
    
    user_input = sys.argv[1]
    output_file = sys.argv[2]
    
    result = handle_chat(user_input)
    
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(result, f, ensure_ascii=False, indent=2)
        
        logger.info("Result written to file")
        
        # 恢復 stdout 並輸出（純 ASCII）
        sys.stdout = _original_stdout
        print(json.dumps({"status": "ok"}, ensure_ascii=True))
        sys.stdout.flush()
        
    except Exception as e:
        logger.error(f"Write file failed: {e}", exc_info=True)
        
        # 恢復 stdout
        sys.stdout = _original_stdout
        error_result = {"status": "error", "message": str(e)}
        print(json.dumps(error_result, ensure_ascii=True))
        sys.stdout.flush()
    
    logger.info("=== chat_handler finished ===\n")

if __name__ == "__main__":
    main()