
import React, { useState, useCallback } from 'react';
import CodeEditor from './components/CodeEditor';
import ControlPanel from './components/ControlPanel';
import OutputDisplay from './components/OutputDisplay';
import { GD_SCRIPT_CODE, FEATURES } from './constants';
import { Feature } from './types';
import { generateContent } from './services/geminiService';

const App: React.FC = () => {
  const [selectedFeature, setSelectedFeature] = useState<Feature>(Feature.EXPLAIN_CODE);
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [output, setOutput] = useState<string>('');
  const [error, setError] = useState<string | null>(null);

  const handleGenerate = useCallback(async () => {
    setIsLoading(true);
    setOutput('');
    setError(null);
    const result = await generateContent(selectedFeature);
    setOutput(result);
    setIsLoading(false);
  }, [selectedFeature]);

  const selectedFeatureInfo = FEATURES.find(f => f.id === selectedFeature);

  return (
    <div className="min-h-screen p-4 sm:p-6 lg:p-8 bg-gray-900 font-sans">
      <header className="text-center mb-8">
        <h1 className="text-4xl sm:text-5xl font-extrabold text-transparent bg-clip-text bg-gradient-to-r from-teal-300 to-blue-500">
          GDScript Gemini Toolkit
        </h1>
        <p className="mt-2 text-lg text-gray-400">
          AI-Powered Analysis and Brainstorming for Godot Developers
        </p>
      </header>
      
      <main className="grid grid-cols-1 lg:grid-cols-3 gap-6 h-[calc(100vh-150px)]">
        <div className="lg:col-span-1 h-full">
            <ControlPanel
                features={FEATURES}
                selectedFeature={selectedFeature}
                onSelectFeature={setSelectedFeature}
                onGenerate={handleGenerate}
                isLoading={isLoading}
            />
        </div>
        <div className="lg:col-span-2 grid grid-rows-2 gap-6 h-full">
            <div className="row-span-1 h-full overflow-hidden">
                 <CodeEditor code={GD_SCRIPT_CODE} />
            </div>
            <div className="row-span-1 h-full overflow-hidden">
                <OutputDisplay 
                    output={output} 
                    isLoading={isLoading} 
                    featureTitle={selectedFeatureInfo?.title || 'Response'}
                />
            </div>
        </div>
        {error && (
            <div className="lg:col-span-3 bg-red-800 text-white p-4 rounded-lg mt-4">
                <strong>Error:</strong> {error}
            </div>
        )}
      </main>
    </div>
  );
};

export default App;
