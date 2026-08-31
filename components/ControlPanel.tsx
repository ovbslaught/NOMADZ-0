
import React, { useState, useEffect } from 'react';
import { Feature, FeatureInfo } from '../types';

interface ControlPanelProps {
  features: FeatureInfo[];
  selectedFeature: Feature;
  onSelectFeature: (feature: Feature) => void;
  onGenerate: () => void;
  isLoading: boolean;
  gamepadConnected?: boolean;
  touchOptimization?: boolean;
}

const ControlPanel: React.FC<ControlPanelProps> = ({
  features,
  selectedFeature,
  onSelectFeature,
  onGenerate,
  isLoading,
  gamepadConnected,
  touchOptimization
}) => {
  const [flipKey, setFlipKey] = useState(0);

  useEffect(() => {
    setFlipKey(prev => prev + 1);
  }, [selectedFeature]);

  return (
    <div className="bg-taupe border-2 border-neonOrange h-full flex flex-col p-3 md:p-5 paper-grain">
      <div className="flex items-center justify-between mb-4 md:mb-6 border-b-2 border-neonOrange pb-2 z-10">
        <h2 className="text-[10px] md:text-[12px] font-black uppercase tracking-[0.2em] md:tracking-[0.3em] text-cream italic neon-text-glow-orange">Command_Handshake</h2>
        <div className="flex gap-1">
          <div className="w-2 h-2 bg-neonOrange shadow-neon-orange"></div>
          <div className="w-2 h-2 bg-burgundy shadow-[0_0_5px_var(--accent-burgundy)]"></div>
        </div>
      </div>
      
      <div className="flex-grow overflow-y-auto space-y-2 md:space-y-3 pr-2 custom-scrollbar z-10">
        {features.map((f) => (
          <button
            key={f.id}
            onClick={() => onSelectFeature(f.id)}
            className={`w-full text-left transition-all relative overflow-hidden group subtle-glitch-hover subtle-glitch-active ${
              touchOptimization ? 'p-6' : 'p-3 md:p-4'
            } border-2 ${
              selectedFeature === f.id
                ? 'bg-cream border-neonOrange border-l-[10px] md:border-l-[12px] translate-x-1 shadow-neon-orange-sm z-10'
                : 'bg-taupe border-earth hover:border-neonOrange hover:translate-x-1 grayscale-50 opacity-80 hover:opacity-100 hover:grayscale-0'
            }`}
          >
            <div className="flex justify-between items-start mb-2">
              <h3 className={`text-[10px] md:text-[11px] font-black uppercase tracking-tighter ${
                selectedFeature === f.id ? 'text-neonOrange neon-text-glow-orange' : 'text-cream/80'
              }`}>
                {f.title}
              </h3>
              {selectedFeature === f.id && gamepadConnected && (
                <span className="button-prompt bg-earth text-cream border-none">A</span>
              )}
            </div>
            <p className={`text-[8px] md:text-[9px] leading-tight uppercase font-bold tracking-tight ${
              selectedFeature === f.id ? 'text-earth' : 'text-cream/40'
            }`}>
              {f.description}
            </p>
            <div className={`absolute bottom-0 left-0 h-1 bg-neonOrange transition-all duration-500 ${selectedFeature === f.id ? 'w-full' : 'w-0 group-hover:w-full'}`}></div>
          </button>
        ))}
      </div>

      <div className="mt-4 md:mt-6 pt-4 md:pt-6 border-t-2 border-neonOrange space-y-3 md:space-y-4 z-10">
        <div key={flipKey} className="book-flip bg-cream border-2 border-neonOrange p-3 md:p-4 text-[8px] md:text-[9px] font-black uppercase shadow-neon-orange-sm">
           <div className="text-taupe mb-1">SELECTED_BUFFER:</div>
           <div className="text-neonOrange text-[10px] md:text-[11px] tracking-widest neon-text-glow-orange truncate">{selectedFeature}</div>
        </div>
        
        <button
          onClick={onGenerate}
          disabled={isLoading}
          className={`w-full bg-earth text-cream font-black subtle-glitch-hover subtle-glitch-active ${touchOptimization ? 'py-7' : 'py-4 md:py-5'} px-4 hover:bg-neonOrange hover:text-white transition-all active:scale-95 disabled:opacity-30 uppercase text-[12px] md:text-[14px] tracking-[0.2em] flex items-center justify-center gap-3 shadow-neon-orange border-2 border-neonOrange`}
        >
          {isLoading ? (
            <>
              <div className="w-4 h-4 border-4 border-cream border-t-transparent animate-spin"></div>
              CALCULATING...
            </>
          ) : (
            <>
               {gamepadConnected && <span className="button-prompt border-cream text-cream">A</span>}
               START_REALM_SCAN
            </>
          )}
        </button>
      </div>
    </div>
  );
};

export default ControlPanel;
