"""Cross-Platform Sync Manager for NOMADZ-0

Coordinates synchronization across:
- GitHub (git operations)
- Google Drive (cloud storage)
- Android/Termux (mobile development)
- Local filesystem
"""

import os
import json
import subprocess
import asyncio
from typing import Dict, List, Optional, Set
from dataclasses import dataclass
from datetime import datetime
import hashlib
from pathlib import Path


@dataclass
class SyncConfig:
    """Configuration for sync operations"""
    github_repo: str
    github_branch: str
    google_drive_path: str
    termux_path: Optional[str]
    local_path: str
    sync_interval: int = 300  # seconds
    auto_commit: bool = True
    auto_push: bool = False


@dataclass
class FileChange:
    """Represents a file change event"""
    path: str
    change_type: str  # 'created', 'modified', 'deleted'
    timestamp: str
    hash: str
    size: int


class GitManager:
    """Manages git operations"""
    
    def __init__(self, repo_path: str, branch: str = "main"):
        self.repo_path = repo_path
        self.branch = branch
    
    def get_status(self) -> Dict[str, List[str]]:
        """Get git status"""
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=self.repo_path,
            capture_output=True,
            text=True
        )
        
        status = {
            "modified": [],
            "added": [],
            "deleted": [],
            "untracked": []
        }
        
        for line in result.stdout.strip().split('\n'):
            if not line:
                continue
            
            status_code = line[:2]
            file_path = line[3:]
            
            if status_code.strip() == "M":
                status["modified"].append(file_path)
            elif status_code.strip() == "A":
                status["added"].append(file_path)
            elif status_code.strip() == "D":
                status["deleted"].append(file_path)
            elif status_code.strip() == "??":
                status["untracked"].append(file_path)
        
        return status
    
    def add_files(self, files: List[str]) -> bool:
        """Add files to git staging"""
        try:
            subprocess.run(
                ["git", "add"] + files,
                cwd=self.repo_path,
                check=True
            )
            return True
        except subprocess.CalledProcessError:
            return False
    
    def commit(self, message: str) -> bool:
        """Commit staged changes"""
        try:
            subprocess.run(
                ["git", "commit", "-m", message],
                cwd=self.repo_path,
                check=True
            )
            return True
        except subprocess.CalledProcessError:
            return False
    
    def push(self, remote: str = "origin") -> bool:
        """Push commits to remote"""
        try:
            subprocess.run(
                ["git", "push", remote, self.branch],
                cwd=self.repo_path,
                check=True
            )
            return True
        except subprocess.CalledProcessError:
            return False
    
    def pull(self, remote: str = "origin") -> bool:
        """Pull changes from remote"""
        try:
            subprocess.run(
                ["git", "pull", remote, self.branch],
                cwd=self.repo_path,
                check=True
            )
            return True
        except subprocess.CalledProcessError:
            return False
    
    def get_current_commit(self) -> str:
        """Get current commit hash"""
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=self.repo_path,
            capture_output=True,
            text=True
        )
        return result.stdout.strip()


class GoogleDriveManager:
    """Manages Google Drive sync operations"""
    
    def __init__(self, drive_path: str):
        self.drive_path = drive_path
    
    def sync_to_drive(self, local_path: str, relative_path: str) -> bool:
        """Sync file to Google Drive"""
        import shutil
        
        try:
            source = os.path.join(local_path, relative_path)
            dest = os.path.join(self.drive_path, relative_path)
            
            # Create destination directory if needed
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            
            # Copy file
            shutil.copy2(source, dest)
            return True
        except Exception as e:
            print(f"Error syncing to Drive: {e}")
            return False
    
    def sync_from_drive(self, local_path: str, relative_path: str) -> bool:
        """Sync file from Google Drive"""
        import shutil
        
        try:
            source = os.path.join(self.drive_path, relative_path)
            dest = os.path.join(local_path, relative_path)
            
            # Create destination directory if needed
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            
            # Copy file
            shutil.copy2(source, dest)
            return True
        except Exception as e:
            print(f"Error syncing from Drive: {e}")
            return False


class TermuxManager:
    """Manages Termux/Android sync operations"""
    
    def __init__(self, termux_path: str):
        self.termux_path = termux_path
    
    def is_termux_available(self) -> bool:
        """Check if running in Termux environment"""
        return os.path.exists("/data/data/com.termux")
    
    def sync_to_termux(self, local_path: str, relative_path: str) -> bool:
        """Sync file to Termux storage"""
        if not self.is_termux_available():
            return False
        
        import shutil
        
        try:
            source = os.path.join(local_path, relative_path)
            dest = os.path.join(self.termux_path, relative_path)
            
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            shutil.copy2(source, dest)
            return True
        except Exception as e:
            print(f"Error syncing to Termux: {e}")
            return False


class CrossPlatformSyncManager:
    """Main sync manager coordinating all platforms"""
    
    def __init__(self, config: SyncConfig):
        self.config = config
        self.git = GitManager(config.local_path, config.github_branch)
        self.gdrive = GoogleDriveManager(config.google_drive_path)
        self.termux = TermuxManager(config.termux_path) if config.termux_path else None
        self.file_hashes: Dict[str, str] = {}
        self.is_running = False
    
    def calculate_file_hash(self, file_path: str) -> str:
        """Calculate SHA256 hash of file"""
        sha256 = hashlib.sha256()
        with open(file_path, 'rb') as f:
            for block in iter(lambda: f.read(4096), b''):
                sha256.update(block)
        return sha256.hexdigest()
    
    def scan_for_changes(self) -> List[FileChange]:
        """Scan for file changes"""
        changes = []
        
        # Scan all files in project
        for root, dirs, files in os.walk(self.config.local_path):
            # Skip .git directory
            if '.git' in root:
                continue
            
            for file in files:
                file_path = os.path.join(root, file)
                relative_path = os.path.relpath(file_path, self.config.local_path)
                
                try:
                    current_hash = self.calculate_file_hash(file_path)
                    file_size = os.path.getsize(file_path)
                    
                    # Check if file is new or modified
                    if relative_path not in self.file_hashes:
                        changes.append(FileChange(
                            path=relative_path,
                            change_type="created",
                            timestamp=datetime.utcnow().isoformat(),
                            hash=current_hash,
                            size=file_size
                        ))
                    elif self.file_hashes[relative_path] != current_hash:
                        changes.append(FileChange(
                            path=relative_path,
                            change_type="modified",
                            timestamp=datetime.utcnow().isoformat(),
                            hash=current_hash,
                            size=file_size
                        ))
                    
                    self.file_hashes[relative_path] = current_hash
                    
                except Exception as e:
                    print(f"Error processing {file_path}: {e}")
        
        return changes
    
    def sync_changes(self, changes: List[FileChange]):
        """Sync changes across all platforms"""
        if not changes:
            return
        
        print(f"Syncing {len(changes)} changes...")
        
        # Sync to Google Drive
        for change in changes:
            if change.change_type in ["created", "modified"]:
                self.gdrive.sync_to_drive(self.config.local_path, change.path)
                
                # Sync to Termux if available
                if self.termux:
                    self.termux.sync_to_termux(self.config.local_path, change.path)
        
        # Git operations
        if self.config.auto_commit:
            git_status = self.git.get_status()
            
            # Add all changes
            all_files = (
                git_status["modified"] +
                git_status["added"] +
                git_status["untracked"]
            )
            
            if all_files:
                self.git.add_files(all_files)
                
                # Create commit message
                commit_msg = f"Auto-sync: {len(changes)} changes at {datetime.utcnow().isoformat()}"
                self.git.commit(commit_msg)
                
                # Push if enabled
                if self.config.auto_push:
                    self.git.push()
                    print("Changes pushed to GitHub")
    
    async def continuous_sync(self):
        """Run continuous synchronization loop"""
        self.is_running = True
        
        print(f"Starting continuous sync (interval: {self.config.sync_interval}s)")
        
        while self.is_running:
            try:
                # Scan for changes
                changes = self.scan_for_changes()
                
                if changes:
                    self.sync_changes(changes)
                
                # Wait for next sync interval
                await asyncio.sleep(self.config.sync_interval)
                
            except Exception as e:
                print(f"Error in sync loop: {e}")
                await asyncio.sleep(10)  # Wait before retrying
    
    def stop_sync(self):
        """Stop the synchronization loop"""
        self.is_running = False
        print("Sync stopped")
    
    def manual_sync(self):
        """Perform one-time manual sync"""
        changes = self.scan_for_changes()
        self.sync_changes(changes)
        print("Manual sync completed")
    
    def get_sync_status(self) -> Dict[str, any]:
        """Get current sync status"""
        git_status = self.git.get_status()
        current_commit = self.git.get_current_commit()
        
        return {
            "is_running": self.is_running,
            "current_commit": current_commit,
            "git_status": git_status,
            "tracked_files": len(self.file_hashes),
            "last_sync": datetime.utcnow().isoformat()
        }


if __name__ == "__main__":
    # Example configuration
    config = SyncConfig(
        github_repo="ovbslaught/NOMADZ-0",
        github_branch="Cosmic-key",
        google_drive_path="/content/drive/MyDrive/NOMADZ-0",
        termux_path="/data/data/com.termux/files/home/NOMADZ-0",
        local_path="/workspaces/NOMADZ-0",
        sync_interval=300,
        auto_commit=True,
        auto_push=False
    )
    
    # Create sync manager
    sync_manager = CrossPlatformSyncManager(config)
    
    # Run continuous sync
    async def main():
        try:
            await sync_manager.continuous_sync()
        except KeyboardInterrupt:
            sync_manager.stop_sync()
    
    asyncio.run(main())
