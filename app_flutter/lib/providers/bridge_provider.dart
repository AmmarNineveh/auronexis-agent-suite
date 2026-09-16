 import 'dart:async';
 import 'dart:convert';
 import 'package:flutter/foundation.dart';
 import 'package:flutter_riverpod/flutter_riverpod.dart';
 import 'package:flutter_riverpod/legacy.dart';
 import 'package:web_socket_channel/web_socket_channel.dart';
 import 'package:shared_preferences/shared_preferences.dart';
 import 'package:xterm/xterm.dart';
 import 'package:uuid/uuid.dart';
 import '../models/models.dart';
 
class BridgeState {
  final bool isConnecting;
  final bool isConnected;
  final String? error;
  final HostConfig? hostConfig;
  final Map<String, dynamic>? systemInfo;
  final List<AgentSessionInfo> sessions;
  final String? activeSessionId;
  final Map<String, List<ChatMessage>> sessionMessages;
  final Map<String, bool> runningSessions;
  final Map<String, SessionStats> sessionStats;
  final List<String> debugLogs;

  BridgeState({
    this.isConnecting = false,
    this.isConnected = false,
    this.error,
    this.hostConfig,
    this.systemInfo,
    this.sessions = const [],
    this.activeSessionId,
    this.sessionMessages = const {},
    this.runningSessions = const {},
    this.sessionStats = const {},
    this.debugLogs = const [],
  });

  BridgeState copyWith({
    bool? isConnecting,
    bool? isConnected,
    String? error,
    HostConfig? hostConfig,
    Map<String, dynamic>? systemInfo,
    List<AgentSessionInfo>? sessions,
    String? activeSessionId,
    Map<String, List<ChatMessage>>? sessionMessages,
    Map<String, bool>? runningSessions,
    Map<String, SessionStats>? sessionStats,
    List<String>? debugLogs,
  }) {
    return BridgeState(
      isConnecting: isConnecting ?? this.isConnecting,
      isConnected: isConnected ?? this.isConnected,
      error: error,
      hostConfig: hostConfig ?? this.hostConfig,
      systemInfo: systemInfo ?? this.systemInfo,
      sessions: sessions ?? this.sessions,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      sessionMessages: sessionMessages ?? this.sessionMessages,
      runningSessions: runningSessions ?? this.runningSessions,
      sessionStats: sessionStats ?? this.sessionStats,
      debugLogs: debugLogs ?? this.debugLogs,
    );
  }
}
 
class BridgeNotifier extends StateNotifier<BridgeState> {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final Map<String, Terminal> _terminals = {};
  final _uuid = const Uuid();

  void addLog(String message) {
    final timestamp = DateTime.now().toIso8601String().split('T').last.substring(0, 8);
    final line = '[$timestamp] $message';
    debugPrint(line);
    final updated = [...state.debugLogs, line];
    state = state.copyWith(debugLogs: updated);
  }

  BridgeNotifier() : super(BridgeState()) {
    _loadSavedHost();
  }
 
   Terminal getTerminal(String sessionId) {
     if (!_terminals.containsKey(sessionId)) {
       final terminal = Terminal(maxLines: 2000);
       terminal.onOutput = (data) {
         sendPtyInput(sessionId, data);
       };
       _terminals[sessionId] = terminal;
     }
     return _terminals[sessionId]!;
   }
 
   Future<void> _loadSavedHost() async {
     try {
       final prefs = await SharedPreferences.getInstance();
       final hostJson = prefs.getString('saved_host_config');
       if (hostJson != null) {
         final config = HostConfig.fromJson(jsonDecode(hostJson));
         state = state.copyWith(hostConfig: config);
       }
     } catch (e) {
       debugPrint('Error loading host config: $e');
     }
   }
 
  Future<void> connect(HostConfig config) async {
    state = state.copyWith(isConnecting: true, error: null, hostConfig: config);
    addLog('Connecting to ws://' + config.host + ':' + config.port.toString() + '/ws ...');
    _disconnectInternal();

    try {
      final uri = Uri.parse(config.wsUrl);
      addLog('Initiating WebSocket handshake...');
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      addLog('WebSocket channel ready!');

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (err) {
          addLog('Stream Error: ' + err.toString());
          state = state.copyWith(
            isConnected: false,
            isConnecting: false,
            error: 'WebSocket error: $err',
          );
        },
        onDone: () {
          addLog('WebSocket closed.');
          state = state.copyWith(
            isConnected: false,
            isConnecting: false,
          );
        },
      );

      // Send authentication handshake
      addLog('Sending auth payload with token...');
      _sendRaw({
        'type': 'auth',
        'token': config.token,
        'client': 'flutter-mobile',
      });

      // Save successfully used host config
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_host_config', jsonEncode(config.toJson()));
    } catch (e) {
      addLog('Catch Exception: ' + e.toString());
      state = state.copyWith(
        isConnecting: false,
        isConnected: false,
        error: 'Connection failed: $e',
      );
    }
  }
 
   void disconnect() {
     _disconnectInternal();
     state = state.copyWith(isConnected: false, isConnecting: false);
   }
 
   void _disconnectInternal() {
     _subscription?.cancel();
     _subscription = null;
     _channel?.sink.close();
     _channel = null;
   }
 
   void _sendRaw(Map<String, dynamic> msg) {
     if (_channel != null) {
       _channel!.sink.add(jsonEncode(msg));
     }
   }
 
   void _handleMessage(dynamic raw) {
     try {
       final data = jsonDecode(raw as String) as Map<String, dynamic>;
       final type = data['type'] as String?;
 
       switch (type) {
         case 'auth_ok':
           state = state.copyWith(
             isConnected: true,
             isConnecting: false,
             systemInfo: data['systemInfo'] as Map<String, dynamic>?,
           );
           refreshSessions();
           break;
 
         case 'auth_error':
           state = state.copyWith(
             isConnected: false,
             isConnecting: false,
             error: data['message'] as String? ?? 'Authentication rejected',
           );
           disconnect();
           break;
 
         case 'session_ready':
           final sessionId = data['sessionId'] as String;
           final session = AgentSessionInfo(
             id: sessionId,
             agent: AgentTypeExtension.fromString(data['agent'] as String? ?? 'codex'),
             command: data['command'] as String?,
             workdir: data['workdir'] as String? ?? '',
             createdAt: DateTime.now(),
           );
           final updatedSessions = [...state.sessions.where((s) => s.id != sessionId), session];
           state = state.copyWith(
             sessions: updatedSessions,
             activeSessionId: sessionId,
           );
           break;
 
        case 'session_closed':
          final closedId = data['sessionId'] as String;
          // Only remove if explicitly removed or verified
          state = state.copyWith(
            sessions: state.sessions.where((s) => s.id != closedId).toList(),
            activeSessionId: state.activeSessionId == closedId
                ? (state.sessions.isNotEmpty ? state.sessions.first.id : null)
                : state.activeSessionId,
          );
          break;
 
         case 'session_list_result':
           final list = (data['sessions'] as List<dynamic>?)
                   ?.map((s) => AgentSessionInfo.fromJson(s as Map<String, dynamic>))
                   .toList() ??
               [];
           state = state.copyWith(
             sessions: list,
             activeSessionId: state.activeSessionId ?? (list.isNotEmpty ? list.first.id : null),
           );
           break;
 
         case 'chunk':
           final sId = data['sessionId'] as String?;
           if (sId != null) {
             final rawPty = data['rawPty'] as String?;
             if (rawPty != null && rawPty.isNotEmpty) {
               final term = getTerminal(sId);
               term.write(rawPty);
             }
           }
           break;
 
         case 'chat_message':
           final sId = data['sessionId'] as String?;
           final msgJson = data['message'] as Map<String, dynamic>?;
           if (sId != null && msgJson != null) {
             final role = msgJson['role'] as String? ?? 'assistant';
             final isUser = role == 'user';
             final msgId = msgJson['id'] as String? ?? _uuid.v4();
             final content = msgJson['content'] as String? ?? '';
 
             final currentMap = Map<String, List<ChatMessage>>.from(state.sessionMessages);
             final list = List<ChatMessage>.from(currentMap[sId] ?? []);
 
             final existingIndex = list.indexWhere((m) => m.id == msgId);
             if (existingIndex != -1) {
               list[existingIndex] = list[existingIndex].copyWith(content: content);
             } else {
               list.add(ChatMessage(
                 id: msgId,
                 isUser: isUser,
                 content: content,
                 timestamp: DateTime.now(),
               ));
             }
             currentMap[sId] = list;
             state = state.copyWith(sessionMessages: currentMap);
           }
           break;
 
        case 'tool_call':
          final sId = data['sessionId'] as String?;
          final toolJson = data['toolCall'] as Map<String, dynamic>?;
          if (sId != null && toolJson != null) {
            final toolItem = ToolCallItem.fromJson(toolJson);
            _appendMessage(sId, ChatMessage(
              id: toolItem.id,
              isUser: false,
              content: toolItem.input ?? toolItem.name,
              timestamp: DateTime.now(),
              toolCall: toolItem,
            ));
          }
          break;

        case 'run_state':
          final sId = data['sessionId'] as String?;
          final isRunning = data['isRunning'] as bool? ?? false;
          if (sId != null) {
            final runs = Map<String, bool>.from(state.runningSessions);
            runs[sId] = isRunning;
            state = state.copyWith(runningSessions: runs);
          }
          break;

        case 'token_usage':
          final sId = data['sessionId'] as String?;
          if (sId != null) {
            final stats = SessionStats(
              inputTokens: data['inputTokens'] as int? ?? 0,
              outputTokens: data['outputTokens'] as int? ?? 0,
              totalTokens: data['totalTokens'] as int? ?? 0,
            );
            final map = Map<String, SessionStats>.from(state.sessionStats);
            map[sId] = stats;
            state = state.copyWith(sessionStats: map);
          }
          break;
 
         case 'approval_request':
           final sId = data['sessionId'] as String?;
           if (sId != null) {
             _appendMessage(sId, ChatMessage(
               id: _uuid.v4(),
               isUser: false,
               content: data['question'] as String? ?? 'Approve this action?',
               timestamp: DateTime.now(),
               isApproval: true,
               requestId: data['requestId'] as String?,
             ));
           }
           break;
 
         case 'error':
           state = state.copyWith(error: data['message'] as String?);
           break;
       }
     } catch (e) {
       debugPrint('Error handling WebSocket message: $e');
     }
   }
 
   void _appendMessage(String sessionId, ChatMessage msg) {
     final currentMap = Map<String, List<ChatMessage>>.from(state.sessionMessages);
     final list = List<ChatMessage>.from(currentMap[sessionId] ?? []);
     list.add(msg);
     currentMap[sessionId] = list;
     state = state.copyWith(sessionMessages: currentMap);
   }
 
   void selectSession(String sessionId) {
     state = state.copyWith(activeSessionId: sessionId);
   }
 
   void createSession(AgentType agent, {String? customCommand, String? workdir, List<String>? args}) {
     _sendRaw({
       'type': 'session_create',
       'agent': agent.id,
       if (customCommand != null && customCommand.isNotEmpty) 'customCommand': customCommand,
       'workdir': workdir,
       'args': args ?? [],
     });
   }
 
   void closeSession(String sessionId) {
     _sendRaw({
       'type': 'session_close',
       'sessionId': sessionId,
     });
     _terminals.remove(sessionId);
   }
 
   void refreshSessions() {
     _sendRaw({'type': 'session_list'});
   }
 
  void sendPrompt(String sessionId, String text) {
    _appendMessage(sessionId, ChatMessage(
      id: _uuid.v4(),
      isUser: true,
      content: text,
      timestamp: DateTime.now(),
    ));
    _sendRaw({
      'type': 'prompt',
      'sessionId': sessionId,
      'text': text,
    });
  }

  void abortRun(String sessionId) {
    _sendRaw({
      'type': 'abort',
      'sessionId': sessionId,
    });
    final runs = Map<String, bool>.from(state.runningSessions);
    runs[sessionId] = false;
    state = state.copyWith(runningSessions: runs);
  }
 
   void sendPtyInput(String sessionId, String data) {
     _sendRaw({
       'type': 'pty_input',
       'sessionId': sessionId,
       'data': data,
     });
   }
 
   void respondApproval(String sessionId, String requestId, bool approved) {
     final currentMap = Map<String, List<ChatMessage>>.from(state.sessionMessages);
     final list = currentMap[sessionId];
     if (list != null) {
       final updatedList = list.map((m) {
         if (m.requestId == requestId) {
           return m.copyWith(approvalGranted: approved);
         }
         return m;
       }).toList();
       currentMap[sessionId] = updatedList;
       state = state.copyWith(sessionMessages: currentMap);
     }
 
     _sendRaw({
       'type': 'approval_response',
       'sessionId': sessionId,
       'requestId': requestId,
       'approved': approved,
     });
   }
 
   @override
   void dispose() {
     _disconnectInternal();
     super.dispose();
   }
 }
 
 final bridgeProvider = StateNotifierProvider<BridgeNotifier, BridgeState>((ref) {
   return BridgeNotifier();
 });
