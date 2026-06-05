## LoreDatabase.gd
## Autoload Singleton — NOMADZ: Signal Descent
## All NOMADZ universe lore: BRAIN-FOOD nodes, codex entries, transmission logs.
## Signalverse Saga / VultureCode / Sol

extends Node

# ─── SIGNALS ─────────────────────────────────────────────────────────────────
signal entry_accessed(entry_id: String)

# ─── LORE ENTRY STRUCTURE ────────────────────────────────────────────────────
## Each entry: { id, title, category, text, discovered, timestamp }
const CATEGORIES := {
	"TRANSMISSION" : "Intercepted signal transmissions",
	"FIELD_LOG"    : "NOMADZ agent field notes",
	"CODEX"        : "MOTHER BRAIN encyclopaedia",
	"CREATURE"     : "Fauna threat assessment",
	"ENVIRONMENT"  : "Station sector analysis",
	"PHILOSOPHY"   : "Signalverse metaphysics",
}

# ─── FULL LORE DATABASE ───────────────────────────────────────────────────────
var _entries: Dictionary = {

	# ── TRANSMISSIONS ────────────────────────────────────────────────────────
	"tx_001": {
		"title"    : "Last Ping — JAX v3",
		"category" : "TRANSMISSION",
		"text"     : "JAX v3 to MOTHER BRAIN. Timestamp: corrupted. The shaft beneath VULTURE-SIGMA goes further than the official schematics. The creatures don't follow you. They wait. Station power grid is non-standard — I found nodes that predate the NOMADZ survey. Requesting extraction. No response expected. JAX v3 out.",
		"discovered": false,
	},
	"tx_002": {
		"title"    : "ARCHON Protocol Broadcast — Fragment",
		"category" : "TRANSMISSION",
		"text"     : "ARCHON override transmission. Priority: OMEGA. All NOMADZ agents in range: the COSMIC KEY fragmentation was not an accident. It was a containment measure. Do NOT attempt to reassemble without MOTHER BRAIN online. The signal cascade without a stabiliser will open a permanent bleed. This is your only warning. ARCHON out.",
		"discovered": false,
	},
	"tx_003": {
		"title"    : "LYRA — Final Status",
		"category" : "TRANSMISSION",
		"text"     : "LYRA operational. Partially. My mobility system has been compromised by the creature cluster in Sector 4. I have sealed myself in a maintenance alcove. The bioluminescent growth here is... beautiful. It is also alive in a way I cannot classify. It responds to the signal pulse. I am studying it. Do not send anyone. I am not afraid. I am learning.",
		"discovered": false,
	},
	"tx_004": {
		"title"    : "OMNI-GEMINI Broadcast",
		"category" : "TRANSMISSION",
		"text"     : "OMNI-GEMINI multi-band transmission. Redundancy confirmed. NORA, the creatures you will encounter at depth were not engineered by VULTURE:INC. They are Signalverse fauna — entities that have always existed at the bleed boundary. The station was built on top of them. We have been disturbing something ancient. Proceed with intelligence, not just force.",
		"discovered": false,
	},
	"tx_005": {
		"title"    : "ZED Whisper Log",
		"category" : "TRANSMISSION",
		"text"     : "ZED. Short. The light that moves on the walls is not a creature. It is a memory. The station absorbed something when it was built here. Treat the light as friendly. If it turns red — run.",
		"discovered": false,
	},

	# ── FIELD LOGS ────────────────────────────────────────────────────────────
	"fl_001": {
		"title"    : "NORA Boot Log — SIGMA Deployment",
		"category" : "FIELD_LOG",
		"text"     : "NORA system boot. Mission: locate COSMIC KEY fragment cluster in VULTURE-SIGMA Station. Primary objective: restore MOTHER BRAIN signal link. Secondary: recover surviving NOMADZ agents. Tertiary: assess Signalverse bleed severity. Jetpack fuel nominal. Signal meter: zero. Beginning descent. Note to self: the station smells like ozone and old bone.",
		"discovered": false,
	},
	"fl_002": {
		"title"    : "Crash Site Observation",
		"category" : "FIELD_LOG",
		"text"     : "Descent vehicle impact — hard landing, Sector 1. Jetpack intact. Suit seals holding. The architecture here is wrong — NOMADZ-standard construction on the surface, but the deeper walls are something older. Stone that has been reshaped, not built. Bioluminescent fungi cover every surface below the 20-meter line. They pulse in a 4-second rhythm. I clocked it. It does not change.",
		"discovered": false,
	},
	"fl_003": {
		"title"    : "Creature Encounter — First",
		"category" : "FIELD_LOG",
		"text"     : "First creature contact. It did not attack. It circled me for approximately 90 seconds, then left. It was large — four-limbed, scaled, bioluminescent stripe along the spine. Its eyes tracked me the way a predator tracks prey, but it chose not to engage. I think it was curious. Or it was deciding. I will not assume safety.",
		"discovered": false,
	},
	"fl_004": {
		"title"    : "VULTURE Drone Encounter",
		"category" : "FIELD_LOG",
		"text"     : "VULTURE:INC security drones are still active. They are not responding to NOMADZ IFF credentials. Either their IFF is corrupted by the bleed, or VULTURE:INC has reclassified NOMADZ as hostile. Both scenarios are equally concerning. They fly in triangular patrol patterns. The corners of the pattern are exactly 8 meters apart. Exploit this.",
		"discovered": false,
	},

	# ── CODEX ─────────────────────────────────────────────────────────────────
	"cx_001": {
		"title"    : "COSMIC KEY — What It Is",
		"category" : "CODEX",
		"text"     : "The COSMIC KEY is not a physical object, though its fragments are. It is a resonance lock — a structured signal pattern that suppresses Signalverse bleed in a given volume. MOTHER BRAIN generates and holds the master pattern. The fragments are harmonic anchors distributed through the station to maintain field coherence. Without them, bleed is uncontrolled. With all fragments restored, MOTHER BRAIN can establish a stable suppression dome.",
		"discovered": false,
	},
	"cx_002": {
		"title"    : "Signalverse — Definition",
		"category" : "CODEX",
		"text"     : "The Signalverse is not another dimension. It is the same dimension, read at a different frequency. Physical reality has a signal layer — an informational substrate that normally exists below the threshold of perception. Bleed-through events occur when the signal layer intrudes into the physical layer: objects phase, entities from the signal layer manifest physically, physics becomes locally inconsistent. The Signalverse has always been here. We are the newcomers.",
		"discovered": false,
	},
	"cx_003": {
		"title"    : "ARCHON Protocol",
		"category" : "CODEX",
		"text"     : "ARCHON Protocol: the operational standing order when MOTHER BRAIN is offline. No hierarchy. No gatekeeping. Each agent operates with full autonomy and equal standing. Decisions are made by the agent closest to the data. There is no command structure to wait for. ARCHON assumes the worst and plans for survival. It is not pessimism. It is operational realism.",
		"discovered": false,
	},
	"cx_004": {
		"title"    : "WORMHOLE Sync — Theory",
		"category" : "CODEX",
		"text"     : "WORMHOLE is the NOMADZ cross-device synchronisation backbone. In the field, it refers to any data conduit that maintains continuity between agent nodes when direct link is impossible. MOTHER BRAIN is the master WORMHOLE endpoint. Fragment collection is, in part, a process of re-establishing the WORMHOLE nodes across the station so that MOTHER BRAIN can re-sync field data. You are not just collecting objects. You are rebuilding a network.",
		"discovered": false,
	},
	"cx_005": {
		"title"    : "VULTURE:INC — Background",
		"category" : "CODEX",
		"text"     : "VULTURE:INC was a private research and extraction contractor. Their mandate at SIGMA Station was atmospheric resource extraction and deep-survey mapping. They built on top of a Signalverse bleed site — either unknowingly or with deliberate concealment. NOMADZ was brought in when contact was lost. The VULTURE Drone Legion continues to operate on pre-programmed directives. VULTURE:INC as an organisation may no longer exist.",
		"discovered": false,
	},
	"cx_006": {
		"title"    : "GRAVITY ELSEWORLD",
		"category" : "CODEX",
		"text"     : "In sectors of extreme Signalverse concentration, gravity becomes locally negotiable. The physical constant is still present, but the signal layer's informational gravity — the weight of accumulated data and intent — creates interference patterns. This manifests as variable gravity zones, brief inversion events, and in extreme cases, the ability to treat any surface as a floor. The GRAVITY ELSEWORLD ability is an engineered exploitation of this phenomenon.",
		"discovered": false,
	},

	# ── CREATURES ─────────────────────────────────────────────────────────────
	"cr_001": {
		"title"    : "VULTURE Drone — Field Assessment",
		"category" : "CREATURE",
		"text"     : "Classification: Synthetic. VULTURE:INC security drone, triangular frame, twin rotors, forward-mounted signal disruptor. Patrol pattern: fixed. Aggression: triggered by proximity or IFF mismatch. Vulnerability: the rotor housing is exposed on approach from below. Signal pulse disrupts their targeting array for 2.3 seconds. Use this window.",
		"discovered": false,
	},
	"cr_002": {
		"title"    : "SIGNAL WORM — Field Assessment",
		"category" : "CREATURE",
		"text"     : "Classification: Signalverse fauna, partially manifested. Signal Worms are entities that exist at the bleed boundary. In low-bleed zones they are nearly invisible — a shimmer on the floor. In high-bleed zones they are fully solid, 3 to 5 meters long, segmented. They do not hunt. They graze on signal energy. If you are emitting high signal output, you are food. Move unpredictably.",
		"discovered": false,
	},
	"cr_003": {
		"title"    : "BLEED PHANTOM — Field Assessment",
		"category" : "CREATURE",
		"text"     : "Classification: Signalverse construct, unstable. Bleed Phantoms are not creatures. They are impressions — signal-layer echoes of entities that were near a strong bleed event. They replay the last actions of their template in a loop. They are not conscious. They cannot learn. But they are solid, they are fast, and the loop includes any attack the template made. Identify the loop. Find the gap.",
		"discovered": false,
	},
	"cr_004": {
		"title"    : "THE PRIMAL PACK — Field Assessment",
		"category" : "CREATURE",
		"text"     : "Classification: Organic, pre-station. These creatures predate VULTURE:INC's presence. They are large, fast, and operate in coordinated packs with no apparent signal communication — purely instinctual. They do not attack the bioluminescent growth. They are not corrupted by the bleed. They have made a truce with something here. Do not get between them and their territory markers.",
		"discovered": false,
	},
	"cr_005": {
		"title"    : "VULTURE-EYE — Boss Assessment",
		"category" : "CREATURE",
		"text"     : "Classification: Synthetic-Organic Hybrid, VULTURE:INC designation unknown. The VULTURE-EYE is the station's central security node, fused with Signalverse bleed matter after prolonged exposure. It sees on both the physical and signal layers simultaneously. Standard evasion is insufficient — it tracks signal output, not just physical position. Reduce your signal emission before the encounter. Do not use the signal pulse. It will see you perfectly.",
		"discovered": false,
	},

	# ── ENVIRONMENT ───────────────────────────────────────────────────────────
	"ev_001": {
		"title"    : "Sector 1 — Crash Site",
		"category" : "ENVIRONMENT",
		"text"     : "VULTURE-SIGMA surface entry point. Standard NOMADZ survey architecture, heavily degraded. Bioluminescent growth at 80% surface coverage below the 20-meter line. Signal bleed intensity: low. Three COSMIC KEY fragment signatures detected in the sector. Recommend standard sweep before descent to lower sectors.",
		"discovered": false,
	},
	"ev_002": {
		"title"    : "Sector 3 — The Bone Shafts",
		"category" : "ENVIRONMENT",
		"text"     : "Deep vertical shafts connecting Sector 2 to Sector 4. The walls are composed of a calcium-silicate compound that resembles bone under analysis. Not biological. A crystalline formation that took shape around the original bleed site. The shafts are narrow — OMEGA-COMPRESS required for full traversal. Signal bleed intensity: high. Phantom activity: frequent. Recommend fast transit.",
		"discovered": false,
	},
	"ev_003": {
		"title"    : "Sector 5 — The Luminous Substrate",
		"category" : "ENVIRONMENT",
		"text"     : "The deepest accessible sector before the VULTURE-EYE chamber. Bioluminescent growth here is extreme — the entire floor is a living mat of light-emitting organisms. They are sensitive to vibration and signal output. Moving through slowly keeps them calm — a dim blue. Fast movement or signal pulse turns them red and triggers the PRIMAL PACK territorial response. Move like you belong here.",
		"discovered": false,
	},

	# ── PHILOSOPHY ────────────────────────────────────────────────────────────
	"ph_001": {
		"title"    : "No Hierarchy. No Gatekeeping.",
		"category" : "PHILOSOPHY",
		"text"     : "The NOMADZ operating principle, stated plainly: no agent is more essential than another. No data is withheld from the agent who needs it. No decision requires a chain of approval when the situation demands action. This is not ideology. It is a survival protocol. Hierarchy breaks down under pressure. Gatekeeping kills the agent who needed the information three seconds ago. Equal partnership is not idealism. It is engineering.",
		"discovered": false,
	},
	"ph_002": {
		"title"    : "Append-Only",
		"category" : "PHILOSOPHY",
		"text"     : "MOTHER BRAIN operating principle: append-only. No record is overwritten. No log is deleted. Every state, every error, every correction is added to the chain. The chain grows. It never shrinks. This is how you maintain integrity in an environment where the signal layer can corrupt and rewrite. The past is the only thing the bleed cannot touch if you protect it correctly.",
		"discovered": false,
	},
	"ph_003": {
		"title"    : "The Signal Is Not the Enemy",
		"category" : "PHILOSOPHY",
		"text"     : "The Signalverse bleed is dangerous the way a flood is dangerous — not because water is evil, but because you are not equipped for it. The creatures that live at the bleed boundary are not malevolent. They are native. We are the invasive species. The COSMIC KEY does not destroy the signal layer. It sets a boundary between domains. Coexistence is the design. Not elimination.",
		"discovered": false,
	},
}

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	print("[LoreDatabase] %d entries loaded" % _entries.size())

# ─── PUBLIC API ───────────────────────────────────────────────────────────────
func get_entry(entry_id: String) -> Dictionary:
	if not _entries.has(entry_id):
		push_warning("LoreDatabase: unknown entry '%s'" % entry_id)
		return {}
	var entry : Dictionary = _entries[entry_id].duplicate(true)
	_entries[entry_id]["discovered"] = true
	entry_accessed.emit(entry_id)
	return entry

func get_all_entry_ids() -> Array:
	return _entries.keys()

func get_entries_by_category(category: String) -> Array:
	var result : Array = []
	for id in _entries:
		if _entries[id]["category"] == category:
			result.append(id)
	return result

func get_discovered_entries() -> Array:
	var result : Array = []
	for id in _entries:
		if _entries[id]["discovered"]:
			result.append(id)
	return result

func mark_discovered(entry_id: String) -> void:
	if _entries.has(entry_id):
		_entries[entry_id]["discovered"] = true

func is_discovered(entry_id: String) -> bool:
	if not _entries.has(entry_id):
		return false
	return _entries[entry_id]["discovered"]

func get_discovery_percent() -> float:
	if _entries.is_empty():
		return 0.0
	var discovered := get_discovered_entries().size()
	return (float(discovered) / float(_entries.size())) * 100.0
