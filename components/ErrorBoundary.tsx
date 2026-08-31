
import React, { Component, ErrorInfo, ReactNode } from 'react';

interface Props {
  children: ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
  errorInfo: ErrorInfo | null;
}

// Fixed: Using React.Component explicitly with generic Props and State to ensure setState and props are correctly inherited and recognized by the compiler.
class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = {
      hasError: false,
      error: null,
      errorInfo: null
    };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error, errorInfo: null };
  }

  // Fixed: Standard React lifecycle method for error catching
  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error("Uncaught error:", error, errorInfo);
    // Fixed: Explicit use of this.setState is valid in classes extending React.Component
    this.setState({ errorInfo });
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="fixed inset-0 bg-black text-neonOrange p-10 flex flex-col items-center justify-center font-mono paper-grain z-[9999]">
          <div className="border-4 border-neonOrange p-8 max-w-2xl w-full shadow-neon-orange animate-pulse">
            <h1 className="text-4xl font-black mb-4">CRITICAL_SYSTEM_HALT</h1>
            <div className="bg-neonOrange text-black px-4 py-1 font-black mb-6">ARCHON_OMEGA_KERNEL_PANIC</div>
            
            <div className="space-y-4 text-xs opacity-80 mb-8 overflow-auto max-h-60 custom-scrollbar p-2 border border-neonOrange/20">
              <p>{">"} TRACE_ID: {Math.random().toString(36).substr(2, 9).toUpperCase()}</p>
              <p>{">"} FAULT_TYPE: {this.state.error?.name || 'UNKNOWN'}</p>
              <p>{">"} MESSAGE: {this.state.error?.message}</p>
              <p>{">"} STACK_TRACE: {this.state.errorInfo?.componentStack}</p>
            </div>

            <div className="flex flex-col gap-4">
              <p className="text-[10px] italic">"Strata corruption detected in primary verification buffer. Attempting cold reboot..."</p>
              <button 
                onClick={() => window.location.reload()}
                className="bg-neonOrange text-black font-black py-4 px-8 hover:bg-white transition-all uppercase tracking-widest"
              >
                [REBOOT_OS]
              </button>
            </div>
          </div>
        </div>
      );
    }

    // Fixed: props is available on this when extending React.Component<Props, State>
    return this.props.children;
  }
}

export default ErrorBoundary;
