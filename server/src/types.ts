 export type AgentType = 'codex' | 'claude' | 'opencode' | 'hermes' | 'custom' | string;

export interface AgentSessionConfig {
  id: string;
  agent: AgentType;
  command?: string;
  workdir: string;
  args?: string[];
}

export interface SystemInfo {
  os: string;
  platform: NodeJS.Platform;
  agents: Record<string, { available: boolean; path?: string }>;
  detectedClis: { name: string; path: string }[];
  defaultDir: string;
  interfaces: { name: string; address: string }[];
}

export type ClientMessage =
  | { type: 'auth'; token: string; client?: string }
  | { type: 'session_create'; agent: AgentType; customCommand?: string; workdir?: string; args?: string[] }
  | { type: 'session_close'; sessionId: string }
  | { type: 'session_list' }
  | { type: 'prompt'; sessionId: string; text: string }
  | { type: 'abort'; sessionId: string }
  | { type: 'pty_input'; sessionId: string; data: string }
  | { type: 'pty_resize'; sessionId: string; cols: number; rows: number }
  | { type: 'approval_response'; sessionId: string; requestId: string; approved: boolean };
 export type ToolCallStatus = 'pending' | 'running' | 'completed' | 'failed' | 'requires_approval';
 
 export interface ToolCallData {
   id: string;
   name: string;
   input?: Record<string, unknown> | string;
   output?: string;
   status: ToolCallStatus;
   diff?: string;
 }
 
 export interface ChatMessageDto {
   id: string;
   sessionId: string;
   role: 'user' | 'assistant' | 'system' | 'tool';
   content: string;
   timestamp: number;
   toolCall?: ToolCallData;
   isThinking?: boolean;
 }

export type ServerMessage =
  | { type: 'auth_ok'; systemInfo: SystemInfo; pairingToken: string }
  | { type: 'auth_error'; message: string }
  | { type: 'session_ready'; sessionId: string; agent: AgentType; command: string; workdir: string }
  | { type: 'session_closed'; sessionId: string }
  | { type: 'session_list_result'; sessions: { id: string; agent: AgentType; command: string; workdir: string; createdAt: number }[] }
  | { type: 'chunk'; sessionId: string; text?: string; rawPty?: string }
  | { type: 'tool_call'; sessionId: string; toolCall: ToolCallData }
  | { type: 'chat_message'; sessionId: string; message: ChatMessageDto }
  | { type: 'run_state'; sessionId: string; isRunning: boolean }
  | { type: 'token_usage'; sessionId: string; inputTokens: number; outputTokens: number; totalTokens: number }
  | { type: 'session_history'; sessionId: string; messages: ChatMessageDto[] }
  | { type: 'approval_request'; sessionId: string; requestId: string; question: string; details?: string }
  | { type: 'error'; sessionId?: string; message: string };
