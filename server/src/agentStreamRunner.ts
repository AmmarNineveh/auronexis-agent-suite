 import { spawn, ChildProcess } from 'child_process';
 import { EventEmitter } from 'events';
 import { ChatMessageDto, ToolCallData, AgentType } from './types.js';
 import { v4 as uuidv4 } from 'uuid';
 
 export interface StreamRunnerEvents {
   onMessage: (msg: ChatMessageDto) => void;
   onToolCall: (tool: ToolCallData) => void;
   onDone: () => void;
 }
 
 export class AgentStreamRunner extends EventEmitter {
   private process: ChildProcess | null = null;
   public isRunning = false;
 
   constructor(
     public agent: AgentType,
     public command: string,
     public cwd: string
   ) {
     super();
   }
 
   public runPrompt(prompt: string, callbacks: StreamRunnerEvents) {
     this.isRunning = true;
     let fullAssistantText = '';
     const assistantMsgId = uuidv4();
 
     // Format prompt execution based on agent type:
     // 1. Codex CLI: codex exec "..."
     // 2. Claude Code: claude -p "..."
     // 3. OpenCode: opencode run "..."
     let executable = this.command;
     let args: string[] = [];
 
    if (this.agent === 'codex') {
      args = ['exec', prompt];
    } else if (this.agent === 'claude') {
      args = ['-p', prompt];
    } else if (this.agent === 'opencode') {
      args = ['run', '--format', 'json', prompt];
    } else {
      args = [prompt];
    }
 
     try {
       this.process = spawn(executable, args, {
         cwd: this.cwd,
         shell: true,
         env: { ...process.env, TERM: 'xterm-256color', FORCE_COLOR: '0' },
       });
 
      this.process.stdout?.on('data', (chunk: Buffer) => {
        const text = chunk.toString('utf-8');
        if (this.agent === 'opencode') {
          const lines = text.split(/\r?\n/);
          for (const line of lines) {
            if (!line.trim().startsWith('{')) continue;
            try {
              const evt = JSON.parse(line.trim());
              if (evt.type === 'content' && evt.content) {
                fullAssistantText += evt.content;
              } else if (evt.type === 'error' && evt.error) {
                fullAssistantText += '\n[Error: ' + (evt.error.message || evt.error.name) + ']';
              }
            } catch {}
          }
          if (fullAssistantText) {
            callbacks.onMessage({
              id: assistantMsgId,
              sessionId: '',
              role: 'assistant',
              content: fullAssistantText,
              timestamp: Date.now(),
            });
            return;
          }
        }

        const clean = text.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, '');
         fullAssistantText += clean;
 
         // Detect tool executions (commands, file writes, diffs)
         this.detectToolCalls(clean, callbacks.onToolCall);
 
         // Stream text update
         callbacks.onMessage({
           id: assistantMsgId,
           sessionId: '',
           role: 'assistant',
           content: fullAssistantText,
           timestamp: Date.now(),
         });
       });
 
      this.process.stderr?.on('data', (chunk: Buffer) => {
        const text = chunk.toString('utf-8');
        const clean = text.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, '');
        // Filter out noisy connection retry warnings
        if (clean.trim() && !clean.includes('WARN') && !clean.includes('INFO') && !clean.includes('Reading additional input')) {
          fullAssistantText += '\n' + clean;
          callbacks.onMessage({
            id: assistantMsgId,
            sessionId: '',
            role: 'assistant',
            content: fullAssistantText,
            timestamp: Date.now(),
          });
        }
      });
 
       this.process.on('close', () => {
         this.isRunning = false;
         callbacks.onDone();
       });
 
       this.process.on('error', (err) => {
         this.isRunning = false;
         callbacks.onMessage({
           id: assistantMsgId,
           sessionId: '',
           role: 'assistant',
           content: fullAssistantText + `\n[Error: ${err.message}]`,
           timestamp: Date.now(),
         });
         callbacks.onDone();
       });
     } catch (err: any) {
       this.isRunning = false;
       callbacks.onMessage({
         id: assistantMsgId,
         sessionId: '',
         role: 'assistant',
         content: `Execution failed: ${err.message}`,
         timestamp: Date.now(),
       });
       callbacks.onDone();
     }
   }
 
   private detectToolCalls(text: string, onTool: (t: ToolCallData) => void) {
     const lines = text.split('\n');
     for (const line of lines) {
       const trimmed = line.trim();
       if (trimmed.startsWith('$ ') || trimmed.startsWith('> ') || trimmed.includes('Running: ') || trimmed.includes('Executing: ')) {
         onTool({
           id: uuidv4(),
           name: 'Command Execution',
           input: trimmed,
           status: 'completed',
         });
       }
       if (trimmed.startsWith('diff --git') || trimmed.startsWith('Index: ') || trimmed.startsWith('--- a/')) {
         onTool({
           id: uuidv4(),
           name: 'Git Diff / Patch',
           input: trimmed,
           diff: trimmed,
           status: 'completed',
         });
       }
     }
   }
 
   public abort() {
     if (this.process) {
       try {
         this.process.kill();
       } catch {}
       this.isRunning = false;
     }
   }
 }
