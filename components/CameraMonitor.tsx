import React, { useEffect, useRef, useState } from 'react';
import { CameraSettings } from '../types';
import CameraSettingsPanel from './CameraSettingsPanel';

interface CameraMonitorProps {
  settings: CameraSettings;
  onUpdateSettings: (settings: CameraSettings) => void;
}

const CameraMonitor: React.FC<CameraMonitorProps> = ({ settings, onUpdateSettings }) => {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [status, setStatus] = useState<'CONNECTING' | 'STABLE' | 'OFFLINE'>('CONNECTING');
  const [isConfigOpen, setIsConfigOpen] = useState(false);

  useEffect(() => {
    let stream: MediaStream | null = null;
    const startCamera = async () => {
      try {
        stream = await navigator.mediaDevices.getUserMedia({ 
          video: { width: 320, height: 240, frameRate: 15 } 
        });
        if (videoRef.current) {
          videoRef.current.srcObject = stream;
          setStatus('STABLE');
        }
      } catch (err) {
        setStatus('OFFLINE');
      }
    };
    startCamera();
    return () => stream?.getTracks().forEach(track => track.stop());
  }, []);

  const videoFilter = `
    brightness(${settings.brightness}%) 
    contrast(${settings.contrast}%) 
    saturate(${settings.saturation}%) 
    sepia(30%)
    ${settings.grayscale ? 'grayscale(100%)' : ''}
  `;

  return (
    <div className="relative bg-taupe/40 border-2 border-neonOrange h-40 shrink-0 overflow-hidden shadow-neon-orange-sm group paper-grain">
      <CameraSettingsPanel 
        isActive={isConfigOpen} 
        settings={settings} 
        onUpdate={onUpdateSettings} 
        onClose={() => setIsConfigOpen(false)} 
      />

      <div className="absolute inset-0 pointer-events-none z-10 opacity-10 bg-[linear-gradient(rgba(92,74,58,0)_50%,rgba(0,0,0,0.25)_50%)] bg-[length:100%_2px]"></div>
      
      <div className="absolute top-0 left-0 right-0 bg-earth/90 border-b border-neonOrange px-2 py-0.5 flex justify-between items-center z-30">
        <span className="text-[8px] font-black text-cream uppercase tracking-tighter italic neon-text-glow-orange">Optic_Feed_{status}</span>
        <button 
          onClick={() => setIsConfigOpen(true)}
          className="text-[8px] font-black text-cream border border-neonOrange px-1.5 py-0.5 hover:bg-neonOrange hover:border-white transition-colors"
        >
          CONFIG
        </button>
      </div>

      <div className="absolute inset-0 z-30 pointer-events-none">
        <div className="absolute top-2 left-2 w-3 h-3 border-t-2 border-l-2 border-neonOrange/60"></div>
        <div className="absolute bottom-2 right-2 w-3 h-3 border-b-2 border-r-2 border-neonOrange/60"></div>
        <div className="absolute top-0 left-0 w-full h-px bg-neonOrange shadow-neon-orange animate-[scan_6s_linear_infinite]"></div>
      </div>

      {status === 'OFFLINE' ? (
        <div className="flex flex-col items-center justify-center h-full text-earth/40 uppercase font-black text-[9px] gap-2 z-20 relative">
          <div className="text-xl">⚠</div>
          Signal_Lost
        </div>
      ) : (
        <video 
          ref={videoRef} 
          autoPlay 
          muted 
          playsInline 
          style={{ filter: videoFilter }}
          className="w-full h-full object-cover grayscale opacity-60 z-10 relative"
        />
      )}

      <div className="absolute bottom-1 left-2 z-30 text-[7px] font-black text-neonOrange uppercase flex gap-4 neon-text-glow-orange">
        <span>FPS: 15.2</span>
        <span>LAT: 4MS</span>
      </div>

      <style dangerouslySetInnerHTML={{ __html: `
        @keyframes scan {
          0% { top: 0; }
          100% { top: 100%; }
        }
      `}} />
    </div>
  );
};

export default CameraMonitor;