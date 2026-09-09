# Memory Companion AI Assistant

一個以 **Godot + Python** 開發的桌面 AI 陪伴系統，整合 AI 對話、雙層記憶、個性管理、語音輸入、AI 八點檔故事生成，以及 Google Calendar 等功能。

## 功能特色

- 💬 AI 對話
- 🧠 雙層記憶系統
  - Session Memory：保存近期對話
  - Summary Memory：整理長期資訊，並使用 FAISS 進行向量搜尋
- 🎭 個性管理
- 🎙️ 語音輸入 / 語音轉文字（STT）
  - 錄製語音
  - 基本音量檢查
  - 使用 Groq API + Whisper large-v3 進行語音辨識
- 📺 AI 八點檔故事生成
  - 多種故事類型
  - 自訂偏好
  - 風格與長度設定
  - 劇情續寫
  - 文字轉語音
- 📅 AI 輔助 Google Calendar
- 🖥️ Godot 桌面寵物介面

## 系統架構

<img width="1386" height="657" alt="image" src="https://github.com/user-attachments/assets/d855bef3-c8b6-4508-9a3b-33bb429e42bc" />


## 使用技術

| 類別 | 技術 |
|---|---|
| 前端 | Godot 4.5 |
| 後端 | Python |
| AI 對話 | OpenRouter |
| 主要對話模型 | `z-ai/glm-4.5-air:free` |
| 故事生成模型 | `meta-llama/llama-3.3-70b-instruct:free` |
| 語音轉文字 | Groq API + Whisper `large-v3` |
| 文字轉語音 | gTTS |
| 向量搜尋 | FAISS |
| 文字嵌入 | Sentence Transformers |
| 行事曆 | Google Calendar API |

## 環境需求

開始之前需要準備：

- Git
- Python 3.11 以上
- Godot 4.5
- 麥克風（使用語音輸入功能時需要）
- 網路連線

本專案的 Godot 專案設定為 **Godot 4.5 / Forward Plus**。Python 套件則整理於 `requirements.txt`。

部分功能需要外部服務的 API 金鑰，例如 OpenRouter、Groq，以及 Google Calendar。

## 安裝方式

### 1. Clone 專案

```bash
git clone https://github.com/ccuhyt/Memory-Companion-AI-Assistant.git
cd Memory-Companion-AI-Assistant
```

### 2. 建立 Python 虛擬環境

Windows PowerShell：

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

如果 PowerShell 不允許執行啟用指令，也可以使用命令提示字元：

```cmd
.venv\Scripts\activate
```

macOS / Linux：

```bash
python3 -m venv .venv
source .venv/bin/activate
```

確認 Python 版本：

```bash
python --version
```

### 3. 安裝 Python 套件

```bash
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

> `PyAudio` 用於麥克風錄音，實際安裝方式可能會依作業系統與 Python 環境有所不同。

### 4. 設定環境變數

將 `.env.example` 複製成 `.env`。

Windows PowerShell：

```powershell
Copy-Item .env.example .env
```

macOS / Linux：

```bash
cp .env.example .env
```

接著開啟 `.env`，填入需要使用的服務資訊：

```env
OPENROUTER_API_KEY=你的_OpenRouter_API_Key
LLM_API_KEY=你的_OpenRouter_API_Key
GROQ_API_KEY=你的_Groq_API_Key
USER_GMAIL=你的_Google_Calendar_帳號
```

目前程式中：

- `LLM_API_KEY`：主要 AI 對話使用
- `OPENROUTER_API_KEY`：八點檔故事生成及相關功能使用
- `GROQ_API_KEY`：語音轉文字使用
- `USER_GMAIL`：Google Calendar 相關功能使用

如果 OpenRouter 使用同一組 API Key，可以將相同的 Key 填入 `OPENROUTER_API_KEY` 與 `LLM_API_KEY`。

> **重要：** 不要把真正的 `.env`、API Key 或私人 Google 憑證上傳到 GitHub。

### 5. Google Calendar 設定（選用）

如果要使用 Google Calendar 功能，除了 `.env` 之外，還需要依照 Google Calendar API 的設定方式準備 Google Cloud 憑證。

專案內提供：

```text
credentials.example.json
```

作為範例檔案。

目前程式的 Calendar 實作會讀取專案根目錄中的 `credentials.json`。因此，如果要啟用 Calendar 功能，需要準備自己的 `credentials.json`。

**注意：** `credentials.json` 若包含真實私人憑證，不能提交到 GitHub。專案只保留範例檔案 `credentials.example.json`。

## 執行專案

### 1. 使用 Godot 開啟

啟動 **Godot 4.5**，匯入 Clone 下來的專案資料夾：

```text
Memory-Companion-AI-Assistant/
```

開啟專案後直接執行即可。

`project.godot` 已經設定好主要場景，因此一般情況下不需要另外選擇場景。

### 2. Python Server 會自動啟動

執行 Godot 專案時，`scripts/main.gd` 會自動啟動：

```text
python_scripts/api_server.py
```

Flask Server 預設使用：

```text
http://127.0.0.1:5000
```

因此一般使用情況下，**不需要另外手動開啟 Python Server**。

Godot 啟動專案時會自動建立 Python Server 程序，離開 Godot 時也會嘗試停止該程序。

### 3. 開始使用

啟動後可以：

1. 與桌面寵物互動
2. 開啟對話介面與 AI 聊天
3. 使用人格管理功能調整人格設定
4. 使用語音輸入將語音轉成文字
5. 開啟八點檔功能生成 AI 故事
6. 若已完成 Google Calendar 設定，可使用相關行事曆功能

## 語音輸入流程

```text
麥克風
   ↓
Godot 語音輸入按鈕
   ↓
Python 錄音程式
   ↓
WAV 錄音檔
   ↓
語音轉文字請求
   ↓
Groq API
   ↓
Whisper large-v3
   ↓
辨識文字
   ↓
Godot 對話介面
```

程式在送出語音辨識前，會先進行基本的音訊音量檢查。

## 雙層記憶系統

本專案使用雙層記憶架構。

### Session Memory

保存近期對話內容，作為短期記憶與目前對話的 Context。

### Summary Memory

將重要資訊整理成長期記憶，並透過 Sentence Transformers 產生向量，再使用 FAISS 進行相似度搜尋，以找出與目前對話相關的記憶。

```text
對話
 ↓
Session Memory
 ↓
記憶整理
 ↓
Summary Memory
 ↓
Sentence Embedding
 ↓
FAISS Index
 ↓
相關記憶搜尋
 ↓
LLM Context
```

## AI 對話

主要對話功能透過 Python 後端連接 OpenRouter。

目前主要模型：

```text
模型：z-ai/glm-4.5-air:free
服務：OpenRouter
```

系統可以將目前對話、相關記憶以及人格設定組合後，再提供給語言模型產生回應。

## 人格管理

專案提供人格管理介面，可以調整桌面寵物的回應方式與人格設定。

相關程式包含：

```text
scripts/PersonalityEditor.gd
scripts/PersonalityManagerUI.gd
python_scripts/personality_manager.py
python_scripts/personality_handler.py
personalities/
```

## AI 八點檔故事生成

專案提供互動式 AI 故事生成功能。

目前包含以下故事類型：

- 重生逆襲
- 真假千金
- 霸道總裁
- 婆媳大戰
- 遺產爭奪
- 出軌復仇
- 失憶梗
- 鄉土溫馨

支援：

- 故事類型選擇
- 使用者偏好
- 語氣設定
- 故事長度
- 劇情續寫

故事生成使用 OpenRouter，模型為：

```text
meta-llama/llama-3.3-70b-instruct:free
```

## 文字轉語音

生成的故事可以透過 gTTS 轉換成語音，使用繁體中文（`zh-TW`）輸出。

## 專案結構

```text
Memory-Companion-AI-Assistant/
│
├── assets/
│   └── animations/
├── audio/
├── novel-generator/
│   └── soap-opera-app/
├── personalities/
├── python_scripts/
│   ├── ai_calendar.py
│   ├── api_server.py
│   ├── calendar_handler.py
│   ├── calendar_system.py
│   ├── chat_handler.py
│   ├── dual_memory_system.py
│   ├── llm_api.py
│   ├── memory_handler.py
│   ├── personality_handler.py
│   ├── personality_manager.py
│   ├── record_audio.py
│   ├── story_generator.py
│   ├── transcribe.py
│   └── ...
├── scenes/
├── scripts/
│   ├── PersonalityEditor.gd
│   ├── PersonalityManagerUI.gd
│   ├── SavingOverlay.gd
│   ├── chat_dialog.gd
│   ├── desktop_pet.gd
│   ├── main.gd
│   ├── python_bridge.gd
│   └── voice_input_button.gd
├── .env.example
├── credentials.example.json
├── project.godot
├── requirements.txt
└── README.md
```

## 重要程式檔案

- `scripts/main.gd` — 專案初始化，以及自動啟動 Python Server
- `scripts/python_bridge.gd` — Godot 與 Python 程序之間的溝通
- `scripts/voice_input_button.gd` — 語音錄製與 STT 請求流程
- `python_scripts/dual_memory_system.py` — 雙層記憶與 FAISS 搜尋
- `python_scripts/api_server.py` — Godot 使用的 Flask Server
- `python_scripts/story_generator.py` — AI 八點檔故事生成
- `python_scripts/ai_calendar.py` — AI 輔助 Google Calendar 功能

## 畫面展示

這裡可以放入實際執行畫面的截圖，展示專案的主要功能。

建議放：

1. 桌面寵物主畫面
2. AI 對話介面
3. 人格管理介面
4. 八點檔故事生成介面
5. 語音輸入 / 語音辨識結果

> README 建議以「實際執行畫面」為主，不需要貼大量程式碼。重要程式則透過上面的 GitHub 檔案連結讓讀者查看即可。

## Demo

Demo 影片上傳 YouTube 後，可以放在這裡：

```text
[YouTube Demo](你的 YouTube 連結)
```

## 專題報告

可以在這裡放上完整專題報告：

```text
[專題報告](你的報告連結)
```
