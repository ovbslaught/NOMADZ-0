import React, { useState, useEffect } from 'react';
import { Search, Folder, Loader2, CheckCircle2 } from 'lucide-react';

interface FoundPath {
  name: string;
  path: string;
  type: 'MOTHER-BRAIN' | 'WORMHOLE' | 'OTHER';
}

const DriveScanner: React.FC = () => {
  const [isScanning, setIsScanning] = useState(false);
  const [results, setResults] = useState<FoundPath[]>([]);
  const [scanProgress, setScanProgress] = useState(0);

  const startScan = () => {
    setIsScanning(true);
    setResults([]);
    setScanProgress(0);
  };

  useEffect(() => {
    if (isScanning && scanProgress < 100) {
      const timer = setTimeout(() => {
        setScanProgress(prev => prev + 5);
        
        // Mock finding directories at specific intervals
        if (scanProgress === 10) {
          setResults(prev => [...prev, { name: 'BRAIN-FOOD', path: '/content/drive/MyDrive/WORMHOLE/BRAIN-HOLE/BRAIN-FOOD', type: 'OTHER' }]);
        }
        if (scanProgress === 20) {
          setResults(prev => [...prev, { name: 'MOTHER-BRAIN', path: '/content/drive/MyDrive/WORMHOLE/MOTHER-BRAIN', type: 'MOTHER-BRAIN' }]);
        }
        if (scanProgress === 30) {
          setResults(prev => [...prev, { name: 'NOMADZ-0', path: '/content/drive/MyDrive/WORMHOLE/NOMADZ-0 [PROMOTED]', type: 'OTHER' }]);
        }
        if (scanProgress === 40) {
          setResults(prev => [...prev, { name: 'COSMIC-BRAIN', path: '/content/drive/MyDrive/WORMHOLE/COSMIC-BRAIN', type: 'OTHER' }]);
        }
        if (scanProgress === 50) {
          setResults(prev => [...prev, { name: 'OMEGA-BRAIN', path: '/content/drive/MyDrive/WORMHOLE/OMEGA-BRAIN', type: 'OTHER' }]);
        }
        if (scanProgress === 60) {
          setResults(prev => [...prev, { name: 'VULTURE-BRAIN', path: '/content/drive/MyDrive/WORMHOLE/VULTURE-BRAIN', type: 'OTHER' }]);
        }
        if (scanProgress === 70) {
          setResults(prev => [...prev, { name: 'GEO-BRAIN', path: '/content/drive/MyDrive/WORMHOLE/GEO-BRAIN', type: 'OTHER' }]);
        }
        if (scanProgress === 80) {
          setResults(prev => [...prev, { name: 'FATHER-LIFE [RESTORED]', path: '/content/drive/MyDrive/WORMHOLE/FATHER-LIFE', type: 'OTHER' }]);
        }
        if (scanProgress === 90) {
          setResults(prev => [...prev, { name: 'ROOT/.Vault', path: '/content/drive/MyDrive/WORMHOLE/ROOT/.Vault', type: 'WORMHOLE' }]);
        }
      }, 100);
      return () => clearTimeout(timer);
    } else if (scanProgress >= 100) {
      setIsScanning(false);
    }
  }, [isScanning, scanProgress]);

  return (
    <div className="h-full flex flex-col bg-cream text-earth font-mono p-6 border-2 border-earth/30 paper-grain overflow-hidden relative shadow-[8px_8px_0px_var(--accent-burgundy)]">
      <div className="absolute top-0 right-0 p-2 text-[6px] font-black text-earth/20 uppercase tracking-[0.5em] -rotate-90 origin-top-right select-none z-0">
        STRATA_SCANNER_MODULE
      </div>

      <div className="flex items-center justify-between mb-8 border-b-2 border-burgundy/20 pb-4 z-10">
        <div className="flex items-center gap-3">
          <Search className="text-neonOrange animate-pulse" size={24} />
          <h2 className="text-xl font-black tracking-widest uppercase italic border-l-4 border-neonOrange pl-3">Drive_Strata_Scanner</h2>
        </div>
        <div className="text-[10px] opacity-50 bg-taupe/10 px-2 py-1">SEARCH_PATH: /content/drive/MyDrive/</div>
      </div>

      {!isScanning && results.length === 0 ? (
        <div className="flex-grow flex flex-col items-center justify-center gap-6 z-10">
          <div className="text-center space-y-2">
            <p className="text-sm opacity-70 italic text-earth">"Initiate recursive walk to locate core Nomadz directories..."</p>
            <p className="text-[10px] opacity-40 uppercase tracking-tighter">Target: {['MOTHER-BRAIN', 'WORMHOLE', 'VULTURE', 'OMEGA'].join(', ')}</p>
          </div>
          <button 
            onClick={startScan}
            className="bg-earth text-cream font-black px-10 py-4 hover:bg-neonOrange transition-all uppercase tracking-[0.2em] border-2 border-burgundy shadow-[4px_4px_0px_rgba(0,0,0,0.2)]"
          >
            [START_RECURSIVE_WALK]
          </button>
        </div>
      ) : (
        <div className="flex-grow flex flex-col gap-6 overflow-hidden z-10">
          <div className="space-y-2">
            <div className="flex justify-between text-[10px] uppercase font-black">
              <span className="text-burgundy">Scanning_Strata...</span>
              <span className="text-earth">{scanProgress}%</span>
            </div>
            <div className="h-1 bg-taupe/20 border border-earth/20 overflow-hidden">
              <div 
                className="h-full bg-gradient-to-r from-burgundy to-neonOrange transition-all duration-300" 
                style={{ width: `${scanProgress}%` }}
              />
            </div>
          </div>

          <div className="flex-grow bg-cream/80 border-2 border-earth/20 p-4 overflow-y-auto custom-scrollbar shadow-inner">
            <div className="space-y-4">
              {results.map((res, i) => (
                <div key={i} className="flex items-start gap-4 animate-in fade-in slide-in-from-left-4 duration-500 border-b border-earth/5 pb-3">
                  <div className="mt-1">
                    <CheckCircle2 size={16} className="text-integrityOk" />
                  </div>
                  <div className="space-y-1">
                    <div className="flex items-center gap-2">
                      <Folder size={14} className="text-neonOrange" />
                      <span className="text-sm font-black text-earth uppercase tracking-wider">{res.name}</span>
                    </div>
                    <div className="text-[10px] opacity-60 break-all font-mono italic">
                      PATH: {res.path}
                    </div>
                    <div className="flex gap-2">
                      <span className="text-[8px] bg-burgundy/10 text-burgundy px-2 py-0.5 font-black border border-burgundy/20">
                        {res.type === 'MOTHER-BRAIN' ? 'CORE_ASSET_HUB' : 'PROTOCOL_GATEWAY'}
                      </span>
                      <button className="text-[8px] underline text-earth hover:text-neonOrange transition-colors uppercase font-black decoration-neonOrange/30">
                        [MOUNT_TO_TERMINAL]
                      </button>
                    </div>
                  </div>
                </div>
              ))}
              
              {isScanning && (
                <div className="flex items-center gap-3 opacity-40 italic text-[10px] text-earth">
                  <Loader2 size={12} className="animate-spin" />
                  <span>Walking: {scanProgress % 20 === 0 ? 'root/sys/...' : 'usr/local/bin/...'}</span>
                </div>
              )}

              {!isScanning && results.length > 0 && (
                <div className="pt-4 border-t border-earth/20 mt-4 bg-taupe/5 p-3 italic">
                  <p className="text-[10px] font-black uppercase text-burgundy mb-2">Scan_Complete. {results.length} Nodes Identified.</p>
                  <button 
                    onClick={startScan}
                    className="text-[9px] border-2 border-burgundy/40 px-3 py-1 bg-cream hover:bg-neonOrange hover:text-white transition-all uppercase font-black"
                  >
                    [RE-SCAN]
                  </button>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default DriveScanner;
