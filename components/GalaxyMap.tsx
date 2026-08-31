import React, { useState, useEffect, useCallback } from 'react';
import { StarSystem, Feature } from '../types';
import NeonParticles from './NeonParticles';

interface GalaxyMapProps {
  systems: StarSystem[];
  isLoading: boolean;
  onJumpComplete?: (target: StarSystem) => void;
}

const GalaxyMap: React.FC<GalaxyMapProps> = ({ systems, isLoading, onJumpComplete }) => {
  const [selectedSystem, setSelectedSystem] = useState<StarSystem | null>(null);
  const [route, setRoute] = useState<StarSystem[]>([]);
  const [isJumping, setIsJumping] = useState(false);
  const [jumpProgress, setJumpProgress] = useState(0);
  const [currentJumpIndex, setCurrentJumpIndex] = useState(0);
  const [particleTrigger, setParticleTrigger] = useState(0);
  const [stabilityHistory, setStabilityHistory] = useState<number[]>([]);

  const getStarColor = (spectral: string) => {
    switch (spectral) {
      case 'O': return '#00ffff';
      case 'B': return '#88ffff';
      case 'A': return '#ffffff';
      case 'F': return '#ffff88';
      case 'G': return '#ffff00';
      case 'K': return '#ffaa00';
      case 'M': return '#ff4400';
      default: return '#ffffff';
    }
  };

  const isConnected = (sysA: StarSystem, sysB: StarSystem) => {
    return sysA.connections.includes(sysB.id) || sysB.connections.includes(sysA.id);
  };

  const handleSystemClick = (s: StarSystem) => {
    if (isJumping) return;

    // Selection Logic: Plotting a "Worldline Highway"
    if (route.length === 0) {
      setRoute([s]);
      setSelectedSystem(s);
    } else {
      const last = route[route.length - 1];
      if (last.id === s.id) {
        // Deselect if clicking the last node (backtrack)
        setRoute(prev => prev.slice(0, -1));
        setSelectedSystem(route.length > 1 ? route[route.length - 2] : null);
      } else if (isConnected(last, s)) {
        // Add to highway if connected
        if (!route.find(rs => rs.id === s.id)) {
          setRoute(prev => [...prev, s]);
          setSelectedSystem(s);
        } else {
          // If already in route, maybe we want to jump back to it or it's a loop
          setSelectedSystem(s);
        }
      } else {
        // Not connected, reset route to this single system
        setRoute([s]);
        setSelectedSystem(s);
      }
    }
    
    // Stability calculation for the node
    const dist = Math.sqrt(Math.pow(s.coords[0] - 50, 2) + Math.pow(s.coords[1] - 50, 2));
    const stability = Math.round(Math.max(10, 100 - dist));
    setStabilityHistory(prev => [...prev.slice(-4), stability]);
  };

  const clearRoute = () => {
    if (isJumping) return;
    setRoute([]);
    setSelectedSystem(null);
  };

  const initiateHighwayJump = async () => {
    if (route.length < 2 || isJumping) return;
    
    setIsJumping(true);
    setParticleTrigger(prev => prev + 1);

    // Sequence through the highway
    for (let i = 0; i < route.length - 1; i++) {
      setCurrentJumpIndex(i);
      setJumpProgress(0);
      
      const duration = 1200; // Jump duration per segment
      const start = Date.now();
      
      await new Promise<void>(resolve => {
        const animate = () => {
          const now = Date.now();
          const p = Math.min(1, (now - start) / duration);
          setJumpProgress(p);
          
          if (p < 1) {
            requestAnimationFrame(animate);
          } else {
            resolve();
          }
        };
        requestAnimationFrame(animate);
      });

      // Update current system ref mid-transit for visual feedback
      setSelectedSystem(route[i+1]);
      setParticleTrigger(prev => prev + 1);
      
      // Artificial delay between jumps
      await new Promise(r => setTimeout(r, 400));
    }

    setIsJumping(false);
    setJumpProgress(0);
    if (onJumpComplete) onJumpComplete(route[route.length - 1]);
  };

  const getStabilityAverage = () => {
    if (stabilityHistory.length === 0) return 100;
    return Math.round(stabilityHistory.reduce((a, b) => a + b, 0) / stabilityHistory.length);
  };

  return (
    <div className={`h-full flex flex-col gap-4 animate-in fade-in zoom-in-95 duration-700 ${isJumping ? 'fusion-glitch' : ''} paper-grain-subtle`}>
      {/* Header telemetry */}
      <div className="flex justify-between items-center bg-burgundy/10 border-2 border-burgundy p-4 shadow-[0_0_15px_var(--accent-burgundy)] relative overflow-hidden shrink-0 z-10">
        <div className="absolute top-0 left-0 w-full h-px bg-burgundy/30 animate-[scan_2s_linear_infinite]"></div>
        <div className="z-10">
          <h2 className="text-burgundy font-black uppercase text-[12px] tracking-widest italic neon-text-glow-burgundy">Wormhole_Nav_v9.2: Highway_Orchestrator</h2>
          <p className="text-earth/60 text-[8px] font-bold uppercase mt-1">
            Mode: {isJumping ? 'ACTIVE_TRANSIT' : 'PLOTTING_WORLDLINE'} | 
            Highway_Nodes: {route.length} | 
            Current: {selectedSystem?.name || '---'}
          </p>
        </div>
        <div className={`z-10 text-[10px] font-black animate-pulse px-3 py-1 border-2 ${isJumping ? 'text-neonOrange border-neonOrange bg-neonOrange/10' : 'text-integrityOk border-integrityOk/40'}`}>
          {isJumping ? `JUMPING_NODE_${currentJumpIndex + 1}/${route.length - 1}` : 'BRIDGE_SYNC_READY'}
        </div>
      </div>

      <div className="flex-grow grid grid-cols-12 gap-4 relative overflow-hidden z-10">
        {/* Galaxy Map Grid */}
        <div className="col-span-8 bg-black border-2 border-earth relative overflow-hidden brutalist-grid opacity-95 group">
          <div className="absolute inset-0 bg-burgundy/5 pointer-events-none"></div>
          
          {/* Static Background Grid Lines */}
          <div className="absolute inset-0 pointer-events-none opacity-10">
            <div className="grid grid-cols-10 grid-rows-10 h-full w-full">
              {[...Array(100)].map((_, i) => <div key={i} className="border border-white/20"></div>)}
            </div>
          </div>

          {/* Highway Connection Lines */}
          <svg className="absolute inset-0 w-full h-full pointer-events-none z-0">
            {/* All available connections (Muted) */}
            {systems.map(s => s.connections.map(connId => {
              const target = systems.find(t => t.id === connId);
              if (!target) return null;
              return (
                <line 
                  key={`base-${s.id}-${connId}`}
                  x1={`${s.coords[0]}%`} y1={`${s.coords[1]}%`} 
                  x2={`${target.coords[0]}%`} y2={`${target.coords[1]}%`} 
                  stroke="rgba(139, 125, 107, 0.1)" strokeWidth="1" strokeDasharray="4 4"
                />
              );
            }))}

            {/* Plotted Highway Route (Active) */}
            {route.length > 1 && route.map((s, i) => {
              if (i === route.length - 1) return null;
              const next = route[i + 1];
              const isCurrentSegment = isJumping && currentJumpIndex === i;
              return (
                <line 
                  key={`route-${i}`}
                  x1={`${s.coords[0]}%`} y1={`${s.coords[1]}%`} 
                  x2={`${next.coords[0]}%`} y2={`${next.coords[1]}%`} 
                  stroke={isCurrentSegment ? "var(--accent-primary)" : "var(--accent-burgundy)"}
                  strokeWidth={isCurrentSegment ? "4" : "2"}
                  className={isCurrentSegment ? "animate-[dash_1s_linear_infinite]" : "opacity-80"}
                  style={{ filter: isCurrentSegment ? "drop-shadow(0 0 10px var(--accent-primary))" : "drop-shadow(0 0 4px var(--accent-burgundy))" }}
                />
              );
            })}
          </svg>

          {/* Jump Visual (Wormhole Tunnel) */}
          {isJumping && route[currentJumpIndex] && route[currentJumpIndex + 1] && (
            <div className="absolute inset-0 z-40 pointer-events-none">
              <div 
                className="absolute w-12 h-12 bg-neonOrange rounded-full blur-xl opacity-40 animate-pulse"
                style={{
                  left: `${route[currentJumpIndex].coords[0] + (route[currentJumpIndex+1].coords[0] - route[currentJumpIndex].coords[0]) * jumpProgress}%`,
                  top: `${route[currentJumpIndex].coords[1] + (route[currentJumpIndex+1].coords[1] - route[currentJumpIndex].coords[1]) * jumpProgress}%`,
                  transform: 'translate(-50%, -50%)'
                }}
              />
            </div>
          )}

          {/* Star System Nodes */}
          {systems.map((s) => {
            const isInRoute = route.some(rs => rs.id === s.id);
            const isLastInRoute = route[route.length - 1]?.id === s.id;
            const isAnchor = s.name.toUpperCase().includes("SIGMA");
            const isActive = selectedSystem?.id === s.id;

            return (
              <button
                key={s.id}
                onClick={() => handleSystemClick(s)}
                className={`absolute -translate-x-1/2 -translate-y-1/2 transition-all duration-300 z-10 
                  ${isInRoute ? 'scale-110' : 'hover:scale-125'}
                `}
                style={{ left: `${s.coords[0]}%`, top: `${s.coords[1]}%` }}
              >
                <div 
                  className={`w-4 h-4 rounded-full flex items-center justify-center border-2 
                    ${isActive ? 'border-neonOrange shadow-[0_0_15px_var(--accent-primary)] ring-4 ring-neonOrange/20' : ''}
                    ${isInRoute ? 'border-burgundy' : 'border-white/20'}
                    ${isAnchor ? 'w-10 h-10 border-neonOrange shadow-[0_0_20px_var(--accent-primary)]' : ''}
                  `}
                  style={{ backgroundColor: getStarColor(s.spectral_class), color: getStarColor(s.spectral_class) }}
                >
                  {isAnchor && <span className="text-black font-black text-[10px]">Ω</span>}
                  {isInRoute && <span className="text-black font-black text-[6px]">{route.findIndex(rs => rs.id === s.id) + 1}</span>}
                  {isActive && <NeonParticles trigger={particleTrigger} />}
                </div>
                
                <div className={`absolute top-full left-1/2 -translate-x-1/2 mt-1 pointer-events-none 
                  ${isActive || isInRoute ? 'block' : 'hidden group-hover:block'}
                `}>
                  <span className={`text-[6px] font-black text-white bg-black/80 px-1 uppercase whitespace-nowrap border 
                    ${isActive ? 'border-neonOrange text-neonOrange neon-text-glow-orange' : 'border-burgundy text-burgundy/80'}
                  `}>
                    {s.name}
                  </span>
                </div>
              </button>
            );
          })}
        </div>

        {/* Side Panel: Worldline Information */}
        <div className="col-span-4 flex flex-col gap-4 overflow-hidden z-10">
          <div className="flex-grow bg-taupe/20 border-2 border-earth p-4 flex flex-col gap-4 overflow-hidden relative shadow-[4px_4px_0px_var(--accent-burgundy)] paper-grain">
            <div className="border-b border-earth pb-2 flex justify-between items-center z-10">
              <h3 className="font-black text-[12px] uppercase italic text-earth">Highway_Manifest</h3>
              <button onClick={clearRoute} className="text-[8px] font-black text-burgundy hover:underline">RESET_ROUTE</button>
            </div>

            {/* Route List */}
            <div className="flex-grow overflow-y-auto custom-scrollbar space-y-2 pr-1 z-10">
              {route.length === 0 ? (
                <div className="h-full flex flex-col items-center justify-center text-center opacity-40">
                  <span className="text-2xl mb-2">🛣️</span>
                  <p className="text-[8px] font-black uppercase tracking-widest leading-loose">
                    Plot_Transit_Sequence<br/>Select_Linked_Nodes
                  </p>
                </div>
              ) : (
                route.map((node, i) => (
                  <div key={`${node.id}-${i}`} className={`p-2 border-l-4 ${selectedSystem?.id === node.id ? 'bg-burgundy/10 border-neonOrange' : 'bg-earth/5 border-burgundy/30'} flex items-center justify-between group transition-all`}>
                    <div className="flex items-center gap-3">
                      <span className="text-[10px] font-black text-burgundy/40">#{i + 1}</span>
                      <div>
                        <div className="text-[9px] font-black text-earth uppercase">{node.name}</div>
                        <div className="text-[6px] text-earth/60 font-mono italic">SYNS_ID: {node.id.split('-')[1]}</div>
                      </div>
                    </div>
                    {i < route.length - 1 && <span className="text-burgundy animate-pulse">→</span>}
                  </div>
                ))
              )}
            </div>

            {/* Telemetry Footer in Side Panel */}
            <div className="mt-4 pt-4 border-t border-earth/20 space-y-3 z-10">
              <div className="flex justify-between text-[9px]">
                <span className="text-earth/60 font-black uppercase italic tracking-tighter">Stability_Avg:</span>
                <span className={`font-black ${getStabilityAverage() < 40 ? 'text-integrityWarn' : 'text-integrityOk'}`}>{getStabilityAverage()}%</span>
              </div>
              <div className="flex justify-between text-[9px]">
                <span className="text-earth/60 font-black uppercase italic tracking-tighter">Energy_Drain:</span>
                <span className="text-earth font-black">{(route.length * 4.2).toFixed(1)} GeV</span>
              </div>
              
              <button
                onClick={initiateHighwayJump}
                disabled={isJumping || route.length < 2 || getStabilityAverage() < 15}
                className={`w-full py-3 font-black uppercase text-[11px] tracking-widest border-2 transition-all active:scale-95 shadow-[4px_4px_0px_rgba(0,0,0,0.1)]
                  ${isJumping ? 'bg-neonOrange text-white border-neonOrange cursor-not-allowed' : 
                    route.length < 2 ? 'bg-taupe/40 text-earth/40 border-earth/20 cursor-not-allowed' :
                    'bg-earth text-cream border-burgundy hover:bg-neonOrange hover:border-neonOrange hover:text-white'}
                `}
              >
                {isJumping ? 'TRANSIT_IN_PROGRESS...' : 'INIT_HIGHWAY_BURST'}
              </button>
            </div>
          </div>

          {/* Narrative / Lore Snip */}
          <div className="bg-black border-2 border-neonOrange/30 p-3 h-24 overflow-hidden relative paper-grain-subtle">
             <div className="absolute top-0 right-0 p-1 text-[5px] text-neonOrange/40 font-mono z-20">ENCRYPT_L4</div>
             <div className="text-neonOrange font-mono text-[8px] leading-tight animate-pulse italic z-10 relative">
                {selectedSystem ? (
                  `> ${selectedSystem.name.toUpperCase()}: ${selectedSystem.description}`
                ) : (
                  "> STANDBY: Awaiting Highway Calibration. Narrative Strata Indexing..."
                )}
             </div>
          </div>
        </div>
      </div>

      <style dangerouslySetInnerHTML={{ __html: `
        @keyframes dash {
          to { stroke-dashoffset: -20; }
        }
        .brutalist-grid {
          background-size: 40px 40px;
          background-image: linear-gradient(to right, rgba(255,255,255,0.05) 1px, transparent 1px),
                            linear-gradient(to bottom, rgba(255,255,255,0.05) 1px, transparent 1px);
        }
      `}} />
    </div>
  );
};

export default GalaxyMap;