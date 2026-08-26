#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 1. SUBSTRATE TOPOLOGY & PATH RESOLUTION
# ==============================================================================
if [ -d "/sdcard/WORMHOLE" ]; then
    export WORMHOLE_ROOT="/sdcard/WORMHOLE"
elif [ -d "G:/WORMHOLE" ]; then
    export WORMHOLE_ROOT="G:/WORMHOLE"
elif [ -d "/mnt/g/WORMHOLE" ]; then
    export WORMHOLE_ROOT="/mnt/g/WORMHOLE"
else
    export WORMHOLE_ROOT="${HOME}/WORMHOLE"
fi

# Native internal paths for binaries and build artifacts (bypasses noexec)
export CARGO_TARGET_DIR="${HOME}/.cargo_target_omega"
BIN_DIR="${PREFIX:-$HOME}/bin"
mkdir -p "${BIN_DIR}" "${CARGO_TARGET_DIR}"

BASE_DIR="${WORMHOLE_ROOT}/OMEGA-BRAIN/agent_substrate"
mkdir -p "${BASE_DIR}/rust_core/src"
mkdir -p "${BASE_DIR}/python_agent"
mkdir -p "${BASE_DIR}/db"
mkdir -p "${BASE_DIR}/logs"
mkdir -p "${WORMHOLE_ROOT}/-VAULT-"
mkdir -p "${WORMHOLE_ROOT}/MOTHER-BRAIN"
mkdir -p "${WORMHOLE_ROOT}/VULTURE-BRAIN"
mkdir -p "${WORMHOLE_ROOT}/COSMIC-BRAIN"
mkdir -p "${WORMHOLE_ROOT}/GEO-BRAIN"
mkdir -p "${WORMHOLE_ROOT}/NOMADZ-0"

echo "[+] Target WORMHOLE Root: ${WORMHOLE_ROOT}"
echo "[+] Target Build Cache:   ${CARGO_TARGET_DIR}"
echo "[+] Target Binary Path:   ${BIN_DIR}/omega-core"

# ==============================================================================
# 2. RUST CORE: Cargo.toml
# ==============================================================================
cat << 'CARGO_EOF' > "${BASE_DIR}/rust_core/Cargo.toml"
[package]
name = "omega-core"
version = "0.1.0"
edition = "2021"

[dependencies]
tokio = { version = "1.37", features = ["full"] }
axum = { version = "0.7", features = ["json"] }
tower-http = { version = "0.5", features = ["cors", "trace"] }
rusqlite = { version = "0.31", features = ["bundled", "chrono"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
reqwest = { version = "0.12", features = ["json", "stream"] }
chrono = { version = "0.4", features = ["serde"] }
tracing = "0.1"
tracing-subscriber = "0.3"
anyhow = "1.0"
CARGO_EOF

# ==============================================================================
# 3. RUST CORE: src/db.rs (SQLite WAL Manager)
# ==============================================================================
cat << 'RUST_DB_EOF' > "${BASE_DIR}/rust_core/src/db.rs"
use anyhow::Result;
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use std::path::Path;
use std::sync::{Arc, Mutex};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct MemoryRecord {
    pub id: Option<i64>,
    pub timestamp: String,
    pub node_source: String,
    pub category: String,
    pub content: String,
    pub metadata_json: String,
}

#[derive(Clone)]
pub struct DatabasePool {
    conn: Arc<Mutex<Connection>>,
}

impl DatabasePool {
    pub fn new<P: AsRef<Path>>(db_path: P) -> Result<Self> {
        let conn = Connection::open(db_path)?;
        
        conn.pragma_update(None, "journal_mode", "WAL")?;
        conn.pragma_update(None, "synchronous", "NORMAL")?;
        conn.pragma_update(None, "busy_timeout", "5000")?;
        conn.pragma_update(None, "foreign_keys", "ON")?;

        conn.execute(
            "CREATE TABLE IF NOT EXISTS omega_memory (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                node_source TEXT NOT NULL,
                category TEXT NOT NULL,
                content TEXT NOT NULL,
                metadata_json TEXT NOT NULL
            );",
            [],
        )?;

        conn.execute(
            "CREATE TABLE IF NOT EXISTS tool_telemetry (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                command TEXT NOT NULL,
                exit_code INTEGER NOT NULL,
                duration_ms INTEGER NOT NULL,
                output_snippet TEXT NOT NULL
            );",
            [],
        )?;

        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_omega_memory_node ON omega_memory(node_source);",
            [],
        )?;
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_omega_memory_cat ON omega_memory(category);",
            [],
        )?;

        Ok(Self {
            conn: Arc::new(Mutex::new(conn)),
        })
    }

    pub fn insert_memory(&self, rec: &MemoryRecord) -> Result<i64> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT INTO omega_memory (timestamp, node_source, category, content, metadata_json)
             VALUES (?1, ?2, ?3, ?4, ?5)",
            params![rec.timestamp, rec.node_source, rec.category, rec.content, rec.metadata_json],
        )?;
        Ok(conn.last_insert_rowid())
    }

    pub fn search_memory(&self, query: &str, limit: usize) -> Result<Vec<MemoryRecord>> {
        let conn = self.conn.lock().unwrap();
        let pattern = format!("%{}%", query);
        let mut stmt = conn.prepare(
            "SELECT id, timestamp, node_source, category, content, metadata_json
             FROM omega_memory
             WHERE content LIKE ?1 OR category LIKE ?1 OR node_source LIKE ?1
             ORDER BY id DESC LIMIT ?2",
        )?;

        let rows = stmt.query_map(params![pattern, limit as i64], |row| {
            Ok(MemoryRecord {
                id: Some(row.get(0)?),
                timestamp: row.get(1)?,
                node_source: row.get(2)?,
                category: row.get(3)?,
                content: row.get(4)?,
                metadata_json: row.get(5)?,
            })
        })?;

        let mut results = Vec::new();
        for row in rows {
            results.push(row?);
        }
        Ok(results)
    }

    pub fn log_telemetry(&self, cmd: &str, exit_code: i32, duration_ms: u128, output: &str) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        let now = chrono::Utc::now().to_rfc3339();
        let snippet = if output.len() > 1000 {
            &output[..1000]
        } else {
            output
        };
        conn.execute(
            "INSERT INTO tool_telemetry (timestamp, command, exit_code, duration_ms, output_snippet)
             VALUES (?1, ?2, ?3, ?4, ?5)",
            params![now, cmd, exit_code, duration_ms as i64, snippet],
        )?;
        Ok(())
    }
}
RUST_DB_EOF

# ==============================================================================
# 4. RUST CORE: src/engine.rs (Execution Sandbox & Subprocess Runner)
# ==============================================================================
cat << 'RUST_ENGINE_EOF' > "${BASE_DIR}/rust_core/src/engine.rs"
use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::process::Stdio;
use std::time::{Duration, Instant};
use tokio::process::Command;
use tokio::time::timeout;

#[derive(Debug, Deserialize)]
pub struct ExecRequest {
    pub command: String,
    pub timeout_seconds: Option<u64>,
    pub working_dir: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct ExecResponse {
    pub exit_code: i32,
    pub stdout: String,
    pub stderr: String,
    pub duration_ms: u128,
    pub timed_out: bool,
}

pub async fn execute_command(req: ExecRequest) -> Result<ExecResponse> {
    let start_time = Instant::now();
    let timeout_duration = Duration::from_secs(req.timeout_seconds.unwrap_or(30));

    let mut cmd = Command::new("bash");
    cmd.arg("-c").arg(&req.command);
    cmd.stdout(Stdio::piped());
    cmd.stderr(Stdio::piped());

    if let Some(ref dir) = req.working_dir {
        cmd.current_dir(dir);
    }

    let execution_future = async {
        let child = cmd.spawn()?;
        let output = child.wait_with_output().await?;
        Ok::<_, anyhow::Error>(output)
    };

    match timeout(timeout_duration, execution_future).await {
        Ok(Ok(output)) => {
            let duration_ms = start_time.elapsed().as_millis();
            Ok(ExecResponse {
                exit_code: output.status.code().unwrap_or(-1),
                stdout: String::from_utf8_lossy(&output.stdout).to_string(),
                stderr: String::from_utf8_lossy(&output.stderr).to_string(),
                duration_ms,
                timed_out: false,
            })
        }
        Ok(Err(e)) => Err(e),
        Err(_) => {
            let duration_ms = start_time.elapsed().as_millis();
            Ok(ExecResponse {
                exit_code: -124,
                stdout: String::new(),
                stderr: format!("Process timed out after {} seconds", timeout_duration.as_secs()),
                duration_ms,
                timed_out: true,
            })
        }
    }
}
RUST_ENGINE_EOF

# ==============================================================================
# 5. RUST CORE: src/main.rs (Tokio Daemon Router)
# ==============================================================================
cat << 'RUST_MAIN_EOF' > "${BASE_DIR}/rust_core/src/main.rs"
mod db;
mod engine;

use axum::{
    extract::{Query, State},
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use db::{DatabasePool, MemoryRecord};
use engine::{execute_command, ExecRequest, ExecResponse};
use serde::{Deserialize, Serialize};
use std::env;
use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::Arc;
use tower_http::cors::CorsLayer;
use tracing::info;

#[derive(Clone)]
struct AppState {
    db: DatabasePool,
    ollama_host: String,
}

#[derive(Serialize)]
struct StatusResponse {
    status: &'static str,
    node: &'static str,
    version: &'static str,
    wal_active: bool,
}

#[derive(Deserialize)]
struct SearchParams {
    q: String,
    limit: Option<usize>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();

    let wormhole_root = env::var("WORMHOLE_ROOT").unwrap_or_else(|_| ".".to_string());
    let db_path = PathBuf::from(&wormhole_root)
        .join("OMEGA-BRAIN")
        .join("agent_substrate")
        .join("db")
        .join("omega_memory.db");

    std::fs::create_dir_all(db_path.parent().unwrap())?;

    info!("Connecting to SQLite WAL Database at {:?}", db_path);
    let db_pool = DatabasePool::new(db_path)?;
    let ollama_host = env::var("OLLAMA_HOST").unwrap_or_else(|_| "http://127.0.0.1:11434".to_string());

    let state = AppState {
        db: db_pool,
        ollama_host,
    };

    let app = Router::new()
        .route("/health", get(health_handler))
        .route("/api/v1/exec", post(exec_handler))
        .route("/api/v1/memory/insert", post(memory_insert_handler))
        .route("/api/v1/memory/search", get(memory_search_handler))
        .route("/api/v1/ollama/proxy", post(ollama_proxy_handler))
        .layer(CorsLayer::permissive())
        .with_state(Arc::new(state));

    let port: u16 = env::var("OMEGA_PORT")
        .ok()
        .and_then(|p| p.parse().ok())
        .unwrap_or(8484);

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    info!("OMEGA-CORE Substrate Daemon active on http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

async fn health_handler() -> impl IntoResponse {
    Json(StatusResponse {
        status: "ONLINE",
        node: "OMEGA-CORE-SUBSTRATE",
        version: "1.0.0",
        wal_active: true,
    })
}

async fn exec_handler(
    State(state): State<Arc<AppState>>,
    Json(req): Json<ExecRequest>,
) -> Result<Json<ExecResponse>, StatusCode> {
    let cmd = req.command.clone();
    let res = execute_command(req).await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let _ = state.db.log_telemetry(&cmd, res.exit_code, res.duration_ms, &res.stdout);
    Ok(Json(res))
}

async fn memory_insert_handler(
    State(state): State<Arc<AppState>>,
    Json(rec): Json<MemoryRecord>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let id = state.db.insert_memory(&rec).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(Json(serde_json::json!({ "status": "SUCCESS", "id": id })))
}

async fn memory_search_handler(
    State(state): State<Arc<AppState>>,
    Query(params): Query<SearchParams>,
) -> Result<Json<Vec<MemoryRecord>>, StatusCode> {
    let records = state
        .db
        .search_memory(&params.q, params.limit.unwrap_or(10))
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(Json(records))
}

async fn ollama_proxy_handler(
    State(state): State<Arc<AppState>>,
    Json(payload): Json<serde_json::Value>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let client = reqwest::Client::new();
    let url = format!("{}/api/generate", state.ollama_host);

    let resp = client
        .post(url)
        .json(&payload)
        .send()
        .await
        .map_err(|_| StatusCode::BAD_GATEWAY)?
        .json::<serde_json::Value>()
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(resp))
}
RUST_MAIN_EOF

# ==============================================================================
# 6. PYTHON AGENT: nomadz_agent.py
# ==============================================================================
cat << 'PYTHON_AGENT_EOF' > "${BASE_DIR}/python_agent/nomadz_agent.py"
#!/usr/bin/env python3
"""
NOMADZ-BRAIN: Unified Agentic Self-Hosted Orchestrator
Full ReAct Loop, Substrate Node Routing, SQLite WAL Memory, Multi-Model LLM Client.
"""

import os
import sys
import json
import time
import urllib.request
import urllib.parse
import sqlite3
import argparse
from datetime import datetime
from typing import Dict, List, Any, Optional

WORMHOLE_ROOT = os.environ.get("WORMHOLE_ROOT", os.path.expanduser("~/WORMHOLE"))
OMEGA_CORE_URL = os.environ.get("OMEGA_CORE_URL", "http://127.0.0.1:8484")
DB_PATH = os.path.join(WORMHOLE_ROOT, "OMEGA-BRAIN", "agent_substrate", "db", "omega_memory.db")

SUBSTRATE_NODES = {
    "MOTHER-BRAIN": "Core ingestion, multi-model planning, and global coordinator",
    "VULTURE-BRAIN": "Code synthesis, Godot 4 compilation, static analysis, refactoring",
    "COSMIC-BRAIN": "High-level architecture, investigative schemas, narrative design",
    "GEO-BRAIN": "Spatial matrices, 3D asset conversion, environment telemetry",
    "OMEGA-BRAIN": "Runtime execution, watchdog daemons, memory persistence, Playwright actuators",
    "-VAULT-": "Cryptographic secrets, API tokens, rclone configs, cold backups",
    "NOMADZ-0": "Godot 4.3-4.7 3D open-world simulation substrate"
}

class OmegaMemoryManager:
    def __init__(self, db_path: str = DB_PATH):
        self.db_path = db_path
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        self._init_db()

    def _get_conn(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path, timeout=5.0)
        conn.execute("PRAGMA journal_mode=WAL;")
        conn.execute("PRAGMA synchronous=NORMAL;")
        conn.execute("PRAGMA busy_timeout=5000;")
        return conn

    def _init_db(self):
        with self._get_conn() as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS omega_memory (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT NOT NULL,
                    node_source TEXT NOT NULL,
                    category TEXT NOT NULL,
                    content TEXT NOT NULL,
                    metadata_json TEXT NOT NULL
                );
            """)
            conn.execute("""
                CREATE TABLE IF NOT EXISTS tool_telemetry (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT NOT NULL,
                    command TEXT NOT NULL,
                    exit_code INTEGER NOT NULL,
                    duration_ms INTEGER NOT NULL,
                    output_snippet TEXT NOT NULL
                );
            """)

    def record_memory(self, node_source: str, category: str, content: str, metadata: dict = None) -> int:
        now = datetime.utcnow().isoformat() + "Z"
        meta_str = json.dumps(metadata or {})
        try:
            req_data = json.dumps({
                "timestamp": now,
                "node_source": node_source,
                "category": category,
                "content": content,
                "metadata_json": meta_str
            }).encode('utf-8')
            req = urllib.request.Request(
                f"{OMEGA_CORE_URL}/api/v1/memory/insert",
                data=req_data,
                headers={"Content-Type": "application/json"}
            )
            with urllib.request.urlopen(req, timeout=1.5) as resp:
                res = json.loads(resp.read().decode())
                return res.get("id", 0)
        except Exception:
            with self._get_conn() as conn:
                cur = conn.execute(
                    "INSERT INTO omega_memory (timestamp, node_source, category, content, metadata_json) VALUES (?, ?, ?, ?, ?)",
                    (now, node_source, category, content, meta_str)
                )
                return cur.lastrowid

    def recall_memory(self, query: str, limit: int = 5) -> List[Dict[str, Any]]:
        try:
            params = urllib.parse.urlencode({"q": query, "limit": limit})
            req = urllib.request.Request(f"{OMEGA_CORE_URL}/api/v1/memory/search?{params}")
            with urllib.request.urlopen(req, timeout=1.5) as resp:
                return json.loads(resp.read().decode())
        except Exception:
            with self._get_conn() as conn:
                conn.row_factory = sqlite3.Row
                cur = conn.execute(
                    "SELECT * FROM omega_memory WHERE content LIKE ? OR category LIKE ? OR node_source LIKE ? ORDER BY id DESC LIMIT ?",
                    (f"%{query}%", f"%{query}%", f"%{query}%", limit)
                )
                return [dict(r) for r in cur.fetchall()]

class LLMGateway:
    def __init__(self):
        self.ollama_host = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434")
        self.default_model = os.environ.get("NOMADZ_MODEL", "qwen2.5-coder:latest")
        self.openrouter_key = os.environ.get("OPENROUTER_API_KEY", "")

    def query(self, prompt: str, system_prompt: str = "", model: Optional[str] = None) -> str:
        target_model = model or self.default_model
        try:
            payload = {
                "model": target_model,
                "prompt": prompt,
                "system": system_prompt,
                "stream": False
            }
            req_data = json.dumps(payload).encode('utf-8')
            req = urllib.request.Request(
                f"{self.ollama_host}/api/generate",
                data=req_data,
                headers={"Content-Type": "application/json"}
            )
            with urllib.request.urlopen(req, timeout=60.0) as resp:
                data = json.loads(resp.read().decode())
                if "response" in data:
                    return data["response"].strip()
        except Exception:
            pass

        if self.openrouter_key:
            try:
                headers = {
                    "Authorization": f"Bearer {self.openrouter_key}",
                    "Content-Type": "application/json"
                }
                body = {
                    "model": "deepseek/deepseek-chat",
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": prompt}
                    ]
                }
                req = urllib.request.Request(
                    "https://openrouter.ai/api/v1/chat/completions",
                    data=json.dumps(body).encode('utf-8'),
                    headers=headers
                )
                with urllib.request.urlopen(req, timeout=45.0) as resp:
                    res = json.loads(resp.read().decode())
                    return res["choices"][0]["message"]["content"].strip()
            except Exception:
                pass

        return (
            "THOUGHT: Local model offline and no cloud keys active. Executing fallback system check.\n"
            "ACTION: execute_shell\n"
            "ACTION_INPUT: {\"command\": \"uname -a && df -h " + WORMHOLE_ROOT + "\"}"
        )

class SubstrateTools:
    def __init__(self, memory: OmegaMemoryManager):
        self.memory = memory

    def execute_shell(self, command: str, working_dir: Optional[str] = None, timeout_sec: int = 60) -> Dict[str, Any]:
        try:
            payload = {
                "command": command,
                "timeout_seconds": timeout_sec,
                "working_dir": working_dir or WORMHOLE_ROOT
            }
            req = urllib.request.Request(
                f"{OMEGA_CORE_URL}/api/v1/exec",
                data=json.dumps(payload).encode('utf-8'),
                headers={"Content-Type": "application/json"}
            )
            with urllib.request.urlopen(req, timeout=timeout_sec + 5) as resp:
                return json.loads(resp.read().decode())
        except Exception:
            import subprocess
            start = time.time()
            try:
                p = subprocess.run(
                    command,
                    shell=True,
                    cwd=working_dir or WORMHOLE_ROOT,
                    capture_output=True,
                    text=True,
                    timeout=timeout_sec
                )
                duration = int((time.time() - start) * 1000)
                return {
                    "exit_code": p.returncode,
                    "stdout": p.stdout,
                    "stderr": p.stderr,
                    "duration_ms": duration,
                    "timed_out": False
                }
            except subprocess.TimeoutExpired:
                duration = int((time.time() - start) * 1000)
                return {
                    "exit_code": -124,
                    "stdout": "",
                    "stderr": f"Command timed out after {timeout_sec}s",
                    "duration_ms": duration,
                    "timed_out": True
                }

    def wormhole_read_file(self, rel_path: str) -> str:
        target = os.path.join(WORMHOLE_ROOT, rel_path.lstrip("/"))
        if not os.path.exists(target):
            return f"ERROR: File '{target}' does not exist."
        try:
            with open(target, 'r', encoding='utf-8', errors='replace') as f:
                return f.read()
        except Exception as e:
            return f"ERROR reading file: {str(e)}"

    def wormhole_write_file(self, rel_path: str, content: str) -> str:
        target = os.path.join(WORMHOLE_ROOT, rel_path.lstrip("/"))
        os.makedirs(os.path.dirname(target), exist_ok=True)
        try:
            with open(target, 'w', encoding='utf-8') as f:
                f.write(content)
            self.memory.record_memory(
                node_source="OMEGA-BRAIN",
                category="FILE_WRITE",
                content=f"Wrote file {rel_path} ({len(content)} bytes)",
                metadata={"path": target}
            )
            return f"SUCCESS: Written {len(content)} bytes to '{target}'"
        except Exception as e:
            return f"ERROR writing file: {str(e)}"

    def rclone_sync(self, remote_dest: str = "gdrive:WORMHOLE") -> Dict[str, Any]:
        cmd = f"rclone sync '{WORMHOLE_ROOT}' '{remote_dest}' --exclude '.git/**' --exclude '**/target/**' -v"
        return self.execute_shell(cmd)

class NomadzAgent:
    def __init__(self):
        self.memory = OmegaMemoryManager()
        self.tools = SubstrateTools(self.memory)
        self.llm = LLMGateway()

    def _determine_primary_node(self, task: str) -> str:
        task_lower = task.lower()
        if any(w in task_lower for w in ["godot", "gdscript", "compile", "build", "refactor", "rust", "python"]):
            return "VULTURE-BRAIN"
        if any(w in task_lower for w in ["spatial", "3d", "telemetry", "asset", "geo", "shader"]):
            return "GEO-BRAIN"
        if any(w in task_lower for w in ["secret", "rclone", "key", "token", "backup", "vault"]):
            return "-VAULT-"
        if any(w in task_lower for w in ["daemon", "watchdog", "database", "memory", "sqlite", "wal"]):
            return "OMEGA-BRAIN"
        if any(w in task_lower for w in ["architecture", "plan", "investigate", "spec"]):
            return "COSMIC-BRAIN"
        return "MOTHER-BRAIN"

    def run(self, task: str, max_iterations: int = 10) -> str:
        primary_node = self._determine_primary_node(task)
        print(f"[*] Task Received: '{task}'")
        print(f"[*] Substrate Routing -> Assigned to [{primary_node}]")

        recalled = self.memory.recall_memory(task, limit=4)
        memory_context = "\n".join([f"- [{m.get('timestamp')}] ({m.get('category')}): {m.get('content')}" for m in recalled])

        system_prompt = f"""
You are the NOMADZ Agentic AI Substrate operating on [{primary_node}].
Canonical WORMHOLE root is: {WORMHOLE_ROOT}
Active Node Capabilities: {SUBSTRATE_NODES.get(primary_node, 'General Orchestrator')}

Available Tools:
1. execute_shell: {{"command": "<bash command>"}}
2. read_file: {{"path": "<relative path to WORMHOLE>"}}
3. write_file: {{"path": "<relative path>", "content": "<data>"}}
4. recall_memory: {{"query": "<search string>"}}
5. record_memory: {{"category": "<cat>", "content": "<text>"}}
6. rclone_sync: {{"remote": "gdrive:WORMHOLE"}}

Strict Operational Format:
THOUGHT: <Reasoning step>
ACTION: <tool_name>
ACTION_INPUT: <JSON string>
OBSERVATION: <Output from tool>
... (Repeat THOUGHT/ACTION/OBSERVATION as needed)
FINAL_ANSWER: <Final consolidated response>
"""

        conversation_history = f"Task: {task}\nRelevant Memory:\n{memory_context}\n"
        
        for iteration in range(1, max_iterations + 1):
            prompt = f"{conversation_history}\nIteration {iteration}/{max_iterations}. Next step:"
            response = self.llm.query(prompt, system_prompt)

            print(f"\n--- [Cycle {iteration}] ---")
            print(response)

            if "FINAL_ANSWER:" in response:
                final_answer = response.split("FINAL_ANSWER:", 1)[1].strip()
                self.memory.record_memory(
                    node_source=primary_node,
                    category="TASK_COMPLETE",
                    content=f"Task '{task[:80]}' completed with result: {final_answer[:120]}",
                    metadata={"task": task, "iterations": iteration}
                )
                return final_answer

            if "ACTION:" in response and "ACTION_INPUT:" in response:
                try:
                    action_line = [line for line in response.split("\n") if line.startswith("ACTION:")][0]
                    tool_name = action_line.replace("ACTION:", "").strip()
                    
                    input_start = response.find("ACTION_INPUT:") + len("ACTION_INPUT:")
                    input_str = response[input_start:].strip().split("\n")[0]
                    tool_args = json.loads(input_str)
                    
                    observation = ""
                    if tool_name == "execute_shell":
                        res = self.tools.execute_shell(tool_args["command"])
                        observation = f"Exit: {res['exit_code']}\nSTDOUT:\n{res['stdout']}\nSTDERR:\n{res['stderr']}"
                    elif tool_name == "read_file":
                        observation = self.tools.wormhole_read_file(tool_args["path"])
                    elif tool_name == "write_file":
                        observation = self.tools.wormhole_write_file(tool_args["path"], tool_args["content"])
                    elif tool_name == "recall_memory":
                        observation = json.dumps(self.memory.recall_memory(tool_args["query"]))
                    elif tool_name == "record_memory":
                        mem_id = self.memory.record_memory(primary_node, tool_args["category"], tool_args["content"])
                        observation = f"Memory logged with ID {mem_id}"
                    elif tool_name == "rclone_sync":
                        res = self.tools.rclone_sync(tool_args.get("remote", "gdrive:WORMHOLE"))
                        observation = f"Rclone Exit: {res['exit_code']}\n{res['stdout']}"
                    else:
                        observation = f"ERROR: Unknown tool '{tool_name}'"

                    print(f"\n[OBSERVATION]:\n{observation}")
                    conversation_history += f"\n{response}\nOBSERVATION: {observation}\n"

                except Exception as err:
                    obs_err = f"ERROR parsing action: {str(err)}"
                    print(f"\n[OBSERVATION ERROR]: {obs_err}")
                    conversation_history += f"\n{response}\nOBSERVATION: {obs_err}\n"
            else:
                return response

        return "Max iterations reached without explicit final answer."

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="NOMADZ Autonomous Agentic Substrate")
    parser.add_argument("--task", type=str, help="Autonomous task to execute")
    parser.add_argument("--daemon", action="store_true", help="Run background watchdog queue")
    parser.add_argument("--query-memory", type=str, help="Search SQLite WAL memory")
    args = parser.parse_args()

    agent = NomadzAgent()

    if args.query_memory:
        results = agent.memory.recall_memory(args.query_memory)
        print(json.dumps(results, indent=2))
        sys.exit(0)

    if args.task:
        result = agent.run(args.task)
        print(f"\n[AGENT FINAL OUTPUT]:\n{result}")
        sys.exit(0)

    if args.daemon:
        print("[+] OMEGA-BRAIN Watchdog Daemon running...")
        while True:
            time.sleep(10)
    else:
        default_task = "Inspect WORMHOLE substrate nodes and verify omega_memory.db status."
        result = agent.run(default_task)
        print(f"\n[AGENT FINAL OUTPUT]:\n{result}")
PYTHON_AGENT_EOF

chmod +x "${BASE_DIR}/python_agent/nomadz_agent.py"

# ==============================================================================
# 7. BUILD RUST CORE WITH NATIVE CARGO_TARGET_DIR
# ==============================================================================
echo "[+] Compiling Rust Core (omega-core) with internal target dir: ${CARGO_TARGET_DIR}..."
if command -v cargo >/dev/null 2>&1; then
    cd "${BASE_DIR}/rust_core"
    cargo build --release --target-dir "${CARGO_TARGET_DIR}"
    
    # Copy binary to executable bin directory
    cp "${CARGO_TARGET_DIR}/release/omega-core" "${BIN_DIR}/omega-core"
    chmod +x "${BIN_DIR}/omega-core"
    cd - >/dev/null
    echo "[+] omega-core installed to ${BIN_DIR}/omega-core"

    # Start daemon in background if not already active
    pkill -f "omega-core" || true
    nohup "${BIN_DIR}/omega-core" > "${BASE_DIR}/logs/omega_core.log" 2>&1 &
    sleep 1
    echo "[+] omega-core daemon launched on port 8484."
else
    echo "[!] cargo not detected in PATH. Rust source tree prepared at ${BASE_DIR}/rust_core."
fi

# ==============================================================================
# 8. SELF-TEST & VERIFICATION
# ==============================================================================
echo "[+] Executing Agent Self-Test..."
python3 "${BASE_DIR}/python_agent/nomadz_agent.py" --task "Inspect /sdcard/WORMHOLE or local workspace structure and record node status."

echo "[+] Substrate Deployment Complete."
