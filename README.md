# Memory Companion AI Assistant

A desktop AI companion built with Godot and Python. The system combines conversational AI, long-term memory, personality management, voice input, AI-generated soap-opera stories, and Google Calendar integration.

## Features

- 💬 AI conversation with context-aware memory
- 🧠 Dual memory system
  - Session memory for recent conversations
  - Summary memory with FAISS vector search
- 🎭 Personality management
- 🎙️ Speech-to-Text (STT)
  - Audio recording
  - Basic audio-level validation
  - Whisper large-v3 through Groq API
- 📺 Soap-opera story generation
  - Multiple story types
  - Custom preferences
  - Tone and length controls
  - Episode continuation
  - Text-to-Speech playback
- 📅 AI-assisted Google Calendar integration
- 🖥️ Godot desktop-pet interface

## System Architecture

```text
┌──────────────────────────────┐
│        Godot Frontend        │
│                              │
│  Desktop Pet / Chat / UI     │
│  Personality / Voice Input   │
│  Soap Opera Interface        │
└──────────────┬───────────────┘
               │
       Python Bridge / IPC
               │
               ▼
┌──────────────────────────────┐
│        Python Backend        │
│                              │
│  Chat Handler                │
│  Dual Memory System          │
│  Personality Manager         │
│  STT / Audio Processing      │
│  Soap Opera Generator        │
│  Calendar Agent              │
└───────┬───────────┬──────────┘
        │           │
        ▼           ▼
   OpenRouter    Groq Whisper
        │
        ▼
   LLM Services

        ┌──────────────────────┐
        │ Google Calendar API  │
        └──────────────────────┘
```

## Technologies

| Category | Technology |
|---|---|
| Frontend | Godot 4.5 |
| Backend | Python |
| AI Chat | OpenRouter |
| Main Chat Model | `z-ai/glm-4.5-air:free` |
| Story Model | `meta-llama/llama-3.3-70b-instruct:free` |
| Speech-to-Text | Whisper `large-v3` via Groq |
| Text-to-Speech | gTTS |
| Vector Search | FAISS |
| Embeddings | Sentence Transformers |
| Calendar | Google Calendar API |

## Requirements

Before starting, install:

- Git
- Python 3.11 or later
- Godot 4.5
- A working microphone for voice input
- Internet connection

The project configuration currently targets Godot 4.5 and Forward Plus. Python dependencies are listed in `requirements.txt`.

Some features require external service credentials, including OpenRouter, Groq, and Google Calendar.

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/ccuhyt/Memory-Companion-AI-Assistant.git
cd Memory-Companion-AI-Assistant
```

### 2. Create a Python virtual environment

Windows PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

If PowerShell blocks script execution, use Command Prompt:

```cmd
.venv\Scripts\activate
```

macOS / Linux:

```bash
python3 -m venv .venv
source .venv/bin/activate
```

Check the Python version:

```bash
python --version
```

### 3. Install Python dependencies

```bash
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

> `PyAudio` is used for microphone recording. Installation can depend on the operating system and Python environment.

### 4. Configure environment variables

Copy `.env.example` to `.env`.

Windows PowerShell:

```powershell
Copy-Item .env.example .env
```

macOS / Linux:

```bash
cp .env.example .env
```

Open `.env` and fill in the required values for the features you want to use:

```env
OPENROUTER_API_KEY=your_openrouter_api_key
LLM_API_KEY=your_openrouter_api_key
GROQ_API_KEY=your_groq_api_key
USER_GMAIL=your_google_calendar_email@example.com
```

The main chat code reads `LLM_API_KEY`. Story generation uses `OPENROUTER_API_KEY`, while Speech-to-Text uses `GROQ_API_KEY`.

> **Security:** Never commit `.env`, real API keys, or a real Google credential file to GitHub.

### 5. Google Calendar setup (optional)

Google Calendar integration requires additional Google Cloud configuration. The repository includes `credentials.example.json` as a template.

If you want to use the calendar feature, configure the required Google Calendar API credentials and place the required credential file in the project according to the project's calendar implementation.

Do not upload real private keys or credential files to GitHub.

## Run the Project

### 1. Open the project in Godot

Launch **Godot 4.5** and import the cloned project folder:

```text
Memory-Companion-AI-Assistant/
```

Open the project and run it.

The main scene is already configured in `project.godot`, so no scene needs to be selected manually for normal startup.

### 2. Python service startup

When the Godot project starts in the editor, `scripts/main.gd` automatically launches:

```text
python_scripts/api_server.py
```

The Flask service listens on port `5000`.

Normally, you **do not need to start this service manually**. Godot starts it as part of the project startup flow and attempts to stop the process when Godot exits.

### 3. Using the application

After the application starts:

1. Interact with the desktop pet.
2. Open the chat interface to start a conversation.
3. Use the personality manager to switch personality settings.
4. Use voice input to record speech and convert it to text.
5. Open the soap-opera feature to generate an AI story.
6. Use calendar-related functions if Google Calendar has been configured.

## Voice Input Flow

```text
Microphone
    ↓
Godot Voice Input Button
    ↓
Python Audio Recorder
    ↓
WAV recording
    ↓
Speech-to-Text request
    ↓
Groq API
    ↓
Whisper large-v3
    ↓
Recognized text
    ↓
Godot Chat Interface
```

The application performs a basic audio-level check before sending the recording for transcription.

## Memory System

The project uses a dual-memory architecture.

### Session Memory

Recent conversations are stored as short-term/session memory and can be used directly as conversation context.

### Summary Memory

Important information is consolidated into long-term memory. The project uses Sentence Transformers to generate embeddings and FAISS for vector-based similarity search.

```text
Conversation
     ↓
Session Memory
     ↓
Memory Consolidation
     ↓
Summary Memory
     ↓
Sentence Embedding
     ↓
FAISS Index
     ↓
Relevant Memory Retrieval
     ↓
LLM Context
```

## AI Conversation

The main conversation flow uses OpenRouter through the Python backend.

Current configuration:

```text
Model: z-ai/glm-4.5-air:free
Provider: OpenRouter
```

Conversation context can be combined with retrieved memory and personality settings before being sent to the language model.

## Personality Management

The project provides a personality management interface for switching the desktop pet's behavior and response style.

Related files include:

```text
scripts/PersonalityEditor.gd
scripts/PersonalityManagerUI.gd
python_scripts/personality_manager.py
python_scripts/personality_handler.py
personalities/
```

## Soap Opera Generator

The project includes an interactive AI story-generation feature.

Available story types include:

- 重生逆襲
- 真假千金
- 霸道總裁
- 婆媳大戰
- 遺產爭奪
- 出軌復仇
- 失憶梗
- 鄉土溫馨

The generator supports:

- Story type selection
- User preferences
- Tone selection
- Story length
- Episode continuation

The story generator uses OpenRouter with:

```text
meta-llama/llama-3.3-70b-instruct:free
```

## Text-to-Speech

Generated stories can be converted to speech using gTTS with Traditional Chinese (`zh-TW`) output.

## Project Structure

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

## Important Source Files

- `scripts/main.gd` — project initialization and automatic Python service startup
- `scripts/python_bridge.gd` — Godot/Python process communication
- `scripts/voice_input_button.gd` — voice recording and STT request flow
- `python_scripts/dual_memory_system.py` — dual-memory and FAISS retrieval
- `python_scripts/api_server.py` — Flask service used by the Godot application
- `python_scripts/story_generator.py` — AI soap-opera generation
- `python_scripts/ai_calendar.py` — AI-assisted Google Calendar processing

## Screenshots

Screenshots of the running application can be added here to demonstrate the main interface and features.

Recommended screenshots:

1. Desktop pet main screen
2. AI chat interface
3. Personality management interface
4. Soap-opera generation interface
5. Voice input / transcription result

## Demo

A demo video can be added here after uploading it to YouTube:

```text
[YouTube Demo](YOUR_YOUTUBE_LINK)
```

## Project Report

The project report can be linked here:

```text
[Project Report](YOUR_REPORT_LINK)
```
