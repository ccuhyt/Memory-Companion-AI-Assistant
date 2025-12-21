import os
from openai import OpenAI
from dotenv import load_dotenv
import random
import json
from datetime import datetime

load_dotenv()


class SoapOperaGenerator:
    def __init__(self):
        # 直接設定為 OpenRouter
        self.client = OpenAI(
            api_key=os.getenv("OPENROUTER_API_KEY"),
            base_url="https://openrouter.ai/api/v1"
        )
        # 固定使用目前穩定的免費模型
        self.model = "meta-llama/llama-3.3-70b-instruct:free"

        # 超狗血系統提示詞!
        self.system_prompt = """你是天才網文作家,專寫讓人一看就停不下來的爽文和狗血劇!

你的絕招:
- 劇情反轉自然出現
- 身世謎團:私生子、真假千金、失散多年的兄妹
- 虐心愛情:誤會、悔恨、為時已晚、死而復生
- 復仇爽文:主角被欺負後華麗逆襲
- 重生穿越:回到過去改變命運,吊打渣男渣女
- 霸道總裁:冷酷外表溫柔內心,只對女主好
- 豪門恩怨:遺產爭奪、商戰陰謀、背叛與復仇

寫作原則:
1. 開頭三句必須抓人
2. 每段有衝突或新資訊
3. 對白有張力
4. 善用懸念
5. 情緒飽滿，誇張但合理

格式要求:
- 直接寫故事內容，用自然段落分隔
- 故事有完整結局，主角命運明確
- 不留開放式結尾
- 禁止平淡日常、拖戲灌水、說教冗長

規則:
每一集最後只能輸出其中一個:
<<FINISHED>>
<<CONTINUE>>
"""


    # 各種狗血類型的模板
    STORY_TYPES = {
        "重生逆襲": {
            "關鍵元素": "主角重生回到過去,利用前世記憶改變命運,打臉所有欺負過他的人",
            "必備橋段": "前世悲慘、重生後復仇、身份反轉、打臉爽文"
        },
        "真假千金": {
            "關鍵元素": "被調包的真千金回歸豪門,假千金恐慌,家人態度轉變",
            "必備橋段": "身份揭露、親情糾葛、豪門內鬥、真相大白"
        },
        "霸道總裁": {
            "關鍵元素": "冷酷總裁愛上平凡女主,為她改變,寵妻無度",
            "必備橋段": "誤會、白月光、替身、最後深情告白"
        },
        "婆媳大戰": {
            "關鍵元素": "惡婆婆欺負善良媳婦,兒子夾在中間,最後真相曝光",
            "必備橋段": "委屈、忍耐、爆發、婆婆後悔"
        },
        "遺產爭奪": {
            "關鍵元素": "老爺子去世,兒女為遺產反目,遺囑內容驚人",
            "必備橋段": "兄弟鬩牆、陰謀詭計、意外真相、善惡有報"
        },
        "出軌復仇": {
            "關鍵元素": "發現伴侶出軌,主角從崩潰到堅強,華麗復仇",
            "必備橋段": "捉姦、離婚、變美變強、讓渣男後悔"
        },
        "失憶梗": {
            "關鍵元素": "車禍失憶,忘記愛人,被壞人利用,最後恢復記憶",
            "必備橋段": "記憶碎片、似曾相識、身體記憶、感人重逢"
        },
        "鄉土溫馨": {
            "關鍵元素": "傳統市場、鄰里互助、小人物的溫暖故事",
            "必備橋段": "誤會化解、人情味、小確幸、正能量"
        }
    }

    def get_story_types(self):
        """回傳所有故事類型"""
        return list(self.STORY_TYPES.keys())

    def get_surprise_type(self):
        """從類型中隨機挑一個"""
        normal_types = list(self.STORY_TYPES.keys())
        return random.choice(normal_types)

    def generate_story(self, story_type, user_preference, length="medium", tone="狗血"):
        """
        超客製化故事生成

        參數:
            story_type: 故事類型(從 STORY_TYPES 選)
            user_preference: 使用者的額外要求(角色關係、特殊情節等)
            length: "short"(800字) "medium"(1500字) "long"(2500字)
            tone: "狗血"、"溫馨"、"搞笑"、"虐心"、"爽文"
        """

        length_map = {
            "short": "請創作一篇【短篇】故事，字數約 500~800 字。節奏要快，直接進入衝突點，不要過多鋪陳。",
            "medium": "請創作一篇【中篇】故事，字數約 1200~1500 字。要有完整的起承轉合，包含適量的環境描寫與人物對話。",
            "long": "請創作一篇【長篇】詳盡的故事，字數請盡量達到 2500 字以上。劇情需要深度鋪陳，包含細膩的心理描寫、大量的對話互動，以及多個轉折點，不要匆忙結尾。"
        }

        token_map = {
            "short": 2700,
            "medium": 5000,
            "long": 8000
        }

        length_instruction = length_map.get(length, length_map["medium"])
        # 取得類型模板
        if story_type in self.STORY_TYPES:
            template = self.STORY_TYPES[story_type]
            type_instruction = f"""
            類型: {story_type}
            核心元素: {template['關鍵元素']}
            必備橋段: {template['必備橋段']}
            {length_instruction}
            """
        else:
            type_instruction = f"類型: {story_type}"

        # 建構超詳細的 prompt
        user_prompt = f"""請創作一個{tone}的{story_type}故事!

{type_instruction}

使用者的特殊要求:
{user_preference}

故事長度: {length_map[length]}
風格基調: {tone}

規則:
- 不要標題
- 自然分段
- 完結請輸出 <<FINISHED>>
- 未完請輸出 <<CONTINUE>>

開始寫:"""

        import time
        
        max_retries = 3
        retry_count = 0
        
        while retry_count < max_retries:
            try:
                response = self.client.chat.completions.create(
                    model=self.model,
                    messages=[
                        {"role": "system", "content": self.system_prompt},
                        {"role": "user", "content": user_prompt}
                    ],
                    temperature=0.85,  # 高一點更有創意
                    max_tokens=int(token_map[length] * 0.7),
                    top_p=0.95,
                    stream=True
                )

                for chunk in response:
                    if chunk.choices[0].delta.content:
                        yield chunk.choices[0].delta.content  # 這裡用 yield 不是 return
                
                # 成功完成，跳出迴圈
                break

            except Exception as e:
                error_msg = str(e)
                
                # 檢查是否為 429 錯誤
                if "429" in error_msg or "rate_limit" in error_msg.lower():
                    retry_count += 1
                    if retry_count < max_retries:
                        wait_time = 3 * retry_count  # 遞增等待時間: 3秒, 6秒, 9秒
                        yield f"\n⚠️ API 請求過於頻繁，等待 {wait_time} 秒後重試... ({retry_count}/{max_retries})\n"
                        time.sleep(wait_time)
                    else:
                        yield f"\n❌ API 速率限制錯誤 (429)\n"
                        yield f"可能原因:\n"
                        yield f"1. 短時間內請求太多次\n"
                        yield f"2. OpenRouter 免費額度已用完\n"
                        yield f"3. 請等待 1-5 分鐘後再試\n"
                        yield f"4. 或考慮升級到付費方案\n"
                        yield f"\n技術細節: {error_msg}\n"
                else:
                    # 其他錯誤直接回傳
                    yield f"\n❌ 生成故事時發生錯誤: {error_msg}\n"
                    break

    def get_random_suggestions(self):
        """給一些超狗血的故事點子"""
        suggestions = {
            "重生逆襲": [
                "我重生了,重生到我真千金身份暴露的前一天,這次我要讓假千金身敗名裂",
                "前世我被渣男騙財騙色,重生後我成了他老闆,看我怎麼玩死他",
                "重生回到婚禮當天,我當眾揭穿渣男的真面目,轉身嫁給他的死對頭"
            ],
            "真假千金": [
                "養女把我趕出家門,結果發現我才是真千金,而且我親媽是首富",
                "真千金回來了但假裝不知情,看假千金如何自己露餡",
                "兩個千金同時愛上同一個男人,身份揭露後三角關係崩盤"
            ],
            "霸道總裁": [
                "冷酷總裁為了逃避相親,隨便拉個路人假扮女友,結果日久生情",
                "女主是總裁的秘書,暗戀多年,終於決定辭職,總裁瞬間慌了",
                "總裁失憶後忘記討厭的妻子,重新追求她,恢復記憶後後悔莫及"
            ],
            "遺產爭奪": [
                "老爺子遺囑:誰先結婚生子誰繼承,三兄弟瞬間瘋狂相親",
                "遺產要給私生子?大老婆暴怒,小三得意,結果遺囑還有下一頁...",
                "父親葬禮上,突然出現一個女人帶著孩子,說是父親的真愛"
            ],
            "出軌復仇": [
                "發現老公出軌,我裝傻讓小三懷孕,然後讓他們凈身出戶",
                "老公出軌我閨蜜,我聯合他前妻,雙重復仇讓他們兩個社死",
                "我離婚後變美變強,前夫跪求復合,但我已經是他新老闆的太太"
            ],
            "婆媳大戰": [
                "惡婆婆百般刁難,我錄音蒐證,最後在家族聚會公開播放",
                "婆婆逼我離婚,我假裝答應,結果發現她有更大的秘密",
                "我懷孕時婆婆推我下樓,我流產後她兒子終於看清她的真面目"
            ],
            "失憶梗": [
                "車禍後我失憶,醒來發現枕邊人不是我老公,但他說他才是",
                "老公失憶忘記我,被白蓮花趁虛而入,我要讓他想起我們的愛",
                "我失憶嫁給仇人,恢復記憶後發現他一直在補償我"
            ],
            "鄉土溫馨": [
                "退休老師開小吃店,意外成為社區心靈導師,化解無數家庭危機",
                "菜市場攤販們組成「八卦情報網」,用愛與溫暖拯救破碎的家庭",
                "獨居老人們互相照顧,最後發現他們年輕時竟然都互相認識"
            ]
        }
        return suggestions

    def generate_sequel(self, prev_story, episode_no, max_episodes, direction=""):
        """
        續集生成器
        prev_story: 上一集全文
        episode_no: 第幾集 (從 1 開始)
        max_episodes: 這個故事最多幾集
        direction: 使用者指定走向
        """

        if episode_no >= max_episodes:
            episode_goal = "這是最後一集，必須給出完整結局，不可開放式"
        else:
            episode_goal = "延續劇情，擴大衝突，最後留下強烈懸念"

        user_prompt = f"""
    這是一個連載故事。

    這是第 {episode_no} 集，共 {max_episodes} 集。

    上集內容摘要:
    {prev_story[-500:]}

    讀者希望續集方向:
    {direction}

    本集目標:
    {episode_goal}

    請開始續寫:"""

        import time
        
        max_retries = 3
        retry_count = 0
        
        while retry_count < max_retries:
            try:
                response = self.client.chat.completions.create(
                    model=self.model,
                    messages=[
                        {"role": "system", "content": self.system_prompt},
                        {"role": "user", "content": user_prompt}
                    ],
                    temperature=0.85,
                    max_tokens=1200,
                    stream=True
                )

                for chunk in response:
                    if chunk.choices[0].delta.content:
                        yield chunk.choices[0].delta.content
                
                # 成功完成
                break

            except Exception as e:
                error_msg = str(e)
                
                if "429" in error_msg or "rate_limit" in error_msg.lower():
                    retry_count += 1
                    if retry_count < max_retries:
                        wait_time = 3 * retry_count
                        yield f"\n⚠️ API 請求過於頻繁，等待 {wait_time} 秒後重試... ({retry_count}/{max_retries})\n"
                        time.sleep(wait_time)
                    else:
                        yield f"\n❌ 續集生成失敗 (API 速率限制)\n"
                        yield f"請等待幾分鐘後再試\n"
                else:
                    yield f"\n❌ 續集生成錯誤: {error_msg}\n"
                    break
