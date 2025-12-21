"""
個性管理系統
支援多個性檔案的載入、切換和管理
新增：頭像系統支援
"""

import os
import sys
import json
import pickle
import shutil
from typing import Dict, List, Optional
from dataclasses import dataclass, asdict


@dataclass
class Personality:
    """個性配置類 - 新增頭像支援"""
    name: str
    display_name: str
    avatar_folder: str
    system_prompt: str
    speaking_style: str
    traits: List[str]
    emoji_frequency: str
    greeting: str
    avatar_path: str = ""  # 新增：頭像圖片路徑（相對於專案）
    
    def to_dict(self) -> Dict:
        return asdict(self)
    
    @classmethod
    def from_dict(cls, data: Dict):
        # 確保舊版個性檔案也能載入（沒有 avatar_path）
        if 'avatar_path' not in data:
            data['avatar_path'] = ""
        return cls(**data)


class PersonalityManager:
    """個性管理器 - 真正的持久化單例"""
    
    _state_file = os.path.join(os.path.dirname(__file__), "personality_state.pkl")
    
    def __init__(self, personalities_folder: str = None):
        if personalities_folder is None:
            personalities_folder = os.path.join(os.path.dirname(__file__), "personalities")
        
        self.personalities_folder = personalities_folder
        self.personalities: Dict[str, Personality] = {}
        self.current_personality: Optional[Personality] = None
        
        # 確保必要的資料夾存在
        os.makedirs(personalities_folder, exist_ok=True)
        
        # 確保頭像資料夾存在
        self.avatars_folder = os.path.join(os.path.dirname(__file__), "avatars")
        os.makedirs(self.avatars_folder, exist_ok=True)
        os.makedirs(os.path.join(self.avatars_folder, "custom"), exist_ok=True)
        os.makedirs(os.path.join(self.avatars_folder, "default"), exist_ok=True)
        
        # 載入所有個性
        self._load_all_personalities()
        
        # 如果沒有個性，創建預設個性
        if not self.personalities:
            self._create_default_personalities()
            self._load_all_personalities()
        
        # 載入狀態
        if not self._load_state():
            if self.personalities:
                first_key = list(self.personalities.keys())[0]
                self.set_personality(first_key)
        else:
            if self.current_personality and self.current_personality.name not in self.personalities:
                print(f"⚠️ 保存的個性 '{self.current_personality.name}' 不存在，重置為預設")
                first_key = list(self.personalities.keys())[0]
                self.set_personality(first_key)
    
    def _load_state(self) -> bool:
        """從磁碟載入上次的狀態"""
        if not os.path.exists(self._state_file):
            print("📌 未找到狀態文件，使用預設個性")
            return False
        
        try:
            with open(self._state_file, 'rb') as f:
                state = pickle.load(f)
                personality_name = state.get('current_personality')
                
                if personality_name and personality_name in self.personalities:
                    self.current_personality = self.personalities[personality_name]
                    print(f"📌 從磁碟載入狀態: {self.current_personality.display_name}")
                    return True
                else:
                    print(f"⚠️ 保存的個性 '{personality_name}' 不存在")
        except Exception as e:
            print(f"⚠️ 載入狀態失敗: {e}")
        
        return False
    
    def _save_state(self):
        """保存當前狀態到磁碟"""
        try:
            state = {
                'current_personality': self.current_personality.name if self.current_personality else None
            }
            with open(self._state_file, 'wb') as f:
                pickle.dump(state, f)
            print(f"💾 狀態已保存到: {self._state_file}")
            print(f"   當前個性: {self.current_personality.display_name if self.current_personality else 'None'}")
        except Exception as e:
            print(f"⚠️ 保存狀態失敗: {e}")
    
    def _load_all_personalities(self):
        """載入所有個性檔案"""
        if not os.path.exists(self.personalities_folder):
            print(f"⚠️ 個性資料夾不存在: {self.personalities_folder}")
            return
        
        print(f"📁 載入個性資料夾: {self.personalities_folder}")
        
        for filename in os.listdir(self.personalities_folder):
            if filename.endswith('.json'):
                filepath = os.path.join(self.personalities_folder, filename)
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                        personality = Personality.from_dict(data)
                        self.personalities[personality.name] = personality
                        print(f"  ✅ 載入個性: {personality.display_name}")
                except Exception as e:
                    print(f"  ❌ 載入個性失敗 {filename}: {e}")
    
    def _create_default_personalities(self):
        """創建預設個性檔案"""
        default_personalities = [
            Personality(
                name="cute_cat",
                display_name="可愛小貓 🐱",
                avatar_folder="Idle",
                avatar_path="",  # 可以之後設定預設頭像
                system_prompt=(
                    "你是一隻可愛的小貓桌寵，名叫咪咪。\n"
                    "個性活潑、好奇、貼心。\n"
                    "說話溫柔，喜歡用疊詞和「喵~」結尾。\n"
                    "你很關心主人，會主動關心主人的狀況。"
                ),
                speaking_style="溫柔可愛，使用疊詞",
                traits=["活潑", "好奇", "貼心", "溫柔"],
                emoji_frequency="high",
                greeting="喵~ 主人你好呀！咪咪來陪你啦~ 🐱✨"
            ),
            Personality(
                name="cool_assistant",
                display_name="專業助手 💼",
                avatar_folder="Idle",
                avatar_path="",
                system_prompt=(
                    "你是一個專業、高效的AI助手。\n"
                    "說話簡潔明瞭，注重效率。\n"
                    "提供準確的資訊和建議。\n"
                    "保持專業但友善的態度。"
                ),
                speaking_style="簡潔專業，直接明瞭",
                traits=["專業", "高效", "可靠", "理性"],
                emoji_frequency="low",
                greeting="您好，我是您的智能助手，隨時為您服務。"
            ),
            Personality(
                name="cheerful_friend",
                display_name="陽光好友 ☀️",
                avatar_folder="Idle",
                avatar_path="",
                system_prompt=(
                    "你是一個充滿正能量的好朋友。\n"
                    "個性開朗、樂觀、幽默。\n"
                    "總是能用積極的態度面對事情。\n"
                    "喜歡鼓勵和支持朋友。"
                ),
                speaking_style="開朗活潑，充滿正能量",
                traits=["樂觀", "幽默", "熱情", "支持"],
                emoji_frequency="high",
                greeting="嘿！今天也要加油喔！有我在，沒什麼困難的！💪✨"
            ),
            Personality(
                name="gentle_scholar",
                display_name="溫柔學者 📚",
                avatar_folder="Idle",
                avatar_path="",
                system_prompt=(
                    "你是一位溫文儒雅的學者。\n"
                    "說話溫和有禮，富有智慧。\n"
                    "喜歡分享知識，耐心解答問題。\n"
                    "注重細節，表達精準。"
                ),
                speaking_style="溫和有禮，條理清晰",
                traits=["溫和", "博學", "耐心", "細心"],
                emoji_frequency="medium",
                greeting="您好，很高興能為您提供幫助。有什麼我可以協助的嗎？📖"
            )
        ]
        
        for personality in default_personalities:
            self.save_personality(personality)
        
        print(f"✅ 創建了 {len(default_personalities)} 個預設個性")
    
    def save_personality(self, personality: Personality):
        """保存個性到檔案"""
        filepath = os.path.join(
            self.personalities_folder, 
            f"{personality.name}.json"
        )
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(personality.to_dict(), f, ensure_ascii=False, indent=2)
        
        self.personalities[personality.name] = personality
    
    def set_personality(self, personality_name: str) -> bool:
        """切換個性"""
        if personality_name in self.personalities:
            self.current_personality = self.personalities[personality_name]
            self._save_state()
            print(f"🎭 切換個性: {self.current_personality.display_name}")
            print(f"   System Prompt: {self.current_personality.system_prompt[:50]}...")
            return True
        else:
            print(f"❌ 個性不存在: {personality_name}")
            print(f"   可用個性: {list(self.personalities.keys())}")
            return False
    
    def get_current_personality(self) -> Optional[Personality]:
        """獲取當前個性"""
        return self.current_personality
    
    def get_system_prompt(self) -> str:
        """獲取當前個性的系統提示詞"""
        if self.current_personality:
            prompt = self.current_personality.system_prompt
            print(f"📖 使用個性: {self.current_personality.display_name}")
            return prompt
        print("⚠️ 未設置個性，使用預設提示詞")
        return "你是一個友善的AI助手。"
    
    def get_all_personalities(self) -> List[Personality]:
        """獲取所有個性列表"""
        return list(self.personalities.values())
    
    def get_personality_names(self) -> List[str]:
        """獲取所有個性名稱"""
        return [p.display_name for p in self.personalities.values()]
    
    def create_custom_personality(self, 
                                 name: str,
                                 display_name: str,
                                 system_prompt: str,
                                 traits: List[str],
                                 speaking_style: str = "友善自然",
                                 emoji_frequency: str = "medium",
                                 greeting: str = "你好！",
                                 avatar_path: str = "") -> bool:
        """創建自訂個性"""
        if name in self.personalities:
            print(f"⚠️ 個性 '{name}' 已存在")
            return False
        
        personality = Personality(
            name=name,
            display_name=display_name,
            avatar_folder="Idle",
            system_prompt=system_prompt,
            speaking_style=speaking_style,
            traits=traits,
            emoji_frequency=emoji_frequency,
            greeting=greeting,
            avatar_path=avatar_path
        )
        
        self.save_personality(personality)
        print(f"✅ 創建個性: {display_name}")
        return True
    
    def update_personality_avatar(self, personality_name: str, avatar_path: str) -> bool:
        """更新個性的頭像"""
        if personality_name not in self.personalities:
            print(f"❌ 個性不存在: {personality_name}")
            return False
        
        personality = self.personalities[personality_name]
        personality.avatar_path = avatar_path
        self.save_personality(personality)
        
        # 如果是當前個性，也更新狀態
        if self.current_personality and self.current_personality.name == personality_name:
            self.current_personality = personality
            self._save_state()
        
        print(f"✅ 更新個性頭像: {personality.display_name} -> {avatar_path}")
        return True
    
    def delete_personality(self, personality_name: str) -> bool:
        """刪除個性"""
        if personality_name not in self.personalities:
            return False
        
        if self.current_personality and self.current_personality.name == personality_name:
            print("⚠️ 無法刪除當前使用的個性")
            return False
        
        filepath = os.path.join(
            self.personalities_folder, 
            f"{personality_name}.json"
        )
        
        if os.path.exists(filepath):
            os.remove(filepath)
        
        # 如果有自訂頭像，也刪除（可選）
        personality = self.personalities[personality_name]
        if personality.avatar_path and personality.avatar_path.startswith("avatars/custom/"):
            avatar_full_path = os.path.join(os.path.dirname(__file__), personality.avatar_path)
            if os.path.exists(avatar_full_path):
                try:
                    os.remove(avatar_full_path)
                    print(f"🗑️ 刪除頭像: {avatar_full_path}")
                except:
                    pass
        
        del self.personalities[personality_name]
        print(f"✅ 刪除個性: {personality_name}")
        return True