import React, { useState, useEffect, useRef } from 'react';
import { NOMADZ_SOUNDTRACK, PORTABLE_PLUGINS } from '../constants';

const MediaCenter: React.FC = () => {
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTrackIndex, setCurrentTrackIndex] = useState(0);
  const [volume, setVolume] = useState(65);
  const [progress, setProgress] = useState(0);
  const [activePlugins, setActivePlugins] = useState<string[]>(['plugin-drive']);
  const [isGlitching, setIsGlitching] = useState(false);

  const track = NOMADZ_SOUNDTRACK[currentTrackIndex];

  useEffect(() => {
    let interval: any;
    if (isPlaying) {
      interval = setInterval(() => {
        setProgress(prev => (prev >= 100 ? 0 : prev + 0.5));
      }, 1000);
    }
    return () => clearInterval(interval);
  }, [isPlaying]);

  const togglePlay = () => setIsPlaying(!isPlaying);
  const nextTrack = () => {
    setCurrentTrackIndex(prev => (prev + 1) % NOMADZ_SOUNDTRACK.length);
    setProgress(0);
  };
  const prevTrack = () => {
    setCurrentTrackIndex(prev => (prev - 1 + NOMADZ_SOUNDTRACK.length) % NOMADZ_SOUNDTRACK.length);
    setProgress(0);
  };

  const togglePlugin = (id: string) => {
    setIsGlitching(true);
    setTimeout(() => setIsGlitching(false), 200);
    setActivePlugins(prev => 
      prev.includes(id) ? prev.filter(p => p !== id) : [...prev, id]
    );
  };

  // Remote Control via Custom Events (Voice/App)
  useEffect(() => {
    const handleRemoteAction = (e: any) => {
      const { action } = e.detail;
      switch (action) {
        case 'play': setIsPlaying(true); break;
        case 'pause': setIsPlaying(false); break;
        case 'next': nextTrack(); break;
        case 'prev': prevTrack(); break;
      }
    };
    window.addEventListener('archon-media', handleRemoteAction);
    return () => window.removeEventListener('archon-media', handleRemoteAction);
  }, []);

  return (
    <div className={`bg-earth/10 border-2 border-neonOrange shadow-neon-orange-sm p-4 flex flex-col gap-4 relative overflow-hidden paper-grain ${isGlitching ? 'fusion-glitch' : ''}`}>
      <div className="absolute top-0 right-0 p-1 text-[5px] font-black text-neonOrange/20 uppercase tracking-widest z-20">OMNI_MEDIA_V1.2</div>
      
      {/* Header */}
      <div className="flex justify-between items-center border-b border-neonOrange/20 pb-2 z-10">
        <h3 className="text-[10px] font-black text-neonOrange uppercase italic tracking-widest flex items-center gap-2 neon-text-glow-orange">
          <span className="animate-pulse">📻</span> OMNI_MEDIA_MOD
        </h3>
        <div className="flex gap-1">
          {[...Array(5)].map((_, i) => (
            <div 
              key={i} 
              className={`w-1 h-3 bg-neonOrange/40 transition-all ${isPlaying ? 'animate-[bounce_0.6s_infinite]' : ''}`}
              style={{ animationDelay: `${i * 0.1}s` }}
            ></div>
          ))}
        </div>
      </div>

      {/* Audio Section */}
      <div className="flex flex-col gap-2 z-10">
        <div className="flex items-center justify-between">
          <div className="flex flex-col max-w-[70%]">
             <span className="text-[9px] font-black text-earth/60 truncate uppercase">{track.author}</span>
             <span className="text-[11px] font-black text-neonOrange uppercase truncate italic neon-text-glow-orange">{track.title}</span>
          </div>
          <span className="text-[8px] font-mono text-earth/40">{track.duration}</span>
        </div>

        {/* Scrub Bar */}
        <div className="h-1 bg-earth/10 w-full relative overflow-hidden group cursor-pointer">
          <div className="absolute inset-0 bg-neonOrange/40 transition-all" style={{ width: `${progress}%` }}></div>
          <div className="absolute inset-0 flex justify-between opacity-20 pointer-events-none">
             {[...Array(20)].map((_, i) => <div key={i} className="w-px h-full bg-neonOrange"></div>)}
          </div>
        </div>

        {/* Controls */}
        <div className="flex items-center justify-between mt-1">
          <div className="flex gap-3">
             <button onClick={prevTrack} className="text-earth hover:text-neonOrange transition-colors text-[10px] font-black">⏮</button>
             <button onClick={togglePlay} className="text-neonOrange hover:text-white transition-all text-[14px] font-black w-6">
                {isPlaying ? '⏸' : '▶'}
             </button>
             <button onClick={nextTrack} className="text-earth hover:text-neonOrange transition-colors text-[10px] font-black">⏭</button>
          </div>
          <div className="flex items-center gap-2">
             <span className="text-[7px] font-black text-earth/40">VOL</span>
             <input 
               type="range" 
               min="0" max="100" 
               value={volume} 
               onChange={(e) => setVolume(parseInt(e.target.value))}
               className="w-16 h-1 appearance-none bg-earth/10 accent-neonOrange cursor-pointer"
             />
          </div>
        </div>
      </div>

      {/* Portable Apps / Plugins Dock */}
      <div className="border-t border-neonOrange/20 pt-3 z-10">
        <div className="text-[7px] font-black text-earth/40 uppercase mb-2 tracking-[0.2em]">Portable_Plugin_Matrix:</div>
        <div className="grid grid-cols-3 gap-2">
           {PORTABLE_PLUGINS.map(plugin => (
             <button 
                key={plugin.id}
                onClick={() => togglePlugin(plugin.id)}
                className={`p-1.5 border-2 flex flex-col items-center gap-1 transition-all ${
                  activePlugins.includes(plugin.id) 
                    ? 'bg-integrityOk border-integrityOk text-white shadow-[0_0_8px_var(--accent-ok)]' 
                    : 'bg-cream border-taupe/40 text-earth hover:border-neonOrange'
                }`}
             >
                <span className="text-[10px]">{plugin.icon}</span>
                <span className="text-[6px] font-black truncate w-full uppercase">{plugin.name.split('_')[0]}</span>
                <div className={`w-full h-0.5 bg-white/20 relative overflow-hidden ${activePlugins.includes(plugin.id) ? 'block' : 'hidden'}`}>
                   <div className="absolute inset-0 bg-white animate-[loading_2s_infinite]"></div>
                </div>
             </button>
           ))}
        </div>
      </div>

      {/* Background Visualizer Buzz */}
      {isPlaying && (
        <div className="absolute inset-0 pointer-events-none opacity-5 flex items-end">
           {[...Array(30)].map((_, i) => (
             <div 
               key={i} 
               className="flex-grow bg-neonOrange"
               style={{ 
                 height: `${Math.random() * 100}%`,
                 transition: 'height 0.2s ease'
               }}
             ></div>
           ))}
        </div>
      )}
    </div>
  );
};

export default MediaCenter;