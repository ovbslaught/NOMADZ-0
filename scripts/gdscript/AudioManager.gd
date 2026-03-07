# AudioManager.gd - Autoload audio controller
extends Node

const BGM_LAYER_COUNT = 4

var bgm_players: Array[AudioStreamPlayer] = []
var sfx_pool: Dictionary = {}

func _ready():
    for i in BGM_LAYER_COUNT:
        var player = AudioStreamPlayer.new()
        player.bus = "BGM"
        add_child(player)
        bgm_players.append(player)

func play_sfx(sound_name: String, volume_db: float = 0.0) -> void:
    if sound_name in sfx_pool:
        var player: AudioStreamPlayer = sfx_pool[sound_name]
        player.volume_db = volume_db
        player.play()
    else:
        push_warning("AudioManager: SFX not found: " + sound_name)

func set_bgm_layer(layer: int, stream: AudioStream, fade_time: float = 1.0) -> void:
    if layer >= BGM_LAYER_COUNT:
        return
    var player = bgm_players[layer]
    if player.playing:
        var tween = create_tween()
        tween.tween_property(player, "volume_db", -80.0, fade_time)
        await tween.finished
    player.stream = stream
    player.volume_db = 0.0
    player.play()

func stop_all_bgm(fade_time: float = 1.0) -> void:
    for player in bgm_players:
        if player.playing:
            var tween = create_tween()
            tween.tween_property(player, "volume_db", -80.0, fade_time)
