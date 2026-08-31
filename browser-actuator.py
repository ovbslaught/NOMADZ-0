#!/usr/bin/env python3
import os
import asyncio
import sqlite3
from fastapi import FastAPI, HTTPException, BackgroundTasks
import uvicorn
from playwright.async_api import async_playwright

# System Specifications & Paths
DB_PATH = "WORMHOLE/BRAIN-HOLE/BRAIN-FOOD/omega_memory.db"
ACTUATOR_STATE = "WORMHOLE/VULTURE-BRAIN/browser-state.json"

app = FastAPI(title="NOMADZ OMEGA-BRAIN Browser Actuator")

class BrowserNode:
    def __init__(self):
        self.playwright = None
        self.browser = None
        self.context = None
        self.page = None

    async def initialize(self, headless: bool = True):
        """Bootstraps the agentic browser instance."""
        if not self.playwright:
            self.playwright = await async_playwright().start()
            # Chromium optimized for agentic DOM manipulation
            self.browser = await self.playwright.chromium.launch(headless=headless)
            self.context = await self.browser.new_context(
                viewport={'width': 1920, 'height': 1080},
                user_agent="NOMADZ-OMEGA-BRAIN-AGENT/1.0"
            )
            self.page = await self.context.new_page()
            self._log_transaction("BROWSER_INIT", f"Headless: {headless}")

    def _log_transaction(self, action: str, target: str):
        """Append-only telemetry to WAL database."""
        try:
            conn = sqlite3.connect(DB_PATH)
            cursor = conn.cursor()
            # Ensure table exists dynamically
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS autonomous_logs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                    command_type TEXT,
                    target TEXT,
                    status TEXT
                )
            ''')
            cursor.execute('''
                INSERT INTO autonomous_logs (command_type, target, status) 
                VALUES (?, ?, 'SUCCESS')
            ''', (action, target))
            conn.commit()
            conn.close()
        except Exception as e:
            print(f"[WARN] Telemetry logging failed: {e}")

    async def goto(self, url: str):
        if not self.page:
            await self.initialize()
        await self.page.goto(url, wait_until="networkidle")
        self._log_transaction("NAVIGATE", url)
        return await self.page.title()

    async def inject_and_execute(self, script: str):
        """Injects and executes arbitrary JS/App scripts directly into the active page."""
        if not self.page:
            raise Exception("Browser node uninitialized. Awaiting navigation.")
        result = await self.page.evaluate(script)
        self._log_transaction("EXECUTE_SCRIPT", "DOM_INJECTION")
        return result

    async def actuate_element(self, selector: str, action: str, value: str = None):
        """Autonomous DOM manipulation."""
        if not self.page:
            raise Exception("Browser node uninitialized.")
        
        element = self.page.locator(selector).first
        if action == "click":
            await element.click()
        elif action == "type" and value:
            await element.fill(value)
        elif action == "extract":
            return await element.inner_text()
            
        self._log_transaction(f"ACTUATE_{action.upper()}", selector)
        return "SUCCESS"

    async def teardown(self):
        if self.browser:
            await self.browser.close()
        if self.playwright:
            await self.playwright.stop()
            self._log_transaction("BROWSER_TEARDOWN", "ALL_NODES")

node = BrowserNode()

@app.on_event("startup")
async def startup_event():
    # Defaulting to headless for background tasks, can be toggled
    await node.initialize(headless=True)

@app.on_event("shutdown")
async def shutdown_event():
    await node.teardown()

@app.post("/agent/browser/navigate")
async def navigate(url: str):
    try:
        title = await node.goto(url)
        return {"status": "success", "title": title, "url": url}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/agent/browser/execute")
async def execute_script(script: str):
    try:
        result = await node.inject_and_execute(script)
        return {"status": "success", "result": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/agent/browser/actuate")
async def actuate(selector: str, action: str, value: str = None):
    try:
        result = await node.actuate_element(selector, action, value)
        return {"status": "success", "result": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    print("[ACTUATOR] Browser node compiled and ready. Deploying API server...")
    # Activating uvicorn to listen for REST commands
    uvicorn.run(app, host="127.0.0.1", port=8001)
