from flask import Flask, request, jsonify, Response, stream_with_context
from flask_cors import CORS
from story_generator import SoapOperaGenerator
import os
from dotenv import load_dotenv
import json
import wave
import audioop
from groq import Groq
from fastapi import UploadFile, File, Form



# 載入環境變數
load_dotenv()

app = Flask(__name__)
CORS(app) # 允許跨域請求

# 初始化故事生成器
generator = SoapOperaGenerator()

# ============================================
# API 端點
# ============================================

@app.route('/api/health', methods=['GET'])
def health_check():
    """健康檢查"""
    return jsonify({"status": "ok", "message": "伺服器運作中"})

@app.route('/api/story_types', methods=['GET'])
def get_story_types():
    """取得所有故事類型"""
    types = generator.get_story_types()
    return jsonify({"types": types})

@app.route('/api/suggestions', methods=['GET'])
def get_suggestions():
    """取得靈感建議"""
    suggestions = generator.get_random_suggestions()
    return jsonify({"suggestions": suggestions})

@app.route('/api/generate', methods=['POST'])
def generate_story():
    """生成故事 (串流模式)"""
    data = request.json
    story_type = data.get('story_type', '重生逆襲')
    user_preference = data.get('user_preference', '請自由發揮')
    tone = data.get('tone', '狗血')
    length = data.get('length', 'medium')

    def generate():
        try:
            # 呼叫生成器，這裡會回傳 generator (yield)
            for chunk in generator.generate_story(
                    story_type=story_type,
                    user_preference=user_preference,
                    length=length,
                    tone=tone
            ):
                # 包裝成 SSE (Server-Sent Events) 格式
                yield f"data: {json.dumps({'text': chunk})}\n\n"
            
            # 結束訊號
            yield f"data: {json.dumps({'done': True})}\n\n"

        except Exception as e:
            # 錯誤處理
            yield f"data: {json.dumps({'error': str(e)})}\n\n"

    # 使用 stream_with_context 確保串流不中斷
    return Response(stream_with_context(generate()), mimetype='text/event-stream')

@app.route('/api/sequel', methods=['POST'])
def generate_sequel():
    """生成續集 (串流模式)"""
    data = request.json
    prev_story = data.get('prev_story', '')
    episode_no = data.get('episode_no', 2)
    max_episodes = data.get('max_episodes', 4)
    direction = data.get('direction', '繼續發展')

    def generate():
        try:
            for chunk in generator.generate_sequel(
                prev_story=prev_story,
                episode_no=episode_no,
                max_episodes=max_episodes,
                direction=direction
            ):
                yield f"data: {json.dumps({'text': chunk})}\n\n"
            yield f"data: {json.dumps({'done': True})}\n\n"
        except Exception as e:
            yield f"data: {json.dumps({'error': str(e)})}\n\n"

    return Response(stream_with_context(generate()), mimetype='text/event-stream')

@app.route('/api/tts', methods=['POST'])
def text_to_speech():
    """文字轉語音 (使用 Google TTS)"""
    data = request.json
    text = data.get('text', '')
    
    if not text:
        return jsonify({"error": "沒有文字"}), 400

    try:
        from gtts import gTTS
        import io
        
        # 生成中文語音
        tts = gTTS(text=text, lang='zh-TW', slow=False)
        
        # 寫入記憶體（不需要建立暫存檔）
        audio_fp = io.BytesIO()
        tts.write_to_fp(audio_fp)
        audio_fp.seek(0)
        
        return Response(audio_fp.read(), mimetype='audio/mpeg')
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/tts_quick', methods=['POST'])
def tts_quick():
    """快速語音生成 (優化版)"""
    data = request.json
    text = data.get('text', '')

    if not text:
        return jsonify({"error": "No text"}), 400

    try:
        from gtts import gTTS
        import io

        # 建立記憶體內的檔案，不存硬碟
        fp = io.BytesIO()
        # gTTS 速度瓶頸在於連線 Google，這裡無法再優化，只能靠分段來讓體感變快
        tts = gTTS(text=text, lang='zh-TW')
        tts.write_to_fp(fp)
        fp.seek(0)

        return Response(fp.read(), mimetype='audio/mpeg')
    except Exception as e:
        print(f"TTS Error: {e}")
        return jsonify({"error": str(e)}), 500

def transcribe_audio(audio_file_path, language="zh"):
    """語音轉文字功能"""
    if not os.path.exists(audio_file_path):
        return "錯誤: 找不到音頻檔案"

    try:
        with wave.open(audio_file_path, 'rb') as wf:
            frames = wf.readframes(wf.getnframes())
            rms = audioop.rms(frames, 2)
            if rms < 300:
                return "[無有效語音]"
    except:
        pass

    api_key = os.getenv("GROQ_API_KEY")
    client = Groq(api_key=api_key)

    with open(audio_file_path, "rb") as audio_file:
        audio_data = audio_file.read()
        params = {
            "file": (os.path.basename(audio_file_path), audio_data),
            "model": "whisper-large-v3",
            "response_format": "text",
            "temperature": 0.0,
        }
        if language != "auto":
            params["language"] = language

        transcription = client.audio.transcriptions.create(**params)

    return str(transcription).strip()


@app.route('/api/stt', methods=['POST'])
def stt_api():
    """語音轉文字 API"""
    # Flask 用 request.files 來接收檔案
    if 'file' not in request.files:
        return jsonify({"error": "沒有上傳檔案"}), 400

    file = request.files['file']
    language = request.form.get('language', 'zh')

    # 儲存暫存檔
    temp_path = "temp.wav"
    file.save(temp_path)

    # 轉錄
    result = transcribe_audio(temp_path, language)

    # 刪除暫存檔
    if os.path.exists(temp_path):
        os.remove(temp_path)

    return jsonify({"text": result})


# ============================================
# 啟動伺服器
# ============================================

if __name__ == '__main__':
    print("\n" + "=" * 70)
    print("🚀 故事生成 API 伺服器啟動中...")
    print("=" * 70)
    print("\n📡 伺服器位址: http://localhost:5000")
    print("\n可用端點:")
    print("  GET  /api/health           - 健康檢查")
    print("  GET  /api/story_types      - 取得故事類型")
    print("  GET  /api/suggestions      - 取得故事建議")
    print("  POST /api/generate         - 生成故事 (串流)")
    print("  POST /api/sequel           - 生成續集 (串流)")
    print("  POST /api/tts              - 文字轉語音")
    print("  POST /api/tts_quick        - 文字轉語音 (快速版) ⚡")
    print("\n" + "=" * 70)
    print("按 Ctrl+C 停止伺服器\n")
    # threaded=True 對於串流非常重要，避免單一請求卡死伺服器
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)