import React, { useState, useRef, useCallback, useEffect } from 'react';
import { MotherBrainAsset, HardwareProfile } from '../types';

interface AssetNodeProps {
  asset: MotherBrainAsset;
  level: number;
  onSelect: (asset: MotherBrainAsset) => void;
  selectedId?: string;
  index: number;
  scrollOffset: number;
  isPanelActive: boolean;
  profile: HardwareProfile;
}

const AssetNode: React.FC<AssetNodeProps> = ({ asset, level, onSelect, selectedId, index, scrollOffset, isPanelActive, profile }) => {
  const [isOpen, setIsOpen] = useState(level < 1);
  const hasChildren = asset.children && asset.children.length > 0;
  const isSelected = selectedId === asset.id;

  const getIcon = () => {
    if (asset.type === 'folder') return isOpen ? '📂' : '📁';
    if (asset.type === 'headless_daemon') return '⚙️';
    return '📜';
  };

  const handleClick = (e: React.MouseEvent | React.TouchEvent) => {
    e.stopPropagation();
    if (hasChildren) setIsOpen(!isOpen);
    else onSelect(asset);
  };

  const itemsVisible = 12;
  const relativeIndex = index - scrollOffset;
  const opacity = Math.max(0, 1 - Math.abs(relativeIndex) / (itemsVisible / 2));
  
  if (opacity <= 0) return null;

  return (
    <div 
      className={`rolodex-item absolute w-full font-mono text-[9px] select-none transition-all duration-300 z-10`}
      style={{
        transform: `translateY(${relativeIndex * 28}px) scale(${0.95 + opacity * 0.05})`,
        opacity: opacity,
        zIndex: Math.round(opacity * 100)
      }}
    >
      <div 
        className={`flex items-center gap-2 py-2 px-3 cursor-pointer border-l-2 ${isSelected ? 'bg-neonOrange/20 border-neonOrange' : 'border-transparent hover:bg-white/40 hover:border-neonOrange'}`}
        style={{ paddingLeft: `${level * 12 + 12}px` }}
        onClick={handleClick}
        onTouchEnd={handleClick}
      >
        <span className={isSelected ? 'neon-text-glow-orange' : ''}>{getIcon()}</span>
        <span className={`truncate ${isSelected ? 'text-neonOrange font-black italic underline' : ''}`}>{asset.name}</span>
      </div>
      {hasChildren && isOpen && (
        <div className="ml-2">
          {asset.children!.map((child, i) => (
            <AssetNode key={child.id} asset={child} level={level + 1} onSelect={onSelect} selectedId={selectedId} index={index + (i + 1) * 0.5} scrollOffset={scrollOffset} isPanelActive={isPanelActive} profile={profile} />
          ))}
        </div>
      )}
    </div>
  );
};

interface MotherBrainRepoProps {
  onSelectAsset: (asset: MotherBrainAsset) => void;
  selectedAssetId?: string;
  isPanelActive: boolean;
  profile: HardwareProfile;
  assets: MotherBrainAsset[];
}

const MotherBrainRepo: React.FC<MotherBrainRepoProps> = ({ onSelectAsset, selectedAssetId, isPanelActive, profile, assets }) => {
  const [scrollOffset, setScrollOffset] = useState(0);
  const touchStartY = useRef(0);

  const handleWheel = (e: React.WheelEvent) => {
    setScrollOffset(prev => prev + (e.deltaY / 100));
  };

  const handleTouchStart = (e: React.TouchEvent) => {
    touchStartY.current = e.touches[0].clientY;
  };

  const handleTouchMove = (e: React.TouchEvent) => {
    const touchY = e.touches[0].clientY;
    const delta = (touchStartY.current - touchY) / 25;
    setScrollOffset(prev => prev + delta);
    touchStartY.current = touchY;
  };

  return (
    <div 
      className="bg-taupe/5 h-full overflow-hidden relative paper-grain touch-none" 
      onWheel={handleWheel}
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
    >
      <div className="bg-earth px-3 py-2 border-b border-neonOrange flex justify-between items-center z-50">
        <h3 className="text-[9px] font-black text-cream uppercase tracking-widest italic neon-text-glow-orange">Strata_View</h3>
        <div className="text-[7px] text-cream/40 font-mono italic">SCROLL_ROLODEX</div>
      </div>
      <div className="flex-grow overflow-hidden relative p-1 bg-cream/10 z-10 h-[calc(100%-35px)]">
        <div className="absolute inset-0 flex flex-col pt-4">
          {assets.map((asset, i) => (
            <AssetNode key={asset.id} asset={asset} level={0} onSelect={onSelectAsset} selectedId={selectedAssetId} index={i} scrollOffset={scrollOffset} isPanelActive={isPanelActive} profile={profile} />
          ))}
        </div>
      </div>
      
      {/* Scroll Indicator */}
      <div className="absolute right-1 top-10 bottom-1 w-0.5 bg-neonOrange/10 z-20">
        <div 
          className="absolute w-full bg-neonOrange shadow-neon-orange transition-all"
          style={{ 
            height: '20px', 
            top: `${Math.min(90, Math.max(0, (scrollOffset / assets.length) * 100))}%` 
          }}
        ></div>
      </div>
    </div>
  );
};

export default MotherBrainRepo;