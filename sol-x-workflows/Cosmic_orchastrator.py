#!/usr/bin/env python3
"""
Cosmic Key Orchestrator - Living Autonomous Universe
Daemonized, Watchdog-Integrated, MCP-Powered
With Procedural Worlds, Civilizations, Factions, Trade, Diplomacy, and Emergent Events
"""
from __future__ import annotations
import os
import sys
import json
import logging
import pathlib
import threading
import time
import random
import signal
import daemon
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import openai
from mcp import MCPServer

# ---------------- Config ----------------
HOME = pathlib.Path.home()
VC_DIR = HOME / "VultureCode"
LOG_FILE = VC_DIR / "cosmic_orchestrator.log"
COSMIC_KEY_FILE = VC_DIR / "cosmic_key.json"
MIN_PY = (3, 8)

# ---------------- Logging ----------------
def setup_logging():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s: %(message)s",
        handlers=[logging.FileHandler(LOG_FILE, encoding="utf-8"), logging.StreamHandler(sys.stdout)]
    )

# ---------------- Secure API Key ----------------
openai_api_key = os.getenv("OPENAI_API_KEY")
if not openai_api_key:
    logging.error("OPENAI_API_KEY not set. Exiting.")
    sys.exit(1)
openai.api_key = openai_api_key

# ---------------- Cosmic Key Utilities ----------------
def load_cosmic() -> dict:
    try:
        with open(COSMIC_KEY_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        logging.error("Failed to load Cosmic Key: %s", e)
        return {}

def save_cosmic(data: dict):
    try:
        with open(COSMIC_KEY_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=4)
    except Exception as e:
        logging.error("Failed to save Cosmic Key: %s", e)

# ---------------- OpenAI Integration ----------------
def generate_ai_content(prompt: str) -> str:
    try:
        response = openai.ChatCompletion.create(
            model="gpt-5-mini",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.85,
            max_tokens=1200
        )
        return response.choices[0].message.content.strip()
    except Exception as e:
        logging.error("OpenAI generation failed: %s", e)
        return ""

# ---------------- Procedural World & Civilization ----------------
def generate_procedural_world(index: int) -> dict:
    world = {
        "id": f"world_{int(time.time())}_{index}",
        "name": f"World-{random.randint(1000,9999)}",
        "type": random.choice(["terrestrial", "gas giant", "ice planet", "oceanic", "desert"]),
        "size": random.randint(5000, 150000),
        "inhabited": True,
        "factions": [],
        "anomalies": [],
        "events": [],
        "created_at": time.time()
    }

    # Procedural civilizations and factions
    for f in range(random.randint(1,3)):
        faction = {
            "id": f"faction_{index}_{f}_{int(time.time())}",
            "name": f"Faction-{random.randint(100,999)}",
            "culture": random.choice(["militaristic", "scientific", "spiritual", "trade-focused", "exploratory"]),
            "population": random.randint(10000, 1000000),
            "relationship": {},  # will hold relations to other factions
            "trade_routes": [],
            "lore": generate_ai_content(f"Create a short lore and history for a {world['type']} world faction.")
        }
        world["factions"].append(faction)

    # Procedural anomalies
    anomalies = ["temporal rift", "gravity distortion", "quantum storm", "ancient ruins", "energy vortex"]
    world["anomalies"] = random.sample(anomalies, k=random.randint(0, 3))

    # Initial events
    events = ["civil war", "scientific breakthrough", "mystical awakening", "planetary alignment", "alien encounter"]
    world["events"] = random.sample(events, k=random.randint(0, 2))

    return world

# ---------------- Universe Expansion & Interconnect ----------------
def interconnect_factions(cosmic_data: dict):
    """Create trade, diplomacy, and conflict relationships between factions across worlds"""
    all_factions = []
    for world in cosmic_data.get("worlds", []):
        all_factions.extend(world.get("factions", []))

    for faction in all_factions:
        faction["relationship"] = {}
        faction["trade_routes"] = []
        others = [f for f in all_factions if f["id"] != faction["id"]]
        for other in random.sample(others, k=min(3, len(others))):
            relation_type = random.choices(["allied", "neutral", "hostile"], weights=[0.3,0.4,0.3])[0]
            faction["relationship"][other["id"]] = relation_type
            if relation_type == "allied":
                faction["trade_routes"].append({"to": other["id"], "goods": random.sample(
                    ["minerals","technology","spices","artifacts","energy"], k=random.randint(1,3))})

def evolve_events(cosmic_data: dict):
    """Simulate events evolving across worlds and factions"""
    for world in cosmic_data.get("worlds", []):
        for event in world.get("events", []):
            # Randomly trigger AI-generated event consequences
            if random.random() < 0.3:
                consequence = generate_ai_content(f"Describe the consequence of '{event}' on world {world['name']} and its factions.")
                world.setdefault("events_log", []).append({"event": event, "consequence": consequence, "timestamp": time.time()})

def expand_universe():
    """Generates new worlds, civilizations, connects factions, and evolves events"""
    while True:
        cosmic_data = load_cosmic()

        # AI-generated cosmic narrative
        ai_update = generate_ai_content("Expand the Cosmic Key universe with new planets, civilizations, factions, and anomalies.")
        if ai_update:
            cosmic_data.setdefault("entries", []).append({"timestamp": time.time(), "content": ai_update})
            logging.info("Added AI Cosmic Key entry.")

        # Procedural worlds
        new_worlds = [generate_procedural_world(i) for i in range(random.randint(1, 3))]
        cosmic_data.setdefault("worlds", []).extend(new_worlds)
        logging.info("Generated %d new procedural worlds with civilizations.", len(new_worlds))

        # Interconnect factions across all worlds
        interconnect_factions(cosmic_data)

        # Evolve ongoing events
        evolve_events(cosmic_data)

        save_cosmic(cosmic_data)
        logging.info("Universe expansion cycle complete. Next cycle in 30 minutes.")
        time.sleep(1800)  # every 30 minutes

# ---------------- Watchdog ----------------
class CosmicEventHandler(FileSystemEventHandler):
    def on_modified(self, event):
        if event.src_path == str(COSMIC_KEY_FILE):
            logging.info("Cosmic Key file modified, reloading...")
            load_cosmic()

def start_watchdog():
    event_handler = CosmicEventHandler()
    observer = Observer()
    observer.schedule(event_handler, path=str(VC_DIR), recursive=False)
    observer.start()
    logging.info("Watchdog started, monitoring Cosmic Key file...")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()

# ---------------- MCP Server ----------------
class CosmicMCPServer(MCPServer):
    def handle_request(self, request):
        logging.info("MCP request received: %s", request)
        if "generate_cosmic" in request.lower():
            threading.Thread(target=expand_universe, daemon=True).start()
            return "Cosmic Key universe expansion started in background."
        return "Request logged."

def start_mcp_server():
    server = CosmicMCPServer()
    server.start()
    logging.info("MCP Server started, awaiting connections...")

# ---------------- Daemon ----------------
def daemonize():
    with daemon.DaemonContext(stdout=sys.stdout, stderr=sys.stderr, signal_map={signal.SIGTERM: 'terminate'}):
        logging.info("Daemonized process started.")
        threading.Thread(target=expand_universe, daemon=True).start()
        start_watchdog()
        start_mcp_server()

# ---------------- Main ----------------
if __name__ == "__main__":
    setup_logging()
    logging.info("Starting Cosmic Key Orchestrator with Living Autonomous Universe...")

    if sys.version_info < MIN_PY:
        logging.error("Python %d.%d or higher is required.", MIN_PY[0], MIN_PY[1])
        sys.exit(1)

    daemonize()