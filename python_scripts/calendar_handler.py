#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
行事曆處理器
處理行事曆的所有操作（無 PyQt5 依賴）
"""

import sys
import json
import os
import argparse
from datetime import datetime, timedelta
from typing import List, Dict

# 簡化的行事曆管理器（不依賴 PyQt5）
class SimpleCalendarManager:
    """簡化的行事曆管理器"""
    
    def __init__(self, data_file: str = "calendar_data.json"):
        self.data_file = data_file
        self.events = []
        self._load_data()
    
    def _load_data(self):
        """載入資料"""
        if os.path.exists(self.data_file):
            try:
                with open(self.data_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    self.events = data.get('events', [])
            except Exception as e:
                print(f"載入資料失敗: {e}", file=sys.stderr)
                self.events = []
    
    def _save_data(self):
        """儲存資料"""
        try:
            with open(self.data_file, 'w', encoding='utf-8') as f:
                json.dump({'events': self.events}, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"儲存資料失敗: {e}", file=sys.stderr)
    
    def add_event(self, title: str, date: str, time: str = "", description: str = "") -> Dict:
        """新增事件"""
        event = {
            'id': len(self.events) + 1,
            'title': title,
            'date': date,
            'time': time,
            'description': description,
            'completed': False,
            'created_at': datetime.now().isoformat()
        }
        self.events.append(event)
        self._save_data()
        return event
    
    def get_upcoming_events(self, days: int = 7) -> List[Dict]:
        """獲取未來 N 天的事件"""
        today = datetime.now().date()
        future_date = today + timedelta(days=days)
        
        upcoming = []
        for event in self.events:
            if event.get('completed'):
                continue
            
            try:
                event_date = datetime.strptime(event['date'], '%Y-%m-%d').date()
                if today <= event_date <= future_date:
                    upcoming.append(event)
            except:
                continue
        
        # 按日期排序
        upcoming.sort(key=lambda x: x['date'])
        return upcoming
    
    def get_month_events(self, year: int, month: int) -> List[Dict]:
        """獲取指定月份的事件"""
        month_events = []
        for event in self.events:
            try:
                event_date = datetime.strptime(event['date'], '%Y-%m-%d')
                if event_date.year == year and event_date.month == month:
                    month_events.append(event)
            except:
                continue
        
        month_events.sort(key=lambda x: x['date'])
        return month_events
    
    def complete_event(self, event_id: int) -> bool:
        """完成事件"""
        for event in self.events:
            if event['id'] == event_id:
                event['completed'] = True
                self._save_data()
                return True
        return False
    
    def delete_event(self, event_id: int) -> bool:
        """刪除事件"""
        for i, event in enumerate(self.events):
            if event['id'] == event_id:
                del self.events[i]
                self._save_data()
                return True
        return False

# 全局單例
_calendar_manager = None

def get_calendar_manager():
    """獲取行事曆管理器單例"""
    global _calendar_manager
    if _calendar_manager is None:
        # 使用絕對路徑
        script_dir = os.path.dirname(os.path.abspath(__file__))
        data_file = os.path.join(script_dir, 'calendar_data.json')
        _calendar_manager = SimpleCalendarManager(data_file)
    return _calendar_manager

def handle_upcoming(days: int) -> dict:
    """獲取未來事件"""
    try:
        manager = get_calendar_manager()
        events = manager.get_upcoming_events(days)
        
        return {
            "success": True,
            "events": events,
            "count": len(events)
        }
    except Exception as e:
        return {"error": str(e)}

def handle_add(data: dict) -> dict:
    """新增事件"""
    try:
        manager = get_calendar_manager()
        
        title = data.get('title', '')
        date = data.get('date', '')
        time = data.get('time', '')
        description = data.get('description', '')
        
        if not title or not date:
            return {"error": "缺少標題或日期"}
        
        event = manager.add_event(title, date, time, description)
        
        return {
            "success": True,
            "event": event
        }
    except Exception as e:
        return {"error": str(e)}

def handle_month(year: int, month: int) -> dict:
    """獲取月份事件"""
    try:
        manager = get_calendar_manager()
        events = manager.get_month_events(year, month)
        
        return {
            "success": True,
            "events": events,
            "count": len(events)
        }
    except Exception as e:
        return {"error": str(e)}

def handle_complete(event_id: int) -> dict:
    """完成事件"""
    try:
        manager = get_calendar_manager()
        success = manager.complete_event(event_id)
        
        if success:
            return {"success": True}
        else:
            return {"error": "事件不存在"}
    except Exception as e:
        return {"error": str(e)}

def handle_delete(event_id: int) -> dict:
    """刪除事件"""
    try:
        manager = get_calendar_manager()
        success = manager.delete_event(event_id)
        
        if success:
            return {"success": True}
        else:
            return {"error": "事件不存在"}
    except Exception as e:
        return {"error": str(e)}

def main():
    """主函數"""
    parser = argparse.ArgumentParser(description='行事曆處理器')
    parser.add_argument('--action', required=True, choices=[
        'upcoming', 'add', 'month', 'complete', 'delete'
    ])
    parser.add_argument('--days', type=int, default=7)
    parser.add_argument('--year', type=int)
    parser.add_argument('--month', type=int)
    parser.add_argument('--event_id', type=int)
    parser.add_argument('--data', type=str)
    
    args = parser.parse_args()
    
    # 根據動作執行
    if args.action == 'upcoming':
        result = handle_upcoming(args.days)
    
    elif args.action == 'add':
        if not args.data:
            result = {"error": "缺少 --data 參數"}
        else:
            try:
                data = json.loads(args.data)
                result = handle_add(data)
            except json.JSONDecodeError:
                result = {"error": "JSON 解析失敗"}
    
    elif args.action == 'month':
        if not args.year or not args.month:
            result = {"error": "缺少 --year 或 --month 參數"}
        else:
            result = handle_month(args.year, args.month)
    
    elif args.action == 'complete':
        if not args.event_id:
            result = {"error": "缺少 --event_id 參數"}
        else:
            result = handle_complete(args.event_id)
    
    elif args.action == 'delete':
        if not args.event_id:
            result = {"error": "缺少 --event_id 參數"}
        else:
            result = handle_delete(args.event_id)
    
    else:
        result = {"error": "未知動作"}
    
    # 輸出 JSON
    print(json.dumps(result, ensure_ascii=False))

if __name__ == "__main__":
    main()