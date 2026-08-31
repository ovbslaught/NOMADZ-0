import React, { useEffect, useState, useCallback } from 'react';

interface Particle {
  id: number;
  x: number;
  y: number;
  vx: number;
  vy: number;
  life: number;
  color: string;
  size: number;
}

interface NeonParticlesProps {
  trigger: any;
  color?: string;
}

const NeonParticles: React.FC<NeonParticlesProps> = ({ trigger, color = 'var(--accent-primary)' }) => {
  const [particles, setParticles] = useState<Particle[]>([]);

  const emitBurst = useCallback(() => {
    const newParticles: Particle[] = [];
    const count = 15;
    for (let i = 0; i < count; i++) {
      const angle = Math.random() * Math.PI * 2;
      const speed = 1 + Math.random() * 3;
      newParticles.push({
        id: Date.now() + i,
        x: 0,
        y: 0,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        life: 1,
        color: color,
        size: 2 + Math.random() * 4,
      });
    }
    setParticles(prev => [...prev, ...newParticles]);
  }, [color]);

  useEffect(() => {
    if (trigger) {
      emitBurst();
    }
  }, [trigger, emitBurst]);

  useEffect(() => {
    const timer = setInterval(() => {
      setParticles(prev => 
        prev
          .map(p => ({
            ...p,
            x: p.x + p.vx,
            y: p.y + p.vy,
            life: p.life - 0.02,
          }))
          .filter(p => p.life > 0)
      );
    }, 16);
    return () => clearInterval(timer);
  }, []);

  return (
    <div className="absolute inset-0 pointer-events-none overflow-visible z-50">
      {particles.map(p => (
        <div
          key={p.id}
          className="absolute rounded-sm"
          style={{
            left: `calc(50% + ${p.x}px)`,
            top: `calc(50% + ${p.y}px)`,
            width: `${p.size}px`,
            height: `${p.size}px`,
            backgroundColor: p.color,
            boxShadow: `0 0 8px ${p.color}`,
            opacity: p.life,
            transform: `scale(${p.life}) rotate(${p.x}deg)`,
          }}
        />
      ))}
    </div>
  );
};

export default NeonParticles;
