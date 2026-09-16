 import express, { Request, Response } from 'express';
 import http from 'http';
 import { WebSocketServer, WebSocket } from 'ws';
 import cors from 'cors';
 import os from 'os';
 import fs from 'fs';
 import path from 'path';
 import { v4 as uuidv4 } from 'uuid';
 import qrcode from 'qrcode-terminal';
 import { SessionManager } from './sessionManager.js';
 import { ClientMessage, ServerMessage, SystemInfo, AgentType } from './types.js';
 import { execSync } from 'child_process';
 
 const PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : 8088;
 const PAIRING_TOKEN = process.env.TOKEN || uuidv4().slice(0, 8);
 
function findCliPath(cliName: string): string | undefined {
  // Check direct known paths for standalone Windows binaries first
  if (cliName === 'codex') {
    const codexExe = 'C:\\Users\\intel\\AppData\\Local\\OpenAI\\Codex\\bin\\12219cbfbcbddde7\\codex.exe';
    if (fs.existsSync(codexExe)) return codexExe;
  }
  if (cliName === 'claude') {
    const claudeExe = 'E:\\npm-global\\node_modules\\@anthropic-ai\\claude-code\\bin\\claude.exe';
    if (fs.existsSync(claudeExe)) return claudeExe;
  }
  if (cliName === 'opencode') {
    const opencodeExe = 'E:\\npm-global\\node_modules\\opencode-ai\\bin\\opencode.exe';
    if (fs.existsSync(opencodeExe)) return opencodeExe;
  }

  try {
    const isWin = process.platform === 'win32';
    const checkCmd = isWin ? `where ${cliName}` : `which ${cliName}`;
     const stdout = execSync(checkCmd, { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'ignore'] });
     const lines = stdout.trim().split(/\r?\n/).filter(Boolean);
     return lines[0];
   } catch {
     return undefined;
   }
 }
 
const codexPath = findCliPath('codex');
const claudePath = findCliPath('claude');
const opencodePath = findCliPath('opencode');
const hermesPath = findCliPath('hermes');

const sessionManager = new SessionManager({
  codex: codexPath,
  claude: claudePath,
  opencode: opencodePath,
  hermes: hermesPath,
});
 
 const app = express();
 app.use(cors());
 app.use(express.json());
 
 function getLocalIps(): { name: string; address: string }[] {
   const interfaces = os.networkInterfaces();
   const results: { name: string; address: string }[] = [];
   for (const name of Object.keys(interfaces)) {
     for (const net of interfaces[name] || []) {
       if (net.family === 'IPv4' && !net.internal) {
         results.push({ name, address: net.address });
       }
     }
   }
   return results;
 }
 
function getSystemInfo(): SystemInfo {
  const knownClis = [
    { id: 'codex', name: 'Codex CLI' },
    { id: 'claude', name: 'Claude Code' },
    { id: 'opencode', name: 'OpenCode' },
    { id: 'hermes', name: 'Hermes Agent' },
    { id: 'aichat', name: 'AIChat CLI' },
    { id: 'ollama', name: 'Ollama' },
  ];
  const detectedClis: { name: string; path: string }[] = [];
  const agentsMap: Record<string, { available: boolean; path?: string }> = {};

  for (const cli of knownClis) {
    const p = findCliPath(cli.id);
    agentsMap[cli.id] = { available: !!p, path: p };
    if (p) {
      detectedClis.push({ name: cli.name, path: p });
    }
  }

  return {
    os: `${os.type()} ${os.release()}`,
    platform: process.platform,
    agents: agentsMap,
    detectedClis,
    defaultDir: process.cwd(),
    interfaces: getLocalIps(),
  };
}
import { GitService } from './gitService.js';
import { FileTreeService } from './fileTreeService.js';

app.get('/api/status', (req: Request, res: Response) => {
  res.json({
    status: 'ok',
    system: getSystemInfo(),
    activeSessions: sessionManager.listSessions().length,
  });
});

app.get('/download', (req: Request, res: Response) => {
  const apkPath = path.resolve(__dirname, '../../app_flutter/build/app/outputs/flutter-apk/app-debug.apk');
  if (fs.existsSync(apkPath)) {
    res.download(apkPath, 'AgentMobile.apk');
  } else {
    res.status(404).send('APK not found. Please build it first.');
  }
});
 
 app.get('/api/pairing-qr', (req: Request, res: Response) => {
   const ips = getLocalIps();
   const primaryIp = ips[0]?.address || '127.0.0.1';
   const payload = {
     host: primaryIp,
     port: PORT,
     token: PAIRING_TOKEN,
     allIps: ips,
   };
   res.json(payload);
 });
 
app.get('/api/projects', (req: Request, res: Response) => {
  const targetDir = (req.query.dir as string) || process.cwd();
  try {
    if (!fs.existsSync(targetDir)) {
      res.status(404).json({ error: 'Directory does not exist' });
      return;
    }
    const items = fs.readdirSync(targetDir, { withFileTypes: true });
    const entries = items
      .filter(item => !item.name.startsWith('.') && item.name !== 'node_modules')
      .map(item => ({
        name: item.name,
        path: path.join(targetDir, item.name),
        isDirectory: item.isDirectory(),
      }));
    res.json({ current: targetDir, entries });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/files/tree', (req: Request, res: Response) => {
  const targetDir = (req.query.dir as string) || process.cwd();
  const depth = req.query.depth ? parseInt(req.query.depth as string, 10) : 2;
  const tree = FileTreeService.listDirectory(targetDir, depth);
  res.json({ root: targetDir, tree });
});

app.get('/api/files/content', (req: Request, res: Response) => {
  const filePath = req.query.path as string;
  if (!filePath) {
    res.status(400).json({ error: 'Path is required' });
    return;
  }
  const content = FileTreeService.readFileContent(filePath);
  res.json({ path: filePath, content });
});

app.get('/api/git/status', (req: Request, res: Response) => {
  const targetDir = (req.query.dir as string) || process.cwd();
  const status = GitService.getStatus(targetDir);
  res.json(status);
});

app.get('/api/git/diff', (req: Request, res: Response) => {
  const targetDir = (req.query.dir as string) || process.cwd();
  const filePath = req.query.file as string | undefined;
  const diff = GitService.getDiff(targetDir, filePath);
  res.json({ diff });
});
 
 const server = http.createServer(app);
 const wss = new WebSocketServer({ server, path: '/ws' });
 
 wss.on('connection', (ws: WebSocket) => {
   let isAuthenticated = false;
 
   const send = (msg: ServerMessage) => {
     if (ws.readyState === WebSocket.OPEN) {
       ws.send(JSON.stringify(msg));
     }
   };
 
   ws.on('message', (raw: Buffer) => {
     try {
       const msg: ClientMessage = JSON.parse(raw.toString('utf-8'));
 
       if (!isAuthenticated) {
         if (msg.type === 'auth') {
           if (msg.token === PAIRING_TOKEN) {
             isAuthenticated = true;
             send({
               type: 'auth_ok',
               systemInfo: getSystemInfo(),
               pairingToken: PAIRING_TOKEN,
             });
           } else {
             send({ type: 'auth_error', message: 'Invalid pairing token' });
             ws.close();
           }
         } else {
           send({ type: 'auth_error', message: 'Authentication required' });
           ws.close();
         }
         return;
       }
 
       switch (msg.type) {
        case 'session_create': {
          const sessionId = 'sess_' + uuidv4().slice(0, 8);
          const cmd = msg.customCommand || undefined;
          sessionManager.createSession(
            {
              id: sessionId,
              agent: msg.agent,
              command: cmd,
              workdir: msg.workdir || process.cwd(),
              args: msg.args,
            },
            (serverMsg) => send(serverMsg)
          );
          const sessionInstance = sessionManager.getSession(sessionId);
          send({
            type: 'session_ready',
            sessionId,
            agent: msg.agent,
            command: sessionInstance?.command || msg.agent,
            workdir: msg.workdir || process.cwd(),
          });
          break;
        }
 
         case 'session_close': {
           sessionManager.closeSession(msg.sessionId);
           send({ type: 'session_closed', sessionId: msg.sessionId });
           break;
         }
 
         case 'session_list': {
           send({
             type: 'session_list_result',
             sessions: sessionManager.listSessions(),
           });
           break;
         }
 
        case 'prompt': {
          const session = sessionManager.getSession(msg.sessionId);
          if (session) {
            session.sendPrompt(msg.text);
          } else {
            send({ type: 'error', sessionId: msg.sessionId, message: 'Session not found' });
          }
          break;
        }

        case 'abort': {
          const session = sessionManager.getSession(msg.sessionId);
          if (session) {
            session.abort();
          }
          break;
        }
 
         case 'pty_input': {
           const session = sessionManager.getSession(msg.sessionId);
           if (session) {
             session.writePty(msg.data);
           }
           break;
         }
 
         case 'pty_resize': {
           const session = sessionManager.getSession(msg.sessionId);
           if (session) {
             session.resize(msg.cols, msg.rows);
           }
           break;
         }
 
         case 'approval_response': {
           const session = sessionManager.getSession(msg.sessionId);
           if (session) {
             session.respondApproval(msg.approved);
           }
           break;
         }
       }
     } catch (err: any) {
       console.error('WS Error:', err);
       send({ type: 'error', message: err.message || 'Unknown server error' });
     }
   });
 });
 
 server.listen(PORT, '0.0.0.0', () => {
   const ips = getLocalIps();
   const primary = ips[0]?.address || '127.0.0.1';
   const pairString = JSON.stringify({
     host: primary,
     port: PORT,
     token: PAIRING_TOKEN,
   });
 
   console.log('====================================================');
   console.log('🤖 AgentMobile Host Bridge Server running!');
   console.log(`📡 Port: ${PORT}`);
   console.log(`🔑 Pairing Token: ${PAIRING_TOKEN}`);
   console.log(`🌐 Available on:`);
   ips.forEach(ip => console.log(`   - http://${ip.address}:${PORT}`));
   console.log('📲 Scan this QR code with the AgentMobile Flutter App:');
   qrcode.generate(pairString, { small: true });
   console.log('====================================================');
 });
