import React, { useState, useEffect } from 'react';
import { COSMIC_KEY_CONTEXT } from '../constants';

const StatusBoard: React.FC = () => {
  const ctx = COSMIC_KEY_CONTEXT;
  const [metrics, setMetrics] = useState({
    neuralLoss: 0.0012,
    indexCount: 1024,
    loraIntegrity: 98.4,
    archonSync: 100,
    walPulse: 0.95,
    ragVectors: 25421
  });

  // Simulating minor shifts in metrics for that "live" feel
  useEffect(() => {
    const interval = setInterval(() => {
      setMetrics(prev => ({
        neuralLoss: Math.max(0.0001, prev.neuralLoss + (Math.random() - 0.5) * 0.0001),
        indexCount: prev.indexCount + (Math.random() > 0.9 ? 1 : 0),
        loraIntegrity: Math.min(100, prev.loraIntegrity + (Math.random() - 0.5) * 0.1),
        archonSync: Math.max(99.8, Math.min(100, prev.archonSync + (Math.random() - 0.5) * 0.05)),
        walPulse: Math.max(0.85, Math.min(1.0, prev.walPulse + (Math.random() - 0.5) * 0.02)),
        ragVectors: prev.ragVectors + (Math.random() > 0.7 ? Math.floor(Math.random() * 5) : 0)
      }));
    }, 3000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="bg-taupe/20 border-2 border-earth p-3 h-14 flex items-center gap-6 font-mono text-[9px] leading-tight text-earth shadow-inner overflow-hidden relative paper-grain-subtle">
      <div className="flex items-center gap-3 relative z-10">
        <div className="text-earth/60 font-black uppercase">ARCHON_PULSE</div>
        <div className="flex items-center gap-1">
          <div className="w-8 h-2 bg-earth/20 rounded-full overflow-hidden">
             <div className="h-full bg-neonOrange transition-all duration-300" style={{ width: `${metrics.walPulse * 100}%` }}></div>
          </div>
          <span className="text-neonOrange font-black">{metrics.archonSync.toFixed(1)}%</span>
        </div>
      </div>
      
      <div className="flex items-center gap-3 relative z-10 hidden lg:flex border-l border-earth/20 pl-4">
        <div className="text-earth/60 font-black uppercase">WAL/WBL</div>
        <div className="flex gap-1">
          <div className={`w-2 h-2 ${metrics.walPulse > 0.9 ? 'bg-integrityOk shadow-neon-ok' : 'bg-integrityWarn'} transition-colors animate-pulse`}></div>
          <div className={`w-2 h-2 ${metrics.walPulse > 0.8 ? 'bg-integrityOk shadow-neon-ok' : 'bg-integrityWarn'} transition-colors animate-pulse`}></div>
        </div>
      </div>

      <div className="flex flex-col justify-center gap-0.5 relative z-10 border-l border-earth/20 pl-4">
        <div className="flex gap-2">
          <span className="text-earth/40 uppercase font-black">NEURAL_LOSS:</span>
          <span className="text-neonOrange font-black">{metrics.neuralLoss.toFixed(4)}</span>
        </div>
        <div className="flex gap-2">
          <span className="text-earth/40 uppercase font-black">RAG_VECTORS:</span>
          <span className="text-integrityOk font-black">{metrics.ragVectors.toLocaleString()}</span>
        </div>
      </div>

      <div className="flex items-center gap-3 bg-burgundy/10 px-3 border-x border-burgundy/40 h-full relative z-10 group cursor-help ml-2">
         <span className="text-[7px] font-black uppercase text-burgundy/60">INDEXED:</span>
         <span className="text-burgundy font-black neon-text-glow-burgundy text-[11px]">{metrics.indexCount}</span>
      </div>

      <div className="flex flex-col items-end gap-0.5 ml-auto relative z-10">
         <div className="flex gap-1">
            <div className="w-1.5 h-1.5 bg-integrityOk animate-ping rounded-full"></div>
            <span className="text-integrityOk font-black">24/7_PERSISTENT</span>
         </div>
         <div className="text-[7px] text-earth/40 italic">MEM_HEARTBEAT: ACTIVE</div>
      </div>

      {/* Background Buzz Effect */}
      <div className="absolute inset-0 bg-neonOrange/5 pointer-events-none opacity-20 animate-pulse"></div>
    </div>
  );
};

export default StatusBoard;