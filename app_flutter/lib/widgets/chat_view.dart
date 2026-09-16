 import 'package:flutter/material.dart';
 import 'package:flutter_riverpod/flutter_riverpod.dart';
 import 'package:flutter_markdown/flutter_markdown.dart';
 import 'package:iconsax_flutter/iconsax_flutter.dart';
 import '../models/models.dart';
 import '../providers/bridge_provider.dart';
 
 class ChatView extends ConsumerStatefulWidget {
   final String sessionId;
   final AgentType agentType;
 
   const ChatView({
     super.key,
     required this.sessionId,
     required this.agentType,
   });
 
   @override
   ConsumerState<ChatView> createState() => _ChatViewState();
 }
 
 class _ChatViewState extends ConsumerState<ChatView> {
   final _inputController = TextEditingController();
   final _scrollController = ScrollController();
 
   @override
   void dispose() {
     _inputController.dispose();
     _scrollController.dispose();
     super.dispose();
   }
 
   void _send() {
     final text = _inputController.text.trim();
     if (text.isEmpty) return;
     _inputController.clear();
     ref.read(bridgeProvider.notifier).sendPrompt(widget.sessionId, text);
     Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
   }
 
   void _scrollToBottom() {
     if (_scrollController.hasClients) {
       _scrollController.animateTo(
         _scrollController.position.maxScrollExtent,
         duration: const Duration(milliseconds: 250),
         curve: Curves.easeOut,
       );
     }
   }
 
   @override
   Widget build(BuildContext context) {
     final bridge = ref.watch(bridgeProvider);
     final messages = bridge.sessionMessages[widget.sessionId] ?? [];
     final colorScheme = Theme.of(context).colorScheme;
 
     WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
 
     return Column(
       children: [
         Expanded(
           child: messages.isEmpty
               ? Center(
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Icon(Iconsax.message_programming, size: 48, color: colorScheme.primary.withOpacity(0.6)),
                       const SizedBox(height: 12),
                       Text(
                         'Session connected to ${widget.agentType.displayName}\nSend a prompt or select a command below.',
                         textAlign: TextAlign.center,
                         style: TextStyle(color: colorScheme.onSurfaceVariant, height: 1.4),
                       ),
                     ],
                   ),
                 )
               : ListView.builder(
                   controller: _scrollController,
                   padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                   itemCount: messages.length,
                   itemBuilder: (context, index) {
                     final msg = messages[index];
                     return _buildMessageTile(msg, colorScheme);
                   },
                 ),
         ),
         _buildInputBar(colorScheme),
       ],
     );
   }
 
   Widget _buildToolTile(ToolCallItem tool, ColorScheme colorScheme) {
     return Container(
       margin: const EdgeInsets.symmetric(vertical: 6),
       padding: const EdgeInsets.all(12),
       decoration: BoxDecoration(
         color: const Color(0xFF161F30),
         borderRadius: BorderRadius.circular(12),
         border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.4)),
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Row(
             children: [
               const Icon(Iconsax.code_circle, color: Color(0xFF60A5FA), size: 18),
               const SizedBox(width: 8),
               Text(
                 tool.name,
                 style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF93C5FD)),
               ),
               const Spacer(),
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                 decoration: BoxDecoration(
                   color: tool.status == 'running' ? Colors.blue.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: Text(
                   tool.status,
                   style: TextStyle(
                     fontSize: 11,
                     color: tool.status == 'running' ? Colors.lightBlueAccent : Colors.greenAccent,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
               ),
             ],
           ),
           if (tool.input != null && tool.input!.isNotEmpty) ...[
             const SizedBox(height: 8),
             Container(
               width: double.infinity,
               padding: const EdgeInsets.all(8),
               decoration: BoxDecoration(
                 color: Colors.black45,
                 borderRadius: BorderRadius.circular(8),
               ),
               child: Text(
                 tool.input!,
                 style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white70),
               ),
             ),
           ],
         ],
       ),
     );
   }
 
   Widget _buildMessageTile(ChatMessage msg, ColorScheme colorScheme) {
     if (msg.toolCall != null) {
       return _buildToolTile(msg.toolCall!, colorScheme);
     }
 
     if (msg.isApproval) {
       return Container(
         margin: const EdgeInsets.symmetric(vertical: 8),
         padding: const EdgeInsets.all(16),
         decoration: BoxDecoration(
           color: Colors.amber.withOpacity(0.12),
           borderRadius: BorderRadius.circular(16),
           border: Border.all(color: Colors.amber.withOpacity(0.5)),
         ),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             const Row(
               children: [
                 Icon(Iconsax.warning_2, color: Colors.amber, size: 22),
                 SizedBox(width: 8),
                 Text('Agent Approval Required', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
               ],
             ),
             const SizedBox(height: 10),
             Text(msg.content, style: const TextStyle(fontSize: 14, height: 1.4)),
             const SizedBox(height: 14),
             if (msg.approvalGranted == null)
               Row(
                 mainAxisAlignment: MainAxisAlignment.end,
                 children: [
                   OutlinedButton.icon(
                     style: OutlinedButton.styleFrom(
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                     ),
                     onPressed: () {
                       ref.read(bridgeProvider.notifier).respondApproval(
                             widget.sessionId,
                             msg.requestId ?? '',
                             false,
                           );
                     },
                     icon: const Icon(Iconsax.close_circle, size: 18),
                     label: const Text('Reject (n)'),
                   ),
                   const SizedBox(width: 10),
                   FilledButton.icon(
                     style: FilledButton.styleFrom(
                       backgroundColor: Colors.green.shade600,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                     ),
                     onPressed: () {
                       ref.read(bridgeProvider.notifier).respondApproval(
                             widget.sessionId,
                             msg.requestId ?? '',
                             true,
                           );
                     },
                     icon: const Icon(Iconsax.tick_circle, size: 18),
                     label: const Text('Approve (y)'),
                   ),
                 ],
               )
             else
               Row(
                 children: [
                   Icon(
                     msg.approvalGranted! ? Iconsax.tick_circle : Iconsax.close_circle,
                     color: msg.approvalGranted! ? Colors.green : Colors.red,
                     size: 18,
                   ),
                   const SizedBox(width: 6),
                   Text(
                     msg.approvalGranted! ? 'Approved' : 'Rejected',
                     style: TextStyle(
                       fontWeight: FontWeight.bold,
                       color: msg.approvalGranted! ? Colors.green : Colors.red,
                     ),
                   ),
                 ],
               ),
           ],
         ),
       );
     }
 
     final isUser = msg.isUser;
     return Align(
       alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
       child: Container(
         constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
         margin: const EdgeInsets.symmetric(vertical: 4),
         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
         decoration: BoxDecoration(
           color: isUser ? colorScheme.primary : colorScheme.surfaceContainerHighest.withOpacity(0.5),
           borderRadius: BorderRadius.only(
             topLeft: const Radius.circular(16),
             topRight: const Radius.circular(16),
             bottomLeft: Radius.circular(isUser ? 16 : 4),
             bottomRight: Radius.circular(isUser ? 4 : 16),
           ),
         ),
         child: MarkdownBody(
           data: msg.content,
           styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
             p: TextStyle(
               fontSize: 14,
               color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
               height: 1.4,
             ),
             code: TextStyle(
               backgroundColor: Colors.black.withOpacity(0.25),
               fontFamily: 'monospace',
               fontSize: 12.5,
             ),
             codeblockDecoration: BoxDecoration(
               color: Colors.black.withOpacity(0.3),
               borderRadius: BorderRadius.circular(10),
             ),
           ),
         ),
       ),
     );
   }
 
  Widget _buildInputBar(ColorScheme colorScheme) {
    final suggestions = widget.agentType.supportedCommands;
    final isRunning = ref.watch(bridgeProvider).runningSessions[widget.sessionId] ?? false;
    final stats = ref.watch(bridgeProvider).sessionStats[widget.sessionId];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.4))),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isRunning ? 'Agent is working...' : 'Status: Ready',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isRunning ? Colors.amberAccent : Colors.grey,
                  ),
                ),
                if (stats != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Tokens: ' + stats.formattedTotal,
                      style: const TextStyle(fontSize: 10, color: Colors.lightBlueAccent, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  Text(
                    'Messages: ${ref.watch(bridgeProvider).sessionMessages[widget.sessionId]?.length ?? 0}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (suggestions.isNotEmpty) ...[
               SizedBox(
                 height: 32,
                 child: ListView.builder(
                   scrollDirection: Axis.horizontal,
                   itemCount: suggestions.length,
                   itemBuilder: (context, index) {
                     final item = suggestions[index];
                     return Padding(
                       padding: const EdgeInsets.only(right: 6),
                       child: ActionChip(
                         visualDensity: VisualDensity.compact,
                         padding: const EdgeInsets.symmetric(horizontal: 4),
                         label: Text(
                           item.command,
                           style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                         ),
                         tooltip: item.description,
                         onPressed: () {
                           _inputController.text = '${item.command} ';
                           _inputController.selection = TextSelection.fromPosition(
                             TextPosition(offset: _inputController.text.length),
                           );
                         },
                       ),
                     );
                   },
                 ),
               ),
               const SizedBox(height: 6),
             ],
             Row(
               children: [
                 Expanded(
                   child: Container(
                     decoration: BoxDecoration(
                       color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                       borderRadius: BorderRadius.circular(24),
                     ),
                     child: TextField(
                       controller: _inputController,
                       maxLines: null,
                       textInputAction: TextInputAction.send,
                       onSubmitted: (_) => _send(),
                       decoration: const InputDecoration(
                         hintText: 'Type instructions or command...',
                         border: InputBorder.none,
                         contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                       ),
                     ),
                   ),
                 ),
                const SizedBox(width: 8),
                if (isRunning)
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: Colors.red.shade700),
                    icon: const Icon(Iconsax.stop, size: 20, color: Colors.white),
                    tooltip: 'Stop Generation',
                    onPressed: () {
                      ref.read(bridgeProvider.notifier).abortRun(widget.sessionId);
                    },
                  )
                else
                  IconButton.filled(
                    icon: const Icon(Iconsax.send_1, size: 20),
                    onPressed: _send,
                  ),
               ],
             ),
           ],
         ),
       ),
     );
   }
 }
