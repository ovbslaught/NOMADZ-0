// motherbrain-protocol.ts - MOTHER-BRAIN data protocol
// Source: Perplexity MOTHER-BRAIN Space

export interface MemoryNode {
  id: string;
  tags: string[];
  content: string;
  embedding?: number[];
  timestamp: number;
  source: 'local'|'drive'|'perplexity';
}

export interface MotherBrainIndex {
  nodes: Map<string,MemoryNode>;
  edges: Map<string,string[]>;
}

export class MotherBrain {
  index: MotherBrainIndex = {nodes:new Map(),edges:new Map()};
  ingest(node:MemoryNode) {
    this.index.nodes.set(node.id,node);
  }
  link(a:string,b:string) {
    const e=this.index.edges.get(a)??[];
    e.push(b);
    this.index.edges.set(a,e);
  }
  search(tag:string):MemoryNode[] {
    return [...this.index.nodes.values()].filter(n=>n.tags.includes(tag));
  }
  serialize():string {
    return JSON.stringify({nodes:[...this.index.nodes.entries()],edges:[...this.index.edges.entries()]},null,2);
  }
}
