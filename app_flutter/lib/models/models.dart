 import 'dart:convert';
 
 enum AgentType { codex, claude, opencode, hermes, custom }
 class AgentCommandSuggestion {
   final String command;
   final String description;
   final String? example;
 
   const AgentCommandSuggestion({
     required this.command,
     required this.description,
     this.example,
   });
 }

extension AgentTypeExtension on AgentType {
  List<AgentCommandSuggestion> get supportedCommands {
    switch (this) {
      case AgentType.codex:
        return const [
          AgentCommandSuggestion(command: '/help', description: 'Show all available Codex commands'),
          AgentCommandSuggestion(command: '/review', description: 'Run code review on current branch'),
          AgentCommandSuggestion(command: '/model', description: 'Switch active model (e.g. /model gpt-5.6-luna)'),
          AgentCommandSuggestion(command: '/status', description: 'Check Codex daemon & workspace status'),
          AgentCommandSuggestion(command: '/diff', description: 'Show current git uncommitted changes'),
          AgentCommandSuggestion(command: '/compact', description: 'Compact conversation context'),
          AgentCommandSuggestion(command: '/clear', description: 'Clear screen and session buffer'),
        ];
      case AgentType.claude:
        return const [
          AgentCommandSuggestion(command: '/help', description: 'Show Claude Code help and options'),
          AgentCommandSuggestion(command: '/compact', description: 'Compact context to save tokens'),
          AgentCommandSuggestion(command: '/cost', description: 'Show token usage and cost for session'),
          AgentCommandSuggestion(command: '/doctor', description: 'Check health and configuration'),
          AgentCommandSuggestion(command: '/init', description: 'Initialize project guide (CLAUDE.md)'),
          AgentCommandSuggestion(command: '/clear', description: 'Clear conversation history'),
        ];
      case AgentType.opencode:
        return const [
          AgentCommandSuggestion(command: '/help', description: 'Show OpenCode commands and modes'),
          AgentCommandSuggestion(command: '/model', description: 'Change LLM model or local provider'),
          AgentCommandSuggestion(command: '/agent', description: 'Switch agent persona or system prompt'),
          AgentCommandSuggestion(command: '/context', description: 'Inspect included files in context'),
          AgentCommandSuggestion(command: '/clear', description: 'Clear active session context'),
        ];
      case AgentType.hermes:
        return const [
          AgentCommandSuggestion(command: '/help', description: 'Hermes Agent commands'),
          AgentCommandSuggestion(command: '/tools', description: 'List available tools & skills'),
          AgentCommandSuggestion(command: '/reset', description: 'Reset memory & context'),
        ];
      case AgentType.custom:
        return const [
          AgentCommandSuggestion(command: '/help', description: 'Help command'),
          AgentCommandSuggestion(command: 'clear', description: 'Clear terminal screen'),
          AgentCommandSuggestion(command: 'exit', description: 'Close current process'),
        ];
    }
  }
  String get id {
    switch (this) {
      case AgentType.codex:
        return 'codex';
      case AgentType.claude:
        return 'claude';
      case AgentType.opencode:
        return 'opencode';
      case AgentType.hermes:
        return 'hermes';
      case AgentType.custom:
        return 'custom';
    }
  }

  String get displayName {
    switch (this) {
      case AgentType.codex:
        return 'Codex CLI';
      case AgentType.claude:
        return 'Claude Code';
      case AgentType.opencode:
        return 'OpenCode';
      case AgentType.hermes:
        return 'Hermes Agent';
      case AgentType.custom:
        return 'Custom CLI';
    }
  }

  String get logoAsset {
    switch (this) {
      case AgentType.codex:
        return 'assets/logos/codex.svg';
      case AgentType.claude:
        return 'assets/logos/claude.svg';
      case AgentType.opencode:
        return 'assets/logos/opencode.svg';
      case AgentType.hermes:
        return 'assets/logos/hermes.svg';
      case AgentType.custom:
        return 'assets/logos/terminal.svg';
    }
  }

  static AgentType fromString(String val) {
    switch (val.toLowerCase()) {
      case 'claude':
        return AgentType.claude;
      case 'opencode':
        return AgentType.opencode;
      case 'hermes':
        return AgentType.hermes;
      case 'custom':
        return AgentType.custom;
      case 'codex':
      default:
        return AgentType.codex;
    }
  }
}
 
 class HostConfig {
   final String host;
   final int port;
   final String token;
 
   HostConfig({
     required this.host,
     required this.port,
     required this.token,
   });
 
   String get wsUrl => 'ws://$host:$port/ws';
   String get httpUrl => 'http://$host:$port';
 
   Map<String, dynamic> toJson() => {
         'host': host,
         'port': port,
         'token': token,
       };
 
   factory HostConfig.fromJson(Map<String, dynamic> json) => HostConfig(
         host: json['host'] as String? ?? '127.0.0.1',
         port: json['port'] as int? ?? 4242,
         token: json['token'] as String? ?? '',
       );
 }
 
class AgentSessionInfo {
  final String id;
  final AgentType agent;
  final String? command;
  final String workdir;
  final DateTime createdAt;

  AgentSessionInfo({
    required this.id,
    required this.agent,
    this.command,
    required this.workdir,
    required this.createdAt,
  });

  factory AgentSessionInfo.fromJson(Map<String, dynamic> json) => AgentSessionInfo(
        id: json['id'] as String,
        agent: AgentTypeExtension.fromString(json['agent'] as String? ?? 'codex'),
        command: json['command'] as String?,
        workdir: json['workdir'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch),
      );
}
 class ToolCallItem {
   final String id;
   final String name;
   final String? input;
   final String? output;
   final String status;
   final String? diff;
 
   ToolCallItem({
     required this.id,
     required this.name,
     this.input,
     this.output,
     required this.status,
     this.diff,
   });
 
   factory ToolCallItem.fromJson(Map<String, dynamic> json) => ToolCallItem(
         id: json['id'] as String? ?? '',
         name: json['name'] as String? ?? 'Tool Call',
         input: json['input']?.toString(),
         output: json['output']?.toString(),
         status: json['status'] as String? ?? 'completed',
         diff: json['diff'] as String?,
       );
 }

class ChatMessage {
  final String id;
  final bool isUser;
  final String content;
  final DateTime timestamp;
  final bool isApproval;
  final String? requestId;
  final bool? approvalGranted;
  final ToolCallItem? toolCall;

  ChatMessage({
    required this.id,
    required this.isUser,
    required this.content,
    required this.timestamp,
    this.isApproval = false,
    this.requestId,
    this.approvalGranted,
    this.toolCall,
  });

  ChatMessage copyWith({
    bool? approvalGranted,
    String? content,
    ToolCallItem? toolCall,
  }) =>
      ChatMessage(
        id: id,
        isUser: isUser,
        content: content ?? this.content,
        timestamp: timestamp,
        isApproval: isApproval,
        requestId: requestId,
        approvalGranted: approvalGranted ?? this.approvalGranted,
        toolCall: toolCall ?? this.toolCall,
      );
}
 class GitStatusData {
   final bool isGit;
   final String? branch;
   final List<String> modified;
   final List<String> added;
   final List<String> deleted;
   final List<String> untracked;
   final List<String> staged;
 
   GitStatusData({
     required this.isGit,
     this.branch,
     this.modified = const [],
     this.added = const [],
     this.deleted = const [],
     this.untracked = const [],
     this.staged = const [],
   });
 
   factory GitStatusData.fromJson(Map<String, dynamic> json) => GitStatusData(
         isGit: json['isGit'] as bool? ?? false,
         branch: json['branch'] as String?,
         modified: (json['modified'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
         added: (json['added'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
         deleted: (json['deleted'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
         untracked: (json['untracked'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
         staged: (json['staged'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
       );
 }
 
 class WorkspaceFileItem {
   final String name;
   final String path;
   final bool isDirectory;
   final int? size;
   final List<WorkspaceFileItem>? children;
 
   WorkspaceFileItem({
     required this.name,
     required this.path,
     required this.isDirectory,
     this.size,
     this.children,
   });
 
   factory WorkspaceFileItem.fromJson(Map<String, dynamic> json) => WorkspaceFileItem(
         name: json['name'] as String? ?? '',
         path: json['path'] as String? ?? '',
         isDirectory: json['isDirectory'] as bool? ?? false,
         size: json['size'] as int?,
         children: (json['children'] as List<dynamic>?)
             ?.map((c) => WorkspaceFileItem.fromJson(c as Map<String, dynamic>))
             .toList(),
       );
 }
 class SessionStats {
   final int inputTokens;
   final int outputTokens;
   final int totalTokens;
 
   SessionStats({
     this.inputTokens = 0,
     this.outputTokens = 0,
     this.totalTokens = 0,
   });
 
   String get formattedTotal {
     if (totalTokens >= 1000000) {
       return (totalTokens / 1000000).toStringAsFixed(1) + 'M';
     }
     if (totalTokens >= 1000) {
       return (totalTokens / 1000).toStringAsFixed(1) + 'k';
     }
     return totalTokens.toString();
   }
 }
