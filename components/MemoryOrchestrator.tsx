import React, { useState, useEffect } from 'react';
import { Database, Brain, Activity, Download, Upload, Cpu, Zap, Layers } from 'lucide-react';

interface MemoryFragment {
  id: string;
  type: 'SHORT' | 'LONG' | 'WORKING';
  content: string;
  relevance: number;
  timestamp: string;
}

const MemoryOrchestrator: React.FC = () => {
  const [fragments, setFragments] = useState<MemoryFragment[]>([
    { id: '1', type: 'LONG', content: 'ARCHON_CORE_PROTOCOL_INIT', relevance: 0.98, timestamp: '2026-05-01' },
    { id: '2', type: 'SHORT', content: 'USER_VOICE_COMMAND_DETECTED', relevance: 0.85, timestamp: 'JUST_NOW' },
    { id: '3', type: 'WORKING', content: 'SYNCING_WORMHOLE_STRATA', relevance: 0.72, timestamp: 'ACTIVE' },
  ]);

  const [activeSync, setActiveSync] = useState(false);

  useEffect(() => {
    if (activeSync) {
      const timer = setTimeout(() => setActiveSync(false), 3000);
      return () => clearTimeout(timer);
    }
  }, [activeSync]);

  const triggerSync = () => {
    setActiveSync(true);
    setFragments(prev => [
      { id: Date.now().toString(), type: 'SHORT', content: `WAL_SNAPSHOT_${Math.floor(Math.random()*1000)}`, relevance: 0.9, timestamp: 'SYNCED' },
      ...prev.slice(0, 5)
    ]);
  };

  return (
    <div className="h-full flex flex-col bg-cream p-4 font-mono select-none paper-grain">
      <div className="flex items-center justify-between mb-6 border-b-2 border-earth pb-2">
        <div className="flex items-center gap-2">
           <Database className="text-neonOrange" size={20} />
           <h2 className="text-sm font-black uppercase tracking-tighter">WAL_WBL_Memory_Orchestrator</h2>
        </div>
        <div className="flex items-center gap-4">
           {activeSync && (
             <div className="flex gap-1 items-center animate-pulse">
                <span className="text-[8px] font-black text-integrityOk">MEMORY_FLUSH_ACTIVE</span>
             </div>
           )}
           <button 
             onClick={triggerSync}
             className="bg-earth text-cream text-[9px] font-black px-3 py-1 uppercase hover:bg-neonOrange hover:text-black transition-all shadow-neon-orange-sm"
           >
             Trigger_Pulse
           </button>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-4 mb-6">
        {[
          { label: 'Long_Term (RAG)', icon: <Brain size={14} />, color: 'burgundy', count: 24521, limit: '8GB' },
          { label: 'Short_Term (WAL)', icon: <Activity size={14} />, color: 'neonOrange', count: 152, limit: '512MB' },
          { label: 'System_Buffer', icon: <Cpu size={14} />, color: 'integrityOk', count: 12, limit: '64MB' }
        ].map(node => (
          <div key={node.label} className={`border-2 border-earth/20 p-3 bg-cream/40 group hover:border-${node.color} transition-all`}>
             <div className="flex items-center gap-2 mb-2">
                <span className={`text-${node.color}`}>{node.icon}</span>
                <span className="text-[7px] font-black uppercase text-earth/60">{node.label}</span>
             </div>
             <div className="text-xl font-black italic tracking-tighter text-earth truncate">{node.count.toLocaleString()}</div>
             <div className="text-[6px] font-mono text-earth/30 uppercase mt-1">CAPACITY_LINK: {node.limit}</div>
          </div>
        ))}
      </div>

      <div className="flex-grow flex flex-col overflow-hidden">
         <div className="flex items-center gap-2 mb-2 px-1">
            <Layers size={12} className="text-earth/40" />
            <h3 className="text-[9px] font-black uppercase text-earth/40">Memory_Stack_Projection</h3>
         </div>
         
         <div className="flex-grow bg-earth p-4 overflow-y-auto custom-scrollbar border-2 border-earth/10 flex flex-col gap-2">
            {fragments.map((f, i) => (
              <div key={f.id} className="bg-cream/5 p-2 border border-neonOrange/20 relative group hover:bg-neonOrange/10 transition-all animate-in slide-in-from-bottom-2 duration-300" style={{ animationDelay: `${i * 100}ms` }}>
                 <div className="flex justify-between items-start mb-1">
                    <span className={`text-[7px] font-black uppercase ${f.type === 'LONG' ? 'text-burgundy' : f.type === 'SHORT' ? 'text-neonOrange' : 'text-integrityOk'}`}>[{f.type}]</span>
                    <span className="text-[6px] text-white/20 font-mono tracking-widest">{f.timestamp}</span>
                 </div>
                 <div className="text-[9px] font-mono text-cream/80 truncate mb-1">{f.content}</div>
                 <div className="flex items-center gap-2">
                    <div className="flex-grow h-1 bg-white/10 overflow-hidden">
                       <div className="h-full bg-neonOrange transition-all" style={{ width: `${f.relevance * 100}%` }}></div>
                    </div>
                    <span className="text-[7px] font-mono text-neonOrange/60">{(f.relevance * 100).toFixed(0)}%</span>
                 </div>
                 <div className="absolute top-0 right-0 w-0.5 h-full bg-neonOrange opacity-0 group-hover:opacity-100 transition-opacity"></div>
              </div>
            ))}
         </div>
      </div>

      <div className="mt-6 grid grid-cols-2 gap-4">
         <div className="bg-integrityOk/5 border-2 border-integrityOk/20 p-3">
             <div className="text-[8px] font-black uppercase text-integrityOk mb-2">Google_Workspace_Sync</div>
             <div className="flex items-center justify-between gap-4">
                <div className="flex flex-col gap-1">
                   <div className="flex items-center gap-1">
                      <div className="w-1 h-1 bg-integrityOk"></div>
                      <span className="text-[7px] text-earth font-bold">Sheets: SYNCED</span>
                   </div>
                   <div className="flex items-center gap-1">
                      <div className="w-1 h-1 bg-integrityOk"></div>
                      <span className="text-[7px] text-earth font-bold">Docs: ACTIVE</span>
                   </div>
                </div>
                <button className="bg-integrityOk text-white text-[8px] font-black px-2 py-1 uppercase">FORCE_RE-MESH</button>
             </div>
         </div>
         <div className="bg-neonOrange/5 border-2 border-neonOrange/20 p-3">
             <div className="text-[8px] font-black uppercase text-neonOrange mb-2">WAL_Heartbeat_Status</div>
             <div className="flex items-center justify-between">
                <div className="flex items-center gap-1">
                   <Zap size={10} className="text-neonOrange animate-pulse" />
                   <span className="text-[8px] text-earth font-black uppercase tracking-tighter">PHASE_STABLE</span>
                </div>
                <div className="text-[10px] font-black text-earth/40">24/7</div>
             </div>
             <div className="mt-1 h-0.5 bg-neonOrange/20 w-full overflow-hidden">
                <div className="h-full bg-neonOrange w-2/3 animate-ping"></div>
             </div>
         </div>
      </div>
    </div>
  );
};

export default MemoryOrchestrator;
