#!/usr/bin/env python3
# fetch_norfolk_osm.py — pull real Norfolk, VA geography from OpenStreetMap
# via Overpass and dump a city JSON Godot eats. No API key, no cost.
# Run: python3 fetch_norfolk_osm.py  (needs: requests, or use urllib fallback)
import json, sys, urllib.request

# Norfolk bbox: south, west, north, east (downtown + harbor + naval station edge)
BBOX = "36.82,-76.40,36.95,-76.19"

OVERPASS_URL = "https://overpass-api.de/api/interpreter"

QUERY = f"""
[out:json][timeout:120];
(
  way["building"]({BBOX});
  relation["building"]({BBOX});
  way["highway"]({BBOX});
  way["natural"="water"]({BBOX});
  way["waterway"]({BBOX});
  way["landuse"~"residential|industrial|military"]({BBOX});
  way["leisure"="park"]({BBOX});
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
    print("querying Overpass for Norfolk bbox... (30-90s)")
    with urllib.request.urlopen(req, timeout=180) as r:
        return json.load(r)

def to_local_m(lat, lon, lat0=36.885, lon0=-76.295):
    # equirectangular projection centered on Norfolk, meters
    import math
    mx = (lon - lon0) * 111320 * math.cos(math.radians(lat0))
    my = (lat - lat0) * 110540
    return round(mx, 1), round(my, 1)

def build(raw):
    nodes = {n["id"]: to_local_m(n["lat"], n["lon"]) for n in raw.get("elements", []) if n["type"] == "node"}
    buildings, roads, water, zones = [], [], [], []
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
        elif tags.get("natural") == "water" or "waterway" in tags:
            water.append({"poly": nds})
        elif "landuse" in tags or tags.get("leisure") == "park":
            zones.append({"poly": nds, "kind": tags.get("landuse", "park")})
    return {"buildings": buildings, "roads": roads, "water": water, "zones": zones}

if __name__ == "__main__":
    raw = fetch()
    city = build(raw)
    out = "norfolk_city.json"
    with open(out, "w") as f:
        json.dump(city, f)
    print(f"done: {len(city['buildings'])} buildings, {len(city['roads'])} roads, "
          f"{len(city['water'])} water, {len(city['zones'])} zones -> {out}")
