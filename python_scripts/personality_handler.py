#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
個性處理器
處理個性管理的所有操作
修正：支持從文件讀取 JSON 數據
"""

import sys
import json
import os
import argparse

# 禁用所有標準輸出（避免編碼問題）
class SilentOutput:
    def write(self, *args, **kwargs):
        pass
    def flush(self):
        pass

# 在 import 之前就禁用輸出
_original_stdout = sys.stdout
_original_stderr = sys.stderr
sys.stdout = SilentOutput()
sys.stderr = SilentOutput()

# 禁用進度條和警告
os.environ['TRANSFORMERS_VERBOSITY'] = 'error'
os.environ['TOKENIZERS_PARALLELISM'] = 'false'

# 導入原有模組
try:
       from personality_manager import PersonalityManager, Personality
except ImportError:
       sys.path.append(os.path.dirname(os.path.dirname(__file__)))
       from personality_manager import PersonalityManager, Personality

def handle_list() -> dict:
    """列出所有個性"""
    try:
        manager = PersonalityManager()
        personalities = manager.get_all_personalities()
        current = manager.current_personality
        
        result = []
        for p in personalities:
            p_dict = p.to_dict()
            p_dict['is_current'] = (current and current.name == p.name)
            result.append(p_dict)
        
        return {
            "success": True,
            "personalities": result
        }
    except Exception as e:
        return {"success": False, "error": str(e)}

def handle_current() -> dict:
    """獲取當前個性"""
    try:
        manager = PersonalityManager()
        
        if manager.current_personality:
            return {
                "success": True,
                "personality": manager.current_personality.to_dict()
            }
        else:
            return {"success": False, "error": "No personality set"}
    except Exception as e:
        return {"success": False, "error": str(e)}

def handle_switch(name: str) -> dict:
    """切換個性"""
    try:
        manager = PersonalityManager()
        success = manager.set_personality(name)
        
        if success:
            return {
                "success": True,
                "personality": manager.current_personality.to_dict()
            }
        else:
            return {"success": False, "error": "Personality not found"}
    except Exception as e:
        return {"success": False, "error": str(e)}

def handle_create(data_input: str) -> dict:
	"""創建新個性"""
	try:
		# 🔧 修復：檢查是文件路徑還是 JSON 字符串
		if data_input.startswith('@'):
			# 這是文件路徑
			file_path = data_input[1:]  # 移除 @ 前綴
			if not os.path.exists(file_path):
				return {"success": False, "error": f"Data file not found: {file_path}"}
			
			with open(file_path, 'r', encoding='utf-8') as f:
				data = json.load(f)
		else:
			# 這是 JSON 字符串
			data = json.loads(data_input)
		
		manager = PersonalityManager()
		
		success = manager.create_custom_personality(
			name=data.get('name'),
			display_name=data.get('display_name'),
			system_prompt=data.get('system_prompt'),
			traits=data.get('traits', []),
			speaking_style=data.get('speaking_style', '友善自然'),
			emoji_frequency=data.get('emoji_frequency', 'medium'),
			greeting=data.get('greeting', '你好！'),
			avatar_path=data.get('avatar_path', '')  # 🆕 包含頭像路徑
		)
		
		if success:
			return {
				"success": True,
				"message": "Personality created successfully"
			}
		else:
			return {
				"success": False,
				"error": "Personality name already exists"
			}
	except json.JSONDecodeError as e:
		return {"success": False, "error": f"Invalid JSON: {str(e)}"}
	except Exception as e:
		return {"success": False, "error": str(e)}

def handle_update(data_input: str) -> dict:
    """更新現有個性"""
    try:
        # 檢查是文件路徑還是 JSON 字符串
        if data_input.startswith('@'):
            # 這是文件路徑
            file_path = data_input[1:]  # 移除 @ 前綴
            if not os.path.exists(file_path):
                return {"success": False, "error": f"Data file not found: {file_path}"}
            
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
        else:
            # 這是 JSON 字符串
            data = json.loads(data_input)
        
        manager = PersonalityManager()
        
        # 檢查個性是否存在
        name = data.get('name')
        if not name or name not in manager.personalities:
            return {
                "success": False,
                "error": "Personality not found"
            }
        
        # 更新個性（重新創建並保存）
        personality = Personality(
            name=name,
            display_name=data.get('display_name'),
            system_prompt=data.get('system_prompt'),
            traits=data.get('traits', []),
            speaking_style=data.get('speaking_style', '友善自然'),
            emoji_frequency=data.get('emoji_frequency', 'medium'),
            greeting=data.get('greeting', '你好！'),
            avatar_folder=data.get('avatar_folder', 'Idle'),
            avatar_path=data.get('avatar_path', '')
        )
        
        manager.save_personality(personality)
        
        # 如果是當前個性，也更新狀態
        if manager.current_personality and manager.current_personality.name == name:
            manager.current_personality = personality
            manager._save_state()
        
        return {
            "success": True,
            "message": "Personality updated successfully"
        }
    except json.JSONDecodeError as e:
        return {"success": False, "error": f"Invalid JSON: {str(e)}"}
    except Exception as e:
        return {"success": False, "error": str(e)}

def handle_delete(name: str) -> dict:
    """刪除個性"""
    try:
        manager = PersonalityManager()
        success = manager.delete_personality(name)
        
        if success:
            return {
                "success": True,
                "message": "Personality deleted successfully"
            }
        else:
            return {
                "success": False,
                "error": "Cannot delete personality (not found or currently in use)"
            }
    except Exception as e:
        return {"success": False, "error": str(e)}

def main():
    """主函數"""
    parser = argparse.ArgumentParser(description='Personality Handler')
    parser.add_argument('--action', required=True, choices=[
        'list', 'current', 'switch', 'create', 'update', 'delete'  # 確保有 'update'
    ])
    parser.add_argument('--name', type=str, help='Personality name')
    parser.add_argument('--data', type=str, help='JSON data or file path (prefix with @)')
    parser.add_argument('--output', type=str, help='Output file path')
    
    args = parser.parse_args()
    
    # 根據動作執行
    if args.action == 'list':
        result = handle_list()
    elif args.action == 'current':
        result = handle_current()
    elif args.action == 'switch':
        if not args.name:
            result = {"success": False, "error": "Missing --name parameter"}
        else:
            result = handle_switch(args.name)
    elif args.action == 'create':
        if not args.data:
            result = {"success": False, "error": "Missing --data parameter"}
        else:
            result = handle_create(args.data)
    elif args.action == 'update':
        if not args.data:
            result = {"success": False, "error": "Missing --data parameter"}
        else:
            result = handle_update(args.data)
    elif args.action == 'delete':
        if not args.name:
            result = {"success": False, "error": "Missing --name parameter"}
        else:
            result = handle_delete(args.name)
    else:
        result = {"success": False, "error": "Unknown action"}
    
    # 寫入文件
    if args.output:
        try:
            with open(args.output, 'w', encoding='utf-8') as f:
                json.dump(result, f, ensure_ascii=False, indent=2)
            
            # 恢復 stdout 並輸出狀態（純 ASCII）
            sys.stdout = _original_stdout
            print(json.dumps({"status": "ok"}, ensure_ascii=True))
            sys.stdout.flush()
        except Exception as e:
            sys.stdout = _original_stdout
            error_result = {"status": "error", "message": str(e)}
            print(json.dumps(error_result, ensure_ascii=True))
            sys.stdout.flush()
    else:
        # 沒有指定輸出文件，直接輸出（純 ASCII）
        sys.stdout = _original_stdout
        output = json.dumps(result, ensure_ascii=True)
        print(output)
        sys.stdout.flush()

if __name__ == "__main__":
    main()