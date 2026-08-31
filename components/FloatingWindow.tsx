import React, { useState, useRef, useEffect } from 'react';

interface FloatingWindowProps {
  title: string;
  onClose?: () => void;
  children: React.ReactNode;
  initialPos?: { x: number, y: number };
  width?: string;
}

const FloatingWindow: React.FC<FloatingWindowProps> = ({ title, onClose, children, initialPos = { x: 100, y: 100 }, width = "400px" }) => {
  const [pos, setPos] = useState(initialPos);
  const [isDragging, setIsDragging] = useState(false);
  const dragStartRef = useRef({ x: 0, y: 0 });

  const handleMouseDown = (e: React.MouseEvent) => {
    setIsDragging(true);
    dragStartRef.current = { x: e.clientX - pos.x, y: e.clientY - pos.y };
  };

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      if (isDragging) {
        setPos({
          x: e.clientX - dragStartRef.current.x,
          y: e.clientY - dragStartRef.current.y,
        });
      }
    };
    const handleMouseUp = () => setIsDragging(false);

    if (isDragging) {
      window.addEventListener('mousemove', handleMouseMove);
      window.addEventListener('mouseup', handleMouseUp);
    }
    return () => {
      window.removeEventListener('mousemove', handleMouseMove);
      window.removeEventListener('mouseup', handleMouseUp);
    };
  }, [isDragging]);

  return (
    <div 
      className="floating-window paper-grain flex flex-col border-2 border-neonOrange overflow-hidden shadow-neon-orange"
      style={{ left: pos.x, top: pos.y, width: width, transition: isDragging ? 'none' : 'transform 0.1s' }}
    >
      <div 
        className="bg-earth p-2 cursor-grab active:cursor-grabbing flex justify-between items-center z-10 border-b border-neonOrange/30"
        onMouseDown={handleMouseDown}
      >
        <span className="text-[9px] font-black text-cream uppercase italic tracking-widest neon-text-glow-orange">{title}</span>
        {onClose && (
          <button onClick={onClose} className="text-neonOrange font-black text-[10px] hover:scale-110 transition-transform neon-text-glow-orange">
            [X]
          </button>
        )}
      </div>
      <div className="flex-grow p-4 brutalist-grid">
        {children}
      </div>
    </div>
  );
};

export default FloatingWindow;