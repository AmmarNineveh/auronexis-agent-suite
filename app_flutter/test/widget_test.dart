 import 'package:flutter_test/flutter_test.dart';
 import 'package:flutter_riverpod/flutter_riverpod.dart';
 import 'package:agent_mobile/main.dart';
 
 void main() {
   testWidgets('AgentMobileApp loads pairing screen smoke test', (WidgetTester tester) async {
     await tester.pumpWidget(const ProviderScope(child: AgentMobileApp()));
     expect(find.text('AgentMobile Pairing'), findsOneWidget);
     expect(find.text('Connect to Host Bridge'), findsOneWidget);
   });
 }
