"""VULTURE Integration - Connects NOMADZ-0 with VULTURE IDE

Provides bidirectional communication between Godot project and
VULTURE development environment for live code sync and debugging.
"""

import json
import asyncio
import websockets
from typing import Dict, List, Any, Optional, Callable
from dataclasses import dataclass
from datetime import datetime
import hashlib


@dataclass
class CodeSyncEvent:
    """Represents a code synchronization event"""
    event_id: str
    event_type: str  # 'file_changed', 'file_created', 'file_deleted'
    file_path: str
    content: Optional[str]
    timestamp: str
    hash: str
    metadata: Dict[str, Any] = None


@dataclass
class DebugEvent:
    """Debug event from Godot runtime"""
    event_id: str
    level: str  # 'info', 'warning', 'error'
    message: str
    source_file: str
    line_number: int
    timestamp: str
    stack_trace: Optional[List[str]] = None


class VultureConnection:
    """Manages WebSocket connection to VULTURE IDE"""
    
    def __init__(self, vulture_url: str = "ws://localhost:8765"):
        self.vulture_url = vulture_url
        self.websocket = None
        self.is_connected = False
        self.event_handlers: Dict[str, List[Callable]] = {}
        self.message_queue = asyncio.Queue()
    
    async def connect(self) -> bool:
        """Establish connection to VULTURE IDE"""
        try:
            self.websocket = await websockets.connect(self.vulture_url)
            self.is_connected = True
            print(f"Connected to VULTURE IDE at {self.vulture_url}")
            
            # Send handshake
            await self.send_message({
                "type": "handshake",
                "client": "NOMADZ-0",
                "version": "0.1.0",
                "capabilities": [
                    "code_sync",
                    "debug_events",
                    "live_reload",
                    "resource_monitoring"
                ]
            })
            
            return True
            
        except Exception as e:
            print(f"Failed to connect to VULTURE IDE: {e}")
            self.is_connected = False
            return False
    
    async def disconnect(self):
        """Close connection to VULTURE IDE"""
        if self.websocket:
            await self.websocket.close()
            self.is_connected = False
            print("Disconnected from VULTURE IDE")
    
    async def send_message(self, message: Dict[str, Any]):
        """Send message to VULTURE IDE"""
        if not self.is_connected or not self.websocket:
            raise ConnectionError("Not connected to VULTURE IDE")
        
        await self.websocket.send(json.dumps(message))
    
    async def receive_messages(self):
        """Receive messages from VULTURE IDE"""
        while self.is_connected:
            try:
                message = await self.websocket.recv()
                data = json.loads(message)
                await self.handle_message(data)
            except websockets.exceptions.ConnectionClosed:
                print("Connection to VULTURE IDE closed")
                self.is_connected = False
                break
            except Exception as e:
                print(f"Error receiving message: {e}")
    
    async def handle_message(self, data: Dict[str, Any]):
        """Handle incoming message from VULTURE IDE"""
        msg_type = data.get("type")
        
        if msg_type in self.event_handlers:
            for handler in self.event_handlers[msg_type]:
                await handler(data)
    
    def on(self, event_type: str, handler: Callable):
        """Register event handler"""
        if event_type not in self.event_handlers:
            self.event_handlers[event_type] = []
        self.event_handlers[event_type].append(handler)
    
    async def sync_file(self, file_path: str, content: str):
        """Sync a file to VULTURE IDE"""
        file_hash = hashlib.sha256(content.encode()).hexdigest()
        
        event = CodeSyncEvent(
            event_id=f"sync_{datetime.utcnow().timestamp()}",
            event_type="file_changed",
            file_path=file_path,
            content=content,
            timestamp=datetime.utcnow().isoformat(),
            hash=file_hash
        )
        
        await self.send_message({
            "type": "code_sync",
            "event": {
                "event_id": event.event_id,
                "event_type": event.event_type,
                "file_path": event.file_path,
                "content": event.content,
                "timestamp": event.timestamp,
                "hash": event.hash
            }
        })
    
    async def send_debug_event(self, event: DebugEvent):
        """Send debug event to VULTURE IDE"""
        await self.send_message({
            "type": "debug_event",
            "event": {
                "event_id": event.event_id,
                "level": event.level,
                "message": event.message,
                "source_file": event.source_file,
                "line_number": event.line_number,
                "timestamp": event.timestamp,
                "stack_trace": event.stack_trace
            }
        })


class GodotBridge:
    """Bridge between Godot engine and VULTURE IDE"""
    
    def __init__(self, vulture_conn: VultureConnection):
        self.vulture_conn = vulture_conn
        self.watched_files: Dict[str, str] = {}  # path -> hash
        self.is_monitoring = False
    
    async def start_file_watcher(self, paths: List[str]):
        """Start watching files for changes"""
        import os
        import time
        
        self.is_monitoring = True
        
        while self.is_monitoring:
            for path in paths:
                if os.path.exists(path):
                    with open(path, 'r') as f:
                        content = f.read()
                        file_hash = hashlib.sha256(content.encode()).hexdigest()
                        
                        # Check if file changed
                        if path not in self.watched_files or self.watched_files[path] != file_hash:
                            self.watched_files[path] = file_hash
                            await self.vulture_conn.sync_file(path, content)
            
            await asyncio.sleep(1)  # Check every second
    
    def stop_file_watcher(self):
        """Stop watching files"""
        self.is_monitoring = False
    
    async def execute_godot_command(self, command: str, args: Dict[str, Any]):
        """Execute a command in Godot engine"""
        # This would integrate with Godot's GDScript runtime
        # For now, this is a placeholder
        await self.vulture_conn.send_message({
            "type": "godot_command",
            "command": command,
            "args": args,
            "timestamp": datetime.utcnow().isoformat()
        })
    
    async def hot_reload_script(self, script_path: str):
        """Hot reload a GDScript file in running Godot instance"""
        await self.execute_godot_command("reload_script", {
            "script_path": script_path
        })


class VultureIntegration:
    """Main integration manager for VULTURE IDE"""
    
    def __init__(self, config: Dict[str, Any] = None):
        self.config = config or {}
        self.vulture_url = self.config.get("vulture_url", "ws://localhost:8765")
        self.connection = VultureConnection(self.vulture_url)
        self.godot_bridge = GodotBridge(self.connection)
        self.is_running = False
    
    async def initialize(self):
        """Initialize the VULTURE integration"""
        print("Initializing VULTURE integration...")
        
        # Connect to VULTURE IDE
        connected = await self.connection.connect()
        if not connected:
            raise ConnectionError("Failed to connect to VULTURE IDE")
        
        # Register event handlers
        self.connection.on("command", self.handle_command)
        self.connection.on("request_sync", self.handle_sync_request)
        self.connection.on("hot_reload", self.handle_hot_reload)
        
        print("VULTURE integration initialized")
    
    async def handle_command(self, data: Dict[str, Any]):
        """Handle command from VULTURE IDE"""
        command = data.get("command")
        args = data.get("args", {})
        
        print(f"Received command: {command}")
        await self.godot_bridge.execute_godot_command(command, args)
    
    async def handle_sync_request(self, data: Dict[str, Any]):
        """Handle file sync request from VULTURE IDE"""
        file_path = data.get("file_path")
        print(f"Sync requested for: {file_path}")
        
        # Read and send file
        try:
            with open(file_path, 'r') as f:
                content = f.read()
                await self.connection.sync_file(file_path, content)
        except Exception as e:
            print(f"Error syncing file {file_path}: {e}")
    
    async def handle_hot_reload(self, data: Dict[str, Any]):
        """Handle hot reload request"""
        script_path = data.get("script_path")
        print(f"Hot reload requested for: {script_path}")
        await self.godot_bridge.hot_reload_script(script_path)
    
    async def start(self, watch_paths: List[str] = None):
        """Start the integration service"""
        if self.is_running:
            print("Integration already running")
            return
        
        self.is_running = True
        
        # Start connection
        await self.initialize()
        
        # Start file watcher if paths provided
        if watch_paths:
            watcher_task = asyncio.create_task(
                self.godot_bridge.start_file_watcher(watch_paths)
            )
        
        # Start message receiver
        receiver_task = asyncio.create_task(
            self.connection.receive_messages()
        )
        
        print("VULTURE integration is running")
        
        # Keep running
        try:
            await asyncio.gather(receiver_task)
        except KeyboardInterrupt:
            print("Shutting down VULTURE integration...")
        finally:
            await self.stop()
    
    async def stop(self):
        """Stop the integration service"""
        self.is_running = False
        self.godot_bridge.stop_file_watcher()
        await self.connection.disconnect()
        print("VULTURE integration stopped")


if __name__ == "__main__":
    # Example usage
    async def main():
        config = {
            "vulture_url": "ws://localhost:8765"
        }
        
        integration = VultureIntegration(config)
        
        # Watch GDScript files
        watch_paths = [
            "scripts/gdscript/QuestSystem.gd",
            "scripts/gdscript/ResourceManager.gd",
            "scripts/gdscript/DialogueSystem.gd"
        ]
        
        await integration.start(watch_paths)
    
    asyncio.run(main())
