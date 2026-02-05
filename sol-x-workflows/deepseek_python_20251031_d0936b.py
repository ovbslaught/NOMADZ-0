def enhance_decision_tracking(self):
    # 既存のrecord_decision()を拡張
    additional_metrics = {
        "response_time": "処理時間計測",
        "resource_usage": "メモリ、CPU使用率",
        "pattern_analysis": "意思決定パターンの分類",
        "error_correlation": "エラーと決定の相関分析"
    }
    return self._add_analytics_layer(additional_metrics)