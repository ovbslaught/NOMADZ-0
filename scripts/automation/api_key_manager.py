#!/usr/bin/env python3
"""
API Key Manager for NOMADZ-0 Automation Stack
Securely manages API keys from vault with auto-rotation
"""

import json
import os
from pathlib import Path
from datetime import datetime, timedelta
import hashlib

VAULT_PATH = Path("vault/.obsidian")
KEY_REGISTRY = VAULT_PATH / "api_keys.json"

class APIKeyManager:
    def __init__(self):
        self.keys = {}
        self.load_keys()
        
    def load_keys(self):
        """Load API keys from vault"""
        if KEY_REGISTRY.exists():
            with open(KEY_REGISTRY, 'r') as f:
                self.keys = json.load(f)
        else:
            self.keys = {
                "firecrawl": {
                    "key": os.getenv("FIRECRAWL_API_KEY", ""),
                    "status": "pending",
                    "last_rotated": None
                },
                "notion": {
                    "key": os.getenv("NOTION_API_KEY", ""),
                    "status": "pending",
                    "last_rotated": None
                },
                "perplexity": {
                    "key": os.getenv("PERPLEXITY_API_KEY", ""),
                    "status": "pending",
                    "last_rotated": None
                },
                "github": {
                    "token": os.getenv("GITHUB_TOKEN", ""),
                    "status": "active",
                    "last_rotated": None
                },
                "google_drive": {
                    "credentials": "vault/.obsidian/google_creds.json",
                    "status": "pending",
                    "last_rotated": None
                }
            }
            self.save_keys()
    
    def save_keys(self):
        """Save keys to vault"""
        VAULT_PATH.mkdir(parents=True, exist_ok=True)
        with open(KEY_REGISTRY, 'w') as f:
            json.dump(self.keys, f, indent=2)
    
    def get_key(self, service):
        """Retrieve API key for service"""
        if service in self.keys:
            key_data = self.keys[service]
            if "key" in key_data:
                return key_data["key"]
            elif "token" in key_data:
                return key_data["token"]
        return None
    
    def set_key(self, service, key):
        """Set or update API key"""
        if service not in self.keys:
            self.keys[service] = {}
        
        self.keys[service]["key"] = key
        self.keys[service]["status"] = "active"
        self.keys[service]["last_rotated"] = datetime.now().isoformat()
        self.save_keys()
        print(f"✓ Updated {service} API key")
    
    def check_rotation_needed(self, service, days=90):
        """Check if key rotation is needed"""
        if service in self.keys:
            last_rotated = self.keys[service].get("last_rotated")
            if last_rotated:
                rotated_date = datetime.fromisoformat(last_rotated)
                if datetime.now() - rotated_date > timedelta(days=days):
                    return True
        return False
    
    def get_status_report(self):
        """Generate API key status report"""
        report = "\n=== API KEY STATUS REPORT ===\n"
        for service, data in self.keys.items():
            status = data.get("status", "unknown")
            last_rotated = data.get("last_rotated", "never")
            has_key = bool(data.get("key") or data.get("token"))
            
            status_icon = "✓" if status == "active" and has_key else "⚠" if status == "pending" else "✗"
            report += f"{status_icon} {service}: {status} (last rotated: {last_rotated})\n"
        
        return report

if __name__ == "__main__":
    manager = APIKeyManager()
    print(manager.get_status_report())
