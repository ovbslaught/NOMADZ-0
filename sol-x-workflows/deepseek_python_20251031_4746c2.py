# pattern_taxonomy.py
"""
Comprehensive Branch Pattern Taxonomy for AI Decision Systems
"""

class BranchPatternTaxonomy:
    def __init__(self):
        self.taxonomy = self._build_comprehensive_taxonomy()
        
    def _build_comprehensive_taxonomy(self):
        """Build comprehensive pattern taxonomy"""
        return {
            # Decision Strategy Patterns
            "decision_strategies": {
                "analytical": {
                    "deep_analysis": "Comprehensive multi-factor analysis",
                    "quick_assessment": "Rapid initial assessment", 
                    "pattern_matching": "Match to known patterns",
                    "cost_benefit": "Explicit cost-benefit analysis"
                },
                "intuitive": {
                    "gut_feeling": "Intuitive first impression",
                    "experience_based": "Leverage past experiences", 
                    "heuristic": "Rule-of-thumb approach",
                    "creative_leap": "Innovative non-linear thinking"
                },
                "collaborative": {
                    "consensus_building": "Build agreement among options",
                    "expert_consultation": "Consult specialized knowledge",
                    "crowd_wisdom": "Leverage collective intelligence", 
                    "human_ai_partnership": "Human-AI collaborative decision"
                }
            },
            
            # Problem Solving Patterns  
            "problem_solving": {
                "divide_conquer": "Break into subproblems",
                "abstraction": "Work at higher abstraction level",
                "analogy": "Apply solutions from similar problems",
                "incremental": "Step-by-step improvement",
                "transformational": "Radically reframe the problem"
            },
            
            # Risk Management Patterns
            "risk_management": {
                "risk_averse": "Minimize potential downsides", 
                "risk_seeking": "Prioritize potential upsides",
                "hedged_bets": "Diversify across options",
                "fail_fast": "Rapid experimentation with quick failure",
                "conservative_iteration": "Small, safe steps forward"
            },
            
            # STORYVERSE Specific Patterns
            "storyverse_specific": {
                "character_interaction": {
                    "emotional_support": "Cope-style emotional intelligence",
                    "technical_analysis": "Bytez-style data processing", 
                    "interface_mediation": "Proxy-style routing",
                    "memory_integration": "Echo-style pattern recall"
                },
                "narrative_management": {
                    "plot_progression": "Advance main story elements",
                    "character_development": "Deepen character arcs",
                    "world_building": "Expand universe details",
                    "pacing_control": "Manage narrative tempo"
                }
            },
            
            # Error Recovery Patterns
            "error_recovery": {
                "retry_simple": "Simple retry with same parameters",
                "retry_with_backoff": "Progressive retry with delays", 
                "alternative_approach": "Try completely different method",
                "graceful_degradation": "Reduce functionality but maintain operation",
                "fallback_mechanism": "Switch to backup system"
            }
        }
    
    def classify_decision_pattern(self, decision_context, decision_data):
        """Classify a decision into the taxonomy"""
        classification = {
            "primary_strategy": None,
            "secondary_strategies": [],
            "risk_profile": None,
            "complexity_level": None,
            "taxonomy_path": []
        }
        
        # Analyze decision characteristics
        characteristics = self._analyze_decision_characteristics(decision_context, decision_data)
        
        # Map to taxonomy
        for category, patterns in self.taxonomy.items():
            for pattern_name, pattern_desc in patterns.items():
                if isinstance(pattern_desc, dict):
                    # Nested patterns
                    for sub_pattern, sub_desc in pattern_desc.items():
                        if self._pattern_matches(characteristics, sub_pattern):
                            classification["secondary_strategies"].append(
                                f"{category}.{pattern_name}.{sub_pattern}"
                            )
                else:
                    if self._pattern_matches(characteristics, pattern_name):
                        if not classification["primary_strategy"]:
                            classification["primary_strategy"] = f"{category}.{pattern_name}"
                        else:
                            classification["secondary_strategies"].append(f"{category}.{pattern_name}")
        
        return classification
    
    def get_recommended_patterns(self, context, desired_outcome):
        """Get recommended patterns for given context and desired outcome"""
        recommendations = []
        
        # Score patterns based on context fit and historical success
        for category, patterns in self.taxonomy.items():
            for pattern_name, pattern_desc in patterns.items():
                score = self._calculate_pattern_score(
                    pattern_name, context, desired_outcome
                )
                
                if score > 0.7:  # High relevance threshold
                    recommendations.append({
                        "pattern": f"{category}.{pattern_name}",
                        "score": score,
                        "description": pattern_desc,
                        "expected_success": self._get_historical_success_rate(
                            f"{category}.{pattern_name}", context
                        )
                    })
        
        return sorted(recommendations, key=lambda x: x["score"], reverse=True)[:5]