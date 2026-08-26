@tool
extends EditorScript

func _run():
	print("--- PROBE START ---")
	var interface = get_editor_interface()
	var base = interface.get_base_control()
	
	print("Root name: ", base.name)
	
	# Try usage of find_children
	var outputs = base.find_children("*Output*", "Control", true, false)
	for node in outputs:
		print("Found Output candidate: ", node.name, " (", node.get_class(), ")")
		print("  Path: ", node.get_path())
		if node is RichTextLabel:
			print("  [Is RichTextLabel!]")
			print("  Text Peek: ", node.get_parsed_text().substr(0, 50).replace("\n", " "))
			
	var debuggers = base.find_children("*Debug*", "Control", true, false)
	for node in debuggers:
		print("Found Debugger candidate: ", node.name, " (", node.get_class(), ")")
		print("  Path: ", node.get_path())
		if node is Tree:
			print("  [Is Tree!]")
			
	# Look for RichTextLabel specifically if not found above
	var rtls = base.find_children("*", "RichTextLabel", true, false)
	for node in rtls:
		if node.get_parent().name == "Output":
			print("Found standard Output Log RTL: ", node.get_path())
			
	print("--- PROBE END ---")

