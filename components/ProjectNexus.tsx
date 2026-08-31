import React, { useState } from 'react';
import { Gamepad2, Box, Layers, Play, Settings, Cpu, HardDrive, Layout, ChevronRight, FileCode } from 'lucide-react';

const ProjectNexus: React.FC = () => {
  const [engine, setEngine] = useState<'GODOT' | 'BLENDER' | 'SIM'>('GODOT');
  const [isLive, setIsLive] = useState(false);

  const projects = [
    { id: '1', name: 'NOMADZ-0_CORE', status: 'READY', type: 'GODOT', frames: 60 },
    { id: '2', name: 'MECHA_ARM_3D', status: 'RENDER', type: 'BLENDER', frames: 240 },
    { id: '3', name: 'WORMHOLE_PARTICLES', status: 'SYNC', type: 'SIM', frames: 0 },
  ];

  return (
    <div className="h-full flex flex-col bg-burgundy/10 border-2 border-burgundy/40 p-4 paper-grain relative overflow-hidden">
      {/* Background Grid Accent */}
      <div className="absolute inset-0 opacity-5 pointer-events-none" style={{ backgroundImage: 'linear-gradient(rgba(0,0,0,.2) 1px, transparent 1px), linear-gradient(90deg, rgba(0,0,0,.2) 1px, transparent 1px)', backgroundSize: '20px 20px' }}></div>

      <div className="flex items-center justify-between mb-4 border-b border-burgundy/20 pb-2 relative z-10">
        <div className="flex items-center gap-3">
          <Gamepad2 className="text-burgundy" size={24} />
          <div>
            <h2 className="text-sm font-black uppercase tracking-tighter italic">Project_Nexus_Engine</h2>
            <div className="flex gap-2 text-[7px] font-black uppercase text-burgundy/60">
              <span className="flex items-center gap-1"><Cpu size={10} /> ENGINE_ACTIVE: {engine}</span>
              <span className="flex items-center gap-1"><Layout size={10} /> MULTI_CELL: ON</span>
            </div>
          </div>
        </div>
        <div className="flex gap-2">
          <button 
            onClick={() => setIsLive(!isLive)}
            className={`px-3 py-1 text-[9px] font-black uppercase transition-all shadow-md ${isLive ? 'bg-integrityOk text-white animate-pulse' : 'bg-cream text-burgundy border border-burgundy/40 hover:bg-burgundy hover:text-cream'}`}
          >
            {isLive ? 'SYSTEM_LIVE' : 'SYNC_ENGINE'}
          </button>
        </div>
      </div>

      <div className="flex gap-1 mb-4 relative z-10">
        {[
          { id: 'GODOT', icon: <Gamepad2 size={14} />, label: 'GODOT_4.3' },
          { id: 'BLENDER', icon: <Box size={14} />, label: 'BLENDER_3.6' },
          { id: 'SIM', icon: <Layers size={14} />, label: 'NOMADZ_SIM' }
        ].map(tab => (
          <button
            key={tab.id}
            onClick={() => setEngine(tab.id as any)}
            className={`flex-grow flex items-center justify-center gap-2 py-2 border-2 text-[8px] font-black transition-all ${engine === tab.id ? 'bg-burgundy text-cream border-burgundy shadow-lg' : 'bg-cream/50 text-burgundy border-burgundy/20 hover:border-burgundy/60'}`}
          >
            {tab.icon}
            {tab.label}
          </button>
        ))}
      </div>

      <div className="flex-grow flex gap-4 overflow-hidden relative z-10">
        {/* Project List */}
        <div className="w-1/3 flex flex-col gap-2 overflow-y-auto custom-scrollbar pr-2">
          {projects.map(p => (
            <div key={p.id} className="p-2 border-2 border-burgundy/10 bg-cream/60 hover:border-burgundy transition-all cursor-pointer group">
              <div className="flex justify-between items-start mb-1">
                <span className="text-[9px] font-black uppercase truncate">{p.name}</span>
                <span className="text-[6px] font-bold bg-burgundy/10 px-1">{p.type}</span>
              </div>
              <div className="flex justify-between items-center text-[7px] text-earth/40 uppercase">
                <span>Status: {p.status}</span>
                <ChevronRight size={10} className="group-hover:translate-x-1 transition-transform" />
              </div>
            </div>
          ))}
          <button className="w-full border-2 border-dashed border-burgundy/20 py-4 text-[8px] font-black text-burgundy/40 uppercase hover:border-burgundy hover:text-burgundy transition-all">
            + Mount_Volume
          </button>
        </div>

        {/* Viewport / Controls */}
        <div className="flex-grow flex flex-col gap-3 bg-black/5 p-3 border-2 border-burgundy/10">
          <div className="flex-grow bg-black relative flex items-center justify-center overflow-hidden">
             {/* Mock Viewport */}
             <div className="absolute inset-0 opacity-20 pointer-events-none">
                <div className="w-full h-full" style={{ background: 'radial-gradient(circle, #800020 0%, transparent 70%)' }}></div>
             </div>
             {isLive ? (
               <div className="text-center">
                 <div className="text-white text-[10px] font-black uppercase tracking-[0.4em] mb-2 animate-pulse">RENDERING_STREAM</div>
                 <div className="flex gap-1 justify-center">
                    {[1,2,3,4,5].map(i => <div key={i} className="w-1 h-4 bg-burgundy animate-bounce" style={{ animationDelay: `${i * 0.1}s` }}></div>)}
                 </div>
               </div>
             ) : (
               <div className="text-burgundy/40 text-[9px] font-black uppercase">Viewport_Standby</div>
             )}
             
             {/* Corner Accents */}
             <div className="absolute top-2 left-2 flex gap-1">
                <div className="w-2 h-2 border-t border-l border-white/20"></div>
                <span className="text-[6px] text-white/40 font-mono">X: 124.22</span>
             </div>
          </div>

          <div className="grid grid-cols-4 gap-2">
            <button className="flex flex-col items-center justify-center p-2 bg-earth text-cream hover:bg-neonOrange hover:text-black transition-all">
              <Play size={12} />
              <span className="text-[7px] font-black mt-1 uppercase">EXEC</span>
            </button>
            <button className="flex flex-col items-center justify-center p-2 bg-burgundy text-cream hover:bg-white hover:text-burgundy transition-all">
              <FileCode size={12} />
              <span className="text-[7px] font-black mt-1 uppercase">SCRPT</span>
            </button>
            <button className="flex flex-col items-center justify-center p-2 bg-cream text-earth border border-earth/20 hover:border-neonOrange transition-all">
              <Box size={12} />
              <span className="text-[7px] font-black mt-1 uppercase">GEOM</span>
            </button>
            <button className="flex flex-col items-center justify-center p-2 bg-cream text-earth border border-earth/20 hover:border-neonOrange transition-all">
              <Settings size={12} />
              <span className="text-[7px] font-black mt-1 uppercase">CFG</span>
            </button>
          </div>
        </div>
      </div>

      <div className="mt-4 flex items-center justify-between border-t border-burgundy/20 pt-2 relative z-10">
        <div className="flex gap-4">
          <div className="flex items-center gap-2">
            <HardDrive size={12} className="text-burgundy" />
            <span className="text-[8px] font-black text-earth uppercase">/vol/nomadz_data_0</span>
          </div>
          <div className="flex items-center gap-2">
             <div className="w-2 h-2 rounded-full bg-integrityOk"></div>
             <span className="text-[8px] font-black text-earth uppercase">VNC_STABLE</span>
          </div>
        </div>
        <div className="text-[8px] font-mono text-burgundy font-black animate-pulse uppercase">NOMADZ-0_SYS_READY</div>
      </div>
    </div>
  );
};

export default ProjectNexus;
