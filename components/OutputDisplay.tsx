
import React, { useState, useEffect } from 'react';
import { Feature, SyncLogEntry } from '../types';

interface OutputDisplayProps {
  output: string;
  isLoading: boolean;
  featureTitle: string;
  featureId: Feature;
  loadingStatus?: string;
  syncLogs?: SyncLogEntry[];
}

const OutputDisplay: React.FC<OutputDisplayProps> = ({ 
  output, isLoading, featureTitle, featureId, loadingStatus, syncLogs = []
}) => {
  const isProduction = featureId === Feature.PRODUCTION_STUDIO;

  return (
    <div className="bg-cream h-full flex flex-col relative overflow-hidden brutalist-grid">
      <div className="px-4 py-2 bg-earth border-b-2 border-neonOrange flex justify-between items-center z-20 shrink-0">
        <h2 className="text-[10px] font-black text-cream uppercase tracking-widest">{featureTitle}</h2>
        <span className="text-neonOrange text-[8px] font-black neon-text-glow-orange">ARCHON-OMEGA_v9.5</span>
      </div>
      
      <div className="flex-grow overflow-y-auto z-10 p-6 paper-grain custom-scrollbar">
        {isLoading ? (
          <div className="h-full flex flex-col items-center justify-center">
            <div className="w-48 h-1 bg-taupe relative overflow-hidden mb-4">
              <div className="absolute inset-0 bg-neonOrange animate-[loading_1s_infinite]"></div>
            </div>
            <p className="text-[9px] font-black text-neonOrange animate-pulse uppercase tracking-[0.3em]">{loadingStatus || 'SYNCING_STRATA'}</p>
          </div>
        ) : output ? (
          <div className="space-y-4">
            {isProduction && (
              <div className="p-4 bg-neonOrange/5 border border-neonOrange/20 mb-4 font-black text-[9px] uppercase italic text-neonOrange">
                PIPELINE_STATUS: SYNTHESIS_COMPLETE // TKINTER_BRIDGE_HOOK_OK
              </div>
            )}
            <pre className="text-[11px] text-earth font-mono leading-relaxed whitespace-pre-wrap border-l-2 border-neonOrange/30 pl-4">
              {output}
            </pre>
          </div>
        ) : (
          <div className="h-full flex flex-col items-center justify-center opacity-30 select-none grayscale">
            <span className="text-4xl mb-4">⚙️</span>
            <p className="text-[10px] font-black uppercase tracking-widest">System_Awaiting_Handshake</p>
          </div>
        )}
      </div>

      <div className="h-32 border-t-2 border-neonOrange/20 bg-earth/5 overflow-hidden flex flex-col z-20">
        <div className="px-4 py-1 border-b border-neonOrange/10 text-[7px] font-black text-earth/60 uppercase bg-taupe/10">
          Sync_Activity_WAL
        </div>
        <div className="flex-grow overflow-y-auto p-2 space-y-1 font-mono text-[7px]">
          {syncLogs.map(log => (
            <div key={log.id} className="flex gap-3 text-earth opacity-80 hover:opacity-100 transition-opacity">
              <span className="shrink-0 text-earth/40">[{log.timestamp}]</span>
              <span className="shrink-0 font-black text-integrityOk bg-integrityOk/10 px-1 border border-integrityOk/20">{log.operation}</span>
              <span className="truncate">{log.target}</span>
              <span className="ml-auto opacity-30 italic">#{log.hash}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default OutputDisplay;
