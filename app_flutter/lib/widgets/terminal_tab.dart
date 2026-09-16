 import 'package:flutter/material.dart';
 import 'package:flutter_riverpod/flutter_riverpod.dart';
 import 'package:iconsax_flutter/iconsax_flutter.dart';
 import 'package:xterm/xterm.dart';
 import '../providers/bridge_provider.dart';
 
 class TerminalTab extends ConsumerStatefulWidget {
   final String sessionId;
 
   const TerminalTab({super.key, required this.sessionId});
 
   @override
   ConsumerState<TerminalTab> createState() => _TerminalTabState();
 }
 
 class _TerminalTabState extends ConsumerState<TerminalTab> {
   void _sendKey(String key) {
     ref.read(bridgeProvider.notifier).sendPtyInput(widget.sessionId, key);
   }
 
   @override
   Widget build(BuildContext context) {
     final terminal = ref.read(bridgeProvider.notifier).getTerminal(widget.sessionId);
     final colorScheme = Theme.of(context).colorScheme;
 
     return Column(
       children: [
         Expanded(
           child: Container(
             color: const Color(0xFF090A0F),
             child: TerminalView(
               terminal,
               backgroundOpacity: 1.0,
               autofocus: true,
             ),
           ),
         ),
         _buildPtyToolbar(colorScheme),
       ],
     );
   }
 
   Widget _buildPtyToolbar(ColorScheme colorScheme) {
     return Container(
       decoration: BoxDecoration(
         color: const Color(0xFF14151B),
         border: Border(top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
       ),
       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
       child: SingleChildScrollView(
         scrollDirection: Axis.horizontal,
         child: Row(
           children: [
             _quickButton('Ctrl+C', () => _sendKey('\x03'), isAccent: true),
             _quickButton('Esc', () => _sendKey('\x1b')),
             _quickButton('Tab', () => _sendKey('\t')),
             _quickButton('Enter', () => _sendKey('\r')),
             _quickIconButton(Iconsax.arrow_up_2, () => _sendKey('\x1b[A')),
             _quickIconButton(Iconsax.arrow_down_1, () => _sendKey('\x1b[B')),
             _quickIconButton(Iconsax.arrow_left_2, () => _sendKey('\x1b[D')),
             _quickIconButton(Iconsax.arrow_right_3, () => _sendKey('\x1b[C')),
             _quickButton('Ctrl+D', () => _sendKey('\x04')),
             _quickButton('Ctrl+Z', () => _sendKey('\x1a')),
           ],
         ),
       ),
     );
   }
 
   Widget _quickButton(String label, VoidCallback onTap, {bool isAccent = false}) {
     return Padding(
       padding: const EdgeInsets.symmetric(horizontal: 3),
       child: Material(
         color: isAccent ? Colors.red.withOpacity(0.2) : const Color(0xFF222430),
         borderRadius: BorderRadius.circular(8),
         child: InkWell(
           borderRadius: BorderRadius.circular(8),
           onTap: onTap,
           child: Padding(
             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
             child: Text(
               label,
               style: TextStyle(
                 fontSize: 12,
                 fontWeight: FontWeight.w600,
                 fontFamily: 'monospace',
                 color: isAccent ? Colors.redAccent : Colors.white70,
               ),
             ),
           ),
         ),
       ),
     );
   }
 
   Widget _quickIconButton(IconData icon, VoidCallback onTap) {
     return Padding(
       padding: const EdgeInsets.symmetric(horizontal: 3),
       child: Material(
         color: const Color(0xFF222430),
         borderRadius: BorderRadius.circular(8),
         child: InkWell(
           borderRadius: BorderRadius.circular(8),
           onTap: onTap,
           child: Padding(
             padding: const EdgeInsets.all(8),
             child: Icon(icon, size: 16, color: Colors.white70),
           ),
         ),
       ),
     );
   }
 }
