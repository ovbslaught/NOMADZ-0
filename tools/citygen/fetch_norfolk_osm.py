#!/usr/bin/env python3
# fetch_norfolk_osm.py — pull real Norfolk geography from OpenStreetMap
# via Overpass and dump a city JSON Godot eats. No API key, no cost.
# COVERAGE: the Bay side — Ocean View, Bay View, Willoughby Spit,
# Chesapeake Bay shoreline (the 35-Myr-old impact crater rim), plus
# downtown Norfolk across the water.
# Run: python3 fetch_norfolk_osm.py
import json, sys, urllib.request

# South, West, North, East
# Covers Willoughby Spit down to Ocean View beach, Bay View, Little
# Creek, downtown Norfolk across the river.
BBOX = "36.86,-76.33,36.98,-76.12"

OVERPASS_URL = "https://overpass-api.de/api/interpreter"

QUERY = f"""
[out:json][timeout:180];
(
  way["building"]({BBOX});
  relation["building"]({BBOX});
  way["highway"]({BBOX});
  way["natural"="water"]({BBOX});
  way["natural"="coastline"]({BBOX});
  way["waterway"]({BBOX});
  way["landuse"~"residential|industrial|military"]({BBOX});
  way["leisure"="park"]({BBOX});
  way["natural"="beach"]({BBOX});
  node["railway"="station"]({BBOX});
);
out body;
>;
out skel qt;
"""

def fetch():
    data = json.dumps({"data": QUERY}).encode()
    req = urllib.request.Request(OVERPASS_URL, data=data,
        headers={"Content-Type": "application/json", "User-Agent": "NOMADZ-citygen/1.0"})
    print("querying Overpass for the Bay side (Ocean View / Willoughby / downtown)... 30-120s")
    with urllib.request.urlopen(req, timeout=240) as r:
        return json.load(r)

def to_local_m(lat, lon, lat0=36.92, lon0=-76.225):
    # centered on the Bay shoreline
    import math
    mx = (lon - lon0) * 111320 * math.cos(math.radians(lat0))
    my = (lat - lat0) * 110540
    return round(mx, 1), round(my, 1)

def build(raw):
    nodes = {n["id"]: to_local_m(n["lat"], n["lon"]) for n in raw.get("elements", []) if n["type"] == "node"}
    buildings, roads, water, coast, zones = [], [], [], [], []
    for el in raw.get("elements", []):
        if el["type"] not in ("way", "relation"):
            continue
        tags = el.get("tags", {})
        nds = [nodes[n] for n in el.get("nodes", []) if n in nodes]
        if len(nds) < 2:
            continue
        if "building" in tags:
            b = {"poly": nds, "levels": tags.get("building:levels", "2")}
            if tags.get("name"): b["name"] = tags["name"]
            buildings.append(b)
        elif "highway" in tags:
            roads.append({"poly": nds, "kind": tags["highway"], "name": tags.get("name", "")})
        elif tags.get("natural") == "coastline":
            coast.append({"poly": nds})
        elif tags.get("natural") in ("water", "beach") or "waterway" in tags:
            water.append({"poly": nds, "beach": tags.get("natural") == "beach"})
        elif "landuse" in tags or tags.get("leisure") == "park":
            zones.append({"poly": nds, "kind": tags.get("landuse", "park")})
    return {"buildings": buildings, "roads": roads, "water": water,
            "coast": coast, "zones": zones}

if __name__ == "__main__":
    raw = fetch()
    city = build(raw)
    out = "norfolk_city.json"
    with open(out, "w") as f:
        json.dump(city, f)
    print(f"done: {len(city['buildings'])} buildings, {len(city['roads'])} roads, "
          f"{len(city['water'])} water/beach, {len(city['coast'])} coast, "
          f"{len(city['zones'])} zones -> {out}")
