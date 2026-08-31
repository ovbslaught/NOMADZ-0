import React, { useState } from 'react';
import { UISettings, HardwareProfile, Feature, FeatureInfo } from '../types';
import { HARDWARE_TARGETS, ARCHON_MANUAL } from '../constants';

interface UISettingsPanelProps {
  settings: UISettings;
  onUpdate: (settings: UISettings) => void;
  onThemeChange: (theme: UISettings['theme']) => void;
  onClose: () => void;
  isActive: boolean;
  allFeatures: FeatureInfo[];
}

const UISettingsPanel: React.FC<UISettingsPanelProps> = ({ settings, onUpdate, onThemeChange, onClose, isActive, allFeatures }) => {
  const [activeTab, setActiveTab] = useState<'VISUAL' | 'LAYOUT' | 'FEATURES' | 'PORTABLE' | 'MANUAL' | 'PERSISTENCE'>('VISUAL');
  const [manualSection, setManualSection] = useState(ARCHON_MANUAL.sections[0].id);

  if (!isActive) return null;

  const handleChange = (key: keyof UISettings, value: any) => {
    onUpdate({ ...settings, [key]: value });
  };

  const handleLayoutChange = (key: keyof UISettings['layout'], value: number) => {
    onUpdate({
      ...settings,
      layout: { ...settings.layout, [key]: value }
    });
  };

  const toggleFeature = (fid: Feature) => {
    const next = settings.activeFeatures.includes(fid)
      ? settings.activeFeatures.filter(id => id !== fid)
      : [...settings.activeFeatures, fid];
    handleChange('activeFeatures', next);
  };

  const Slider = ({ label, value, min, max, step = 1, unit = "", onChange }: { label: string, value: number, min: number, max: number, step?: number, unit?: string, onChange: (val: number) => void }) => (
    <div className="mb-4">
      <div className="flex justify-between items-center mb-1">
        <label className="text-[9px] text-earth font-black uppercase italic">{label}</label>
        <span className="text-[9px] text-neonOrange font-mono">{value}{unit}</span>
      </div>
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        onChange={(e) => onChange(parseFloat(e.target.value))}
        className="w-full h-1 bg-taupe/30 border border-taupe/50 rounded-none appearance-none cursor-pointer accent-neonOrange"
      />
    </div>
  );

  const hardwareProfiles: HardwareProfile[] = ['LEGACY', 'BALANCED', 'MOBILE_STARK', 'ULTRA', 'SWITCH', 'WII_U', '3DS', 'SHIELD_PORTABLE'];

  return (
    <div className="fixed inset-0 z-[200] flex items-center justify-center bg-black/60 backdrop-blur-md p-4 animate-in fade-in duration-300">
      <div className="bg-cream border-4 border-earth w-full max-w-2xl p-6 shadow-[15px_15px_0px_var(--accent-burgundy)] flex flex-col gap-6 relative max-h-[95vh] overflow-hidden paper-grain">
        <div className="absolute top-0 right-0 p-2 text-[6px] font-black text-earth/20 uppercase tracking-widest z-20">
          ARCHON_UI_KERNEL_CONFIG_V9.5
        </div>

        <div className="flex justify-between items-center border-b-2 border-earth pb-2 z-10 shrink-0">
          <h3 className="text-[12px] font-black text-earth uppercase tracking-widest italic">ARCHON_SYS_CALIBRATION</h3>
          <button 
            onClick={onClose}
            className="text-burgundy hover:text-neonOrange transition-colors text-[10px] font-black underline"
          >
            [COMMIT_CHANGES]
          </button>
        </div>

        {/* Tabs */}
        <div className="flex gap-2 border-b border-earth/20 shrink-0 z-10 overflow-x-auto no-scrollbar">
          {['VISUAL', 'LAYOUT', 'FEATURES', 'PORTABLE', 'PERSISTENCE', 'MANUAL'].map(tab => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab as any)}
              className={`px-4 py-2 text-[10px] font-black tracking-widest transition-all whitespace-nowrap ${activeTab === tab ? 'bg-earth text-cream' : 'text-earth/40 hover:text-earth'}`}
            >
              {tab}
            </button>
          ))}
        </div>

        <div className="flex-grow overflow-y-auto custom-scrollbar z-10 pr-2">
          {activeTab === 'VISUAL' && (
            <div className="space-y-6">
              <div className="flex flex-col gap-2">
                <label className="text-[9px] text-earth font-black uppercase italic">Hardware_Target</label>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
                    {hardwareProfiles.map(profile => (
                      <button 
                          key={profile}
                          onClick={() => handleChange('hardwareProfile', profile)}
                          className={`p-2 text-[8px] font-black border-2 transition-all flex flex-col items-center gap-1 ${settings.hardwareProfile === profile ? 'bg-earth text-cream border-earth shadow-inner' : 'bg-cream text-earth border-taupe/40 hover:border-neonOrange'}`}
                      >
                          <span className="text-[9px]">{(HARDWARE_TARGETS as any)[profile].name}</span>
                          <span className="opacity-40 italic">{(HARDWARE_TARGETS as any)[profile].fps}FPS</span>
                      </button>
                    ))}
                </div>
              </div>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                <div className="space-y-4">
                  <Slider label="Glitch_Intensity" value={settings.glitchIntensity} min={0} max={5} step={0.1} onChange={(v) => handleChange('glitchIntensity', v)} />
                  <Slider label="Scanline_Weight" value={settings.scanlineWeight} min={0} max={1} step={0.05} onChange={(v) => handleChange('scanlineWeight', v)} />
                  <Slider label="System_Health" value={settings.glitchIntensity > 3 ? 20 : 100 - (settings.glitchIntensity * 20)} min={0} max={100} unit="%" onChange={(v) => handleChange('glitchIntensity', (100 - v) / 20)} />
                  <Slider label="CRT_Warp" value={settings.crtWarp} min={0} max={50} step={1} onChange={(v) => handleChange('crtWarp', v)} />
                </div>
                <div className="space-y-4">
                   <Slider label="Neon_Intensity" value={settings.neonIntensity} min={0} max={3} step={0.1} onChange={(v) => handleChange('neonIntensity', v)} />
                   <Slider label="Terminal_Brightness" value={settings.terminalBrightness} min={0.2} max={1.5} step={0.05} onChange={(v) => handleChange('terminalBrightness', v)} />
                   <Slider label="Memory_Depth" value={settings.persistence?.ragMemoryLimit || 1024} min={256} max={4096} step={128} unit="MB" onChange={(v) => handleChange('persistence', { ...settings.persistence, ragMemoryLimit: v })} />
                  <div className="flex flex-col gap-2">
                    <label className="text-[9px] text-earth font-black uppercase italic">Active_Theme</label>
                    <div className="grid grid-cols-2 gap-2">
                      {['cream', 'void', 'budowski-dark', 'neon-vulture', 'paper-sepia'].map(theme => (
                        <button 
                          key={theme}
                          onClick={() => onThemeChange(theme as any)}
                          className={`py-2 text-[8px] font-black border-2 transition-all uppercase ${settings.theme === theme ? 'bg-earth text-cream border-earth shadow-inner' : 'bg-cream text-earth border-taupe/40'}`}
                        >
                          {theme.replace('-', ' ')}
                        </button>
                      ))}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {activeTab === 'LAYOUT' && (
            <div className="space-y-6">
              <Slider label="Left_Panel_Width" value={settings.layout.leftColWidth} min={15} max={40} unit="%" onChange={(v) => handleLayoutChange('leftColWidth', v)} />
              <Slider label="Right_Panel_Width" value={settings.layout.rightColWidth} min={15} max={40} unit="%" onChange={(v) => handleLayoutChange('rightColWidth', v)} />
              <Slider label="Header_Height" value={settings.layout.headerHeight} min={60} max={120} unit="px" onChange={(v) => handleLayoutChange('headerHeight', v)} />
              
              <div className="grid grid-cols-2 gap-4">
                 <button 
                    onClick={() => handleChange('floatingWindows', !settings.floatingWindows)}
                    className={`p-4 border-2 font-black text-[10px] uppercase transition-all ${settings.floatingWindows ? 'bg-earth text-cream border-earth' : 'bg-cream text-earth border-taupe/40'}`}
                 >
                    Floating_Windows: {settings.floatingWindows ? 'ON' : 'OFF'}
                 </button>
                 <button 
                    onClick={() => handleChange('dualScreenMode', !settings.dualScreenMode)}
                    className={`p-4 border-2 font-black text-[10px] uppercase transition-all ${settings.dualScreenMode ? 'bg-earth text-cream border-earth' : 'bg-cream text-earth border-taupe/40'}`}
                 >
                    Dual_Screen_Mode: {settings.dualScreenMode ? 'ON' : 'OFF'}
                 </button>
              </div>
            </div>
          )}

          {activeTab === 'FEATURES' && (
            <div className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                  {allFeatures.map(f => (
                    <button
                      key={f.id}
                      onClick={() => toggleFeature(f.id)}
                      className={`flex items-center justify-between p-3 border-2 transition-all ${
                        settings.activeFeatures.includes(f.id) 
                          ? 'bg-integrityOk/10 border-integrityOk text-integrityOk' 
                          : 'bg-taupe/5 border-taupe/20 text-earth/40'
                      }`}
                    >
                      <div className="text-left">
                        <div className="text-[9px] font-black uppercase tracking-widest">{f.title}</div>
                        <div className="text-[7px] opacity-60">ID: {f.id}</div>
                      </div>
                      <div className={`w-3 h-3 border ${settings.activeFeatures.includes(f.id) ? 'bg-integrityOk border-integrityOk' : 'border-taupe/40'}`}></div>
                    </button>
                  ))}
              </div>
            </div>
          )}

          {activeTab === 'PORTABLE' && (
             <div className="space-y-4">
                <h4 className="text-[10px] text-burgundy font-black uppercase tracking-widest border-b border-burgundy/20 pb-2">Portable & Headless Configuration</h4>
                <div className="grid grid-cols-2 gap-4">
                  {[
                    { key: 'handsFreeVoice', label: 'Hands-Free Voice' },
                    { key: 'headlessMode', label: 'Headless Mode' },
                    { key: 'portableLive', label: 'USB Live Instance' },
                    { key: 'telegramSync', label: 'Telegram Bridge' },
                    { key: 'usbAutoDetect', label: 'USB Auto-Detect' },
                    { key: 'touchOptimization', label: 'Touch UI' },
                  ].map(item => (
                    <button 
                        key={item.key}
                        onClick={() => handleChange(item.key as keyof UISettings, !settings[item.key as keyof UISettings])}
                        className={`p-4 border-2 font-black text-[10px] uppercase transition-all ${settings[item.key as keyof UISettings] ? 'bg-earth text-cream border-earth' : 'bg-cream text-earth border-taupe/40'}`}
                    >
                      {item.label}: {settings[item.key as keyof UISettings] ? 'ACTIVE' : 'OFF'}
                    </button>
                  ))}
                </div>
             </div>
          )}

          {activeTab === 'PERSISTENCE' && (
            <div className="space-y-6">
              <h4 className="text-[10px] text-burgundy font-black uppercase tracking-widest border-b border-burgundy/20 pb-2">WAL / WBL Persistence & RAG Memory</h4>
              <div className="grid grid-cols-2 gap-4">
                 <button 
                    onClick={() => onUpdate({ ...settings, persistence: { ...settings.persistence, walEnabled: !settings.persistence.walEnabled } })}
                    className={`p-4 border-2 font-black text-[10px] uppercase transition-all ${settings.persistence.walEnabled ? 'bg-integrityOk text-white border-integrityOk' : 'bg-cream text-earth border-taupe/40'}`}
                 >
                    WAL_Integrity: {settings.persistence.walEnabled ? 'ENFORCED' : 'OFF'}
                 </button>
                 <button 
                    onClick={() => onUpdate({ ...settings, persistence: { ...settings.persistence, vectorSync: !settings.persistence.vectorSync } })}
                    className={`p-4 border-2 font-black text-[10px] uppercase transition-all ${settings.persistence.vectorSync ? 'bg-neonOrange text-black border-neonOrange' : 'bg-cream text-earth border-taupe/40'}`}
                 >
                    Vector_Sync: {settings.persistence.vectorSync ? 'REAL_TIME' : 'MANUAL'}
                 </button>
              </div>
              <Slider 
                label="RAG_Memory_Buffer" 
                value={settings.persistence.ragMemoryLimit} 
                min={128} 
                max={4096} 
                unit="MB" 
                onChange={(v) => onUpdate({ ...settings, persistence: { ...settings.persistence, ragMemoryLimit: v } })} 
              />
              <Slider 
                label="Pulse_Frequency" 
                value={settings.persistence.pulseFrequency} 
                min={0.1} 
                max={5.0} 
                step={0.1} 
                unit="Hz" 
                onChange={(v) => onUpdate({ ...settings, persistence: { ...settings.persistence, pulseFrequency: v } })} 
              />
            </div>
          )}

          {activeTab === 'MANUAL' && (
            <div className="flex h-full flex-col md:flex-row gap-6">
               <div className="md:w-1/3 border-b md:border-b-0 md:border-r border-earth/20 flex flex-col gap-1 pr-4 pb-4 md:pb-0">
                  {ARCHON_MANUAL.sections.map(s => (
                    <button 
                       key={s.id}
                       onClick={() => setManualSection(s.id)}
                       className={`text-left p-2 text-[8px] font-black uppercase transition-all ${manualSection === s.id ? 'bg-earth text-cream' : 'hover:bg-earth/5 text-earth/60'}`}
                    >
                       {s.title}
                    </button>
                  ))}
                  <div className="mt-4 border-t border-earth/20 pt-4 space-y-2">
                     <div className="text-[7px] font-black text-earth/40 uppercase">External_Links:</div>
                     {ARCHON_MANUAL.links.map(l => (
                       <a key={l.title} href={l.url} target="_blank" className="block text-[8px] font-black text-neonOrange hover:underline truncate">
                          [{l.title}]
                       </a>
                     ))}
                  </div>
               </div>
               <div className="md:w-2/3 space-y-4">
                  {ARCHON_MANUAL.sections.find(s => s.id === manualSection) && (
                    <div className="animate-in fade-in slide-in-from-right-2 duration-300">
                       <h4 className="text-[10px] font-black text-burgundy uppercase mb-2">/manual/{manualSection}</h4>
                       <div className="text-[9px] text-earth leading-relaxed font-mono whitespace-pre-wrap bg-cream/50 p-4 border border-earth/10">
                          {ARCHON_MANUAL.sections.find(s => s.id === manualSection)?.content}
                       </div>
                    </div>
                  )}
               </div>
            </div>
          )}
        </div>

        <div className="bg-earth p-2 text-[8px] font-mono text-neonOrange uppercase italic border border-neonOrange/30 text-center z-10 shrink-0">
          "TERMINAL_RECONFIGURATION_ACTIVE: ARCHON_v9.5_PROTO"
        </div>
      </div>
    </div>
  );
};

export default UISettingsPanel;