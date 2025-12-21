import pyaudio
import wave
import sys
import os
import time


def record_audio_controlled(output_file, lock_file, sample_rate=16000):
    CHUNK = 1024
    FORMAT = pyaudio.paInt16
    CHANNELS = 1

    audio = pyaudio.PyAudio()

    print("Python: 初始化錄音...", flush=True)

    try:
        stream = audio.open(
            format=FORMAT,
            channels=CHANNELS,
            rate=sample_rate,
            input=True,
            frames_per_buffer=CHUNK
        )

        frames = []

        # 先預錄0.2秒緩衝，避免開頭被切掉
        print("Python: 預熱緩衝中...", flush=True)
        for _ in range(int(sample_rate / CHUNK * 0.2)):
            data = stream.read(CHUNK, exception_on_overflow=False)
            frames.append(data)

        print("Python: 開始正式錄音...", flush=True)

        # 持續錄音直到鎖定檔案被刪除
        while os.path.exists(lock_file):
            data = stream.read(CHUNK, exception_on_overflow=False)
            frames.append(data)

        print("Python: 偵測到停止信號", flush=True)

        # 再錄0.3秒緩衝，避免結尾被切掉
        for _ in range(int(sample_rate / CHUNK * 0.3)):
            try:
                data = stream.read(CHUNK, exception_on_overflow=False)
                frames.append(data)
            except:
                break

        stream.stop_stream()
        stream.close()
        audio.terminate()

        print("Python: 正在儲存檔案...", flush=True)

        # 確保目錄存在
        output_dir = os.path.dirname(output_file)
        if output_dir and not os.path.exists(output_dir):
            os.makedirs(output_dir)

        # 儲存音頻
        wf = wave.open(output_file, 'wb')
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(audio.get_sample_size(FORMAT))
        wf.setframerate(sample_rate)
        wf.writeframes(b''.join(frames))
        wf.close()

        file_size = os.path.getsize(output_file)
        print(f"Python: 檔案已儲存 ({file_size} bytes)", flush=True)
        print(f"RESULT_SAVED:{output_file}", flush=True)

    except Exception as e:
        print(f"Python Error: {e}", flush=True)
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python record_audio.py <output_wav> <lock_file>")
        sys.exit(1)

    output_path = sys.argv[1]
    lock_path = sys.argv[2]

    record_audio_controlled(output_path, lock_path)