#!/usr/bin/env python3
"""
knowledge_graph.py - SQLite RAG -> JSON-LD + Obsidian backlinks
Builds bidirectional knowledge graph from vault + RAG database
"""
import os, json, sqlite3, hashlib, re
from pathlib import Path

REPO = os.environ.get('NOMADZ_REPO', '/workspaces/NOMADZ-0')
VAULT = os.path.join(REPO, 'vault')
RAG_DB = os.path.join(REPO, 'data', 'rag.db')
GRAPH_OUT = os.path.join(REPO, 'data', 'knowledge_graph.jsonld')
BACKLINKS_OUT = os.path.join(REPO, 'data', 'backlinks.json')

def extract_links(content):
    wikilinks = re.findall(r'\[\[([^\]]+)\]\]', content)
    mdlinks = re.findall(r'\[([^\]]+)\]\(([^)]+)\)', content)
    tags = re.findall(r'#([\w/-]+)', content)
    return {'wikilinks': wikilinks, 'mdlinks': mdlinks, 'tags': tags}

def scan_vault():
    nodes, edges = [], []
    backlinks = {}
    for root, dirs, files in os.walk(VAULT):
        for f in files:
            if not f.endswith('.md'): continue
            path = os.path.join(root, f)
            with open(path) as file:
                content = file.read()
            rel = os.path.relpath(path, VAULT)
            nid = hashlib.md5(rel.encode()).hexdigest()
            links = extract_links(content)
            nodes.append({'@id': nid, '@type': 'Note', 'title': f, 'path': rel,
                          'tags': links['tags'], 'links_out': len(links['wikilinks']) + len(links['mdlinks'])})
            for target in links['wikilinks']:
                edges.append({'@type': 'LinksTo', 'source': nid, 'target': target})
                backlinks.setdefault(target, []).append(rel)
    return nodes, edges, backlinks

def scan_rag_db():
    if not os.path.exists(RAG_DB): return []
    conn = sqlite3.connect(RAG_DB)
    rows = conn.execute('SELECT url, tag, project, title FROM scrapes').fetchall()
    conn.close()
    nodes = []
    for url, tag, proj, title in rows:
        nid = hashlib.md5(url.encode()).hexdigest()
        nodes.append({'@id': nid, '@type': 'WebResource', 'url': url, 'tag': tag,
                      'project': proj, 'title': title})
    return nodes

def build_graph():
    vault_nodes, edges, backlinks = scan_vault()
    rag_nodes = scan_rag_db()
    graph = {
        '@context': 'https://schema.org',
        '@type': 'Graph',
        'name': 'NOMADZ-0 Knowledge Graph',
        'nodes': vault_nodes + rag_nodes,
        'edges': edges,
        'stats': {'vault_notes': len(vault_nodes), 'web_resources': len(rag_nodes),
                  'total_edges': len(edges), 'unique_tags': len(set(t for n in vault_nodes for t in n.get('tags', [])))}
    }
    with open(GRAPH_OUT, 'w') as f:
        json.dump(graph, f, indent=2)
    with open(BACKLINKS_OUT, 'w') as f:
        json.dump(backlinks, f, indent=2)
    print(f'[KG] Graph: {len(graph["nodes"])} nodes, {len(edges)} edges')
    print(f'[KG] Output: {GRAPH_OUT}')
    print(f'[KG] Backlinks: {BACKLINKS_OUT}')

if __name__ == '__main__':
    build_graph()
