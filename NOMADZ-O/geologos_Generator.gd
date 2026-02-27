#!/usr/bin/env python3
"""
Entity: GEOLOGOS Generator
Purpose: Converts the NOMADZ Knowledge Pillars into a validated JSON schema for Godot.
Pillar: P5 (Global Consciousness Integration)
"""

import json
import os
import random

PILLARS = [
    "Geology", "Atmosphere", "Biology", "Magnetics", "Tectonics", 
    "Radiation", "Hydrology", "Cryology", "Xenobiology", "Seismology",
    "Chemistry", "Physics", "Anthropology", "Archaeology", "Linguistics",
    "Botany", "Zoology", "Meteorology", "Astronomy", "Orbital_Mechanics",
    "Sub-Surface_Mining", "Fusion_Dynamics", "Quantum_Persistence", 
    "Memory_Hardening", "Signal_Theory", "Ethical_Remembrance"
]

def generate_geologos_schema():
    geologos_data = {
        "metadata": {
            "version": "1.0.0",
            "author": "The Architect",
            "system": "NOMADZ_CORE"
        },
        "pillars": {}
    }

    for pillar in PILLARS:
        geologos_data["pillars"][pillar] = {
            "id": pillar.lower(),
            "sections": []
        }
        
        # Generate 7 procedural sections per pillar as per Roadmap
        for i in range(1, 8):
            section = {
                "section_id": f"{pillar.lower()}_{i:03d}",
                "name": f"{pillar} Insight {i}",
                "weight": round(random.uniform(0.1, 1.0), 2),
                "tags": [pillar.lower(), "procedural", "lore"],
                "data_integrity": 1.0
            }
            geologos_data["pillars"][pillar]["sections"].append(section)

    output_path = "data/GEOLOGOS.json"
    os.makedirs("data", exist_ok=True)
    
    with open(output_path, "w") as f:
        json.dump(geologos_data, f, indent=4)
    
    print(f"✓ GEOLOGOS Schema generated with {len(PILLARS)} pillars and 182 sections.")

if __name__ == "__main__":
    generate_geologos_schema()