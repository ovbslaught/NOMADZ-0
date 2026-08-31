import React, { useState } from 'react';
import { MOCK_INTEGRATIONS } from '../constants';
import { IntegrationConfig, IntegrationProvider } from '../types';

interface IntegrationHubProps {
  extractedKey?: string | null;
}

const IntegrationHub: React.FC<IntegrationHubProps> = ({ extractedKey }) => {
  const [integrations, setIntegrations] = useState<IntegrationConfig[]>(MOCK_INTEGRATIONS);
  const [filter, setFilter] = useState('');
  const [isOAuthActive, setIsOAuthActive] = useState(false);
  const [activeKeyInput, setActiveKeyInput] = useState<string | null>(null);
  const [tempKey, setTempKey] = useState('');
  const [isKeyFound, setIsKeyFound] = useState(!!extractedKey);
  const [scanResult, setScanResult] = useState<string | null>(null);

  const getProviderIcon = (provider: IntegrationProvider) => {
    switch (provider) {
      case 'TELEGRAM': return '✈️';
      case 'GOOGLE':
      case 'DRIVE':
      case 'GOOGLE_WORKSPACE':
      case 'GOOGLE_MEET': return '📁';
      case 'ANTHROPIC':
      case 'CLAUDE_3_SONNET':
      case 'CLAUDECODE':
      case 'CLAUDE': return '🛡️';
      case 'GROK': return '𝕏';
      case 'PERPLEXITY': return '🧠';
      case 'OLLAMA': return '🦙';
      case 'MISTRAL': return '🌪️';
      case 'DEEPSEEK': return '🐋';
      case 'OBSIDIAN': return '💎';
      case 'NOTION': return '📝';
      case 'TERMUX':
      case 'TERMUX_SYNC': return '🐚';
      case 'VSCODIUM': return '⚙️';
      case 'MCP': return '🔌';
      case 'GITHUB': return '🐙';
      case 'CUSTOM':
      case 'OPENCODE': return '📖';
      case 'GEMINI_NODE' as any:
      case 'GOOGLE': return '✨';
      case 'GODOT_4_3': return '🤖';
      case 'PYTHON': return '🐍';
      case 'KALI':
      case 'KALI_LINUX': return '⚖️';
      default: return '🔗';
    }
  };

  const getStatusColor = (status: IntegrationConfig['status']) => {
    switch (status) {
      case 'ACTIVE':
      case 'ONLINE': return 'bg-integrityOk shadow-[0_0_8px_var(--accent-ok)]';
      case 'OFFLINE': return 'bg-integrityWarn opacity-50 shadow-none';
      case 'SYNCING': return 'bg-neonOrange animate-pulse shadow-[0_0_10px_var(--accent-primary)]';
    }
  };

  const handleOAuth = (provider?: string) => {
    setIsOAuthActive(true);
    setScanResult(`UPLINKING TO ${provider || 'OMNI_COMM'} SECTORS...`);
    // Simulate pop-up and key search
    setTimeout(() => {
      const updated = integrations.map(i => 
        (i.provider === 'TELEGRAM' || i.provider === 'GOOGLE_MEET' || (provider && i.provider === provider)) 
        ? { ...i, status: 'ACTIVE' as const } 
        : i
      );
      setIntegrations(updated);
      setIsKeyFound(true);
      setScanResult(`RECOVERED: [${provider || 'COMM_LINKS'}], [E2EE_VAULT], [AUTO_SYNC]`);
    }, 2500);
  };

  const handleSaveKey = (id: string) => {
    setIntegrations(prev => prev.map(i => i.id === id ? { ...i, apiKey: tempKey, status: 'ACTIVE' } : i));
    setActiveKeyInput(null);
    setTempKey('');
  };

  const filteredIntegrations = integrations.filter(i => 
    i.name.toLowerCase().includes(filter.toLowerCase()) || 
    i.provider.toLowerCase().includes(filter.toLowerCase())
  );

  return (
    <div className="bg-taupe/10 border-2 border-earth h-full flex flex-col p-4 shadow-[8px_8px_0px_rgba(128,0,32,0.1)] relative overflow-hidden group paper-grain">
      <div className="absolute top-0 right-0 p-2 text-[6px] font-black text-earth/20 uppercase tracking-[0.5em] -rotate-90 origin-top-right select-none z-20">
        Omni_Comm_Kernel_V5.8
      </div>

      <div className="flex items-center justify-between mb-4 border-b-2 border-burgundy/30 pb-2 z-10">
        <div>
          <h2 className="text-[12px] font-black uppercase tracking-[0.2em] text-earth italic">Omni_Comm_Link</h2>
          <p className="text-[7px] text-earth/40 uppercase font-bold">Secure_Nodes: {integrations.filter(i => i.status === 'ACTIVE').length}/{integrations.length}</p>
        </div>
        <div className="flex gap-2">
          <button 
            onClick={() => handleOAuth('GOOGLE_WORKSPACE')}
            className="px-3 py-1 text-[8px] font-black uppercase transition-all border-2 z-20 bg-cream text-earth border-taupe/40 hover:border-integrityOk hover:text-integrityOk"
          >
            SYNC_WORKSPACE_FREE
          </button>
          <button 
            onClick={() => handleOAuth()}
            className={`px-3 py-1 text-[8px] font-black uppercase transition-all border-2 z-20 ${isOAuthActive || extractedKey ? 'bg-integrityOk text-white border-integrityOk animate-pulse' : 'bg-earth text-cream border-burgundy hover:bg-neonOrange'}`}
          >
            {isOAuthActive || extractedKey ? (isKeyFound || extractedKey ? 'COMM_SYNC_OK' : 'LINKING_BOTS') : 'INIT_COMM_LINK'}
          </button>
        </div>
      </div>

      {scanResult && (
        <div className="mb-4 p-2 bg-neonOrange/10 border border-neonOrange/40 text-[8px] font-black text-neonOrange uppercase italic animate-in slide-in-from-top-2 duration-500 z-10">
           {scanResult}
        </div>
      )}

      <div className="mb-4 z-10">
        <input 
          type="text" 
          placeholder="SEARCH_COMM_BRIDGES..." 
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
          className="w-full bg-cream/50 border-2 border-earth/20 p-2 text-[9px] font-black uppercase text-earth focus:border-neonOrange focus:outline-none placeholder:text-earth/30 transition-all"
        />
      </div>

      <div className="flex-grow overflow-y-auto space-y-2 pr-2 custom-scrollbar z-10">
        {filteredIntegrations.map((config) => (
          <div key={config.id} className="bg-cream/40 border-2 border-taupe/30 p-3 relative group/item hover:border-neonOrange transition-all hover:translate-x-1">
            <div className="flex justify-between items-start mb-1">
              <span className={`flex items-center gap-2 text-[6px] font-black text-cream px-1.5 py-0.5 tracking-widest uppercase ${config.provider === 'TELEGRAM' ? 'bg-[#24A1DE]' : 'bg-earth'}`}>
                <span>{getProviderIcon(config.provider)}</span>
                {config.provider}
              </span>
              <div className={`w-1.5 h-1.5 ${getStatusColor(config.status)}`}></div>
            </div>
            
            <h3 className="text-[9px] font-black uppercase text-earth truncate">{config.name}</h3>
            
            {activeKeyInput === config.id ? (
              <div className="mt-2 space-y-2">
                <input 
                  type="password"
                  placeholder="ENTER_API_KEY..."
                  value={tempKey}
                  onChange={(e) => setTempKey(e.target.value)}
                  className="w-full bg-cream border border-earth/20 p-1 text-[8px] font-mono focus:outline-none focus:border-neonOrange"
                />
                <div className="flex gap-2">
                  <button onClick={() => handleSaveKey(config.id)} className="bg-earth text-cream px-2 py-0.5 text-[7px] font-black uppercase">SAVE_KEY</button>
                  <button onClick={() => setActiveKeyInput(null)} className="text-earth/40 text-[7px] font-black uppercase underline">CANCEL</button>
                </div>
              </div>
            ) : (
              <>
                <div className="mt-2 grid grid-cols-2 gap-x-4 gap-y-1 text-[6px] font-mono text-earth/60 uppercase">
                  <div className="flex justify-between">
                    <span>STATE:</span>
                    <span className={config.status === 'ACTIVE' || config.status === 'ONLINE' ? 'text-integrityOk font-black' : 'text-integrityWarn font-black'}>{config.status}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>BYOK:</span>
                    <span className="text-earth font-black">{config.apiKey ? 'LOADED' : 'NONE'}</span>
                  </div>
                </div>

                <div className="mt-2 flex gap-2">
                  {['OPENAI_GPT4', 'CLAUDE_3_SONNET', 'NOTEBOOK_LM'].includes(config.provider) ? (
                    <button 
                      onClick={() => setActiveKeyInput(config.id)}
                      className="text-[7px] font-black uppercase underline decoration-neonOrange/40 hover:text-neonOrange transition-colors"
                    >
                      [CONFIGURE_KEY]
                    </button>
                  ) : (
                    <button 
                      onClick={() => handleOAuth(config.provider)}
                      className="text-[7px] font-black uppercase underline decoration-earth/40 hover:text-earth transition-colors"
                    >
                      [SYNC_BRIDGE]
                    </button>
                  )}
                </div>
              </>
            )}

            <div className="absolute top-0 left-0 w-0.5 h-full bg-burgundy/10 group-hover/item:bg-neonOrange transition-colors"></div>
          </div>
        ))}
      </div>

      <div className="mt-4 pt-4 border-t-2 border-burgundy/20 z-10">
         <div className="flex justify-between text-[7px] font-black text-earth/40 uppercase mb-1">
            <span>E2EE_VAULT_PROTOCOL:</span>
            <span className="text-integrityOk font-black tracking-widest animate-pulse">AES_GCM_READY</span>
         </div>
         <div className="h-1 bg-taupe/20 w-full relative overflow-hidden">
            <div className="absolute inset-0 bg-gradient-to-r from-burgundy via-neonOrange to-integrityOk w-full animate-[loading_4s_linear_infinite]"></div>
         </div>
      </div>
    </div>
  );
};

export default IntegrationHub;