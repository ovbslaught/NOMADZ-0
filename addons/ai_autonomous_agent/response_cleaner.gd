class_name ResponseCleaner

const think_open_tag:= "<think>"
const think_close_tag:= "</think>"

static func clean(original_text:String) -> String:
	return remove_think_tags(original_text)


## Removes text between <think> </think>, which some models like deepseek-r1 include.
static func remove_think_tags(original_text:String) -> String:
	var think_target:AIHubPlugin.ThinkingTargets = ProjectSettings.get_setting(AIHubPlugin.PREF_REMOVE_THINK, AIHubPlugin.ThinkingTargets.Output)
	if think_target == AIHubPlugin.ThinkingTargets.Chat:
		return original_text
		
	var think_o:int = original_text.find(think_open_tag)
	var think_c:int = original_text.find(think_close_tag)
	if think_o >= 0 and think_c > think_o:
		var prefix :String = original_text.substr(0, think_o)
		var suffix :String = original_text.substr(think_c + think_close_tag.length(), original_text.length()) 
		var think_content:String = original_text.substr(think_o + think_open_tag.length(), think_c - think_o - think_close_tag.length() + 1)
		if not think_content.is_empty() and think_target == AIHubPlugin.ThinkingTargets.Output:
			print("[AI assistant thinking process]:\n%s" % think_content)
		return remove_think_tags(prefix + suffix)
	return original_text.strip_edges(true)

