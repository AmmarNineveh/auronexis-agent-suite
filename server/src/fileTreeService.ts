 import fs from 'fs';
 import path from 'path';
 
 export interface FileNode {
   name: string;
   path: string;
   isDirectory: boolean;
   size?: number;
   children?: FileNode[];
 }
 
 const IGNORED_NAMES = new Set([
   'node_modules', '.git', '.gradle', 'build', 'dist', '.dart_tool', '.idea', '__pycache__', '.venv'
 ]);
 
 export class FileTreeService {
   public static listDirectory(targetDir: string, maxDepth: number = 2, currentDepth: number = 0): FileNode[] {
     try {
       if (!fs.existsSync(targetDir)) return [];
       const items = fs.readdirSync(targetDir, { withFileTypes: true });
       const nodes: FileNode[] = [];
 
       for (const item of items) {
         if (item.name.startsWith('.') && item.name !== '.env') continue;
         if (IGNORED_NAMES.has(item.name)) continue;
 
         const fullPath = path.join(targetDir, item.name);
         const isDir = item.isDirectory();
 
         const node: FileNode = {
           name: item.name,
           path: fullPath,
           isDirectory: isDir,
         };
 
         if (isDir && currentDepth < maxDepth) {
           node.children = this.listDirectory(fullPath, maxDepth, currentDepth + 1);
         } else if (!isDir) {
           try {
             node.size = fs.statSync(fullPath).size;
           } catch {}
         }
 
         nodes.push(node);
       }
 
       return nodes.sort((a, b) => {
         if (a.isDirectory === b.isDirectory) return a.name.localeCompare(b.name);
         return a.isDirectory ? -1 : 1;
       });
     } catch {
       return [];
     }
   }
 
   public static readFileContent(filePath: string, maxBytes: number = 100000): string {
     try {
       if (!fs.existsSync(filePath)) return '';
       const stat = fs.statSync(filePath);
       if (stat.size > maxBytes) {
         const buffer = Buffer.alloc(maxBytes);
         const fd = fs.openSync(filePath, 'r');
         fs.readSync(fd, buffer, 0, maxBytes, 0);
         fs.closeSync(fd);
         return buffer.toString('utf-8') + '\n\n... [Truncated due to size]';
       }
       return fs.readFileSync(filePath, 'utf-8');
     } catch (err: any) {
       return 'Error reading file: ' + err.message;
     }
   }
 }
