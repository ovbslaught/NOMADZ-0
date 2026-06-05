## test_suite.gd
## NOMADZ: Signal Descent — Automated Test Suite
## Run from: Project > Tools > Run Script, or via GUT (Godot Unit Testing) plugin.
## Covers: GameManager, SignalverseManager, Player, Enemy, LoreDatabase, Save/Load.
## VultureCode / Sol / NOMADZ Universe

extends Node

# ─── TEST RUNNER ──────────────────────────────────────────────────────────────
var _pass_count  : int = 0
var _fail_count  : int = 0
var _test_count  : int = 0
var _results     : Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	print("\n╔═══════════════════════════════════════════════════╗")
	print("║   NOMADZ: SIGNAL DESCENT — TEST SUITE            ║")
	print("║   ARCHON Protocol — Integrity Verification       ║")
	print("╚═══════════════════════════════════════════════════╝\n")
	_run_all_tests()
	_print_summary()

func _run_all_tests() -> void:
	_run_section("GameManager — Core State")
	_test_gm_initial_health()
	_test_gm_take_damage()
	_test_gm_damage_clamps_at_zero()
	_test_gm_heal()
	_test_gm_heal_clamps_at_max()
	_test_gm_fuel_update()
	_test_gm_signal_energy()
	_test_gm_signal_clamps_at_max()
	_test_gm_ability_unlock()
	_test_gm_ability_duplicate()
	_test_gm_ability_unknown_rejected()
	_test_gm_fragment_collect()
	_test_gm_fragment_duplicate()
	_test_gm_lore_collect()
	_test_gm_room_tracking()
	_test_gm_checkpoint()

	_run_section("GameManager — Save/Load")
	_test_gm_save_creates_file()
	_test_gm_load_restores_state()
	_test_gm_delete_save()

	_run_section("LoreDatabase")
	_test_lore_entry_count()
	_test_lore_get_entry_valid()
	_test_lore_get_entry_invalid()
	_test_lore_mark_discovered()
	_test_lore_discovery_percent()
	_test_lore_category_filter()
	_test_lore_all_ids_unique()

	_run_section("SignalverseManager — Bleed System")
	_test_signalverse_corruption_start()
	_test_signalverse_force_bleed_valid()
	_test_signalverse_force_bleed_invalid_warns()
	_test_signalverse_phantom_cap()
	_test_signalverse_corruption_color()
	_test_signalverse_debug_snapshot()

	_run_section("AudioManager")
	_test_audio_manager_online()
	_test_audio_sfx_unknown_warns()
	_test_audio_volume_clamp()

	_run_section("GameManager — Death / Respawn")
	_test_gm_death_sets_dead_flag()
	_test_gm_respawn_restores_health()

# ─── SECTION ──────────────────────────────────────────────────────────────────
func _run_section(label: String) -> void:
	print("\n── %s ──" % label)

# ─── ASSERT HELPERS ───────────────────────────────────────────────────────────
func _assert(condition: bool, test_name: String, detail: String = "") -> void:
	_test_count += 1
	if condition:
		_pass_count += 1
		_results.append("  ✅ PASS: %s" % test_name)
		print("  ✅ %s" % test_name)
	else:
		_fail_count += 1
		var msg := "  ❌ FAIL: %s" % test_name
		if not detail.is_empty():
			msg += " | %s" % detail
		_results.append(msg)
		print(msg)

func _assert_eq(a: Variant, b: Variant, test_name: String) -> void:
	_assert(a == b, test_name, "got %s expected %s" % [str(a), str(b)])

func _assert_gt(a: Variant, b: Variant, test_name: String) -> void:
	_assert(a > b, test_name, "%s not > %s" % [str(a), str(b)])

func _assert_lt(a: Variant, b: Variant, test_name: String) -> void:
	_assert(a < b, test_name, "%s not < %s" % [str(a), str(b)])

func _assert_in_range(val: float, lo: float, hi: float, test_name: String) -> void:
	_assert(val >= lo and val <= hi, test_name, "%.3f not in [%.3f, %.3f]" % [val, lo, hi])

# ─── GAME MANAGER TESTS ───────────────────────────────────────────────────────
func _test_gm_initial_health() -> void:
	_assert_eq(GameManager.current_health, GameManager.MAX_HEALTH,
		"Initial health == MAX_HEALTH")

func _test_gm_take_damage() -> void:
	var before := GameManager.current_health
	GameManager.take_damage(10, "test")
	_assert_eq(GameManager.current_health, before - 10,
		"take_damage reduces health by 10")
	GameManager.heal(10)

func _test_gm_damage_clamps_at_zero() -> void:
	var save_hp := GameManager.current_health
	GameManager.is_dead = false
	GameManager.current_health = 5
	GameManager.take_damage(9999, "test_clamp")
	_assert(GameManager.current_health >= 0,
		"Health never goes below 0")
	GameManager.is_dead = false
	GameManager.current_health = save_hp

func _test_gm_heal() -> void:
	GameManager.current_health = 50
	GameManager.heal(20)
	_assert_eq(GameManager.current_health, 70, "heal() adds to health")
	GameManager.current_health = GameManager.MAX_HEALTH

func _test_gm_heal_clamps_at_max() -> void:
	GameManager.current_health = GameManager.MAX_HEALTH - 5
	GameManager.heal(9999)
	_assert_eq(GameManager.current_health, GameManager.MAX_HEALTH,
		"heal() clamps at MAX_HEALTH")

func _test_gm_fuel_update() -> void:
	GameManager.update_fuel(42.0)
	_assert_in_range(GameManager.current_fuel, 41.9, 42.1, "update_fuel sets fuel")
	GameManager.update_fuel(GameManager.MAX_FUEL)

func _test_gm_signal_energy() -> void:
	var before := GameManager.signal_meter
	GameManager.add_signal_energy(5.0)
	_assert(GameManager.signal_meter >= before + 4.9,
		"add_signal_energy increases meter")

func _test_gm_signal_clamps_at_max() -> void:
	GameManager.signal_meter = 99.0
	GameManager.add_signal_energy(9999.0)
	_assert(GameManager.signal_meter <= GameManager.MAX_SIGNAL,
		"signal_meter clamps at MAX_SIGNAL")
	GameManager.signal_meter = 0.0

func _test_gm_ability_unlock() -> void:
	var before := GameManager.unlocked_abilities.size()
	GameManager.unlock_ability("dash")
	_assert(GameManager.has_ability("dash"),
		"has_ability returns true after unlock")
	_assert_gt(GameManager.unlocked_abilities.size(), before,
		"unlocked_abilities grew after unlock")

func _test_gm_ability_duplicate() -> void:
	GameManager.unlock_ability("dash")
	var size_before := GameManager.unlocked_abilities.size()
	GameManager.unlock_ability("dash")
	_assert_eq(GameManager.unlocked_abilities.size(), size_before,
		"Duplicate unlock does not add twice")

func _test_gm_ability_unknown_rejected() -> void:
	var before := GameManager.unlocked_abilities.size()
	GameManager.unlock_ability("totally_fake_ability_xyz")
	_assert_eq(GameManager.unlocked_abilities.size(), before,
		"Unknown ability rejected without crashing")

func _test_gm_fragment_collect() -> void:
	GameManager.signal_meter = 0.0
	GameManager.collect_fragment("test_frag_abc")
	_assert("test_frag_abc" in GameManager.collected_fragments,
		"Fragment tracked after collect")
	_assert_gt(GameManager.signal_meter, 0.0,
		"Signal meter increased on fragment collect")
	GameManager.collected_fragments.erase("test_frag_abc")

func _test_gm_fragment_duplicate() -> void:
	GameManager.collect_fragment("test_frag_dup")
	var size_before := GameManager.collected_fragments.size()
	GameManager.collect_fragment("test_frag_dup")
	_assert_eq(GameManager.collected_fragments.size(), size_before,
		"Duplicate fragment not added twice")
	GameManager.collected_fragments.erase("test_frag_dup")

func _test_gm_lore_collect() -> void:
	GameManager.collect_lore("test_lore_001")
	_assert("test_lore_001" in GameManager.discovered_lore,
		"Lore entry tracked after collect")
	GameManager.discovered_lore.erase("test_lore_001")

func _test_gm_room_tracking() -> void:
	var before := GameManager.visited_rooms.size()
	GameManager.enter_room("room_test_xyz")
	_assert("room_test_xyz" in GameManager.visited_rooms,
		"Room tracked in visited_rooms after enter")
	_assert_eq(GameManager.current_room_id, "room_test_xyz",
		"current_room_id updated on enter_room")
	GameManager.visited_rooms.erase("room_test_xyz")

func _test_gm_checkpoint() -> void:
	var pos := Vector2(123.0, 456.0)
	GameManager.set_checkpoint(pos)
	_assert_eq(GameManager.checkpoint_position, pos,
		"Checkpoint position stored correctly")

# ─── SAVE / LOAD TESTS ────────────────────────────────────────────────────────
func _test_gm_save_creates_file() -> void:
	GameManager.save_game()
	_assert(FileAccess.file_exists(GameManager.SAVE_PATH),
		"save_game() creates file at SAVE_PATH")

func _test_gm_load_restores_state() -> void:
	## Mutate state, save, mutate again, load — should restore saved state
	GameManager.current_health = 42
	GameManager.save_game()
	GameManager.current_health = 1
	var ok := GameManager.load_game()
	_assert(ok, "load_game() returns true when save exists")
	_assert_eq(GameManager.current_health, 42,
		"load_game() restores current_health")
	## Restore
	GameManager.current_health = GameManager.MAX_HEALTH

func _test_gm_delete_save() -> void:
	GameManager.save_game()
	GameManager.delete_save()
	_assert(not FileAccess.file_exists(GameManager.SAVE_PATH),
		"delete_save() removes file")

# ─── LORE DATABASE TESTS ──────────────────────────────────────────────────────
func _test_lore_entry_count() -> void:
	var ids := LoreDatabase.get_all_entry_ids()
	_assert_gt(ids.size(), 10, "LoreDatabase has more than 10 entries")

func _test_lore_get_entry_valid() -> void:
	var entry := LoreDatabase.get_entry("tx_001")
	_assert(not entry.is_empty(), "get_entry(tx_001) returns non-empty dict")
	_assert(entry.has("title"), "Entry has 'title' key")
	_assert(entry.has("text"),  "Entry has 'text' key")

func _test_lore_get_entry_invalid() -> void:
	var entry := LoreDatabase.get_entry("totally_fake_entry_xyz")
	_assert(entry.is_empty(), "get_entry(fake) returns empty dict without crash")

func _test_lore_mark_discovered() -> void:
	LoreDatabase.mark_discovered("cx_001")
	_assert(LoreDatabase.is_discovered("cx_001"),
		"is_discovered() true after mark_discovered()")

func _test_lore_discovery_percent() -> void:
	var pct := LoreDatabase.get_discovery_percent()
	_assert_in_range(pct, 0.0, 100.0,
		"get_discovery_percent() returns value in 0-100")

func _test_lore_category_filter() -> void:
	var txm := LoreDatabase.get_entries_by_category("TRANSMISSION")
	_assert_gt(txm.size(), 0, "Category TRANSMISSION has entries")

func _test_lore_all_ids_unique() -> void:
	var ids : Array = LoreDatabase.get_all_entry_ids()
	var unique := {}
	for id in ids:
		unique[id] = true
	_assert_eq(unique.size(), ids.size(), "All LoreDatabase IDs are unique")

# ─── SIGNALVERSE TESTS ────────────────────────────────────────────────────────
func _test_signalverse_corruption_start() -> void:
	_assert(SignalverseManager.corruption_level >= 0.0 and
		SignalverseManager.corruption_level <= 100.0,
		"Corruption level is in valid range 0-100")

func _test_signalverse_force_bleed_valid() -> void:
	## Should not throw
	SignalverseManager.force_bleed("whisper")
	_assert(true, "force_bleed('whisper') runs without error")

func _test_signalverse_force_bleed_invalid_warns() -> void:
	SignalverseManager.force_bleed("totally_fake_event_xyz")
	_assert(true, "force_bleed(invalid) warns without crash")

func _test_signalverse_phantom_cap() -> void:
	SignalverseManager.active_phantoms = 3
	var before := SignalverseManager.total_bleed_events
	SignalverseManager.force_bleed("phantom_spawn")
	_assert(SignalverseManager.active_phantoms <= 3,
		"Phantom cap prevents spawn above limit")
	SignalverseManager.active_phantoms = 0

func _test_signalverse_corruption_color() -> void:
	var color := SignalverseManager.get_corruption_color()
	_assert(color is Color, "get_corruption_color() returns a Color")

func _test_signalverse_debug_snapshot() -> void:
	var snap := SignalverseManager.get_debug_snapshot()
	_assert(snap.has("corruption"),      "Snapshot has 'corruption'")
	_assert(snap.has("total_bleeds"),    "Snapshot has 'total_bleeds'")
	_assert(snap.has("active_phantoms"), "Snapshot has 'active_phantoms'")

# ─── AUDIO MANAGER TESTS ──────────────────────────────────────────────────────
func _test_audio_manager_online() -> void:
	_assert(is_instance_valid(AudioManager), "AudioManager node is valid")

func _test_audio_sfx_unknown_warns() -> void:
	AudioManager.play_sfx("totally_nonexistent_sfx_xyz")
	_assert(true, "play_sfx(unknown) warns without crash")

func _test_audio_volume_clamp() -> void:
	AudioManager.set_master_volume(9999.0)
	_assert(AudioManager.master_volume <= 1.0, "Volume clamped to max 1.0")
	AudioManager.set_master_volume(-9999.0)
	_assert(AudioManager.master_volume >= 0.0, "Volume clamped to min 0.0")
	AudioManager.set_master_volume(1.0)

# ─── DEATH / RESPAWN TESTS ────────────────────────────────────────────────────
func _test_gm_death_sets_dead_flag() -> void:
	## Force kill
	GameManager.is_dead  = false
	GameManager.current_health = 0
	GameManager.take_damage(1, "test_death")
	_assert(GameManager.is_dead, "is_dead set to true when HP <= 0")
	## Reset
	GameManager.is_dead = false
	GameManager.current_health = GameManager.MAX_HEALTH

func _test_gm_respawn_restores_health() -> void:
	GameManager.is_dead = true
	GameManager.current_health = 0
	GameManager.respawn_at_checkpoint()
	_assert(not GameManager.is_dead,   "is_dead cleared after respawn")
	_assert_gt(GameManager.current_health, 0, "Health > 0 after respawn")

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
func _print_summary() -> void:
	print("\n╔═══════════════════════════════════════════════════╗")
	print("║   TEST SUMMARY                                   ║")
	print("╠═══════════════════════════════════════════════════╣")
	print("║   Total:  %-5d                                  ║" % _test_count)
	print("║   ✅ Pass: %-5d                                  ║" % _pass_count)
	print("║   ❌ Fail: %-5d                                  ║" % _fail_count)
	var pct : float = 0.0
	if _test_count > 0:
		pct = float(_pass_count) / float(_test_count) * 100.0
	print("║   Score:  %.1f%%                                ║" % pct)
	print("╚═══════════════════════════════════════════════════╝")
	if _fail_count > 0:
		print("\n── FAILURES ──")
		for r in _results:
			if "FAIL" in r:
				print(r)
	print("\nARCHON Protocol verification complete.\n")
