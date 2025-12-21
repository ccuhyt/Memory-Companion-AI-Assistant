from fastapi import FastAPI, UploadFile, File, Form
import uvicorn
import os
import wave
import audioop
from groq import Groq
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

def transcribe_audio(audio_file_path, language="zh"):
    if not os.path.exists(audio_file_path):
        return "錯誤: 找不到音頻檔案"

    try:
        with wave.open(audio_file_path, 'rb') as wf:
            frames = wf.readframes(wf.getnframes())
            rms = audioop.rms(frames, 2)
            if rms < 200:
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


@app.post("/stt")
async def stt_api(file: UploadFile = File(...), language: str = Form("zh")):
    temp_path = "temp.wav"

    with open(temp_path, "wb") as f:
        f.write(await file.read())

    result = transcribe_audio(temp_path, language)

    os.remove(temp_path)

    return {"text": result}


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=5003)
