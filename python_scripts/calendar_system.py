"""
月曆與事件提醒系統
支援事件管理、自動提醒、持久化存儲
"""

import os
import json
import time
from datetime import datetime, timedelta
from typing import List, Dict, Optional, Callable
from dataclasses import dataclass, asdict
from PyQt5.QtCore import QTimer, pyqtSignal, QObject


@dataclass
class CalendarEvent:
    """行事曆事件"""
    id: int
    title: str
    description: str
    date: str  # YYYY-MM-DD
    time: str  # HH:MM
    remind_before: int  # 提前多少分鐘提醒
    is_completed: bool = False
    created_at: str = ""
    
    def to_dict(self) -> Dict:
        return asdict(self)
    
    @classmethod
    def from_dict(cls, data: Dict):
        return cls(**data)
    
    def get_datetime(self) -> datetime:
        """獲取事件的完整時間"""
        datetime_str = f"{self.date} {self.time}"
        return datetime.strptime(datetime_str, "%Y-%m-%d %H:%M")
    
    def should_remind(self, current_time: datetime) -> bool:
        """判斷是否應該提醒"""
        if self.is_completed:
            return False
        
        event_time = self.get_datetime()
        remind_time = event_time - timedelta(minutes=self.remind_before)
        
        # 如果當前時間在提醒時間之後，且在事件時間之前
        return remind_time <= current_time <= event_time


class CalendarManager(QObject):
    """行事曆管理器"""
    
    # 信號
    event_reminder = pyqtSignal(object)  # 觸發提醒時發送事件
    
    def __init__(self, save_path: str = "calendar_data.json"):
        super().__init__()
        self.save_path = save_path
        self.events: Dict[int, CalendarEvent] = {}
        self.next_id = 1
        self.reminded_events = set()  # 記錄已提醒過的事件
        
        # 載入已存在的事件
        self._load_from_disk()
        
        # 設置定時檢查器（每分鐘檢查一次）
        self.check_timer = QTimer()
        self.check_timer.timeout.connect(self._check_reminders)
        self.check_timer.start(60000)  # 60秒
        
        # 立即檢查一次
        self._check_reminders()
    
    def add_event(self, title: str, description: str, 
                 date: str, time: str, remind_before: int = 10) -> CalendarEvent:
        """
        添加事件
        
        Args:
            title: 事件標題
            description: 事件描述
            date: 日期 (YYYY-MM-DD)
            time: 時間 (HH:MM)
            remind_before: 提前多少分鐘提醒
        """
        event = CalendarEvent(
            id=self.next_id,
            title=title,
            description=description,
            date=date,
            time=time,
            remind_before=remind_before,
            created_at=datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        )
        
        self.events[self.next_id] = event
        self.next_id += 1
        
        self._save_to_disk()
        print(f"✅ 已添加事件: {title} ({date} {time})")
        
        return event
    
    def get_event(self, event_id: int) -> Optional[CalendarEvent]:
        """獲取指定事件"""
        return self.events.get(event_id)
    
    def get_events_by_date(self, date: str) -> List[CalendarEvent]:
        """獲取指定日期的所有事件"""
        return [e for e in self.events.values() if e.date == date]
    
    def get_upcoming_events(self, days: int = 7) -> List[CalendarEvent]:
        """獲取未來N天的事件"""
        today = datetime.now().date()
        end_date = today + timedelta(days=days)
        
        upcoming = []
        for event in self.events.values():
            event_date = datetime.strptime(event.date, "%Y-%m-%d").date()
            if today <= event_date <= end_date and not event.is_completed:
                upcoming.append(event)
        
        # 按時間排序
        upcoming.sort(key=lambda e: e.get_datetime())
        return upcoming
    
    def get_all_events(self) -> List[CalendarEvent]:
        """獲取所有事件"""
        return list(self.events.values())
    
    def update_event(self, event_id: int, **kwargs) -> bool:
        """更新事件"""
        if event_id not in self.events:
            return False
        
        event = self.events[event_id]
        for key, value in kwargs.items():
            if hasattr(event, key):
                setattr(event, key, value)
        
        self._save_to_disk()
        print(f"✅ 已更新事件: {event.title}")
        return True
    
    def complete_event(self, event_id: int) -> bool:
        """標記事件為已完成"""
        if event_id not in self.events:
            return False
        
        self.events[event_id].is_completed = True
        self._save_to_disk()
        print(f"✅ 事件已完成: {self.events[event_id].title}")
        return True
    
    def delete_event(self, event_id: int) -> bool:
        """刪除事件"""
        if event_id not in self.events:
            return False
        
        event_title = self.events[event_id].title
        del self.events[event_id]
        
        # 從已提醒列表中移除
        self.reminded_events.discard(event_id)
        
        self._save_to_disk()
        print(f"🗑️ 已刪除事件: {event_title}")
        return True
    
    def _check_reminders(self):
        """檢查是否有需要提醒的事件"""
        current_time = datetime.now()
        
        for event in self.events.values():
            # 如果這個事件還沒提醒過，且應該提醒
            if event.id not in self.reminded_events and event.should_remind(current_time):
                print(f"⏰ 觸發提醒: {event.title}")
                self.event_reminder.emit(event)
                self.reminded_events.add(event.id)
    
    def _save_to_disk(self):
        """保存到磁碟"""
        try:
            data = {
                'events': [e.to_dict() for e in self.events.values()],
                'next_id': self.next_id,
                'reminded_events': list(self.reminded_events)
            }
            
            with open(self.save_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            
        except Exception as e:
            print(f"❌ 保存事件失敗: {e}")
    
    def _load_from_disk(self):
        """從磁碟載入"""
        try:
            if not os.path.exists(self.save_path):
                return
            
            with open(self.save_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            # 載入事件
            for event_data in data.get('events', []):
                event = CalendarEvent.from_dict(event_data)
                self.events[event.id] = event
            
            self.next_id = data.get('next_id', 1)
            self.reminded_events = set(data.get('reminded_events', []))
            
            print(f"✅ 載入了 {len(self.events)} 個事件")
            
        except Exception as e:
            print(f"⚠️ 載入事件失敗: {e}")
    
    def get_today_summary(self) -> str:
        """獲取今日事件摘要"""
        today = datetime.now().strftime("%Y-%m-%d")
        today_events = self.get_events_by_date(today)
        
        if not today_events:
            return "今天沒有安排事件。"
        
        summary = f"今天有 {len(today_events)} 個事件:\n"
        for event in today_events:
            status = "✅" if event.is_completed else "⏰"
            summary += f"{status} {event.time} - {event.title}\n"
        
        return summary.strip()
    
    def get_month_events(self, year: int, month: int) -> Dict[str, List[CalendarEvent]]:
        """獲取指定月份的所有事件，按日期分組"""
        events_by_date = {}
        
        for event in self.events.values():
            event_date = datetime.strptime(event.date, "%Y-%m-%d")
            if event_date.year == year and event_date.month == month:
                date_key = event.date
                if date_key not in events_by_date:
                    events_by_date[date_key] = []
                events_by_date[date_key].append(event)
        
        # 每個日期的事件按時間排序
        for date_key in events_by_date:
            events_by_date[date_key].sort(key=lambda e: e.time)
        
        return events_by_date


class CalendarUI:
    """行事曆UI助手 - 提供格式化輸出"""
    
    @staticmethod
    def format_event_list(events: List[CalendarEvent]) -> str:
        """格式化事件列表"""
        if not events:
            return "沒有事件"
        
        lines = []
        for event in events:
            status = "✅" if event.is_completed else "📅"
            lines.append(f"{status} [{event.date} {event.time}] {event.title}")
            if event.description:
                lines.append(f"   📝 {event.description}")
            lines.append(f"   ⏰ 提前 {event.remind_before} 分鐘提醒")
            lines.append("")
        
        return "\n".join(lines)
    
    @staticmethod
    def format_month_calendar(year: int, month: int, events_by_date: Dict[str, List[CalendarEvent]]) -> str:
        """格式化月曆視圖"""
        import calendar
        
        # 生成月曆
        cal = calendar.monthcalendar(year, month)
        
        lines = []
        lines.append(f"\n{'='*50}")
        lines.append(f"{year}年 {month}月".center(50))
        lines.append(f"{'='*50}")
        lines.append("  一   二   三   四   五   六   日")
        lines.append("-" * 50)
        
        for week in cal:
            week_str = ""
            for day in week:
                if day == 0:
                    week_str += "    "
                else:
                    date_key = f"{year:04d}-{month:02d}-{day:02d}"
                    has_event = date_key in events_by_date
                    marker = "●" if has_event else " "
                    week_str += f"{day:2d}{marker} "
            lines.append(week_str)
        
        lines.append("=" * 50)
        lines.append("\n● = 有事件的日期\n")
        
        # 列出有事件的日期
        if events_by_date:
            lines.append("本月事件:")
            for date_key in sorted(events_by_date.keys()):
                date_events = events_by_date[date_key]
                lines.append(f"\n{date_key}:")
                for event in date_events:
                    status = "✅" if event.is_completed else "⏰"
                    lines.append(f"  {status} {event.time} - {event.title}")
        
        return "\n".join(lines)


# 測試代碼
if __name__ == "__main__":
    from PyQt5.QtWidgets import QApplication
    import sys
    
    app = QApplication(sys.argv)
    
    # 初始化行事曆管理器
    calendar = CalendarManager("test_calendar.json")
    
    # 設置提醒回調
    def on_reminder(event):
        print(f"\n🔔 【提醒】{event.title}")
        print(f"   時間: {event.date} {event.time}")
        print(f"   描述: {event.description}\n")
    
    calendar.event_reminder.connect(on_reminder)
    
    # 添加測試事件
    print("\n--- 添加事件 ---")
    calendar.add_event(
        "開會",
        "與團隊討論專案進度",
        "2024-12-15",
        "14:30",
        remind_before=15
    )
    
    calendar.add_event(
        "寫作業",
        "完成數學作業",
        "2024-12-15",
        "18:00",
        remind_before=30
    )
    
    # 獲取今日摘要
    print("\n--- 今日摘要 ---")
    print(calendar.get_today_summary())
    
    # 獲取未來事件
    print("\n--- 未來7天事件 ---")
    upcoming = calendar.get_upcoming_events(7)
    print(CalendarUI.format_event_list(upcoming))
    
    # 顯示月曆
    print("\n--- 月曆視圖 ---")
    events_by_date = calendar.get_month_events(2024, 12)
    print(CalendarUI.format_month_calendar(2024, 12, events_by_date))
    
    sys.exit(app.exec_())