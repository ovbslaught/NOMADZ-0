# vulture_agent_analysis.py - Enhanced Version

class VultureAgentAnalysis:
    def __init__(self, decision_history):
        self.decision_history = decision_history
        self.branch_patterns = {}
        self.analysis_results = {}
    
    def analyze_by_branch_pattern(self):
        """Group decisions by branch_pattern and calculate success rates"""
        pattern_analysis = {}
        
        for decision in self.decision_history:
            branch_pattern = decision.get('branch_pattern', 'default')
            
            if branch_pattern not in pattern_analysis:
                pattern_analysis[branch_pattern] = {
                    'count': 0,
                    'successful_decisions': 0,
                    'total_success_rate': 0,
                    'recent_success_rate': 0,
                    'decision_examples': []
                }
            
            # Update counters
            pattern_data = pattern_analysis[branch_pattern]
            pattern_data['count'] += 1
            pattern_data['total_success_rate'] += decision.get('success_rate', 0)
            
            # Track successful decisions
            if decision.get('success_rate', 0) > 0.7:  # Threshold for success
                pattern_data['successful_decisions'] += 1
            
            # Store recent examples (limit to 5)
            if len(pattern_data['decision_examples']) < 5:
                pattern_data['decision_examples'].append({
                    'timestamp': decision.get('timestamp'),
                    'success_rate': decision.get('success_rate', 0),
                    'context': decision.get('context', {})
                })
        
        # Calculate averages and metrics
        for pattern, data in pattern_analysis.items():
            if data['count'] > 0:
                data['average_success_rate'] = data['total_success_rate'] / data['count']
                data['success_ratio'] = data['successful_decisions'] / data['count']
                
                # Calculate confidence score
                data['confidence_score'] = self._calculate_confidence_score(data)
        
        self.branch_patterns = pattern_analysis
        return pattern_analysis
    
    def _calculate_confidence_score(self, pattern_data):
        """Calculate confidence score based on sample size and consistency"""
        base_confidence = pattern_data['average_success_rate']
        sample_size_boost = min(1.0, pattern_data['count'] / 50)  # Boost for more samples
        consistency_penalty = self._calculate_consistency_penalty(pattern_data)
        
        confidence = base_confidence * (0.7 + 0.3 * sample_size_boost) - consistency_penalty
        return max(0, min(1, confidence))
    
    def _calculate_consistency_penalty(self, pattern_data):
        """Calculate penalty based on success rate variance"""
        # Simple implementation - can be enhanced with actual variance calculation
        success_ratio = pattern_data['success_ratio']
        if success_ratio > 0.8 or success_ratio < 0.2:
            return 0  # Consistent performance (high or low)
        else:
            return 0.2  # Inconsistent performance penalty
    
    def run_analysis(self):
        """Run comprehensive analysis including branch pattern analysis"""
        # Existing analyses
        basic_stats = self._calculate_basic_statistics()
        temporal_analysis = self._analyze_temporal_patterns()
        
        # New branch pattern analysis
        branch_analysis = self.analyze_by_branch_pattern()
        
        # Integration of all analyses
        self.analysis_results = {
            'basic_statistics': basic_stats,
            'temporal_patterns': temporal_analysis,
            'branch_pattern_analysis': branch_analysis,
            'recommendations': self._generate_recommendations(branch_analysis),
            'analysis_timestamp': self._get_current_timestamp(),
            'total_decisions_analyzed': len(self.decision_history)
        }
        
        return self.analysis_results
    
    def _generate_recommendations(self, branch_analysis):
        """Generate actionable recommendations based on branch pattern analysis"""
        recommendations = []
        
        # Find best performing patterns
        successful_patterns = []
        for pattern, data in branch_analysis.items():
            if data['count'] >= 5 and data['average_success_rate'] > 0.7:
                successful_patterns.append((pattern, data['average_success_rate']))
        
        # Sort by success rate
        successful_patterns.sort(key=lambda x: x[1], reverse=True)
        
        if successful_patterns:
            recommendations.append({
                'type': 'leverage_successful_patterns',
                'patterns': successful_patterns[:3],  # Top 3
                'confidence': 'high'
            })
        
        # Identify patterns to avoid
        poor_patterns = []
        for pattern, data in branch_analysis.items():
            if data['count'] >= 3 and data['average_success_rate'] < 0.3:
                poor_patterns.append((pattern, data['average_success_rate']))
        
        if poor_patterns:
            recommendations.append({
                'type': 'avoid_poor_patterns',
                'patterns': poor_patterns,
                'confidence': 'medium'
            })
        
        # Suggest pattern experimentation
        underutilized_patterns = []
        for pattern, data in branch_analysis.items():
            if data['count'] < 5 and data.get('success_ratio', 0) > 0.5:
                underutilized_patterns.append(pattern)
        
        if underutilized_patterns:
            recommendations.append({
                'type': 'experiment_with_patterns',
                'patterns': underutilized_patterns,
                'reason': 'Limited data but promising initial results'
            })
        
        return recommendations
    
    def _calculate_basic_statistics(self):
        """Calculate basic decision statistics"""
        # Implementation details...
        pass
    
    def _analyze_temporal_patterns(self):
        """Analyze temporal patterns in decisions"""
        # Implementation details...
        pass
    
    def _get_current_timestamp(self):
        """Get current timestamp"""
        from datetime import datetime
        return datetime.now().isoformat()

# Enhanced Decision Recording with Branch Pattern Tracking
class EnhancedDecisionRecorder:
    def __init__(self):
        self.decision_history = []
    
    def record_decision_with_pattern(self, decision_data, branch_pattern, context):
        """Record decision with branch pattern information"""
        enhanced_decision = {
            **decision_data,
            'branch_pattern': branch_pattern,
            'context': context,
            'timestamp': self._get_current_timestamp(),
            'pattern_metadata': self._extract_pattern_metadata(branch_pattern, context)
        }
        
        self.decision_history.append(enhanced_decision)
        return enhanced_decision
    
    def _extract_pattern_metadata(self, branch_pattern, context):
        """Extract metadata for pattern analysis"""
        return {
            'pattern_complexity': self._calculate_pattern_complexity(branch_pattern),
            'context_relevance': self._assess_context_relevance(branch_pattern, context),
            'execution_environment': self._get_environment_context()
        }
    
    def _calculate_pattern_complexity(self, branch_pattern):
        """Calculate complexity of the branch pattern"""
        # Simple implementation - count decision points
        complexity = branch_pattern.count('->') + branch_pattern.count('|')
        return min(1.0, complexity / 10)  # Normalize to 0-1
    
    def _assess_context_relevance(self, branch_pattern, context):
        """Assess how well the pattern matches the context"""
        # Implementation for context matching
        return 0.8  # Placeholder
    
    def _get_environment_context(self):
        """Get execution environment context"""
        return {
            'system_load': 0.6,  # Placeholder
            'available_resources': 'high',
            'time_constraints': 'normal'
        }

# Integration with Existing Improvement Engine
def integrate_branch_analysis(improvement_engine):
    """Integrate branch pattern analysis with the improvement engine"""
    
    # Create enhanced recorder
    enhanced_recorder = EnhancedDecisionRecorder()
    
    # Override decision recording to include branch patterns
    original_record_decision = improvement_engine.record_decision
    
    def enhanced_record_decision(decision_type, data, branch_pattern=None, context=None):
        if branch_pattern is None:
            branch_pattern = infer_branch_pattern(data)
        
        enhanced_data = enhanced_recorder.record_decision_with_pattern(
            data, branch_pattern, context or {}
        )
        
        # Call original method
        original_record_decision(decision_type, enhanced_data)
        
        return enhanced_data
    
    improvement_engine.record_decision = enhanced_record_decision
    
    # Add analysis capability
    improvement_engine.analyze_branch_patterns = lambda: VultureAgentAnalysis(
        enhanced_recorder.decision_history
    ).run_analysis()
    
    return improvement_engine

def infer_branch_pattern(decision_data):
    """Infer branch pattern from decision data"""
    # Simple pattern inference based on decision characteristics
    decision_type = decision_data.get('type', '')
    success_rate = decision_data.get('success_rate', 0)
    
    if 'improvement' in decision_type:
        if success_rate > 0.7:
            return "improvement_high_success"
        else:
            return "improvement_low_success"
    elif 'error' in decision_type:
        return "error_handling"
    else:
        return "general_decision"

# Usage Example
def main():
    """Example usage of the enhanced analysis system"""
    
    # Initialize the improvement engine
    engine = ContinuousImprovementEngine()
    
    # Integrate branch pattern analysis
    enhanced_engine = integrate_branch_analysis(engine)
    
    # Record some decisions with branch patterns
    enhanced_engine.record_decision(
        "performance_improvement",
        {"success_rate": 0.85, "impact": "high"},
        branch_pattern="optimization->measurement->validation",
        context={"system_load": 0.8, "user_count": 150}
    )
    
    # Run analysis
    analysis_results = enhanced_engine.analyze_branch_patterns()
    
    print("Branch Pattern Analysis Results:")
    print(f"Total patterns analyzed: {len(analysis_results['branch_pattern_analysis'])}")
    print(f"Recommendations: {analysis_results['recommendations']}")

if __name__ == "__main__":
    main()