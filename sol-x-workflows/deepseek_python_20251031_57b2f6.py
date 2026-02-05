# pattern_decision_router.py
"""
Pattern-Based Decision Routing System
"""

class PatternBasedDecisionRouter:
    def __init__(self):
        self.routing_rules = {}
        self.pattern_success_rates = {}
        self.context_pattern_map = {}
        
    def route_decision(self, decision_context, available_options):
        """Route decision to best pattern based on context and history"""
        
        # 1. Analyze context
        context_analysis = self._analyze_decision_context(decision_context)
        
        # 2. Find matching patterns
        candidate_patterns = self._find_candidate_patterns(context_analysis)
        
        # 3. Score and rank patterns
        ranked_patterns = self._rank_patterns_by_effectiveness(
            candidate_patterns, context_analysis
        )
        
        # 4. Select best pattern
        selected_pattern = self._select_optimal_pattern(ranked_patterns)
        
        # 5. Apply pattern to decision
        decision_result = self._apply_pattern_to_decision(
            selected_pattern, decision_context, available_options
        )
        
        # 6. Prepare for learning
        self._queue_for_learning(decision_context, selected_pattern, decision_result)
        
        return {
            "decision": decision_result,
            "selected_pattern": selected_pattern,
            "pattern_confidence": ranked_patterns[0]["confidence"],
            "alternative_patterns": ranked_patterns[1:3]
        }
    
    def update_routing_rules(self, pattern_analysis):
        """Update routing rules based on latest analysis"""
        
        for pattern, data in pattern_analysis.items():
            success_rate = data.get('average_success_rate', 0.5)
            confidence = data.get('confidence_score', 0.5)
            
            # Update success rates
            self.pattern_success_rates[pattern] = {
                'success_rate': success_rate,
                'confidence': confidence,
                'sample_size': data.get('count', 0),
                'last_updated': datetime.now()
            }
            
            # Extract context patterns from successful decisions
            successful_decisions = [
                ex for ex in data.get('decision_examples', [])
                if ex.get('success_rate', 0) > 0.7
            ]
            
            for decision in successful_decisions:
                context_features = self._extract_context_features(
                    decision.get('context', {})
                )
                self._update_context_pattern_map(pattern, context_features)
    
    def _find_candidate_patterns(self, context_analysis):
        """Find patterns that match the current context"""
        candidates = []
        
        for pattern, pattern_data in self.pattern_success_rates.items():
            context_match_score = self._calculate_context_match(
                pattern, context_analysis
            )
            
            if context_match_score > 0.3:  # Minimum threshold
                candidates.append({
                    "pattern": pattern,
                    "context_match": context_match_score,
                    "success_rate": pattern_data["success_rate"],
                    "confidence": pattern_data["confidence"],
                    "composite_score": self._calculate_composite_score(
                        context_match_score,
                        pattern_data["success_rate"],
                        pattern_data["confidence"]
                    )
                })
        
        return sorted(candidates, key=lambda x: x["composite_score"], reverse=True)
    
    def _calculate_composite_score(self, context_match, success_rate, confidence):
        """Calculate composite score for pattern selection"""
        return (
            context_match * 0.4 +
            success_rate * 0.4 + 
            confidence * 0.2
        )