#!/usr/bin/env python3
# PC Drive Scanner - Scans C: and D: drives for NOMADZ-0 assets
import os
import json
from datetime import datetime
from pathlib import Path

print("[PC_SCANNER] Scanning C: and D: drives for NOMADZ-0 assets...")

# Target file extensions for assets
asset_extensions = {
    'scripts': ['.gd', '.gdscript', '.py', '.js', '.cs'],
    'audio': ['.wav', '.mp3', '.ogg', '.aif', '.flac', '.als'],  # .als = Ableton Live Set
    'visual': ['.png', '.jpg', '.jpeg', '.bmp', '.tga', '.svg', '.psd', '.aseprite'],
    '3d': ['.obj', '.fbx', '.gltf', '.glb', '.blend', '.dae'],
    'config': ['.json', '.toml', '.yaml', '.yml', '.xml', '.cfg', '.ini'],
    'retroarch': ['.nes', '.smc', '.sfc', '.md', '.gen', '.gba', '.n64', '.z64'],
}

# Search patterns for NOMADZ-0 related folders
target_patterns = [
    'NOMADZ', 'nomadz', 'godot', 'Godot', 
    'RetroArch', 'retroarch',
    'Ableton', 'ableton', 'Audacity',
    'scripts', 'assets', 'resources',
    'game', 'sim', 'simulation'
]

def scan_drive(drive_letter):
    """Scan a drive for relevant assets"""
    results = {
        'drive': drive_letter,
        'folders_found': [],
        'assets_by_type': {k: [] for k in asset_extensions.keys()},
        'total_files': 0
    }
    
    drive_path = f"{drive_letter}:/"
    
    if not os.path.exists(drive_path):
        print(f"[PC_SCANNER] Drive {drive_letter}: not found")
        return None
    
    print(f"\n[PC_SCANNER] Scanning {drive_letter}:/ ...")
    
    try:
        for root, dirs, files in os.walk(drive_path):
            # Skip system folders
            if any(x in root.lower() for x in ['windows', 'program files', '$recycle', 'appdata']):
                continue
            
            # Check if folder matches target patterns
            for pattern in target_patterns:
                if pattern.lower() in root.lower():
                    results['folders_found'].append(root)
                    print(f"  Found: {root}")
                    break
            
            # Scan files
            for file in files:
                file_path = os.path.join(root, file)
                ext = os.path.splitext(file)[1].lower()
                
                # Categorize by extension
                for category, extensions in asset_extensions.items():
                    if ext in extensions:
                        results['assets_by_type'][category].append({
                            'path': file_path,
                            'name': file,
                            'size': os.path.getsize(file_path) if os.path.isfile(file_path) else 0
                        })
                        results['total_files'] += 1
    
    except PermissionError as e:
        print(f"[PC_SCANNER] Permission denied: {e}")
    except Exception as e:
        print(f"[PC_SCANNER] Error: {e}")
    
    return results

# Scan both drives
all_results = {}

for drive in ['C', 'D']:
    result = scan_drive(drive)
    if result:
        all_results[drive] = result

# Generate report
report_file = f"logs/pc_drive_scan_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
os.makedirs("logs", exist_ok=True)

with open(report_file, 'w') as f:
    json.dump(all_results, f, indent=2)

print(f"\n[PC_SCANNER] Report saved to: {report_file}")

# Summary
for drive, data in all_results.items():
    print(f"\n[{drive}:] Summary:")
    print(f"  Folders found: {len(data['folders_found'])}")
    print(f"  Total files: {data['total_files']}")
    for category, items in data['assets_by_type'].items():
        if items:
            print(f"  {category}: {len(items)} files")

print("\n[PC_SCANNER] Scan complete!")
