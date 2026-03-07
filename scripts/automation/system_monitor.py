#!/usr/bin/env python3
"""
System Monitor for NOMADZ-0 - Track automation health, resource usage
Integrates with Notion for logging and alerting
"""

import psutil
import json
from datetime import datetime
from pathlib import Path
import subprocess

class SystemMonitor:
    def __init__(self):
        self.log_path = Path("logs/system_monitor.jsonl")
        self.log_path.parent.mkdir(exist_ok=True)
        
    def get_system_stats(self):
        """Collect system resource stats"""
        return {
            "timestamp": datetime.now().isoformat(),
            "cpu_percent": psutil.cpu_percent(interval=1),
            "memory_percent": psutil.virtual_memory().percent,
            "disk_usage": psutil.disk_usage('/').percent,
            "process_count": len(psutil.pids())
        }
    
    def check_daemon_status(self):
        """Check if automation daemon is running"""
        try:
            result = subprocess.run(
                ["ps", "aux"],
                capture_output=True,
                text=True
            )
            return "daemon_runner.py" in result.stdout
        except:
            return False
    
    def check_github_sync(self):
        """Check last git push timestamp"""
        try:
            result = subprocess.run(
                ["git", "log", "-1", "--format=%at"],
                capture_output=True,
                text=True,
                cwd="/workspaces/NOMADZ-0"
            )
            last_commit = int(result.stdout.strip())
            age_hours = (datetime.now().timestamp() - last_commit) / 3600
            return {
                "last_commit_hours_ago": round(age_hours, 2),
                "status": "ok" if age_hours < 24 else "stale"
            }
        except:
            return {"status": "error"}
    
    def check_vault_sync(self):
        """Check Obsidian vault file count and recent updates"""
        vault_path = Path("vault")
        if vault_path.exists():
            md_files = list(vault_path.rglob("*.md"))
            return {
                "file_count": len(md_files),
                "status": "ok" if len(md_files) > 0 else "empty"
            }
        return {"status": "not_found"}
    
    def generate_health_report(self):
        """Generate comprehensive health report"""
        stats = self.get_system_stats()
        daemon_running = self.check_daemon_status()
        github_sync = self.check_github_sync()
        vault_sync = self.check_vault_sync()
        
        report = {
            "timestamp": datetime.now().isoformat(),
            "system": stats,
            "services": {
                "daemon": "running" if daemon_running else "stopped",
                "github": github_sync,
                "vault": vault_sync
            },
            "overall_health": self._calculate_health(stats, daemon_running)
        }
        
        # Log to JSONL
        with open(self.log_path, 'a') as f:
            f.write(json.dumps(report) + "\n")
        
        return report
    
    def _calculate_health(self, stats, daemon_running):
        """Calculate overall system health score"""
        health_score = 100
        
        if stats["cpu_percent"] > 80:
            health_score -= 20
        if stats["memory_percent"] > 80:
            health_score -= 20
        if stats["disk_usage"] > 90:
            health_score -= 30
        if not daemon_running:
            health_score -= 30
        
        if health_score >= 80:
            return "excellent"
        elif health_score >= 60:
            return "good"
        elif health_score >= 40:
            return "degraded"
        else:
            return "critical"
    
    def print_dashboard(self):
        """Print monitoring dashboard to terminal"""
        report = self.generate_health_report()
        
        print("\n" + "="*60)
        print("NOMADZ-0 SYSTEM MONITOR DASHBOARD")
        print("="*60)
        print(f"Timestamp: {report['timestamp']}")
        print(f"Overall Health: {report['overall_health'].upper()}")
        print("\nSystem Resources:")
        print(f"  CPU: {report['system']['cpu_percent']}%")
        print(f"  Memory: {report['system']['memory_percent']}%")
        print(f"  Disk: {report['system']['disk_usage']}%")
        print("\nServices:")
        print(f"  Daemon: {report['services']['daemon']}")
        print(f"  GitHub Sync: {report['services']['github']['status']}")
        print(f"  Vault: {report['services']['vault']['status']}")
        print("="*60 + "\n")

if __name__ == "__main__":
    monitor = SystemMonitor()
    monitor.print_dashboard()
