#!/usr/bin/env python3
"""
firecrawl_pipeline.py - 24/7 Firecrawl -> Notion/Obsidian/SQLite pipeline
Run every 15 min via cron or daemon_runner.py
"""
import os, json, sqlite3, requests, hashlib
from datetime import datetime

FIRECRAWL_API_KEY = os.environ.get('FIRECRAWL_API_KEY', '')
NOTION_TOKEN = os.environ.get('NOTION_TOKEN', '')
NOTION_DB_ID = os.environ.get('NOTION_DB_ID', '2971b391d04780f1af84f3a654a1ed53')
REPO = os.environ.get('NOMADZ_REPO', '/workspaces/NOMADZ-0')
VAULT = os.path.join(REPO, 'vault')
RAG_DB = os.path.join(REPO, 'data', 'rag.db')
LOG = os.path.join(REPO, 'logs', 'pipeline.log')

TARGETS = [
    {'url': 'https://www.usgs.gov/news/science-snippet', 'tag': 'geology', 'project': 'GEOLOGOS'},
    {'url': 'https://www.bas.ac.uk/media/latest-news/', 'tag': 'antarctic', 'project': 'GEOLOGOS'},
    {'url': 'https://arxiv.org/list/astro-ph.GA/recent', 'tag': 'cosmology', 'project': 'COSMO'},
    {'url': 'https://www.nasa.gov/news/', 'tag': 'space', 'project': 'NEO-SOL-OMEGA'},
    {'url': 'https://godotengine.org/news/', 'tag': 'godot', 'project': 'NOMADZ-0'},
    {'url': 'https://www.anthropic.com/news', 'tag': 'ai', 'project': 'VULTURE'},
    {'url': 'https://modelcontextprotocol.io/changelog', 'tag': 'mcp', 'project': 'VULTURE'},
    {'url': 'https://firecrawl.dev/blog', 'tag': 'firecrawl', 'project': 'VULTURE'},
    {'url': 'https://itch.io/games/top-rated/tag-godot', 'tag': 'gamedev', 'project': 'NOMADZ-0'},
    {'url': 'https://phys.org/space-news/', 'tag': 'physics', 'project': 'COSMO'},
]

def log(msg):
    ts = datetime.now().isoformat()
    line = f'[{ts}] {msg}'
    print(line)
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    with open(LOG, 'a') as f: f.write(line + '\n')

def init_db():
    os.makedirs(os.path.dirname(RAG_DB), exist_ok=True)
    c = sqlite3.connect(RAG_DB)
    c.execute('''CREATE TABLE IF NOT EXISTS scrapes (
        id TEXT PRIMARY KEY, url TEXT, tag TEXT, project TEXT,
        title TEXT, content TEXT, scraped_at TEXT,
        pushed_notion INT DEFAULT 0, pushed_obsidian INT DEFAULT 0)''')
    c.commit()
    return c

def scrape(url):
    if FIRECRAWL_API_KEY:
        try:
            r = requests.post('https://api.firecrawl.dev/v1/scrape',
                headers={'Authorization': f'Bearer {FIRECRAWL_API_KEY}', 'Content-Type': 'application/json'},
                json={'url': url, 'formats': ['markdown'], 'onlyMainContent': True}, timeout=30)
            if r.status_code == 200:
                d = r.json().get('data', {})
                return {'title': d.get('metadata', {}).get('title', url), 'content': d.get('markdown', '')[:4000]}
        except Exception as e:
            log(f'Firecrawl err: {e}')
    try:
        r = requests.get(url, timeout=15, headers={'User-Agent': 'NOMADZ-0 Research/1.0'})
        return {'title': url, 'content': r.text[:4000]}
    except:
        return {'title': url, 'content': '[scrape failed]'}

def push_notion(title, content, tag, project, url):
    if not NOTION_TOKEN: return False
    try:
        h = {'Authorization': f'Bearer {NOTION_TOKEN}', 'Content-Type': 'application/json', 'Notion-Version': '2022-06-28'}
        b = {'parent': {'database_id': NOTION_DB_ID},
             'properties': {'title': {'title': [{'text': {'content': f'[{project}][{tag}] {title[:80]}'}}]}},
             'children': [{'object': 'block', 'type': 'paragraph',
                           'paragraph': {'rich_text': [{'type': 'text', 'text': {'content': f'Source: {url}\nScraped: {datetime.now().isoformat()}\n\n{content[:1800]}'}}]}}]}
        r = requests.post('https://api.notion.com/v1/pages', headers=h, json=b, timeout=20)
        return r.status_code == 200
    except Exception as e:
        log(f'Notion err: {e}')
        return False

def push_obsidian(title, content, tag, project, url):
    try:
        folder = os.path.join(VAULT, project)
        os.makedirs(folder, exist_ok=True)
        safe = ''.join(c for c in title[:50] if c.isalnum() or c in ' -_').strip()
        ts = datetime.now().strftime('%Y%m%d_%H%M')
        path = os.path.join(folder, f'{ts}_{safe[:35]}.md')
        fm = f'---\ntags: [{tag}, {project.lower()}]\nurl: {url}\nscraped: {datetime.now().isoformat()}\nproject: {project}\n---\n\n'
        with open(path, 'w') as f: f.write(fm + f'# {title}\n\n{content}')
        return True
    except Exception as e:
        log(f'Obsidian err: {e}')
        return False

def run():
    db = init_db()
    log(f'Pipeline started. {len(TARGETS)} targets.')
    new = 0
    for t in TARGETS:
        url, tag, proj = t['url'], t['tag'], t['project']
        uid = hashlib.md5(f"{url}{datetime.now().strftime('%Y%m%d%H')}".encode()).hexdigest()
        if db.execute('SELECT id FROM scrapes WHERE id=?', (uid,)).fetchone():
            log(f'SKIP {url}'); continue
        log(f'Scraping [{proj}][{tag}]: {url}')
        res = scrape(url)
        title, content = res['title'], res['content']
        db.execute('INSERT INTO scrapes VALUES (?,?,?,?,?,?,?,0,0)',
                   (uid, url, tag, proj, title, content, datetime.now().isoformat()))
        db.commit()
        n_ok = push_notion(title, content, tag, proj, url)
        o_ok = push_obsidian(title, content, tag, proj, url)
        db.execute('UPDATE scrapes SET pushed_notion=?,pushed_obsidian=? WHERE id=?', (int(n_ok), int(o_ok), uid))
        db.commit()
        log(f'  Notion: {"OK" if n_ok else "FAIL"} | Obsidian: {"OK" if o_ok else "FAIL"}')
        new += 1
    db.close()
    log(f'Done. {new} new entries.')

if __name__ == '__main__':
    run()
