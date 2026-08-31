
import React from 'react';
import { CameraSettings } from '../types';

interface CameraSettingsPanelProps {
  settings: CameraSettings;
  onUpdate: (settings: CameraSettings) => void;
  onClose: () => void;
  isActive: boolean;
}

const CameraSettingsPanel: React.FC<CameraSettingsPanelProps> = ({ settings, onUpdate, onClose, isActive }) => {
  if (!isActive) return null;

  const handleChange = (key: keyof CameraSettings, value: number | boolean) => {
    onUpdate({ ...settings, [key]: value });
  };

  const Slider = ({ label, value, min, max, onChange }: { label: string, value: number, min: number, max: number, onChange: (val: number) => void }) => (
    <div className="mb-4">
      <div className="flex justify-between items-center mb-1">
        <label className="text-[9px] text-earth font-black uppercase italic">{label}</label>
        <span className="text-[9px] text-neonOrange font-mono">{value}%</span>
      </div>
      <input
        type="range"
        min={min}
        max={max}
        value={value}
        onChange={(e) => onChange(parseInt(e.target.value))}
        className="w-full h-1 bg-bone border border-tan rounded-none appearance-none cursor-pointer accent-neonOrange"
      />
    </div>
  );

  return (
    <div className="absolute inset-0 z-50 bg-cream/95 backdrop-blur-sm border-2 border-earth p-4 flex flex-col animate-in fade-in slide-in-from-bottom-2 duration-150">
      <div className="flex justify-between items-center mb-6 border-b-2 border-tan pb-2">
        <h3 className="text-[10px] font-black text-earth uppercase tracking-widest">Optic_Handshake_v3</h3>
        <button 
          onClick={onClose}
          className="text-dust hover:text-neonOrange transition-colors text-xs font-black"
        >
          [CLOSE]
        </button>
      </div>

      <div className="flex-grow space-y-4 overflow-y-auto custom-scrollbar pr-2">
        <Slider label="Brightness" value={settings.brightness} min={0} max={200} onChange={(v) => handleChange('brightness', v)} />
        <Slider label="Contrast" value={settings.contrast} min={0} max={200} onChange={(v) => handleChange('contrast', v)} />
        <Slider label="Saturation" value={settings.saturation} min={0} max={200} onChange={(v) => handleChange('saturation', v)} />
        
        <div className="flex items-center justify-between mt-6 p-3 bg-bone border border-tan">
          <label className="text-[9px] text-earth font-black uppercase">Grayscale_Module</label>
          <button
            onClick={() => handleChange('grayscale', !settings.grayscale)}
            className={`w-12 h-6 border-2 transition-all relative ${settings.grayscale ? 'bg-neonOrange border-neonOrange' : 'bg-cream border-tan'}`}
          >
            <div className={`absolute top-0.5 w-4 h-4 bg-earth transition-all ${settings.grayscale ? 'right-1' : 'left-1'}`}></div>
          </button>
        </div>
      </div>

      <div className="mt-6 pt-3 border-t border-tan flex justify-between">
        <button 
          onClick={() => onUpdate({ brightness: 100, contrast: 100, saturation: 100, grayscale: true })}
          className="text-[8px] text-dust hover:text-earth uppercase font-black"
        >
          RESET_CALIBRATION
        </button>
        <span className="text-[8px] text-neonGreen font-black">STABLE</span>
      </div>
    </div>
  );
};

export default CameraSettingsPanel;
