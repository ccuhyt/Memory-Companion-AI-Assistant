#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
輸出輔助函數
統一處理 JSON 輸出到文件
"""

import json
import sys

def output_to_file(result: dict, output_file: str):
    """
    將結果寫入文件並輸出狀態
    
    Args:
        result: 要輸出的字典
        output_file: 輸出文件路徑
    """
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(result, f, ensure_ascii=False, indent=2)
        
        # 輸出簡單的成功訊息（純 ASCII）
        print(json.dumps({"status": "ok"}, ensure_ascii=True))
        sys.stdout.flush()
        return True
    
    except Exception as e:
        error_result = {"status": "error", "message": str(e)}
        print(json.dumps(error_result, ensure_ascii=True))
        sys.stdout.flush()
        return False

def output_direct(result: dict):
    """
    直接輸出結果（用於不需要文件的場景）
    僅使用 ASCII 字符
    """
    # 將所有中文轉為 ASCII 安全的格式
    output = json.dumps(result, ensure_ascii=True)
    print(output)
    sys.stdout.flush()