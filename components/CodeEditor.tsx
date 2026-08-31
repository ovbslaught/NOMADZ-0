
import React from 'react';

interface CodeEditorProps {
  code: string;
  fileName?: string;
}

const CodeEditor: React.FC<CodeEditorProps> = ({ code, fileName }) => {
  // Modular syntax highlighting rules
  const highlightLine = (line: string) => {
    if (!line.trim()) return '&nbsp;';

    return line
      // Decorators
      .replace(/@export|@ready|@onready/g, '<span class="syntax-decorator">$&</span>')
      // Comments
      .replace(/#.*/g, '<span class="syntax-comment">$&</span>')
      // Strings
      .replace(/".*?"/g, '<span class="syntax-string">$&</span>')
      // Keywords
      .replace(/\b(var|func|class|extends|void|for|if|else|while|return|break|continue|match|enum)\b/g, '<span class="syntax-keyword">$&</span>')
      // Built-in Types
      .replace(/\b(Dictionary|float|int|bool|Array|String|Vector2|Vector3|Node|Color|Rect2)\b/g, '<span class="syntax-type">$&</span>')
      // Domain Identifiers
      .replace(/\b(rng|galaxy_map|RealmData|active_refs|master_seed|ARCHON|VCN|SIGNAL)\b/gi, '<span class="syntax-identifier">$&</span>');
  };

  return (
    <div className="bg-taupe border-2 border-earth h-full flex flex-col relative group overflow-hidden shadow-[12px_12px_0px_rgba(92,74,58,0.2)] paper-grain">
      {/* Brutalist Header */}
      <div className="flex items-center justify-between px-4 py-2 bg-earth border-b-2 border-neonOrange z-10">
        <div className="flex items-center gap-4">
          <div className="w-3 h-3 rounded-full bg-neonOrange shadow-neon-orange animate-pulse"></div>
          <span className="text-[10px] font-black text-cream uppercase italic tracking-[0.3em]">
            {fileName || 'Verification_Buffer_V5'}
          </span>
        </div>
        <div className="flex gap-1">
          {[1, 2, 3].map(i => <div key={i} className="w-3 h-1 bg-neonOrange/30"></div>)}
        </div>
      </div>

      <div className="flex-grow flex overflow-hidden z-10">
        {/* Line Numbers */}
        <div className="bg-taupe/80 border-r-2 border-earth text-[var(--syntax-line-numbers-text)] text-[10px] font-mono p-5 text-right select-none w-14">
          {code.split('\n').map((_, i) => (
            <div key={i} className="leading-tight mb-1">{i + 1}</div>
          ))}
        </div>
        
        {/* Code View */}
        <div className="p-5 flex-grow overflow-auto custom-scrollbar bg-cream/90 brutalist-grid">
          <pre className="text-[12px] whitespace-pre-wrap leading-tight font-mono">
            <code className="text-earth">
              {code.split('\n').map((line, i) => (
                <div 
                  key={i} 
                  className="syntax-line-hover mb-1" 
                  dangerouslySetInnerHTML={{ __html: highlightLine(line) }} 
                />
              ))}
            </code>
          </pre>
        </div>
      </div>

      {/* Extreme Neon Indicators */}
      <div className="absolute top-16 right-8 space-y-3 pointer-events-none group-hover:opacity-100 opacity-60 transition-all duration-500 scale-95 group-hover:scale-100 z-20">
        <div className="bg-earth border-2 border-neonOrange px-3 py-1.5 text-[9px] font-black uppercase flex items-center gap-3 shadow-neon-orange text-neonOrange">
          <div className="w-2 h-2 bg-neonOrange animate-ping"></div>
          Status: Memory_Locked
        </div>
        <div className="bg-earth border-2 border-burgundy px-3 py-1.5 text-[9px] font-black uppercase flex items-center gap-3 text-burgundy neon-text-glow-burgundy">
          <div className="w-2 h-2 bg-burgundy"></div>
          Borrow: Active_Ref
        </div>
        <div className="bg-neonOrange border-2 border-earth px-3 py-1.5 text-[9px] font-black uppercase flex items-center gap-3 text-white shadow-neon-orange">
          <div className="w-2 h-2 bg-white animate-pulse"></div>
          Alert: Deterministic
        </div>
      </div>
    </div>
  );
};

export default CodeEditor;
