#!/usr/bin/env python3
"""
Knowledge Graph Expander - Continuously grows NOMADZ-0 knowledge base
Integrates multiple data sources, creates semantic links, extracts entities
"""

import json
import sqlite3
from pathlib import Path
from datetime import datetime
import re

class KnowledgeGraphExpander:
    def __init__(self, db_path="data/knowledge_graph.db"):
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self.conn = sqlite3.connect(self.db_path)
        self.init_schema()
        
    def init_schema(self):
        """Initialize knowledge graph database schema"""
        cursor = self.conn.cursor()
        
        # Nodes table (entities/concepts)
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS nodes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT UNIQUE NOT NULL,
                type TEXT NOT NULL,
                properties TEXT,
                created_at TEXT,
                updated_at TEXT
            )
        ''')
        
        # Edges table (relationships)
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS edges (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_id INTEGER NOT NULL,
                target_id INTEGER NOT NULL,
                relationship TEXT NOT NULL,
                weight REAL DEFAULT 1.0,
                properties TEXT,
                created_at TEXT,
                FOREIGN KEY (source_id) REFERENCES nodes(id),
                FOREIGN KEY (target_id) REFERENCES nodes(id)
            )
        ''')
        
        # Embeddings table (for semantic search)
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS embeddings (
                node_id INTEGER PRIMARY KEY,
                embedding BLOB,
                FOREIGN KEY (node_id) REFERENCES nodes(id)
            )
        ''')
        
        self.conn.commit()
    
    def add_node(self, name, node_type, properties=None):
        """Add or update a node in the knowledge graph"""
        cursor = self.conn.cursor()
        now = datetime.now().isoformat()
        
        props_json = json.dumps(properties) if properties else None
        
        cursor.execute('''
            INSERT OR REPLACE INTO nodes (name, type, properties, created_at, updated_at)
            VALUES (?, ?, ?, COALESCE((SELECT created_at FROM nodes WHERE name = ?), ?), ?)
        ''', (name, node_type, props_json, name, now, now))
        
        self.conn.commit()
        return cursor.lastrowid
    
    def add_edge(self, source_name, target_name, relationship, weight=1.0, properties=None):
        """Add a relationship between two nodes"""
        cursor = self.conn.cursor()
        
        # Get or create nodes
        source_id = self.get_or_create_node(source_name)
        target_id = self.get_or_create_node(target_name)
        
        props_json = json.dumps(properties) if properties else None
        now = datetime.now().isoformat()
        
        cursor.execute('''
            INSERT INTO edges (source_id, target_id, relationship, weight, properties, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (source_id, target_id, relationship, weight, props_json, now))
        
        self.conn.commit()
    
    def get_or_create_node(self, name, node_type="concept"):
        """Get node ID or create if doesn't exist"""
        cursor = self.conn.cursor()
        cursor.execute('SELECT id FROM nodes WHERE name = ?', (name,))
        result = cursor.fetchone()
        
        if result:
            return result[0]
        else:
            return self.add_node(name, node_type)
    
    def extract_entities_from_text(self, text, source_doc=None):
        """Extract named entities and concepts from text"""
        # Simple entity extraction (can be enhanced with NLP)
        entities = []
        
        # Extract capitalized phrases (potential named entities)
        capitalized = re.findall(r'\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\b', text)
        entities.extend([(e, "named_entity") for e in capitalized])
        
        # Extract technical terms (words with hyphens or camelCase)
        technical = re.findall(r'\b[a-z]+(?:-[a-z]+)+|[a-z]+[A-Z][a-zA-Z]+\b', text)
        entities.extend([(e, "technical_term") for e in technical])
        
        # Add entities to graph
        for entity, entity_type in entities:
            node_id = self.add_node(entity, entity_type)
            if source_doc:
                self.add_edge(source_doc, entity, "mentions")
        
        return entities
    
    def ingest_markdown_file(self, md_path):
        """Ingest a markdown file into knowledge graph"""
        md_path = Path(md_path)
        if not md_path.exists():
            return
        
        content = md_path.read_text()
        doc_name = md_path.stem
        
        # Add document node
        self.add_node(doc_name, "document", {
            "path": str(md_path),
            "size": len(content)
        })
        
        # Extract wikilinks [[link]]
        wikilinks = re.findall(r'\[\[([^\]]+)\]\]', content)
        for link in wikilinks:
            self.add_edge(doc_name, link, "links_to")
        
        # Extract hashtags
        hashtags = re.findall(r'#([a-zA-Z0-9_-]+)', content)
        for tag in hashtags:
            tag_node = self.add_node(f"tag:{tag}", "tag")
            self.add_edge(doc_name, f"tag:{tag}", "tagged_with")
        
        # Extract entities
        self.extract_entities_from_text(content, doc_name)
    
    def ingest_vault(self, vault_path="vault"):
        """Ingest entire Obsidian vault"""
        vault_path = Path(vault_path)
        if not vault_path.exists():
            print(f"Vault not found: {vault_path}")
            return
        
        md_files = list(vault_path.rglob("*.md"))
        print(f"Ingesting {len(md_files)} markdown files...")
        
        for md_file in md_files:
            try:
                self.ingest_markdown_file(md_file)
            except Exception as e:
                print(f"Error ingesting {md_file}: {e}")
        
        print("Vault ingestion complete!")
    
    def get_stats(self):
        """Get knowledge graph statistics"""
        cursor = self.conn.cursor()
        
        cursor.execute('SELECT COUNT(*) FROM nodes')
        node_count = cursor.fetchone()[0]
        
        cursor.execute('SELECT COUNT(*) FROM edges')
        edge_count = cursor.fetchone()[0]
        
        cursor.execute('SELECT type, COUNT(*) FROM nodes GROUP BY type')
        types = cursor.fetchall()
        
        return {
            "nodes": node_count,
            "edges": edge_count,
            "types": dict(types)
        }
    
    def export_to_json(self, output_path="data/knowledge_graph.json"):
        """Export graph to JSON for visualization"""
        cursor = self.conn.cursor()
        
        # Get all nodes
        cursor.execute('SELECT id, name, type, properties FROM nodes')
        nodes = [{"id": row[0], "name": row[1], "type": row[2], "properties": json.loads(row[3]) if row[3] else {}} 
                 for row in cursor.fetchall()]
        
        # Get all edges
        cursor.execute('''
            SELECT e.source_id, e.target_id, e.relationship, e.weight
            FROM edges e
        ''')
        edges = [{"source": row[0], "target": row[1], "relationship": row[2], "weight": row[3]} 
                 for row in cursor.fetchall()]
        
        graph_data = {"nodes": nodes, "edges": edges}
        
        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(graph_data, indent=2))
        
        print(f"Graph exported to {output_path}")
        return graph_data

if __name__ == "__main__":
    kg = KnowledgeGraphExpander()
    kg.ingest_vault()
    stats = kg.get_stats()
    print(f"\nKnowledge Graph Stats: {json.dumps(stats, indent=2)}")
    kg.export_to_json()
