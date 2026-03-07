"""AI Orchestrator - Multi-Agent Coordination System for NOMADZ-0

Manages AI agent lifecycle, task distribution, and coordination across
multiple AI models and services (Perplexity, Claude, GPT, Gemini, etc.)
"""

import asyncio
import json
import sqlite3
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, asdict
from enum import Enum
from datetime import datetime
import aiohttp


class AgentRole(Enum):
    """AI Agent Role Types"""
    RESEARCHER = "researcher"
    CODER = "coder"
    ANALYST = "analyst"
    ORCHESTRATOR = "orchestrator"
    CREATIVE = "creative"
    QA_TESTER = "qa_tester"
    WORLDBUILDER = "worldbuilder"


class TaskStatus(Enum):
    """Task execution status"""
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


@dataclass
class AIAgent:
    """Represents an AI agent with specific capabilities"""
    agent_id: str
    role: AgentRole
    model: str  # e.g., "claude-3-opus", "gpt-4", "sonar-pro"
    capabilities: List[str]
    max_tokens: int
    temperature: float = 0.7
    is_active: bool = True
    metadata: Dict[str, Any] = None


@dataclass
class Task:
    """Represents a task to be executed by an agent"""
    task_id: str
    description: str
    role_required: AgentRole
    priority: int  # 1-10, higher = more urgent
    status: TaskStatus
    assigned_agent: Optional[str] = None
    result: Optional[Any] = None
    created_at: str = None
    completed_at: Optional[str] = None
    dependencies: List[str] = None
    metadata: Dict[str, Any] = None

    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.utcnow().isoformat()
        if self.dependencies is None:
            self.dependencies = []
        if self.metadata is None:
            self.metadata = {}


class AIOrchestrator:
    """Main orchestrator for managing AI agents and task execution"""
    
    def __init__(self, db_path: str = "nomadz_ai.db"):
        self.db_path = db_path
        self.agents: Dict[str, AIAgent] = {}
        self.tasks: Dict[str, Task] = {}
        self.task_queue: asyncio.Queue = asyncio.Queue()
        self._init_database()
        self._load_default_agents()
    
    def _init_database(self):
        """Initialize SQLite database for persistent storage"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Agents table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS agents (
                agent_id TEXT PRIMARY KEY,
                role TEXT NOT NULL,
                model TEXT NOT NULL,
                capabilities TEXT,
                max_tokens INTEGER,
                temperature REAL,
                is_active INTEGER,
                metadata TEXT
            )
        ''')
        
        # Tasks table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS tasks (
                task_id TEXT PRIMARY KEY,
                description TEXT NOT NULL,
                role_required TEXT NOT NULL,
                priority INTEGER,
                status TEXT,
                assigned_agent TEXT,
                result TEXT,
                created_at TEXT,
                completed_at TEXT,
                dependencies TEXT,
                metadata TEXT,
                FOREIGN KEY (assigned_agent) REFERENCES agents (agent_id)
            )
        ''')
        
        # Execution history
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS execution_history (
                execution_id INTEGER PRIMARY KEY AUTOINCREMENT,
                task_id TEXT,
                agent_id TEXT,
                timestamp TEXT,
                duration_ms INTEGER,
                tokens_used INTEGER,
                success INTEGER,
                error_message TEXT,
                FOREIGN KEY (task_id) REFERENCES tasks (task_id),
                FOREIGN KEY (agent_id) REFERENCES agents (agent_id)
            )
        ''')
        
        conn.commit()
        conn.close()
    
    def _load_default_agents(self):
        """Load default AI agent configurations"""
        default_agents = [
            AIAgent(
                agent_id="researcher_001",
                role=AgentRole.RESEARCHER,
                model="sonar-pro",
                capabilities=["web_search", "data_analysis", "citation"],
                max_tokens=4000
            ),
            AIAgent(
                agent_id="coder_001",
                role=AgentRole.CODER,
                model="claude-3-opus",
                capabilities=["code_generation", "debugging", "refactoring"],
                max_tokens=8000,
                temperature=0.3
            ),
            AIAgent(
                agent_id="analyst_001",
                role=AgentRole.ANALYST,
                model="gpt-4-turbo",
                capabilities=["data_analysis", "visualization", "reporting"],
                max_tokens=4000
            ),
            AIAgent(
                agent_id="creative_001",
                role=AgentRole.CREATIVE,
                model="claude-3-opus",
                capabilities=["storytelling", "worldbuilding", "dialogue"],
                max_tokens=6000,
                temperature=0.9
            ),
        ]
        
        for agent in default_agents:
            self.register_agent(agent)
    
    def register_agent(self, agent: AIAgent):
        """Register a new AI agent"""
        self.agents[agent.agent_id] = agent
        
        # Persist to database
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute('''
            INSERT OR REPLACE INTO agents 
            (agent_id, role, model, capabilities, max_tokens, temperature, is_active, metadata)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            agent.agent_id,
            agent.role.value,
            agent.model,
            json.dumps(agent.capabilities),
            agent.max_tokens,
            agent.temperature,
            1 if agent.is_active else 0,
            json.dumps(agent.metadata) if agent.metadata else '{}'
        ))
        conn.commit()
        conn.close()
    
    async def submit_task(self, task: Task) -> str:
        """Submit a new task to the orchestrator"""
        self.tasks[task.task_id] = task
        
        # Persist to database
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO tasks 
            (task_id, description, role_required, priority, status, assigned_agent, 
             result, created_at, completed_at, dependencies, metadata)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            task.task_id,
            task.description,
            task.role_required.value,
            task.priority,
            task.status.value,
            task.assigned_agent,
            json.dumps(task.result) if task.result else None,
            task.created_at,
            task.completed_at,
            json.dumps(task.dependencies),
            json.dumps(task.metadata)
        ))
        conn.commit()
        conn.close()
        
        # Add to queue
        await self.task_queue.put(task)
        return task.task_id
    
    def get_available_agent(self, role: AgentRole) -> Optional[AIAgent]:
        """Find an available agent for the given role"""
        for agent in self.agents.values():
            if agent.role == role and agent.is_active:
                return agent
        return None
    
    async def execute_task(self, task: Task) -> Any:
        """Execute a task using the appropriate agent"""
        agent = self.get_available_agent(task.role_required)
        if not agent:
            raise ValueError(f"No available agent for role: {task.role_required}")
        
        task.assigned_agent = agent.agent_id
        task.status = TaskStatus.RUNNING
        
        start_time = datetime.utcnow()
        
        try:
            # This is where you would integrate with actual AI APIs
            # For now, this is a placeholder
            result = await self._call_ai_model(agent, task)
            
            task.result = result
            task.status = TaskStatus.COMPLETED
            task.completed_at = datetime.utcnow().isoformat()
            
            duration_ms = int((datetime.utcnow() - start_time).total_seconds() * 1000)
            self._log_execution(task, agent, duration_ms, success=True)
            
            return result
            
        except Exception as e:
            task.status = TaskStatus.FAILED
            task.result = {"error": str(e)}
            
            duration_ms = int((datetime.utcnow() - start_time).total_seconds() * 1000)
            self._log_execution(task, agent, duration_ms, success=False, error=str(e))
            
            raise
    
    async def _call_ai_model(self, agent: AIAgent, task: Task) -> Any:
        """Call the AI model API (placeholder for actual implementation)"""
        # This would be implemented with actual API calls to:
        # - Perplexity API
        # - Anthropic Claude API
        # - OpenAI API
        # - Google Gemini API
        # etc.
        
        await asyncio.sleep(0.1)  # Simulate API call
        return {"status": "success", "message": f"Task {task.task_id} executed by {agent.agent_id}"}
    
    def _log_execution(self, task: Task, agent: AIAgent, duration_ms: int, 
                      success: bool, error: str = None, tokens_used: int = 0):
        """Log task execution to database"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO execution_history 
            (task_id, agent_id, timestamp, duration_ms, tokens_used, success, error_message)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (
            task.task_id,
            agent.agent_id,
            datetime.utcnow().isoformat(),
            duration_ms,
            tokens_used,
            1 if success else 0,
            error
        ))
        conn.commit()
        conn.close()
    
    async def process_queue(self):
        """Process tasks from the queue"""
        while True:
            task = await self.task_queue.get()
            try:
                await self.execute_task(task)
            except Exception as e:
                print(f"Error executing task {task.task_id}: {e}")
            finally:
                self.task_queue.task_done()
    
    def get_agent_stats(self, agent_id: str) -> Dict[str, Any]:
        """Get performance statistics for an agent"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT 
                COUNT(*) as total_tasks,
                SUM(success) as successful_tasks,
                AVG(duration_ms) as avg_duration,
                SUM(tokens_used) as total_tokens
            FROM execution_history
            WHERE agent_id = ?
        ''', (agent_id,))
        
        result = cursor.fetchone()
        conn.close()
        
        return {
            "total_tasks": result[0] or 0,
            "successful_tasks": result[1] or 0,
            "avg_duration_ms": result[2] or 0,
            "total_tokens": result[3] or 0,
            "success_rate": (result[1] / result[0] * 100) if result[0] else 0
        }


if __name__ == "__main__":
    # Example usage
    orchestrator = AIOrchestrator()
    
    # Create a sample task
    task = Task(
        task_id="task_001",
        description="Research the latest developments in procedural generation",
        role_required=AgentRole.RESEARCHER,
        priority=5,
        status=TaskStatus.PENDING
    )
    
    # Run async
    async def main():
        task_id = await orchestrator.submit_task(task)
        print(f"Task submitted: {task_id}")
        
        # Start queue processor
        processor = asyncio.create_task(orchestrator.process_queue())
        
        # Wait a bit for task to complete
        await asyncio.sleep(1)
        
        # Get agent stats
        stats = orchestrator.get_agent_stats("researcher_001")
        print(f"Agent stats: {stats}")
    
    asyncio.run(main())
