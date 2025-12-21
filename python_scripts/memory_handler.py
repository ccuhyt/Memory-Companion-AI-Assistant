#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
記憶處理器 - 重構版
支援新的文件導向記憶系統
"""

import sys
import json
import os
import argparse
import logging
from datetime import datetime

# 禁用所有標準輸出（避免編碼問題）
class SilentOutput:
    def write(self, *args, **kwargs):
        pass
    def flush(self):
        pass

# 暫時禁用輸出
_original_stdout = sys.stdout
_original_stderr = sys.stderr
sys.stdout = SilentOutput()
sys.stderr = SilentOutput()

# 禁用進度條和警告
os.environ['TRANSFORMERS_VERBOSITY'] = 'error'
os.environ['TOKENIZERS_PARALLELISM'] = 'false'

# 設置日誌
log_dir = "logs"
os.makedirs(log_dir, exist_ok=True)
log_file = os.path.join(log_dir, f"memory_{datetime.now().strftime('%Y%m%d')}.log")

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(log_file, encoding='utf-8'),
    ]
)
logger = logging.getLogger(__name__)

# 導入模組
try:
    from dual_memory_system import DualMemorySystem
except ImportError:
    sys.path.append(os.path.dirname(os.path.dirname(__file__)))
    from dual_memory_system import DualMemorySystem

# 全局單例
_memory_system = None

def get_memory_system():
    global _memory_system
    if _memory_system is None:
        logger.info("Initializing DualMemorySystem")
        _memory_system = DualMemorySystem()
    return _memory_system

def handle_stats() -> dict:
    """獲取記憶統計"""
    try:
        logger.info("Getting memory stats")
        memory_system = get_memory_system()
        stats = memory_system.get_stats()
        logger.info(f"Stats: {stats}")
        return {"success": True, "stats": stats}
    except Exception as e:
        logger.error(f"Error getting stats: {e}", exc_info=True)
        return {"success": False, "error": str(e)}

def handle_clear() -> dict:
    """清空短期記憶（不影響長期記憶）"""
    try:
        logger.info("Clearing session memory")
        memory_system = get_memory_system()
        memory_system.session_memory.clear()
        logger.info("Session memory cleared")
        return {"success": True, "message": "Session memory cleared"}
    except Exception as e:
        logger.error(f"Error clearing memory: {e}", exc_info=True)
        return {"success": False, "error": str(e)}

def handle_search(query: str) -> dict:
    """搜尋記憶"""
    try:
        logger.info(f"Searching memories for: {query[:50]}")
        memory_system = get_memory_system()
        session_results, summary_results = memory_system.get_relevant_memories(query)
        
        logger.info(f"Found {len(session_results)} session results, {len(summary_results)} summary results")
        
        return {
            "success": True,
            "session_memories": session_results,
            "summary_memories": summary_results
        }
    except Exception as e:
        logger.error(f"Error searching memories: {e}", exc_info=True)
        return {"success": False, "error": str(e)}

def handle_end_session() -> dict:
    """
    結束會話：
    1. 將短期記憶逐條總結並存入長期記憶
    2. 清空短期記憶
    """
    try:
        logger.info("=== Starting session end process ===")
        memory_system = get_memory_system()
        
        # 獲取當前對話數量
        dialogue_count = len(memory_system.session_memory.dialogues)
        logger.info(f"Total dialogues to process: {dialogue_count}")
        
        if dialogue_count == 0:
            logger.info("No dialogues to save")
            return {
                "success": True,
                "message": "No dialogues to save",
                "dialogue_count": 0,
                "summaries_created": 0
            }
        
        # 記錄短期記憶文件路徑
        session_file = memory_system.session_memory.session_file
        logger.info(f"Session memory file: {session_file}")
        logger.info(f"File exists before processing: {os.path.exists(session_file)}")
        
        # 執行會話結束流程
        logger.info("Processing dialogues and creating summaries...")
        result = memory_system.end_session()
        
        # 檢查文件是否被清空
        logger.info(f"File exists after processing: {os.path.exists(session_file)}")
        if os.path.exists(session_file):
            try:
                with open(session_file, 'r', encoding='utf-8') as f:
                    remaining_data = json.load(f)
                    logger.info(f"Remaining dialogues in file: {len(remaining_data)}")
            except:
                logger.warning("Could not read session file after processing")
        
        # 記錄長期記憶文件
        summary_index = os.path.join(memory_system.summary_memory.save_path, "summaries.index")
        summary_pkl = os.path.join(memory_system.summary_memory.save_path, "summaries.pkl")
        logger.info(f"Summary index exists: {os.path.exists(summary_index)}")
        logger.info(f"Summary pkl exists: {os.path.exists(summary_pkl)}")
        
        logger.info(f"Session ended:")
        logger.info(f"  - Success: {result.get('success', False)}")
        logger.info(f"  - Dialogues processed: {result.get('dialogue_count', 0)}")
        logger.info(f"  - Summaries created: {result.get('summaries_created', 0)}")
        
        if result.get('errors'):
            logger.warning(f"  - Errors: {result['errors']}")
        
        logger.info("=== Session end process completed ===")
        
        return result
        
    except Exception as e:
        logger.error(f"Error ending session: {e}", exc_info=True)
        return {
            "success": False,
            "error": str(e),
            "dialogue_count": 0,
            "summaries_created": 0
        }

def main():
    """主函數"""
    logger.info("=== memory_handler started ===")
    
    parser = argparse.ArgumentParser(description='Memory Handler')
    parser.add_argument('--action', required=True, choices=[
        'stats', 'clear', 'search', 'end'
    ])
    parser.add_argument('--query', type=str)
    parser.add_argument('--output', type=str, help='Output file path')
    
    args = parser.parse_args()
    logger.info(f"Action: {args.action}")
    
    # 根據動作執行
    if args.action == 'stats':
        result = handle_stats()
    elif args.action == 'clear':
        result = handle_clear()
    elif args.action == 'search':
        if not args.query:
            result = {"success": False, "error": "Missing --query parameter"}
        else:
            result = handle_search(args.query)
    elif args.action == 'end':
        result = handle_end_session()
    else:
        result = {"success": False, "error": "Unknown action"}
    
    # 寫入文件
    if args.output:
        try:
            with open(args.output, 'w', encoding='utf-8') as f:
                json.dump(result, f, ensure_ascii=False, indent=2)
            
            logger.info("Result written to file")
            
            # 恢復 stdout 並輸出（純 ASCII）
            sys.stdout = _original_stdout
            print(json.dumps({"status": "ok"}, ensure_ascii=True))
            sys.stdout.flush()
        except Exception as e:
            logger.error(f"Write file failed: {e}", exc_info=True)
            sys.stdout = _original_stdout
            error_result = {"status": "error", "message": str(e)}
            print(json.dumps(error_result, ensure_ascii=True))
            sys.stdout.flush()
    else:
        # 直接輸出（純 ASCII）
        sys.stdout = _original_stdout
        output = json.dumps(result, ensure_ascii=True)
        print(output)
        sys.stdout.flush()
    
    logger.info("=== memory_handler finished ===\n")

if __name__ == "__main__":
    main()