import os
import datetime
import json
from dotenv import load_dotenv
from google.oauth2 import service_account
from googleapiclient.discovery import build
from openai import OpenAI  

# ================= 設定區 =================
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(current_dir)
env_path = os.path.join(parent_dir, '.env')

load_dotenv(env_path)

OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")
USER_GMAIL = os.getenv("USER_GMAIL")

# 2. 指定 OpenRouter 上的免費模型
# 推薦: "google/gemini-2.0-flash-exp:free" (目前免費且強大)
# 備用: "google/gemini-exp-1206:free" 或 "meta-llama/llama-3.3-70b-instruct:free"
MODEL_NAME = "meta-llama/llama-3.3-70b-instruct:free"

# 4. Google Calendar API 設定
SCOPES = ['https://www.googleapis.com/auth/calendar']
SERVICE_ACCOUNT_FILE = os.path.join(parent_dir, 'credentials.json')
if not os.path.exists(SERVICE_ACCOUNT_FILE):
    SERVICE_ACCOUNT_FILE = 'credentials.json'

# ================= OpenRouter 初始化 =================

client = None

def get_ai_client():
    global client
    if client is None:
        if not OPENROUTER_API_KEY:
            print("❌ 錯誤：找不到 OPENROUTER_API_KEY，請檢查 .env 檔案")
            return None
        
        client = OpenAI(
            base_url="https://openrouter.ai/api/v1",
            api_key=OPENROUTER_API_KEY,
        )
    return client

# ================= 功能區 (日曆部分不變) =================

def get_calendar_service():
    """驗證並取得日曆服務"""
    if not os.path.exists(SERVICE_ACCOUNT_FILE):
        print(f"❌ 錯誤：找不到 {SERVICE_ACCOUNT_FILE}")
        return None
    creds = service_account.Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE, scopes=SCOPES)
    return build('calendar', 'v3', credentials=creds)

def add_event_to_google(summary, start_time_str):
    """將行程加入 Google 日曆"""
    try:
        service = get_calendar_service()
        if not service: return "❌ 無法連接 Google 服務"
        
        # 解析時間
        try:
            start_dt = datetime.datetime.strptime(start_time_str, "%Y-%m-%d %H:%M")
        except ValueError:
            return f"❌ 時間格式錯誤：AI 回傳了 '{start_time_str}'"
            
        end_dt = start_dt + datetime.timedelta(hours=1)
        
        event = {
            'summary': summary,
            'start': {'dateTime': start_dt.isoformat(), 'timeZone': 'Asia/Taipei'},
            'end': {'dateTime': end_dt.isoformat(), 'timeZone': 'Asia/Taipei'},
        }

        # 這裡要做簡單的防呆，避免意外寫入範例信箱
        if "你的" in USER_GMAIL:
             return "❌ 設定錯誤：請修改 USER_GMAIL 為真實信箱！"

        service.events().insert(calendarId=USER_GMAIL, body=event).execute()
        return f"已幫你加入：【{summary}】\n時間：{start_dt.strftime('%Y-%m-%d %H:%M')}"
    except Exception as e:
        return f"❌ 發生錯誤: {str(e)}"

# ================= AI 處理區 (核心修改) =================

def ai_process_intent(user_text):
    # 1. 獲取當前時間
    now = datetime.datetime.now()
    current_time_str = now.strftime("%Y-%m-%d %H:%M (%A)") 
    
    # 2. System Prompt
    system_prompt = f"""
    現在時刻是：{current_time_str}
    你是行事曆助理。請判斷使用者輸入是否包含「時間」與「事件」。
    如果包含，請根據「現在時刻」計算出正確的「未來時間點」。
    
    規則：
    1. 如果包含明確意圖，action 填 "add_event"，並且必須同時提供 "summary" 和 "time" 欄位。
    2. 如果只是閒聊或時間不明確，action 填 "chat"。
    3. summary 欄位填入事件名稱（例如：開會、報告、面試等）。
    4. time 欄位必須嚴格轉換為 "YYYY-MM-DD HH:MM" 格式 (24小時制)。
    5. 嚴格只回傳 JSON 字串，不要包含 Markdown 標記 (如 ```json ... ```)。
    
    範例輸出格式：
    {{"action": "add_event", "summary": "報告", "time": "2025-12-12 15:00"}}
    或
    {{"action": "chat"}}
    """

    user_prompt = f"使用者輸入：{user_text}"

    try:
        # 修改：先獲取 client
        ai_client = get_ai_client()
        if not ai_client:
            return {"action": "chat", "error": "API Key missing"}

        # 使用 OpenAI SDK 格式呼叫 OpenRouter
        response = ai_client.chat.completions.create(
            model=MODEL_NAME,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            extra_headers={
                "HTTP-Referer": "https://localhost:8080", 
                "X-Title": "MyCalendarApp"
            }
        )
        
        raw_content = response.choices[0].message.content

        # 清理字串 (有些模型還是會忍不住加 Markdown)
        clean_text = raw_content.replace("```json", "").replace("```", "").strip()
        
        return json.loads(clean_text)

    except Exception as e:
        print(f"\n[Debug] OpenRouter 呼叫失敗: {e}")
        return {"action": "chat"}

def run_calendar_flow(user_input):
    """完整的日曆流程處理"""
    try:
        # 1. 先用 AI 判斷意圖
        intent = ai_process_intent(user_input)
        
        # 2. 如果只是閒聊
        if intent.get("action") != "add_event":
            return None  # 返回 None 表示這是閒聊
        
        # 3. 如果是要加行程
        summary = intent.get("summary")
        time_str = intent.get("time")
        
        if not summary or not time_str:
            return "❌ AI 解析失敗：缺少事件名稱或時間"
        
        # 4. 顯示確認訊息
        print(f"\n📅 偵測到行程：")
        print(f"   事件：{summary}")
        print(f"   時間：{time_str}")
        confirm = input("要加入日曆嗎？(y/n): ")
        
        # 5. 根據使用者確認決定是否加入
        if confirm.lower() in ['y', 'yes', '是', '好', '要']:
            return add_event_to_google(summary, time_str)
        else:
            return "❌ 已取消新增"
            
    except Exception as e:
        return f"❌ 處理失敗: {str(e)}"
      
# ================= 模擬測試區 =================

if __name__ == "__main__":
    print("輸入 'exit' 離開")
    
    while True:
        user_input = input("\n(User): ")
        if user_input.lower() == "exit":
            break  

        result = run_calendar_flow(user_input)
        # === 處理結果 ===
        if result:
            print(result)  # 如果是日曆事件，印出結果 (成功或取消)
        else:
            # 如果 result 是 None，代表是閒聊
            print("(AI 回覆): 這是閒聊模式，這裡可以接你的聊天機器人...")
