import React, { useEffect, useState } from 'react';

interface SystemPulseProps {
  frequency: number;
  intensity: number;
  onPulse?: () => void;
}

const SystemPulse: React.FC<SystemPulseProps> = ({ frequency, intensity, onPulse }) => {
  const [active, setActive] = useState(false);

  useEffect(() => {
    const interval = setInterval(() => {
      setActive(true);
      onPulse?.();
      setTimeout(() => setActive(false), 200);
    }, 1000 / frequency);
    
    return () => clearInterval(interval);
  }, [frequency, onPulse]);

  return (
    <div className={`fixed inset-0 pointer-events-none z-[90] transition-opacity duration-300 ${active ? 'opacity-10' : 'opacity-0'}`}>
       <div className="w-full h-full border-[20px] border-neonOrange shadow-[inset_0_0_100px_rgba(255,140,0,0.5)]"></div>
       <div className="absolute top-1/2 left-0 w-full h-0.5 bg-neonOrange shadow-neon-orange" style={{ transform: `scaleY(${intensity})` }}></div>
    </div>
  );
};

export default SystemPulse;
