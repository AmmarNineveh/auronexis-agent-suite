 import * as pty from 'node-pty';
 import { AgentType, AgentSessionConfig, ServerMessage } from './types.js';
 import { EventEmitter } from 'events';
 import * as path from 'path';
 import * as fs from 'fs';
 
 export interface SessionEvents {
   onMessage: (msg: ServerMessage) => void;
 }
 import { ChatMessageDto, ToolCallData } from './types.js';
 import { v4 as uuidv4 } from 'uuid';
 import { AgentStreamRunner } from './agentStreamRunner.js';

export class AgentSession extends EventEmitter {
  public id: string;
  public agent: AgentType;
  public command: string;
  public workdir: string;
  public createdAt: number;
  public messages: ChatMessageDto[] = [];
  private ptyProcess: pty.IPty;
  private buffer: string = '';
  private streamRunner: AgentStreamRunner | null = null;
  private currentAssistantMessage: ChatMessageDto | null = null;
  private flushTimer: NodeJS.Timeout | null = null;

  constructor(config: AgentSessionConfig, agentCommand: string, agentArgs: string[]) {
    super();
    this.id = config.id;
    this.agent = config.agent;
    this.command = agentCommand;
    this.workdir = config.workdir && fs.existsSync(config.workdir) ? config.workdir : process.cwd();
    this.createdAt = Date.now();

  const isWindows = process.platform === 'win32';
   const ptyEnv = {
     ...process.env,
     TERM: 'xterm-256color',
     COLORTERM: 'truecolor',
     FORCE_COLOR: '1',
   };
   delete (ptyEnv as any).TERM_PROGRAM;

   let spawnBinary = agentCommand;
   let spawnArgs: string[] = config.args || agentArgs;

   if (agentCommand.toLowerCase().endsWith('.exe')) {
     spawnBinary = agentCommand;
     spawnArgs = config.args || agentArgs;
   } else if (isWindows) {
     spawnBinary = 'cmd.exe';
     spawnArgs = ['/c', (agentCommand + ' ' + (config.args || agentArgs).join(' ')).trim()];
   } else {
     spawnBinary = 'bash';
     spawnArgs = ['-c', (agentCommand + ' ' + (config.args || agentArgs).join(' ')).trim()];
   }

   this.ptyProcess = pty.spawn(spawnBinary, spawnArgs, {
     name: 'xterm-256color',
     cols: 120,
     rows: 40,
     cwd: this.workdir,
     useConpty: false,
     env: ptyEnv as Record<string, string>,
   });
 
     this.ptyProcess.onData((data: string) => {
       this.handleOutput(data);
     });
 
     this.ptyProcess.onExit(({ exitCode }) => {
        console.log(`[SESSION ${this.id}] Process exited with code ${exitCode}. Preserving session in UI.`);
     });
   }
 
   public writePty(data: string) {
     this.ptyProcess.write(data);
   }
 
   public resize(cols: number, rows: number) {
     try {
       this.ptyProcess.resize(cols, rows);
     } catch (err) {
       console.error('Resize error:', err);
     }
   }
 
  public sendPrompt(text: string) {
    console.log(`[SESSION ${this.id}] >>> USER PROMPT: "${text}"`);
    const userMsg: ChatMessageDto = {
      id: uuidv4(),
      sessionId: this.id,
      role: 'user',
      content: text,
      timestamp: Date.now(),
    };
    this.messages.push(userMsg);
    this.emit('message', {
      type: 'chat_message',
      sessionId: this.id,
      message: userMsg,
    } as ServerMessage);

    // If the agent is codex, claude, or opencode, run it via the headless StreamRunner for rich smart chat responses!
    if (this.agent === 'codex' || this.agent === 'claude' || this.agent === 'opencode') {
      if (!this.streamRunner) {
        this.streamRunner = new AgentStreamRunner(this.agent, this.command, this.workdir);
      }
      this.emit('message', {
        type: 'run_state',
        sessionId: this.id,
        isRunning: true,
      } as ServerMessage);

      this.streamRunner.runPrompt(text, {
        onMessage: (msg) => {
          msg.sessionId = this.id;
          this.emit('message', {
            type: 'chat_message',
            sessionId: this.id,
            message: msg,
          } as ServerMessage);
        },
        onToolCall: (tool) => {
          this.emit('message', {
            type: 'tool_call',
            sessionId: this.id,
            toolCall: tool,
          } as ServerMessage);
        },
        onDone: () => {
          console.log(`[SESSION ${this.id}] Stream completed.`);
          this.emit('message', {
            type: 'run_state',
            sessionId: this.id,
            isRunning: false,
          } as ServerMessage);

          // Calculate estimate token usage
          const totalChars = this.messages.reduce((acc, m) => acc + m.content.length, 0);
          const approxTokens = Math.round(totalChars / 3.8);
          this.emit('message', {
            type: 'token_usage',
            sessionId: this.id,
            inputTokens: Math.round(approxTokens * 0.4),
            outputTokens: Math.round(approxTokens * 0.6),
            totalTokens: approxTokens,
          } as ServerMessage);
        },
      });
    } else {
      // Fallback to raw PTY for custom CLI and terminals
      this.writePty(text + '\r\n');
    }
  }

  public respondApproval(approved: boolean) {
    const text = approved ? 'Approved' : 'Rejected';
    const sysMsg: ChatMessageDto = {
      id: uuidv4(),
      sessionId: this.id,
      role: 'system',
      content: `User response: ${text}`,
      timestamp: Date.now(),
    };
    this.messages.push(sysMsg);
    this.emit('message', {
      type: 'chat_message',
      sessionId: this.id,
      message: sysMsg,
    } as ServerMessage);

    this.writePty(approved ? 'y\r\n' : 'n\r\n');
  }

  public abort() {
    if (this.streamRunner && this.streamRunner.isRunning) {
      this.streamRunner.abort();
      this.emit('message', {
        type: 'run_state',
        sessionId: this.id,
        isRunning: false,
      } as ServerMessage);
      const abortMsg: ChatMessageDto = {
        id: uuidv4(),
        sessionId: this.id,
        role: 'system',
        content: '[Run cancelled by user]',
        timestamp: Date.now(),
      };
      this.messages.push(abortMsg);
      this.emit('message', {
        type: 'chat_message',
        sessionId: this.id,
        message: abortMsg,
      } as ServerMessage);
    } else {
      // For PTY, send SIGINT (Ctrl+C)
      this.writePty('\x03');
    }
  }
   public close() {
     try {
       this.ptyProcess.kill();
     } catch (err) {
       console.error('Error killing session process:', err);
     }
   }
 
  private handleOutput(data: string) {
    console.log(`[SESSION ${this.id}] <<< PTY DATA (${data.length} bytes): ${JSON.stringify(data.slice(0, 80))}`);
    const cleanText = data.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, '').replace(/\r/g, '');
    this.emit('message', {
      type: 'chunk',
      sessionId: this.id,
      rawPty: data,
      text: cleanText,
    } as ServerMessage);

    this.buffer += data;
    if (this.buffer.length > 10000) {
      this.buffer = this.buffer.slice(-5000);
    }

    this.processStreamForChat(cleanText);
    this.parseSpecialEvents(data, cleanText);
  }

  private processStreamForChat(cleanText: string) {
    if (!cleanText.trim()) return;
    
    // Filter out spinner animations, ANSI title sequences and raw TUI boxes
    const text = cleanText.trim();
    // If headless streamRunner is handling this session, do not echo raw PTY noise to chat!
    if (this.streamRunner && this.streamRunner.isRunning) {
      return;
    }
    if (text.includes('Agents') && (text.includes('⠋') || text.includes('⠙') || text.includes('⠹') || text.includes('⠸') || text.includes('⠼') || text.includes('⠴') || text.includes('⠦') || text.includes('⠧') || text.includes('⠇') || text.includes('⠏'))) {
      return; // Ignore spinner spinner animation frames!
    }
    if (text.startsWith('╭') || text.startsWith('│') || text.startsWith('╰') || text.startsWith('>_ OpenAI Codex') || text.includes('Ask Codex to do anything')) {
      return; // Ignore ASCII header banner
    }
    
    // Broadcast immediately so user sees streaming response
    this.emit('message', {
      type: 'chat_message',
      sessionId: this.id,
      message: {
        id: uuidv4(),
        sessionId: this.id,
        role: 'assistant',
        content: text,
        timestamp: Date.now(),
      },
    } as ServerMessage);
  }

  private parseSpecialEvents(chunk: string, cleanText: string) {
    const lower = cleanText.toLowerCase();
    if (lower.includes('running:') || lower.includes('executing:') || lower.includes('patching:')) {
      const toolCall: ToolCallData = {
        id: uuidv4(),
        name: 'Tool Execution',
        input: cleanText.trim(),
        status: 'running',
      };
      this.emit('message', {
        type: 'tool_call',
        sessionId: this.id,
        toolCall,
      } as ServerMessage);
    }

    const lowerChunk = chunk.toLowerCase();
    if (lowerChunk.includes('(y/n)') || lowerChunk.includes('[y/n]') || lowerChunk.includes('allow this action?') || lowerChunk.includes('do you want to proceed?')) {
      this.emit('message', {
        type: 'approval_request',
        sessionId: this.id,
        requestId: 'req_' + Date.now(),
        question: chunk.trim(),
      } as ServerMessage);
    }
  }
 }
 
export class SessionManager {
  private sessions: Map<string, AgentSession> = new Map();
  private agentCommands: Record<string, string>;

  constructor(agentPaths: Record<string, string | undefined>) {
    this.agentCommands = {
      codex: agentPaths.codex || 'codex',
      claude: agentPaths.claude || 'claude',
      opencode: agentPaths.opencode || 'opencode',
      hermes: agentPaths.hermes || 'hermes',
    };
  }

  public createSession(config: AgentSessionConfig, onMessage: (msg: ServerMessage) => void): AgentSession {
    const cmd = config.command || this.agentCommands[config.agent] || config.agent;
    const session = new AgentSession(config, cmd, []);
    session.on('message', onMessage);
    this.sessions.set(config.id, session);
    return session;
  }
 
   public getSession(id: string): AgentSession | undefined {
     return this.sessions.get(id);
   }
 
   public closeSession(id: string): boolean {
     const session = this.sessions.get(id);
     if (session) {
       session.close();
       this.sessions.delete(id);
       return true;
     }
     return false;
   }
 
  public listSessions() {
    return Array.from(this.sessions.values()).map(s => ({
      id: s.id,
      agent: s.agent,
      command: s.command,
      workdir: s.workdir,
      createdAt: s.createdAt,
    }));
  }
 }
