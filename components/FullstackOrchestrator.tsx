import React, { useState } from 'react';
import { Feature } from '../types';
import { Terminal, Database, Globe, Cpu, Atom, FileText, Play } from 'lucide-react';

const FullstackOrchestrator: React.FC = () => {
  const [activePillar, setActivePillar] = useState<string>('TOOLS');
  const [logs, setLogs] = useState<string[]>(["[SYSTEM] ARCHON_OMEGA_FULLSTACK_KERNEL_INIT", "[READY] EXPRESS_SERVER_LISTENING_ON_PORT_3000"]);

  const pillars = [
    { id: 'TOOLS', icon: <Terminal size={16} />, label: 'GEOLOGOS_TOOLS' },
    { id: 'LABS', icon: <Cpu size={16} />, label: 'GEOLOGOS_LABS' },
    { id: 'LATEX', icon: <FileText size={16} />, label: 'GEOLOGOS_LATEX' },
    { id: 'ATOMS', icon: <Atom size={16} />, label: 'GEOLOGOS_ATOMS' },
    { id: 'PLAYWRIGHT', icon: <Globe size={16} />, label: 'PLAYWRIGHT_AUTONOMY' },
    { id: 'TERMUX', icon: <Terminal size={16} />, label: 'TERMUX_ANDROID_SYNC' },
  ];

  const handleAction = (action: string) => {
    setLogs(prev => [`[EXEC] ${action}_INITIATED`, ...prev].slice(0, 20));
    setTimeout(() => {
      setLogs(prev => [`[OK] ${action}_COMPLETE`, ...prev]);
    }, 1500);
  };

  return (
    <div className="h-full flex flex-col bg-taupe/5 border-2 border-neonOrange p-4 paper-grain overflow-hidden">
      <div className="flex items-center justify-between mb-2 border-b border-neonOrange/30 pb-2">
        <h2 className="text-lg font-black italic uppercase tracking-tighter">Fullstack_Orchestrator</h2>
        <div className="flex gap-2">
          <span className="text-[8px] font-black bg-integrityOk text-white px-2 py-0.5 animate-pulse">SERVER_ONLINE</span>
          <span className="text-[8px] font-black bg-neonOrange text-black px-2 py-0.5">V-9.5_KERNEL</span>
        </div>
      </div>

      <div className="grid grid-cols-6 gap-2 mb-4">
        {pillars.map(p => (
          <button
            key={p.id}
            onClick={() => setActivePillar(p.id)}
            className={`flex flex-col items-center justify-center p-2 border-2 transition-all ${
              activePillar === p.id 
                ? 'bg-neonOrange text-black border-neonOrange shadow-neon-orange-sm' 
                : 'bg-cream/50 text-earth border-earth/20 hover:border-neonOrange/50'
            }`}
          >
            {p.icon}
            <span className="text-[7px] font-black mt-1 uppercase">{p.id}</span>
          </button>
        ))}
      </div>

      <div className="flex-grow grid grid-cols-2 gap-4 overflow-hidden">
        <div className="flex flex-col gap-4">
          <div className="bg-cream/80 border-2 border-earth/20 p-4 flex-grow">
            <h3 className="text-[10px] font-black uppercase mb-4 flex items-center gap-2">
              <Database size={12} /> {activePillar}_CONTROLS
            </h3>
            <div className="flex flex-col gap-2">
              {activePillar === 'TERMUX' ? (
                <>
                  <button 
                    onClick={() => handleAction('INITIALIZE_TERMUX_PAIRING')}
                    className="w-full bg- earth text-cream text-[9px] font-black py-2 uppercase hover:bg-neonOrange hover:text-black transition-all"
                  >
                    Pair_Android_Device
                  </button>
                  <button 
                    onClick={() => handleAction('SYNC_WORMHOLE_TO_TERMUX')}
                    className="w-full border-2 border-earth text-earth text-[9px] font-black py-2 uppercase hover:border-neonOrange hover:text-neonOrange transition-all"
                  >
                    Sync_Wormhole_to_Termux
                  </button>
                  <button 
                    onClick={() => handleAction('RUN_GEMINI_CLI_TERMUX')}
                    className="w-full bg-burgundy text-white text-[9px] font-black py-2 uppercase hover:bg-neonOrange hover:text-black transition-all"
                  >
                    Run_Gemini-CLI_Remote
                  </button>
                </>
              ) : (
                <>
                  <button 
                    onClick={() => handleAction(`CLONE_${activePillar}_REPO`)}
                    className="w-full bg-earth text-cream text-[9px] font-black py-2 uppercase hover:bg-neonOrange hover:text-black transition-all"
                  >
                    Injest_{activePillar}_Repository
                  </button>
                  <button 
                    onClick={() => handleAction(`SYNC_${activePillar}_PILLAR`)}
                    className="w-full border-2 border-earth text-earth text-[9px] font-black py-2 uppercase hover:border-neonOrange hover:text-neonOrange transition-all"
                  >
                    Sync_Geologos_Pillar
                  </button>
                </>
              )}
              {activePillar === 'PLAYWRIGHT' && (
                <button 
                  onClick={() => handleAction('START_AUTONOMOUS_BROWSER')}
                  className="w-full bg-burgundy text-white text-[9px] font-black py-2 uppercase hover:bg-neonOrange hover:text-black transition-all"
                >
                  Init_Playwright_Autonomy
                </button>
              )}
            </div>
          </div>
        </div>

        <div className="bg-black p-4 font-mono text-[9px] text-integrityOk overflow-y-auto custom-scrollbar border-2 border-earth/40">
          <div className="flex items-center gap-2 mb-2 border-b border-integrityOk/20 pb-1">
            <Play size={10} /> <span>KERNEL_LOG_STREAM</span>
          </div>
          {logs.map((log, i) => (
            <div key={i} className="mb-1">
              <span className="opacity-50">[{new Date().toLocaleTimeString()}]</span> {log}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default FullstackOrchestrator;
