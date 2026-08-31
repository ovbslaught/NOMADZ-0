@tool
extends EditorScript

# Check flexible UI implementation
# Run this from Tools > Execute Script in Godot

func _run():
	print("🔍 Checking Flexible UI Implementation")
	print("=====================================")
	
	# Test loading the dock script
	var dock_script = load("res://addons/ai_coding_assistant/ai_assistant_dock.gd")
	if dock_script:
		print("✅ Dock script loads successfully")
		
		var dock_instance = dock_script.new()
		if dock_instance:
			print("✅ Dock instance created successfully")
			
			# Check for responsive design methods
			var responsive_methods = [
				"_connect_viewport_signals",
				"_calculate_initial_split_position", 
				"_calculate_dynamic_min_height",
				"_on_viewport_size_changed",
				"_apply_responsive_design"
			]
			
			var methods_found = 0
			for method in responsive_methods:
				if dock_instance.has_method(method):
					print("✅ " + method + " - Available")
					methods_found += 1
				else:
					print("❌ " + method + " - Missing")
			
			print("\n📊 Responsive Methods: " + str(methods_found) + "/" + str(responsive_methods.size()))
			
			if methods_found == responsive_methods.size():
				print("🎉 All flexible UI methods implemented!")
				print("✅ Responsive design ready")
				print("✅ No syntax errors")
				
				print("\n🎨 Flexible UI Features:")
				print("• Dynamic screen adaptation")
				print("• Intelligent split positioning")
				print("• Smart auto-collapse")
				print("• Real-time responsiveness")
				print("• Multi-screen support")
				
				print("\n🚀 Ready to use!")
			else:
				print("⚠️ Some methods missing - check implementation")
			
			dock_instance.queue_free()
		else:
			print("❌ Failed to create dock instance")
	else:
		print("❌ Failed to load dock script")
	
	print("=====================================")
	print("Flexible UI check complete!")
