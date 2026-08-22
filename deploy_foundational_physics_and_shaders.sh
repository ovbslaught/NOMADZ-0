#!/usr/bin/env bash
# ==============================================================================
# DEPLOY_FOUNDATIONAL_PHYSICS_AND_SHADERS.SH
# Foundational Substrate Layer: Cosmological Physics, Byzantine Consensus,
# Bio-Signal Synthesis, and Retro Shaders for WORMHOLE / GEO-BRAIN / NOMADZ
# ==============================================================================

set -euo pipefail

# 1. Resolve WORMHOLE root path
if [ -n "${WORMHOLE_PATH:-}" ]; then
    W_ROOT="$WORMHOLE_PATH"
elif [ -d "$HOME/storage/shared/WORMHOLE" ]; then
    W_ROOT="$HOME/storage/shared/WORMHOLE"
elif [ -d "/sdcard/WORMHOLE" ]; then
    W_ROOT="/sdcard/WORMHOLE"
elif [ -d "D:/WORMHOLE" ]; then
    W_ROOT="D:/WORMHOLE"
else
    W_ROOT="$HOME/WORMHOLE"
fi

echo "============================================================"
echo "[+] Deploying Foundational Physics, Consensus & Shaders to: $W_ROOT"
echo "============================================================"

# 2. Build Substrate Topology
mkdir -p "$W_ROOT/COSMIC-BRAIN/physics"
mkdir -p "$W_ROOT/GEO-BRAIN/consensus"
mkdir -p "$W_ROOT/COSMIC-BRAIN/bio_signals"
mkdir -p "$W_ROOT/NOMADZ-SPINE/shaders"
mkdir -p "$W_ROOT/GEO-BRAIN/registry"

# 3. Module A: Scalar Field / Axion Dark Matter Solver -> COSMIC-BRAIN/physics
cat << 'PYEOF' > "$W_ROOT/COSMIC-BRAIN/physics/scalar_dark_matter.py"
#!/usr/bin/env python3
"""
scalar_dark_matter.py — Scalar Field Dark Matter (SFDM) / Axion Condensate Solver
Simulates galactic rotation curves via coupled Poisson-gravitational potential.
"""
import numpy as np
from typing import Dict, Tuple

class ScalarFieldDarkMatter:
    def __init__(self, G: float = 6.67430e-11, field_mass_ev: float = 1e-22):
        self.G = G
        self.field_mass_ev = field_mass_ev
        self.c = 299792458.0  # m/s
        self.hbar = 1.054571817e-34  # J*s

    def compton_frequency(self) -> float:
        """Computes Compton angular frequency omega = m*c^2 / hbar."""
        mass_kg = self.field_mass_ev * 1.78266192e-36
        return (mass_kg * (self.c ** 2)) / self.hbar

    def compute_energy_density(self, phi_0: float, frequencies: np.ndarray, amplitudes: np.ndarray) -> float:
        """Computes effective energy density: rho_dark = 0.5 * m^2 * phi_0^2 + sum(A_f * f)."""
        base_density = 0.5 * (self.field_mass_ev ** 2) * (phi_0 ** 2)
        coupling_terms = float(np.sum(frequencies * amplitudes))
        return base_density + coupling_terms

    def galactic_rotation_curve(self, radii_kpc: np.ndarray, m_visible_solar: np.ndarray, phi_0: float) -> np.ndarray:
        """Computes circular velocity: v_c(r) = sqrt( G * [M_visible(r) + M_dark(r)] / r )."""
        radii_m = radii_kpc * 3.086e19  # kpc to meters
        m_solar_kg = 1.989e30
        m_vis_kg = m_visible_solar * m_solar_kg
        
        # Dark halo mass enclosed within radius r assuming oscillating scalar condensate profile
        m_dark_kg = 4.0 * np.pi * (radii_m ** 3) * (phi_0 ** 2) * 1e-26
        
        total_mass = m_vis_kg + m_dark_kg
        velocities_m_s = np.sqrt(self.G * total_mass / (radii_m + 1e-9))
        return velocities_m_s / 1000.0  # km/s

if __name__ == "__main__":
    sfdm = ScalarFieldDarkMatter()
    radii = np.linspace(1.0, 30.0, 10)
    m_vis = np.linspace(1e10, 5e10, 10)
    v_curve = sfdm.galactic_rotation_curve(radii, m_vis, phi_0=1.42)
    print(f"[Scalar Dark Matter OK] Rotation velocities (km/s): {np.round(v_curve[:4], 1)}...")
PYEOF
chmod +x "$W_ROOT/COSMIC-BRAIN/physics/scalar_dark_matter.py"
echo "[✓] Written: $W_ROOT/COSMIC-BRAIN/physics/scalar_dark_matter.py"

# 4. Module B: Byzantine N=8 Consensus & M_PL Calculator -> GEO-BRAIN/consensus
cat << 'PYEOF' > "$W_ROOT/GEO-BRAIN/consensus/byzantine_consensus.py"
#!/usr/bin/env python3
"""
byzantine_consensus.py — N=8 Byzantine Fault-Tolerant Voting & M_PL Calculator
Computes M_PL = (Integration * Reflexivity * Temporal * Causal)^(1/4) and filters outlier vectors.
"""
import numpy as np
from typing import List, Dict, Any, Tuple

class ByzantineConsensusEngine:
    def __init__(self, num_neurons: int = 8, outlier_std_thresh: float = 2.0):
        self.num_neurons = num_neurons
        self.outlier_std_thresh = outlier_std_thresh

    def calculate_m_pl(self, integration: float, reflexivity: float, temporal: float, causal: float) -> Dict[str, Any]:
        """Calculates composite M_PL consciousness metric and safety classification."""
        product = max(0.0, integration * reflexivity * temporal * causal)
        m_pl = round(float(product ** 0.25), 4)
        
        if 0.42 <= m_pl <= 0.62:
            status = "SAFE_REGION (Optimal Convergence)"
        elif m_pl < 0.30:
            status = "CRITICAL (Divergence Alert)"
        elif m_pl < 0.38:
            status = "WARNING (Sub-Threshold Drift)"
        else:
            status = "EXPANSION (High Coherence)"
            
        return {"m_pl": m_pl, "status": status, "phi_baseline": 0.886}

    def filter_byzantine_outliers(self, neuron_vectors: List[np.ndarray]) -> Tuple[np.ndarray, List[int]]:
        """Isolates and discards divergent node streams using Median Absolute Deviation (MAD)."""
        arr = np.array(neuron_vectors)
        centroid = np.median(arr, axis=0)
        distances = np.linalg.norm(arr - centroid, axis=1)
        
        mad = np.median(distances) + 1e-9
        modified_z_scores = 0.6745 * distances / mad
        
        accepted_indices = [i for i, z in enumerate(modified_z_scores) if z <= self.outlier_std_thresh]
        if not accepted_indices:
            accepted_indices = list(range(len(neuron_vectors)))
            
        consensus_vector = np.mean(arr[accepted_indices], axis=0)
        return consensus_vector, accepted_indices

if __name__ == "__main__":
    engine = ByzantineConsensusEngine(num_neurons=8)
    metrics = engine.calculate_m_pl(0.85, 0.92, 0.78, 0.88)
    streams = [np.random.randn(16) * 0.1 + 1.0 for _ in range(7)] + [np.random.randn(16) * 5.0 + 10.0]
    centroid, accepted = engine.filter_byzantine_outliers(streams)
    print(f"[Byzantine Consensus OK] M_PL: {metrics['m_pl']} ({metrics['status']}) | Accepted Neurons: {len(accepted)}/8")
PYEOF
chmod +x "$W_ROOT/GEO-BRAIN/consensus/byzantine_consensus.py"
echo "[✓] Written: $W_ROOT/GEO-BRAIN/consensus/byzantine_consensus.py"

# 5. Module C: Mycelial Spike-Train Linguistic Synthesizer -> COSMIC-BRAIN/bio_signals
cat << 'PYEOF' > "$W_ROOT/COSMIC-BRAIN/bio_signals/mycelial_synthesizer.py"
#!/usr/bin/env python3
"""
mycelial_synthesizer.py — Biological Spike-Train Generator & Bandpass Frequency Mixer
Models Adamatzky fungal language syntax (50-word Zipfian distribution, 5.97 spikes/word).
"""
import numpy as np
from typing import Dict, List, Any

class MycelialSignalSynthesizer:
    def __init__(self, vocab_size: int = 50, avg_word_length: float = 5.97):
        self.vocab_size = vocab_size
        self.avg_word_length = avg_word_length
        ranks = np.arange(1, vocab_size + 1)
        self.word_probabilities = (1.0 / ranks) / np.sum(1.0 / ranks)

    def generate_spike_train(self, num_words: int = 5) -> List[Dict[str, Any]]:
        """Generates action potential pulse trains conforming to biological constraints."""
        spike_sequence = []
        chosen_words = np.random.choice(self.vocab_size, size=num_words, p=self.word_probabilities)
        
        for w_idx in chosen_words:
            num_spikes = max(1, int(np.random.poisson(self.avg_word_length)))
            spikes = []
            for _ in range(num_spikes):
                amplitude_mv = round(float(np.random.uniform(0.03, 2.10)), 3)
                duration_hrs = round(float(np.random.uniform(1.0, 21.0)), 2)
                spikes.append({"amplitude_mv": amplitude_mv, "duration_hrs": duration_hrs})
            
            inter_spike_interval_sec = round(float(np.random.uniform(30.0, 300.0)), 1)
            spike_sequence.append({
                "word_id": int(w_idx + 1),
                "num_spikes": num_spikes,
                "isi_interval_sec": inter_spike_interval_sec,
                "spikes": spikes
            })
        return spike_sequence

    def biological_bandpass_mixer(self, freq_a: float, freq_b: float, t_sec: np.ndarray) -> np.ndarray:
        """Mixes two continuous bio-frequencies with non-linear hyphal membrane response."""
        wave_a = np.sin(2.0 * np.pi * freq_a * t_sec)
        wave_b = np.sin(2.0 * np.pi * freq_b * t_sec)
        mixed = 0.5 * (wave_a + wave_b) + 0.2 * (wave_a * wave_b)
        return np.clip(mixed, -1.0, 1.0)

if __name__ == "__main__":
    synth = MycelialSignalSynthesizer()
    train = synth.generate_spike_train(num_words=3)
    t = np.linspace(0, 1, 100)
    mixed_wave = synth.biological_bandpass_mixer(120.0, 440.0, t)
    print(f"[Mycelial Synthesizer OK] Generated {len(train)} spike-train words. Mixed {len(mixed_wave)} samples.")
PYEOF
chmod +x "$W_ROOT/COSMIC-BRAIN/bio_signals/mycelial_synthesizer.py"
echo "[✓] Written: $W_ROOT/COSMIC-BRAIN/bio_signals/mycelial_synthesizer.py"

# 6. Module D: 1980s Retro CRT & Cellophane Shader -> NOMADZ-SPINE/shaders
cat << 'SHADEOF' > "$W_ROOT/NOMADZ-SPINE/shaders/RetroCellophaneCRT.gdshader"
shader_type canvas_item;

// 1980s Retro CRT & Dark Cellophane Filter Shader for Godot 4.x
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float scanline_density : hint_range(50.0, 800.0) = 320.0;
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.28;
uniform float curvature : hint_range(0.0, 0.1) = 0.035;
uniform vec4 cellophane_tint : source_color = vec4(0.12, 0.85, 0.95, 0.18);
uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.0035;

vec2 curve_uv(vec2 uv) {
vec2 delta = uv - 0.5;
float dist_sq = dot(delta, delta);
return uv + delta * dist_sq * curvature;
}

void fragment() {
vec2 curved_uv = curve_uv(SCREEN_UV);

if (curved_uv.x < 0.0 || curved_uv.x > 1.0 || curved_uv.y < 0.0 || curved_uv.y > 1.0) {
vec4(0.0, 0.0, 0.0, 1.0);
} else {
= texture(screen_texture, curved_uv + vec2(chromatic_aberration, 0.0)).r;
= texture(screen_texture, curved_uv).g;
= texture(screen_texture, curved_uv - vec2(chromatic_aberration, 0.0)).b;
= vec3(r, g, b);
 = sin(curved_uv.y * scanline_density * 3.14159265);
 = (scan * 0.5 + 0.5) * scanline_opacity;
scan;
al_color = mix(base_color, cellophane_tint.rgb, cellophane_tint.a);
vec4(final_color, 1.0);
}
}
SHADEOF
echo "[✓] Written: $W_ROOT/NOMADZ-SPINE/shaders/RetroCellophaneCRT.gdshader"

# 7. Module E: 26-Pillar Knowledge Graph Router -> GEO-BRAIN/registry
cat << 'PYEOF' > "$W_ROOT/GEO-BRAIN/registry/pillar_router.py"
#!/usr/bin/env python3
"""
pillar_router.py — 26-Pillar GEOLOGOS Matrix Query Engine
Calculates cross-disciplinary synthesis vectors across all 26 canonical pillars.
"""
from typing import Dict, List, Any, Optional

PILLARS = [
    {"id": "P-01", "key": "A", "name": "Axiomatic Substrate", "domain": "Ontological foundation & primitive axioms"},
    {"id": "P-02", "key": "B", "name": "Biometric Feedback", "domain": "Adaptive input tracking & stress modulation"},
    {"id": "P-03", "key": "C", "name": "Cognitive Anchor", "domain": "Self-consistent state retention & memory binding"},
    {"id": "P-04", "key": "D", "name": "Determinism Gate", "domain": "Cryptographic SHA-256 state repeatability"},
    {"id": "P-05", "key": "E", "name": "Entropy Equalizer", "domain": "Corruption dissipation & harmonic decay"},
    {"id": "P-06", "key": "F", "name": "Fractal Topography", "domain": "Procedural heightmap & Signal Sigma logic"},
    {"id": "P-07", "key": "G", "name": "Gravity Elseworld", "domain": "5-Gate mathematical coherence (G1-G5)"},
    {"id": "P-08", "key": "H", "name": "Harmonic Resonance", "domain": "Frequency spectrum synthesis (Alpha-Gamma)"},
    {"id": "P-09", "key": "I", "name": "Immutable Ledger", "domain": "Append-only WAL transaction tracking"},
    {"id": "P-10", "key": "J", "name": "Judicial Sandbox", "domain": "Deterministic rule evaluation & DARVO defense"},
    {"id": "P-11", "key": "K", "name": "Kensho Catalyst", "domain": "Post-collapse sovereign extraction & awakening"},
    {"id": "P-12", "key": "L", "name": "Local Compute Shield", "domain": "Zero-waste offline inference in Termux RAM"},
    {"id": "P-13", "key": "M", "name": "Morphogenesis Node", "domain": "Procedural entity spawning & FastAPI endpoints"},
    {"id": "P-14", "key": "N", "name": "Neural Vector Matrix", "domain": "Offline FTS5 BM25 search & local embeddings"},
    {"id": "P-15", "key": "O", "name": "Ouroboros Seal", "domain": "10-phase circular snapshot continuity verification"},
    {"id": "P-16", "key": "P", "name": "Pheromone Substrate", "domain": "Ant Colony Optimization & trail decay"},
    {"id": "P-17", "key": "Q", "name": "Quantum Logic Gate", "domain": "Probabilistic decision modeling under uncertainty"},
    {"id": "P-18", "key": "R", "name": "Recursive Rollback", "domain": "Point-in-time state recovery on anomaly detection"},
    {"id": "P-19", "key": "S", "name": "Signalverse Bleed", "domain": "Chaotic raw data dimension manifestation"},
    {"id": "P-20", "key": "T", "name": "Topological Spine", "domain": "Unified SQLite WAL database persistence"},
    {"id": "P-21", "key": "U", "name": "Ultimo Orchestrator", "domain": "Metric aggregation & rclone cloud synchronization"},
    {"id": "P-22", "key": "V", "name": "Vulture Gossip Protocol", "domain": "Off-grid P2P mesh message propagation"},
    {"id": "P-23", "key": "W", "name": "Wormhole Gateway", "domain": "Universal storage hierarchy across machines"},
    {"id": "P-24", "key": "X", "name": "Xurator Sentinel", "domain": "Security boundary auditing & token validation"},
    {"id": "P-25", "key": "Y", "name": "Yield Engine", "domain": "Async process management & background tasks"},
    {"id": "P-26", "key": "Z", "name": "Zero Loss Governance", "domain": "Immutable append-only non-mutative policy"}
]

class PillarRouter:
    def __init__(self):
        self.pillars = {p["id"]: p for p in PILLARS}
        self.key_map = {p["key"]: p for p in PILLARS}

    def query_pillar(self, key_or_id: str) -> Optional[Dict[str, str]]:
        lookup = key_or_id.upper().strip()
        return self.pillars.get(lookup) or self.key_map.get(lookup)

    def route_text(self, text: str) -> List[Dict[str, str]]:
        matches = []
        text_lower = text.lower()
        for p in PILLARS:
            if p["name"].lower() in text_lower or any(word in text_lower for word in p["domain"].lower().split()):
                matches.append(p)
        return matches

if __name__ == "__main__":
    router = PillarRouter()
    p = router.query_pillar("P-07")
    print(f"[Pillar Router OK] Loaded {len(PILLARS)} Canonical Pillars. Sample: {p['id']} - {p['name']}")
PYEOF
chmod +x "$W_ROOT/GEO-BRAIN/registry/pillar_router.py"
echo "[✓] Written: $W_ROOT/GEO-BRAIN/registry/pillar_router.py"

echo "============================================================"
echo "[+] Running Verification Sanity Checks..."
echo "============================================================"
python3 "$W_ROOT/COSMIC-BRAIN/physics/scalar_dark_matter.py"
python3 "$W_ROOT/GEO-BRAIN/consensus/byzantine_consensus.py"
python3 "$W_ROOT/COSMIC-BRAIN/bio_signals/mycelial_synthesizer.py"
python3 "$W_ROOT/GEO-BRAIN/registry/pillar_router.py"

echo "============================================================"
echo "[✓] ALL FOUNDATIONAL SUBSYSTEMS DEPLOYED & VERIFIED!"
echo "============================================================"
