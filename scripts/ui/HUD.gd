extends CanvasLayer

@export var ocean_fx_rect: ColorRect
@export var vulture_warning_rect: ColorRect
@export var health_bar: ProgressBar

func _ready() -> void:
    # Ensure this node is in the HUD group so systems can find it
    add_to_group("HUD")
    
    # Reset visuals on boot
    if ocean_fx_rect:
        ocean_fx_rect.visible = false
    
    if vulture_warning_rect:
        vulture_warning_rect.visible = false
        vulture_warning_rect.modulate.a = 0.0

# Called by OceanMatrix.gd when entering/exiting the fluid volume
func toggle_ocean_fx(is_submerged: bool) -> void:
    if ocean_fx_rect:
        ocean_fx_rect.visible = is_submerged
        print("[HUD] Ocean FX set to: ", is_submerged)

# Called by VultureMonitor.gd when tension breaches the threshold
func flash_vulture_warning() -> void:
    if not vulture_warning_rect:
        return
        
    print("[HUD] Rendering Vulture Anomaly Warning!")
    vulture_warning_rect.visible = true
    vulture_warning_rect.color = Color(1.0, 0.0, 0.0, 1.0) # Crimson Red
    
    # Animate a harsh system flash
    var tween = create_tween()
    tween.tween_property(vulture_warning_rect, "modulate:a", 0.4, 0.1)
    tween.tween_property(vulture_warning_rect, "modulate:a", 0.0, 0.5)
    tween.tween_callback(func(): vulture_warning_rect.visible = false)

# Called by PlayerController when taking damage or healing
func update_health(current: float, max_val: float) -> void:
    if health_bar:
        health_bar.max_value = max_val
        
        # Smoothly animate the health bar dropping
        var tween = create_tween()
        tween.tween_property(health_bar, "value", current, 0.2).set_trans(Tween.TRANS_SINE)
        
        # Change color based on health status (Green -> Yellow -> Red)
        var ratio = current / max_val
        var sb = StyleBoxFlat.new()
        if ratio > 0.5:
            sb.bg_color = Color("00ffcc") # Neon Cyan
        elif ratio > 0.25:
            sb.bg_color = Color("ffcc00") # Warning Yellow
        else:
            sb.bg_color = Color("ff0033") # Critical Red
            
        health_bar.add_theme_stylebox_override("fill", sb)
