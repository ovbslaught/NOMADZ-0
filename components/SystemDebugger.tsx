import React, { useState } from 'react';
import { LogEntry } from '../types';

interface SystemDebuggerProps {
  logs: LogEntry[];
  isActive: boolean;
  onClear: () => void;
}

const SystemDebugger: React.FC<SystemDebuggerProps> = ({ logs, isActive, onClear }) => {
  const [filter, setFilter] = useState<'ALL' | 'INFO' | 'WARN' | 'ERROR'>('ALL');
  const [expandedLogId, setExpandedLogId] = useState<string | null>(null);

  if (!isActive) return null;

  const filteredLogs = logs.filter(log => {
    if (filter === 'ALL') return true;
    if (filter === 'ERROR') return log.level === 'ERROR' || log.level === 'FATAL';
    return log.level === filter;
  });

  const getLevelColor = (level: LogEntry['level']) => {
    switch(level) {
      case 'ERROR':
      case 'FATAL':
        return 'text-integrityWarn';
      case 'WARN':
        return 'text-neonOrange';
      case 'INFO':
      default:
        return 'text-integrityOk';
    }
  };

  const filters: ('ALL' | 'INFO' | 'WARN' | 'ERROR')[] = ['ALL', 'INFO', 'WARN', 'ERROR'];

  return (
    <div className="flex flex-col h-full bg-black/90 border-2 border-neonOrange p-4 paper-grain overflow-hidden">
      <div className="flex justify-between items-center border-b border-neonOrange/20 pb-2 mb-2">
        <h3 className="text-neonOrange font-black text-[10px] uppercase tracking-widest italic">ARCHON_SYS_DEBUG_KERNEL</h3>
        <button 
          onClick={onClear}
          className="text-[8px] font-black text-neonOrange/40 hover:text-neonOrange uppercase underline"
        >
          [PURGE_LOGS]
        </button>
      </div>
      
      <div className="flex gap-1 mb-2">
        {filters.map(f => (
          <button 
            key={f}
            onClick={() => setFilter(f)}
            className={`px-3 py-1 text-[7px] font-black uppercase border transition-all ${filter === f ? 'bg-neonOrange text-white border-neonOrange' : 'bg-black/20 text-neonOrange/50 border-neonOrange/20'}`}
          >
            {f} ({f === 'ALL' ? logs.length : logs.filter(l => l.level === f || (f === 'ERROR' && (l.level === 'FATAL' || l.level === 'ERROR'))).length})
          </button>
        ))}
      </div>

      <div className="flex-grow overflow-y-auto custom-scrollbar font-mono text-[9px] space-y-1">
        {filteredLogs.length === 0 ? (
          <div className="text-neonOrange/20 italic p-4 text-center">NO_LOGS_MATCH_FILTER</div>
        ) : (
          filteredLogs.map((log) => (
            <div key={log.id}>
              <div 
                className={`flex gap-3 p-1 border-b border-white/5 cursor-pointer hover:bg-white/5 ${getLevelColor(log.level)}`}
                onClick={() => setExpandedLogId(log.id === expandedLogId ? null : log.id)}
              >
                <span className="opacity-40 shrink-0">[{log.timestamp}]</span>
                <span className="font-black shrink-0 w-12">[{log.level}]</span>
                <span className="opacity-60 shrink-0 w-24 truncate">[{log.module}]</span>
                <span className="flex-grow truncate" title={log.message}>{log.message}</span>
                {log.data && <span className="text-neonOrange/50">[+]</span>}
              </div>
              {expandedLogId === log.id && log.data && (
                <div className="bg-black/50 p-2 border-l-2 border-neonOrange">
                  <pre className="text-white/70 text-[8px] whitespace-pre-wrap">
                    {JSON.stringify(log.data, null, 2)}
                  </pre>
                </div>
              )}
            </div>
          ))
        )}
      </div>

      <div className="mt-4 pt-2 border-t border-neonOrange/10 grid grid-cols-2 gap-4 text-[8px] font-black uppercase text-neonOrange/40">
        <div>Heap_Usage: {(Math.random() * 50 + 20).toFixed(2)}MB</div>
        <div>Thread_Wait: {(Math.random() * 10).toFixed(1)}ms</div>
      </div>
    </div>
  );
};

export default SystemDebugger;