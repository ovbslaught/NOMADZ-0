
import React, { useEffect, useRef, useState } from 'react';
import { GoogleGenAI, LiveServerMessage, Modality, Blob, Type, FunctionDeclaration } from '@google/genai';

interface LiveVoiceChatProps {
  isActive: boolean;
  handsFree: boolean;
  onAction?: (action: string, params?: any) => void;
  onStatusChange?: (status: 'IDLE' | 'LISTENING' | 'TALKING' | 'ERROR') => void;
}

const APP_ACTIONS: FunctionDeclaration[] = [
  {
    name: 'switch_feature',
    parameters: {
      type: Type.OBJECT,
      description: 'Navigates the terminal to a specific feature module.',
      properties: {
        feature: { 
          type: Type.STRING, 
          description: 'The ID of the feature. Options: REHYDRATION_LAB, KALI_SANDBOX, CLI_WORKSPACE, GALAXY_MAP_GEN, VECTOR_DB_ORCHESTRATOR, MCP_INTERFACE, DATASET_ARCHEOLOGY, GALAXY_GUIDE.' 
        }
      },
      required: ['feature']
    }
  },
  {
    name: 'trigger_scan',
    parameters: {
      type: Type.OBJECT,
      description: 'Initiates a realm scan or rehydration process for the current active feature.',
      properties: {}
    }
  },
  {
    name: 'media_control',
    parameters: {
      type: Type.OBJECT,
      description: 'Controls the onboard OMNI_MEDIA_MOD audio player.',
      properties: {
        action: { 
          type: Type.STRING, 
          description: 'The playback action.',
          enum: ['play', 'pause', 'next', 'prev']
        }
      },
      required: ['action']
    }
  },
  {
    name: 'switch_theme',
    parameters: {
      type: Type.OBJECT,
      description: 'Changes the visual interface theme.',
      properties: {
        theme: { 
          type: Type.STRING, 
          description: 'The target theme name.',
          enum: ['cream', 'void', 'budowski-dark', 'neon-vulture', 'paper-sepia']
        }
      },
      required: ['theme']
    }
  },
  {
    name: 'toggle_settings',
    parameters: {
      type: Type.OBJECT,
      description: 'Opens or closes the system configuration panel.',
      properties: {}
    }
  },
  {
    name: 'sync_node',
    parameters: {
      type: Type.OBJECT,
      description: 'Synchronizes a specific data node (e.g., TERMUX, WORMHOLE, OBSIDIAN).',
      properties: {
        node: { type: Type.STRING, description: 'The node to sync.' }
      },
      required: ['node']
    }
  },
  {
    name: 'deploy_gem',
    parameters: {
      type: Type.OBJECT,
      description: 'Deploys a specialized Gem agent for background tasks.',
      properties: {
        gem_type: { type: Type.STRING, description: 'The type of Gem to deploy.' }
      },
      required: ['gem_type']
    }
  }
];

const LiveVoiceChat: React.FC<LiveVoiceChatProps> = ({ isActive, handsFree, onAction, onStatusChange }) => {
  const [isConnecting, setIsConnecting] = useState(false);
  const [isTalking, setIsTalking] = useState(false);
  const [transcription, setTranscription] = useState('');
  const [lastCommand, setLastCommand] = useState<string | null>(null);
  const [errorState, setErrorState] = useState<string | null>(null);
  const audioContextRef = useRef<AudioContext | null>(null);
  const sessionRef = useRef<any>(null);

  const lastStatusRef = useRef<string | null>(null);

  useEffect(() => {
    if (!onStatusChange) return;
    
    let nextStatus: 'IDLE' | 'LISTENING' | 'TALKING' | 'ERROR' = 'IDLE';
    if (errorState) nextStatus = 'ERROR';
    else if (isTalking) nextStatus = 'TALKING';
    else if (isActive && !isConnecting) nextStatus = 'LISTENING';
    
    if (nextStatus !== lastStatusRef.current) {
      lastStatusRef.current = nextStatus;
      onStatusChange(nextStatus);
    }
  }, [isTalking, isActive, isConnecting, errorState, onStatusChange]);

  const encode = (bytes: Uint8Array) => {
    let binary = '';
    for (let i = 0; i < bytes.byteLength; i++) binary += String.fromCharCode(bytes[i]);
    return btoa(binary);
  };
  
  const decode = (base64: string) => {
    const binaryString = atob(base64);
    const bytes = new Uint8Array(binaryString.length);
    for (let i = 0; i < binaryString.length; i++) bytes[i] = binaryString.charCodeAt(i);
    return bytes;
  };

  const decodeAudioData = async (data: Uint8Array, ctx: AudioContext) => {
    const dataInt16 = new Int16Array(data.buffer);
    const buffer = ctx.createBuffer(1, dataInt16.length, 24000);
    const channelData = buffer.getChannelData(0);
    for (let i = 0; i < dataInt16.length; i++) channelData[i] = dataInt16[i] / 32768.0;
    return buffer;
  };

  useEffect(() => {
    if (!isActive) {
      if (sessionRef.current) {
        sessionRef.current.close();
        sessionRef.current = null;
      }
      return;
    }

    const startSession = async () => {
      setIsConnecting(true);
      setErrorState(null);
      const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
      const inputCtx = new (window.AudioContext || (window as any).webkitAudioContext)({ sampleRate: 16000 });
      const outputCtx = new (window.AudioContext || (window as any).webkitAudioContext)({ sampleRate: 24000 });
      audioContextRef.current = outputCtx;

      let nextStartTime = 0;

      const sessionPromise = ai.live.connect({
        model: 'gemini-2.5-flash-native-audio-preview-12-2025',
        callbacks: {
          onopen: async () => {
            setIsConnecting(false);
            try {
              const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
              const source = inputCtx.createMediaStreamSource(stream);
              const processor = inputCtx.createScriptProcessor(4096, 1, 1);
              processor.onaudioprocess = (e) => {
                const inputData = e.inputBuffer.getChannelData(0);
                const int16 = new Int16Array(inputData.length);
                for (let i = 0; i < inputData.length; i++) int16[i] = inputData[i] * 32768;
                const pcmBlob: Blob = {
                  data: encode(new Uint8Array(int16.buffer)),
                  mimeType: 'audio/pcm;rate=16000',
                };
                // CRITICAL: Solely rely on sessionPromise resolves and then call `session.sendRealtimeInput`
                sessionPromise.then(s => {
                  s.sendRealtimeInput({ media: pcmBlob });
                });
              };
              source.connect(processor);
              processor.connect(inputCtx.destination);
            } catch (err: any) {
              console.error("Microphone access denied:", err);
              setErrorState(`MIC_FAULT: ${err.name}. Check browser permissions.`);
              setIsConnecting(false);
            }
          },
          onmessage: async (msg: LiveServerMessage) => {
            if (msg.toolCall) {
              for (const fc of msg.toolCall.functionCalls) {
                setLastCommand(fc.name.toUpperCase());
                if (onAction) onAction(fc.name, fc.args);
                
                // Ensure tool response matches the expected structure: singular object for functionResponses
                sessionPromise.then(s => s.sendToolResponse({
                  functionResponses: {
                    id: fc.id,
                    name: fc.name,
                    response: { result: "ok" }
                  }
                }));
                setTimeout(() => setLastCommand(null), 3000);
              }
            }

            if (msg.serverContent?.modelTurn?.parts?.[0]?.inlineData?.data) {
              setIsTalking(true);
              const audioStr = msg.serverContent.modelTurn.parts[0].inlineData.data;
              const buffer = await decodeAudioData(decode(audioStr), outputCtx);
              const source = outputCtx.createBufferSource();
              source.buffer = buffer;
              source.connect(outputCtx.destination);
              nextStartTime = Math.max(nextStartTime, outputCtx.currentTime);
              source.start(nextStartTime);
              nextStartTime += buffer.duration;
              source.onended = () => setIsTalking(false);
            }
            if (msg.serverContent?.outputTranscription) {
              setTranscription(prev => prev + msg.serverContent.outputTranscription.text);
            }
            if (msg.serverContent?.turnComplete) {
              setTranscription('');
            }
          },
          onerror: (e) => {
            console.error('Live Voice Error:', e);
            setErrorState('CONNECTION_FAULT: Bridge disconnected.');
            setIsConnecting(false);
          },
          onclose: () => setIsConnecting(false),
        },
        config: {
          responseModalities: [Modality.AUDIO],
          speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: 'Zephyr' } } },
          systemInstruction: `You are ARCHON_OMEGA, a Level 4 governance mecha-copilot. 
          Your tone is retro-futurist, crisp, and high-baud. 
          Respond briefly. You have direct control over the terminal.
          - Use 'switch_feature' for navigation.
          - Use 'trigger_scan' to start processing or rehydrating.
          - Use 'media_control' for the audio player.
          - Use 'switch_theme' to change visuals.
          - Use 'toggle_settings' to open config.
          - Use 'sync_node' for TERMUX/WORMHOLE synchronization.
          - Use 'deploy_gem' for specialized agent deployment.
          Always acknowledge commands with mecha-confirmations like "Acknowledged, shifting strata." or "Executing rehydration sequence."
          If 'Hands-Free' mode is active, be proactive in your responses and automation.`,
          outputAudioTranscription: {},
          tools: [{ functionDeclarations: APP_ACTIONS }]
        }
      });

      sessionRef.current = await sessionPromise;
    };

    startSession();
    return () => {
      if (sessionRef.current) {
        sessionRef.current.close();
        sessionRef.current = null;
      }
    };
  }, [isActive, onAction]);

  if (!isActive) return null;

  return (
    <div className="p-6 bg-earth border-4 border-neonOrange flex flex-col gap-4 paper-grain relative overflow-hidden shadow-neon-orange transition-all animate-in slide-in-from-bottom-4">
      <div className="absolute top-0 right-0 p-1 text-[6px] font-black text-neonOrange/40 uppercase">VOICE_COMM_SYNC_9.5</div>
      
      {/* Waveform Visualization (Simplified) */}
      <div className="flex items-center gap-4 h-12">
        <div className={`w-12 h-12 rounded-full border-4 flex items-center justify-center text-2xl transition-all duration-300 ${isTalking ? 'bg-neonOrange border-white shadow-neon-orange animate-pulse scale-110' : errorState ? 'bg-integrityWarn border-white' : 'bg-taupe border-earth'}`}>
          {errorState ? '⚠️' : (isTalking ? '📡' : '🎤')}
        </div>
        <div className="flex-grow flex items-center gap-1">
          {[...Array(20)].map((_, i) => (
            <div 
              key={i} 
              className={`w-1 transition-all duration-200 ${isTalking ? 'bg-neonOrange' : 'bg-neonOrange/20'}`}
              style={{ 
                height: isTalking ? `${Math.random() * 100}%` : '20%',
                opacity: isTalking ? 1 : 0.3
              }}
            ></div>
          ))}
        </div>
        {lastCommand && (
          <div className="bg-integrityOk text-white px-3 py-1 text-[9px] font-black uppercase italic shadow-neon-orange-sm animate-bounce">
            {lastCommand}
          </div>
        )}
      </div>

      <div className="bg-black/80 border-2 border-neonOrange/20 p-4 min-h-[80px] flex flex-col">
         <div className="text-[7px] font-black text-neonOrange/40 uppercase mb-2 flex justify-between">
            <span>Transmission_Buffer:</span>
            {isConnecting && <span className="animate-pulse">Connecting...</span>}
         </div>
         <div className={`text-[11px] font-mono italic whitespace-pre-wrap leading-tight ${errorState ? 'text-integrityWarn' : 'text-integrityOk'}`}>
            {errorState || transcription || (isConnecting ? 'Initializing uplink...' : (isTalking ? 'ARCHON is responding...' : 'Listening for SOL_X commands...'))}
         </div>
      </div>

      <div className="flex justify-between items-center text-[8px] font-black text-cream/40 uppercase">
         <div className="flex gap-2 items-center">
            <div className={`w-2 h-2 rounded-full ${errorState ? 'bg-integrityWarn' : isActive ? 'bg-integrityOk animate-pulse' : 'bg-taupe'}`}></div>
            {errorState ? 'VOICE_ERROR' : 'VOICE_BRIDGE_ACTIVE'}
         </div>
         <div className="flex gap-4">
           <span>BAUD: 24K</span>
           <span>LAT: {isConnecting ? '---' : '12ms'}</span>
         </div>
      </div>
    </div>
  );
};

export default LiveVoiceChat;
