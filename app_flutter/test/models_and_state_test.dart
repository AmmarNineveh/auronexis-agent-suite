 import 'package:flutter_test/flutter_test.dart';
 import 'package:agent_mobile/models/models.dart';
 
 void main() {
   group('Models & Protocols Test', () {
     test('HostConfig generates correct URLs and serializes properly', () {
       final config = HostConfig(host: '192.168.1.50', port: 4242, token: 'abc-123');
       expect(config.wsUrl, equals('ws://192.168.1.50:4242/ws'));
       expect(config.httpUrl, equals('http://192.168.1.50:4242'));
 
       final json = config.toJson();
       final restored = HostConfig.fromJson(json);
       expect(restored.host, equals('192.168.1.50'));
       expect(restored.port, equals(4242));
       expect(restored.token, equals('abc-123'));
     });
 
     test('AgentType mapping and displayName verification', () {
       expect(AgentType.codex.id, equals('codex'));
       expect(AgentType.codex.displayName, equals('Codex CLI'));
      expect(AgentTypeExtension.fromString('claude'), equals(AgentType.claude));
      expect(AgentTypeExtension.fromString('opencode'), equals(AgentType.opencode));
      expect(AgentTypeExtension.fromString('hermes'), equals(AgentType.hermes));
      expect(AgentTypeExtension.fromString('custom'), equals(AgentType.custom));
      expect(AgentTypeExtension.fromString('unknown'), equals(AgentType.codex));
    });
 
     test('ChatMessage creation and copyWith approval state', () {
       final msg = ChatMessage(
         id: 'msg_1',
         isUser: false,
         content: 'Do you approve file delete?',
         timestamp: DateTime.now(),
         isApproval: true,
         requestId: 'req_99',
       );
 
       expect(msg.isApproval, isTrue);
       expect(msg.approvalGranted, isNull);
 
       final approved = msg.copyWith(approvalGranted: true);
       expect(approved.approvalGranted, isTrue);
       expect(approved.requestId, equals('req_99'));
     });
   });
 }
