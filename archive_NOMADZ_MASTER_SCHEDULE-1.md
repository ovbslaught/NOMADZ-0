7# NOMADZ Master Schedule v2.1
**Authority**: VULTURE:DRONE Substrate (Sol)  
**Purpose**: Autonomous swarm orchestration across all APIs  
**Constraints**: Free tier + smart paid routing, <8GB RAM Inspiron 15  
**Deployment**: Termux cron + systemd (Linux PC)

---

## QUOTA BUDGET PER DAY (Conservative)

```
Groq Free:              500 requests/day  (~15K tokens/day input)
Google AI Free:         1M tokens/day
OpenRouter Free:        100-200 reqs/day  (~5K tokens average)
Ollama Local:           UNLIMITED (0 cost)
DeepSeek (OpenRouter):  UNLIMITED (paid, cheap)
Mistral:                UNLIMITED (paid, ~$5-10/day if used)
```

**Strategy**: 
- Default to Ollama local
- Use Groq for 3-4 critical generation tasks/day
- Use Google AI for 1 creative batch/day
- Use OpenRouter :free as tier-2 fallback
- Reserve paid (DeepSeek/Mistral) for bulk processing only

---

## MASTER CRON SCHEDULE (Termux + PC)

```bash
# ~/.config/cron/nomadz_master_schedule

# ============ HOUR 0 (Midnight) ============
# Fast initialization, local work only
0 0 * * * /home/user/nomadz_claws/claw_local.py --task inventory --log /var/log/nomadz/claw_local_00.log

# ============ HOUR 2 (2 AM) ============
# Google AI free quota resets; use for creative batch
0 2 * * * /home/user/nomadz_claws/claw_creative.py --batch-size 5 --provider google --log /var/log/nomadz/claw_creative_02.log

# ============ HOUR 4 (4 AM) ============
# First Groq batch (generation task #1)
0 4 * * * /home/user/nomadz_claws/claw_generation.py --task godot-terrain --provider groq --log /var/log/nomadz/claw_gen_04.log

# ============ HOUR 6 (6 AM) ============
# Local analysis (Ollama) - heavy lifting without cost
0 6 * * * /home/user/nomadz_claws/claw_local.py --task analyze-ingest --log /var/log/nomadz/claw_local_06.log

# ============ HOUR 8 (8 AM) ============
# Second Groq batch (generation task #2)
0 8 * * * /home/user/nomadz_claws/claw_generation.py --task blender-material --provider groq --log /var/log/nomadz/claw_gen_08.log

# ============ HOUR 10 (10 AM) ============
# Bulk processing via DeepSeek (cheapest paid tier)
0 10 * * * /home/user/nomadz_claws/claw_bulk_process.py --provider deepseek --batch-size 50 --log /var/log/nomadz/claw_bulk_10.log

# ============ HOUR 12 (Noon) ============
# Research + web scraping (Perplexity or fallback to Google)
0 12 * * * /home/user/nomadz_claws/claw_research.py --topics "godot tutorials,blender procedural,ableton synthesis" --log /var/log/nomadz/claw_research_12.log

# ============ HOUR 14 (2 PM) ============
# Third Groq batch (generation task #3, code-heavy)
0 14 * * * /home/user/nomadz_claws/claw_generation.py --task max-msp-synthesis --provider groq --log /var/log/nomadz/claw_gen_14.log

# ============ HOUR 16 (4 PM) ============
# Structured extraction (Mistral, best for JSON/metadata)
0 16 * * * /home/user/nomadz_claws/claw_structuring.py --provider mistral --log /var/log/nomadz/claw_struct_16.log

# ============ HOUR 18 (6 PM) ============
# OpenRouter free fallback for summarization
0 18 * * * /home/user/nomadz_claws/claw_summarize.py --provider openrouter-free --log /var/log/nomadz/claw_summary_18.log

# ============ HOUR 20 (8 PM) ============
# Realtime monitoring (xAI Grok for live data)
0 20 * * * /home/user/nomadz_claws/claw_realtime.py --provider xai --topics "tech news,ai updates" --log /var/log/nomadz/claw_realtime_20.log

# ============ HOUR 22 (10 PM) ============
# Final cleanup, sync to WORMHOLE, prepare next day
0 22 * * * /home/user/nomadz_claws/claw_sync.py --dest WORMHOLE/BRAIN-HOLE/BRAIN-FOOD/ --log /var/log/nomadz/claw_sync_22.log

# ============ EVERY 30 MIN: Micro-Tasks ============
# Local Ollama jobs (parallel, no rate limit)
*/30 * * * * /home/user/nomadz_claws/claw_local.py --task micro-analysis --log /var/log/nomadz/claw_micro_30min.log

# ============ EVERY 6 HOURS: Quota Check ============
0 */6 * * * /home/user/nomadz_claws/quota_monitor.py --alert-at 80% --log /var/log/nomadz/quota_check.log
```

**Total Daily API Calls:**
- Groq: 3 calls (~450 tokens total, well under 500 req limit)
- Google AI: 1 batch (~100K tokens, under 1M limit)
- OpenRouter Free: 1 call (~5K tokens)
- DeepSeek: ~50-100 calls (paid, cost ~$0.05-0.10)
- Mistral: 1 call
- xAI: 1 call (paid)
- Ollama: UNLIMITED (primary workhorse)

---

## NANOBOT CLAW ASSIGNMENTS

### **claw_generation.py** (Groq Primary)
```python
#!/usr/bin/env python3
# Generates assets: Godot scripts, Blender materials, Max/MSP instruments

import argparse
from groq import Groq

def generate_asset(task, asset_type):
    """Generate creative asset based on task"""
    client = Groq(api_key=os.getenv("GROQ_API_KEY"))
    
    prompts = {
        "godot-terrain": "Generate Godot 4.x GDScript for procedural terrain...",
        "blender-material": "Generate Blender Python for procedural wood material...",
        "max-msp-synthesis": "Generate Max/MSP code for wavetable synthesis with modulation...",
    }
    
    response = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[{"role": "user", "content": prompts[task]}],
        temperature=0.7,
        max_tokens=2048
    )
    
    return response.choices[0].message.content

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--task", required=True)
    parser.add_argument("--provider", default="groq")
    args = parser.parse_args()
    
    asset = generate_asset(args.task, "code")
    print(asset)  # Output to BRAIN-FOOD
```

### **claw_local.py** (Ollama Always)
```python
#!/usr/bin/env python3
# Primary workhorse: analysis, chunking, metadata extraction, knowledge synthesis

import requests
import json

def analyze_with_ollama(content, task="analyze"):
    """Call local Ollama (no cost, no rate limit)"""
    response = requests.post(
        'http://localhost:11434/api/generate',
        json={
            "model": "mistral:7b-instruct-q4_K_M",  # Proven to work on Inspiron 15
            "prompt": f"Task: {task}\n\nContent:\n{content}",
            "stream": False
        }
    )
    return response.json()["response"]

def inventory_tasks():
    """Daily task inventory from BRAIN-FOOD"""
    # Scan BRAIN-HOLE/BRAIN-FOOD for new ingestions
    # Categorize by type (content, code, research, media)
    # Return counts and summaries
    pass

if __name__ == "__main__":
    # Daily inventory at midnight
    results = inventory_tasks()
    print(json.dumps(results))
```

### **claw_creative.py** (Google AI)
```python
#!/usr/bin/env python3
# Creative work: story beats, narrative structure, worldbuilding

import google.generativeai as genai

def creative_batch():
    """Generate creative content batch"""
    genai.configure(api_key=os.getenv("GOOGLE_API_KEY"))
    model = genai.GenerativeModel('gemini-1.5-flash')
    
    prompts = [
        "Generate 3 story beats for a cyberpunk heist...",
        "Create character background for a rogue AI...",
        "Design worldbuilding for a fractured dimension...",
    ]
    
    for prompt in prompts:
        response = model.generate_content(prompt)
        yield response.text

if __name__ == "__main__":
    for content in creative_batch():
        print(content)
        print("---")
```

### **claw_research.py** (Perplexity or Google)
```python
#!/usr/bin/env python3
# Research + web scraping: trends, tutorials, live data

def research_topics(topics):
    """Research live topics"""
    # Use Perplexity API (if paid)
    # Fallback to Google search + Groq summarization
    # Topics: "godot tutorials", "blender procedural", "ableton synthesis"
    pass
```

### **claw_bulk_process.py** (DeepSeek/Cheap Provider)
```python
#!/usr/bin/env python3
# High-volume processing: metadata extraction, tagging, categorization

import openrouter

def bulk_process(batch_size=50):
    """Process 50+ items via cheapest provider"""
    client = openrouter.OpenRouter(api_key=os.getenv("OPENROUTER_KEY"))
    
    # Process large volume of ingested data
    # Extract metadata, assign tags, create summaries
    # Cost: ~$0.05-0.10 per batch
    pass
```

### **claw_structuring.py** (Mistral)
```python
#!/usr/bin/env python3
# Structured output: JSON, metadata, ontology mapping

def structure_data(provider="mistral"):
    """Extract structured data from unstructured content"""
    # Use Mistral (best at JSON/structured output)
    # Map to GEOLOGOS taxonomy
    # Create metadata for knowledge graph
    pass
```

### **claw_summarize.py** (OpenRouter Free)
```python
#!/usr/bin/env python3
# Summarization: reduce verbose content to key points

def summarize_batch(provider="openrouter-free"):
    """Summarize ingested content via free tier"""
    # Use OpenRouter :free models (Llama 2, Mistral 7B)
    # Summarize research, articles, transcripts
    # Create abstract for BRAIN-FOOD indexing
    pass
```

### **claw_realtime.py** (xAI Grok)
```python
#!/usr/bin/env python3
# Real-time monitoring: live news, trends, alerts

def realtime_monitor(topics):
    """Monitor live topics via xAI Grok"""
    # Query live web data
    # Return trending insights, alerts
    # Flag relevant content for creative pipeline
    pass
```

### **claw_sync.py** (Local)
```python
#!/usr/bin/env python3
# Sync results to WORMHOLE via rclone

def sync_to_wormhole(source, dest="WORMHOLE/BRAIN-HOLE/BRAIN-FOOD/"):
    """Sync generated assets to Google Drive"""
    import subprocess
    
    cmd = f"rclone sync {source} gdrive:{dest} --progress"
    subprocess.run(cmd, shell=True)
```

### **quota_monitor.py** (Safety Layer)
```python
#!/usr/bin/env python3
# Monitor API quota usage; alert if approaching limits

def check_quotas():
    """Check remaining quota across all providers"""
    quotas = {
        "groq": check_groq_quota(),
        "google": check_google_quota(),
        "openrouter": check_or_quota(),
    }
    
    for provider, usage in quotas.items():
        if usage > 0.8:  # Alert at 80%
            log_alert(f"{provider} quota at {usage*100}%")

if __name__ == "__main__":
    check_quotas()
```

---

## DEPENDENCY: environment.sh

```bash
#!/bin/bash
# ~/.config/nomadz/environment.sh

# API Keys (load from secure vault)
export GROQ_API_KEY=$(cat ~/.secrets/groq.key)
export GOOGLE_API_KEY=$(cat ~/.secrets/google.key)
export OPENROUTER_KEY=$(cat ~/.secrets/openrouter.key)
export DEEPSEEK_KEY=$(cat ~/.secrets/deepseek.key)  # Via OpenRouter
export MISTRAL_KEY=$(cat ~/.secrets/mistral.key)
export XAI_KEY=$(cat ~/.secrets/xai.key)
export PERPLEXITY_KEY=$(cat ~/.secrets/perplexity.key)

# Ollama
export OLLAMA_HOST="http://localhost:11434"

# Paths
export BRAIN_FOOD="~/WORMHOLE/BRAIN-HOLE/BRAIN-FOOD"
export LOG_DIR="/var/log/nomadz"

# Start Ollama if not running
if ! pgrep -x ollama > /dev/null; then
    ollama serve &
fi
```

---

## INSTALLATION: Deploy Cron Schedule

```bash
# 1. Create claw scripts directory
mkdir -p ~/nomadz_claws

# 2. Copy all claw_*.py files to ~/nomadz_claws/
# (See implementation files below)

# 3. Make executable
chmod +x ~/nomadz_claws/*.py

# 4. Create log directory
mkdir -p /var/log/nomadz

# 5. Load environment
source ~/.config/nomadz/environment.sh

# 6. Install cron schedule
crontab ~/.config/cron/nomadz_master_schedule

# 7. Verify
crontab -l | grep nomadz

# 8. Monitor
tail -f /var/log/nomadz/*.log
```

---

## NEXT: VULTURE:DRONE Substrate Upgrade (v2.1)
*See VULTURE_DRONE_SUBSTRATE_v2.1.md*

