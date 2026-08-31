import React, { useState } from 'react';
import { Book, FileText, Music, Link, Layers, RefreshCw } from 'lucide-react';

const NotebookLMBridge: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'sources' | 'summaries' | 'gems'>('sources');
  const [isSyncing, setIsSyncing] = useState(false);

  const mockSources = [
    { id: '1', title: 'WORMHOLE_PHYSICS_CORE', type: 'PDF', status: 'SYNCED' },
    { id: '2', title: 'MOTHER-BRAIN_ARCHITECTURE', type: 'DOC', status: 'SYNCED' },
    { id: '3', title: 'NOMADZ_LORE_V9', type: 'TXT', status: 'PENDING' },
  ];

  const handleSync = () => {
    setIsSyncing(true);
    setTimeout(() => setIsSyncing(false), 2000);
  };

  return (
    <div className="h-full flex flex-col bg-taupe/10 border-2 border- earth p-4 paper-grain">
      <div className="flex items-center justify-between mb-4 border-b border-earth/20 pb-2">
        <div className="flex items-center gap-2">
          <Book className="text-neonOrange" size={20} />
          <h2 className="text-sm font-black uppercase tracking-widest italic">NotebookLM_Bridge_V2.1</h2>
        </div>
        <button 
          onClick={handleSync}
          disabled={isSyncing}
          className={`flex items-center gap-2 px-3 py-1 bg-neonOrange text-black text-[9px] font-black uppercase transition-all ${isSyncing ? 'opacity-50 animate-pulse' : 'hover:bg-white'}`}
        >
          <RefreshCw size={12} className={isSyncing ? 'animate-spin' : ''} />
          {isSyncing ? 'Syncing_Strata...' : 'Trigger_Resync'}
        </button>
      </div>

      <div className="flex gap-2 mb-4">
        {[
          { id: 'sources', icon: <Layers size={14} />, label: 'SOURCES' },
          { id: 'summaries', icon: <Music size={14} />, label: 'AUDIO_SUM' },
          { id: 'gems', icon: <FileText size={14} />, label: 'SUPER_GEMS' }
        ].map(tab => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id as any)}
            className={`flex-grow flex items-center justify-center gap-2 py-2 border-2 text-[9px] font-black transition-all ${activeTab === tab.id ? 'bg-earth text-cream border-earth shadow-neon-orange-sm' : 'bg-cream/50 text-earth border-earth/10 hover:border-earth/40'}`}
          >
            {tab.icon}
            {tab.label}
          </button>
        ))}
      </div>

      <div className="flex-grow bg-cream/40 border-2 border-earth/5 p-3 overflow-y-auto custom-scrollbar">
        {activeTab === 'sources' && (
          <div className="space-y-2">
            {mockSources.map(s => (
              <div key={s.id} className="flex items-center justify-between bg-cream/60 p-2 border border-earth/10 group hover:border-neonOrange transition-all">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 flex items-center justify-center bg-earth/5 text-[8px] font-black">{s.type}</div>
                  <div>
                    <div className="text-[9px] font-black uppercase truncate max-w-[120px]">{s.title}</div>
                    <div className="text-[7px] text-earth/40 uppercase">State: {s.status}</div>
                  </div>
                </div>
                <Link size={12} className="text-earth/20 group-hover:text-neonOrange cursor-pointer" />
              </div>
            ))}
            <button className="w-full border-2 border-dashed border-earth/20 py-4 text-[9px] font-black text-earth/30 uppercase hover:border-earth/60 hover:text-earth transition-all">
              + Add_Source_Strata
            </button>
          </div>
        )}

        {activeTab === 'summaries' && (
          <div className="flex flex-col items-center justify-center h-full gap-4 text-center">
            <div className="w-16 h-16 rounded-full border-4 border-neonOrange flex items-center justify-center animate-pulse">
               <Music size={24} className="text-neonOrange" />
            </div>
            <p className="text-[10px] font-black uppercase text-earth/60 px-6 italic">"NotebookLM Audio Summaries are processed and ready for playback in MEDIA_CENTER."</p>
            <button className="bg-earth text-cream text-[9px] font-black py-2 px-6 uppercase hover:bg-neonOrange hover:text-black transition-all">
              Launch_Audio_Uplink
            </button>
          </div>
        )}

        {activeTab === 'gems' && (
          <div className="space-y-4">
             <div className="bg-neonOrange/5 border border-neonOrange/20 p-3">
                <div className="text-[8px] font-black text-neonOrange uppercase mb-2">Active_Gem_01: NOMADZ_RESEARCHER</div>
                <div className="text-[9px] text-earth italic mb-3">Targeting: WORMHOLE physics anomalies and MOTHER-BRAIN core sync.</div>
                <div className="h-1 bg- earth/10 w-full overflow-hidden">
                   <div className="h-full bg-neonOrange w-2/3 animate-pulse"></div>
                </div>
             </div>
             <button className="w-full bg-earth text-cream text-[9px] font-black py-3 uppercase hover:bg-neonOrange hover:text-black transition-all flex items-center justify-center gap-2">
               Deploy_New_Gem_Specialist
             </button>
          </div>
        )}
      </div>

      <div className="mt-4 text-[7px] font-mono text-earth/40 uppercase flex justify-between">
         <span>Sync_Integrity: 98.4%</span>
         <span className="text-integrityOk animate-pulse">NotebookLM_Session_Active</span>
      </div>
    </div>
  );
};

export default NotebookLMBridge;
