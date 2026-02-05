# vulture_agent_analysis.py

def analyze_by_branch_pattern(decision_history):
    """
    Analyze the decision history by grouping by branch_pattern and calculating average success rate.
    
    Args:
        decision_history (list): List of decision records (dicts)
        
    Returns:
        dict: A dictionary keyed by branch_pattern with average success rate and count.
    """
    pattern_groups = {}
    for decision in decision_history:
        pattern = decision.get('branch_pattern')
        if pattern is None:
            continue
        success_rate = decision.get('success_rate')
        if success_rate is None:
            continue
            
        if pattern not in pattern_groups:
            pattern_groups[pattern] = {'total_success': 0, 'count': 0}
        
        pattern_groups[pattern]['total_success'] += success_rate
        pattern_groups[pattern]['count'] += 1
    
    # Calculate average for each pattern
    result = {}
    for pattern, data in pattern_groups.items():
        result[pattern] = {
            'average_success_rate': data['total_success'] / data['count'],
            'count': data['count']
        }
    
    return result

# Assume the existing run_analysis function looks something like this:
def run_analysis(decision_history):
    """
    Run various analyses on the decision history.
    
    Args:
        decision_history (list): List of decision records.
        
    Returns:
        dict: A dictionary containing different analysis results.
    """
    analyses = {}
    
    # Existing analyses...
    # ...
    
    # New analysis: by branch pattern
    analyses['by_branch_pattern'] = analyze_by_branch_pattern(decision_history)
    
    return analyses