"""
雙記憶庫系統 - 重構版
1. 短期記憶：直接寫入 JSON 文件（session_memory.json）
2. 長期記憶：逐條儲存到 FAISS 索引（summary_memory）
3. 避免遞歸，防止 stack overflow
"""

import os
import json
import sys
import time
import pickle
import numpy as np
from typing import List, Dict, Tuple, Optional
from datetime import datetime
from io import StringIO

# ⚠️ 禁用 transformers 的進度條和警告
os.environ['TRANSFORMERS_VERBOSITY'] = 'error'
os.environ['TOKENIZERS_PARALLELISM'] = 'false'

import warnings
warnings.filterwarnings('ignore')

try:
    old_stderr = sys.stderr
    sys.stderr = StringIO()
    from sentence_transformers import SentenceTransformer
    sys.stderr = old_stderr
except ImportError as e:
    print(f"請安裝 sentence-transformers: pip install sentence-transformers", file=sys.stderr)
    raise

try:
    import faiss
except ImportError:
    class MockFaiss:
        class IndexFlatIP:
            def __init__(self, dimension):
                self.dimension = dimension
                self.data = []
            def add(self, embedding):
                self.data.append(embedding[0])
            def search(self, query, k):
                if not self.data:
                    return np.array([[0.0]]), np.array([[0]])
                scores = []
                for i, vec in enumerate(self.data):
                    if len(vec) == len(query[0]):
                        score = np.dot(query[0], vec) / (np.linalg.norm(query[0]) * np.linalg.norm(vec) + 1e-8)
                        scores.append((score, i))
                scores.sort(reverse=True)
                scores = scores[:k]
                return (np.array([[s[0] for s in scores]]), 
                       np.array([[s[1] for s in scores]]))
        @staticmethod
        def write_index(index, filepath):
            with open(filepath, 'wb') as f:
                pickle.dump(index.data, f)
        @staticmethod
        def read_index(filepath):
            idx = MockFaiss.IndexFlatIP(768)
            try:
                with open(filepath, 'rb') as f:
                    idx.data = pickle.load(f)
            except:
                pass
            return idx
    faiss = MockFaiss()


class SessionMemory:
    """短期記憶庫 - 直接寫入 JSON 文件"""
    
    def __init__(self, save_path: str = "memory_data"):
        self.save_path = save_path
        self.session_file = os.path.join(save_path, "session_memory.json")
        os.makedirs(save_path, exist_ok=True)
        
        # 載入現有的短期記憶
        self.dialogues = self._load_from_file()
        
    def _load_from_file(self) -> List[Dict]:
        """從文件載入短期記憶"""
        if os.path.exists(self.session_file):
            try:
                with open(self.session_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except:
                return []
        return []
    
    def _save_to_file(self):
        """保存到文件"""
        try:
            with open(self.session_file, 'w', encoding='utf-8') as f:
                json.dump(self.dialogues, f, ensure_ascii=False, indent=2)
        except Exception as e:
            pass  # 靜默失敗
    
    def add_dialogue(self, user_input: str, bot_response: str):
        """添加對話記錄 - 立即寫入文件"""
        dialogue = {
            'user_input': user_input,
            'bot_response': bot_response,
            'timestamp': time.time(),
            'datetime': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }
        
        self.dialogues.append(dialogue)
        self._save_to_file()  # 立即保存
    
    def get_recent(self, count: int = 5) -> List[Dict]:
        """獲取最近的對話"""
        return self.dialogues[-count:] if self.dialogues else []
    
    def get_all(self) -> List[Dict]:
        """獲取所有對話"""
        return self.dialogues
    
    def clear(self):
        """清空短期記憶並刪除文件"""
        self.dialogues = []
        
        # 寫入空數組到文件
        try:
            with open(self.session_file, 'w', encoding='utf-8') as f:
                json.dump([], f, ensure_ascii=False, indent=2)
        except Exception as e:
            # 如果寫入失敗，嘗試直接刪除文件
            try:
                if os.path.exists(self.session_file):
                    os.remove(self.session_file)
            except:
                pass  # 靜默失敗


class SummaryMemory:
    """長期記憶庫 - 儲存總結和重要資訊"""
    
    def __init__(self, embedding_model, save_path: str = "memory_data"):
        self.model = embedding_model
        self.dimension = embedding_model.get_sentence_embedding_dimension()
        self.index = faiss.IndexFlatIP(self.dimension)
        self.save_path = save_path
        
        self.summaries = []  # 總結文本列表
        self.metadata = []   # 元數據列表
        
        os.makedirs(save_path, exist_ok=True)
        
        # 載入已存在的長期記憶
        self._load_from_disk()
    
    def add_summary(self, summary_text: str, metadata: Dict = None):
        """添加單條總結記憶"""
        # 生成嵌入向量
        embedding = self.model.encode([summary_text], show_progress_bar=False)
        self.index.add(embedding.astype('float32'))
        
        # 添加元數據
        if metadata is None:
            metadata = {}
        metadata['timestamp'] = time.time()
        metadata['datetime'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        self.summaries.append(summary_text)
        self.metadata.append(metadata)
    
    def search(self, query: str, top_k: int = 5, threshold: float = 0.5) -> List[Dict]:
        """搜尋相關總結"""
        if len(self.summaries) == 0:
            return []
        
        query_embedding = self.model.encode([query], show_progress_bar=False)
        
        k = min(top_k, len(self.summaries))
        scores, indices = self.index.search(query_embedding.astype('float32'), k)
        
        results = []
        for score, idx in zip(scores[0], indices[0]):
            if idx < len(self.summaries) and score >= threshold:
                results.append({
                    'text': self.summaries[idx],
                    'score': float(score),
                    'metadata': self.metadata[idx],
                    'index': idx
                })
        
        return results
    
    def save_to_disk(self):
        """保存長期記憶到磁碟"""
        try:
            # 保存 FAISS 索引
            faiss.write_index(self.index, os.path.join(self.save_path, "summaries.index"))
            
            # 保存數據
            with open(os.path.join(self.save_path, "summaries.pkl"), 'wb') as f:
                pickle.dump({
                    'summaries': self.summaries,
                    'metadata': self.metadata
                }, f)
        except Exception as e:
            pass  # 靜默失敗
    
    def _load_from_disk(self):
        """從磁碟載入長期記憶"""
        try:
            index_path = os.path.join(self.save_path, "summaries.index")
            if os.path.exists(index_path):
                self.index = faiss.read_index(index_path)
            
            pkl_path = os.path.join(self.save_path, "summaries.pkl")
            if os.path.exists(pkl_path):
                with open(pkl_path, 'rb') as f:
                    data = pickle.load(f)
                    self.summaries = data.get('summaries', [])
                    self.metadata = data.get('metadata', [])
        except Exception as e:
            pass  # 靜默失敗


class DualMemorySystem:
    """雙記憶庫系統管理器"""
    
    def __init__(self, model_name: str = 'paraphrase-multilingual-MiniLM-L12-v2'):
        try:
            old_stdout = sys.stdout
            old_stderr = sys.stderr
            sys.stdout = StringIO()
            sys.stderr = StringIO()
            
            self.model = SentenceTransformer(model_name)
            
            sys.stdout = old_stdout
            sys.stderr = old_stderr
        except Exception as e:
            sys.stdout = old_stdout
            sys.stderr = old_stderr
            raise
        
        # 初始化兩個記憶庫
        self.session_memory = SessionMemory()
        self.summary_memory = SummaryMemory(self.model)
    
    def add_dialogue(self, user_input: str, bot_response: str):
        """記錄對話到短期記憶（立即寫入文件）"""
        self.session_memory.add_dialogue(user_input, bot_response)
    
    def get_relevant_memories(self, query: str, 
                             session_k: int = 5, 
                             summary_k: int = 5) -> Tuple[List[Dict], List[Dict]]:
        """從兩個記憶庫獲取相關記憶"""
        # 從短期記憶獲取最近對話
        session_results = self.session_memory.get_recent(session_k)
        
        # 從長期記憶搜尋
        summary_results = self.summary_memory.search(query, top_k=summary_k)
        
        return session_results, summary_results
    
    def build_context_for_llm(self, user_input: str, personality_prompt: str = "") -> str:
        """構建給 LLM 的完整上下文"""
        session_results, summary_results = self.get_relevant_memories(user_input)
        
        context_parts = []
        
        # 1. 個性提示詞
        if personality_prompt:
            context_parts.append(f"【你的個性設定】\n{personality_prompt}\n")
        
        # 2. 長期記憶
        if summary_results:
            context_parts.append("【長期記憶 - 過往對話總結】")
            for i, result in enumerate(summary_results, 1):
                context_parts.append(f"{i}. {result['text']}")
            context_parts.append("")
        
        # 3. 短期記憶
        if session_results:
            context_parts.append("【短期記憶 - 最近對話】")
            for i, result in enumerate(session_results, 1):
                context_parts.append(f"{i}. 用戶說: {result['user_input']}")
                context_parts.append(f"   你回應: {result['bot_response']}")
            context_parts.append("")
        
        # 4. 當前問題
        context_parts.append(f"【當前對話】\n用戶: {user_input}\n")
        context_parts.append("請基於你的個性和記憶，自然地回應用戶。")
        
        return "\n".join(context_parts)
    
    def end_session(self) -> dict:
        """
        結束會話：
        1. 將短期記憶逐條總結並存入長期記憶
        2. 清空短期記憶文件
        """
        dialogues = self.session_memory.get_all()
        
        if not dialogues:
            return {
                'success': True,
                'message': 'No dialogues to save',
                'dialogue_count': 0,
                'summaries_created': 0
            }
        
        summaries_created = 0
        errors = []
        
        try:
            # 逐條處理對話，避免遞歸
            # 將對話按主題分組（每5輪對話一組）
            batch_size = 5
            for i in range(0, len(dialogues), batch_size):
                try:
                    batch = dialogues[i:i+batch_size]
                    
                    # 為這批對話創建總結
                    summary_text = self._create_batch_summary(batch)
                    
                    # 存入長期記憶
                    self.summary_memory.add_summary(summary_text, {
                        'dialogue_count': len(batch),
                        'start_time': batch[0]['datetime'],
                        'end_time': batch[-1]['datetime'],
                        'batch_index': i // batch_size
                    })
                    
                    summaries_created += 1
                    
                except Exception as e:
                    error_msg = f"Batch {i//batch_size} failed: {str(e)}"
                    errors.append(error_msg)
                    continue  # 繼續處理下一批
            
            # 保存長期記憶到磁碟
            try:
                self.summary_memory.save_to_disk()
            except Exception as e:
                errors.append(f"Save to disk failed: {str(e)}")
            
            # 清空短期記憶（即使保存失敗也要清空，避免重複）
            try:
                self.session_memory.clear()
            except Exception as e:
                errors.append(f"Clear session failed: {str(e)}")
            
        except Exception as e:
            errors.append(f"Unexpected error: {str(e)}")
        
        return {
            'success': len(errors) == 0,
            'message': 'Session ended and saved' if not errors else 'Session ended with errors',
            'dialogue_count': len(dialogues),
            'summaries_created': summaries_created,
            'errors': errors if errors else None
        }
    
    def _create_batch_summary(self, dialogues: List[Dict]) -> str:
        """為一批對話創建總結"""
        if not dialogues:
            return "Empty dialogue batch"
        
        # 簡單的文本總結（不調用 LLM）
        summary_parts = []
        summary_parts.append(f"對話時段: {dialogues[0]['datetime']} - {dialogues[-1]['datetime']}")
        summary_parts.append(f"對話輪數: {len(dialogues)}")
        summary_parts.append("\n主要內容:")
        
        # 提取關鍵話題
        for i, d in enumerate(dialogues, 1):
            user_input = d['user_input'][:50]  # 截取前50字
            summary_parts.append(f"{i}. 用戶: {user_input}...")
        
        return "\n".join(summary_parts)
    
    def get_stats(self) -> Dict:
        """獲取記憶統計"""
        return {
            'session_dialogues': len(self.session_memory.dialogues),
            'total_summaries': len(self.summary_memory.summaries),
            'session_memory_active': len(self.session_memory.dialogues) > 0
        }