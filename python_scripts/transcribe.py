import os
import sys
import audioop
import wave
from groq import Groq
from dotenv import load_dotenv

# 設定 UTF-8 輸出
if sys.platform == "win32":
    import io

    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

# 載入環境變數
load_dotenv()


def transcribe_audio(audio_file_path, language="zh"):
    """
    使用Groq API將音頻轉換為文字
    """
    # 檢查檔案
    if not os.path.exists(audio_file_path):
        return f"錯誤: 找不到音頻檔案"

    file_size = os.path.getsize(audio_file_path)

    if file_size < 1000:
        return "錯誤: 音頻檔案太小"

    # 檢查音量
    try:
        with wave.open(audio_file_path, 'rb') as wf:
            frames = wf.readframes(wf.getnframes())
            rms = audioop.rms(frames, 2)

            MIN_VOLUME_THRESHOLD = 300

            if rms < MIN_VOLUME_THRESHOLD:
                return "[無有效語音]"
    except Exception as e:
        # 音量檢測失敗不影響轉錄
        pass

    # 初始化 Groq
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        return "錯誤: 找不到API金鑰"

    client = Groq(api_key=api_key)

    try:
        with open(audio_file_path, "rb") as audio_file:
            audio_data = audio_file.read()

            params = {
                "file": (os.path.basename(audio_file_path), audio_data),
                "model": "whisper-large-v3",
                "response_format": "text",
                "temperature": 0.0,
            }

            # 指定語言
            if language and language != "auto":
                params["language"] = language

            transcription = client.audio.transcriptions.create(**params)

        result = str(transcription).strip()

        if not result or result == "":
            return "[無聲音]"

        return result

    except Exception as e:
        return f"錯誤: {str(e)}"


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(1)

    audio_file = sys.argv[1]
    language = sys.argv[2] if len(sys.argv) > 2 else "zh"

    result = transcribe_audio(audio_file, language)

    # 寫入檔案(使用 UTF-8)
    output_txt = audio_file.replace(".wav", "_result.txt")
    try:
        with open(output_txt, 'w', encoding='utf-8') as f:
            f.write(result)
    except Exception as e:
        # 寫檔失敗也要讓程式正常結束
        pass