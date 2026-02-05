def observable_self_repair(self):
    repair_metrics = {
        "repair_attempts": "修復試行回数",
        "success_rate": "自己修復成功率", 
        "recovery_time": "修復にかかった時間",
        "root_cause_analysis": "障害原因の分類"
    }
    self.record_decision("self_repair_analysis", repair_metrics)