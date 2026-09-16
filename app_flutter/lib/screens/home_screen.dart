 import 'package:flutter/material.dart';
 import 'package:flutter_riverpod/flutter_riverpod.dart';
 import 'package:flutter_svg/flutter_svg.dart';
 import 'package:iconsax_flutter/iconsax_flutter.dart';
 import '../models/models.dart';
 import '../providers/bridge_provider.dart';
 import '../widgets/chat_view.dart';
 import '../widgets/terminal_tab.dart';
 import 'pairing_screen.dart';
import '../widgets/workspace_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
   const HomeScreen({super.key});
 
   @override
   ConsumerState<HomeScreen> createState() => _HomeScreenState();
 }
 
 class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
   late TabController _tabController;
 
   @override
   void initState() {
     super.initState();
     _tabController = TabController(length: 2, vsync: this);
   }
 
   @override
   void dispose() {
     _tabController.dispose();
     super.dispose();
   }
 
   void _showCreateSessionDialog() {
     AgentType selectedAgent = AgentType.codex;
     final workdirController = TextEditingController();
     final customCmdController = TextEditingController();
 
     final system = ref.read(bridgeProvider).systemInfo;
     if (system != null && system['defaultDir'] != null) {
       workdirController.text = system['defaultDir'] as String;
     }
 
     showDialog(
       context: context,
       builder: (ctx) => StatefulBuilder(
         builder: (context, setModalState) => AlertDialog(
           title: const Row(
             children: [
               Icon(Iconsax.add_circle, size: 24),
               SizedBox(width: 10),
               Text('New Agent Session', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
             ],
           ),
           content: SingleChildScrollView(
             child: Column(
               mainAxisSize: MainAxisSize.min,
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 const Text('Choose Agent / CLI:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                 const SizedBox(height: 10),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                   decoration: BoxDecoration(
                     border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                     borderRadius: BorderRadius.circular(12),
                   ),
                   child: DropdownButtonHideUnderline(
                     child: DropdownButton<AgentType>(
                       value: selectedAgent,
                       isExpanded: true,
                       items: AgentType.values.map((agent) {
                         return DropdownMenuItem(
                           value: agent,
                           child: Row(
                             children: [
                               SvgPicture.asset(
                                 agent.logoAsset,
                                 width: 22,
                                 height: 22,
                               ),
                               const SizedBox(width: 12),
                               Text(agent.displayName, style: const TextStyle(fontWeight: FontWeight.w500)),
                             ],
                           ),
                         );
                       }).toList(),
                       onChanged: (val) {
                         if (val != null) {
                           setModalState(() {
                             selectedAgent = val;
                           });
                         }
                       },
                     ),
                   ),
                 ),
                 if (selectedAgent == AgentType.custom) ...[
                   const SizedBox(height: 14),
                   const Text('Custom Command:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                   const SizedBox(height: 6),
                   TextField(
                     controller: customCmdController,
                     decoration: InputDecoration(
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                       hintText: 'e.g. hermes, ollama run llama3, aichat',
                       isDense: true,
                       prefixIcon: const Icon(Iconsax.code_1, size: 20),
                     ),
                   ),
                 ],
                 const SizedBox(height: 16),
                 const Text('Workspace Directory:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                 const SizedBox(height: 6),
                 TextField(
                   controller: workdirController,
                   decoration: InputDecoration(
                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                     hintText: 'e.g. C:/Users/.../MyProject',
                     isDense: true,
                     prefixIcon: const Icon(Iconsax.folder, size: 20),
                   ),
                 ),
               ],
             ),
           ),
           actions: [
             TextButton(
               onPressed: () => Navigator.of(ctx).pop(),
               child: const Text('Cancel'),
             ),
             FilledButton.icon(
               icon: const Icon(Iconsax.play, size: 18),
               onPressed: () {
                 final customCmd = selectedAgent == AgentType.custom ? customCmdController.text.trim() : null;
                 ref.read(bridgeProvider.notifier).createSession(
                       selectedAgent,
                       customCommand: customCmd,
                       workdir: workdirController.text.trim().isEmpty ? null : workdirController.text.trim(),
                     );
                 Navigator.of(ctx).pop();
               },
               label: const Text('Launch Agent'),
             ),
           ],
         ),
       ),
     );
   }
 
   @override
   Widget build(BuildContext context) {
     final state = ref.watch(bridgeProvider);
     final sessions = state.sessions;
     final activeSession = sessions.where((s) => s.id == state.activeSessionId).firstOrNull;
     final theme = Theme.of(context);
     final colorScheme = theme.colorScheme;
 
     return Scaffold(
       appBar: AppBar(
         leading: Builder(
           builder: (context) => IconButton(
             icon: const Icon(Iconsax.menu_1),
             tooltip: 'Sessions Menu',
             onPressed: () => Scaffold.of(context).openDrawer(),
           ),
         ),
         title: activeSession != null
             ? Row(
                 children: [
                   SvgPicture.asset(
                     activeSession.agent.logoAsset,
                     width: 24,
                     height: 24,
                   ),
                   const SizedBox(width: 10),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           activeSession.agent.displayName,
                           style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                         ),
                         Text(
                           activeSession.workdir,
                           style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                           overflow: TextOverflow.ellipsis,
                         ),
                       ],
                     ),
                   ),
                 ],
               )
             : const Text('AgentMobile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
         bottom: TabBar(
           controller: _tabController,
           indicatorSize: TabBarIndicatorSize.tab,
           dividerColor: Colors.transparent,
           tabs: const [
             Tab(icon: Icon(Iconsax.messages_2), text: 'Smart Chat'),
             Tab(icon: Icon(Iconsax.code), text: 'Live PTY'),
           ],
         ),
        actions: [
          if (activeSession != null)
            IconButton(
              icon: const Icon(Iconsax.folder_open),
              tooltip: 'Project Files & Git',
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => WorkspaceSheet(workdir: activeSession.workdir),
                );
              },
            ),
          IconButton(
            icon: const Icon(Iconsax.add_circle),
            tooltip: 'New Agent Session',
             onPressed: _showCreateSessionDialog,
           ),
           IconButton(
             icon: const Icon(Iconsax.logout_1),
             tooltip: 'Disconnect',
             onPressed: () {
               ref.read(bridgeProvider.notifier).disconnect();
               Navigator.of(context).pushReplacement(
                 MaterialPageRoute(builder: (_) => const PairingScreen()),
               );
             },
           ),
         ],
       ),
       drawer: Drawer(
         child: Column(
           children: [
             DrawerHeader(
               decoration: BoxDecoration(
                 color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
               ),
               child: Row(
                 crossAxisAlignment: CrossAxisAlignment.center,
                 children: [
                   Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(
                       color: colorScheme.primaryContainer,
                       borderRadius: BorderRadius.circular(14),
                     ),
                     child: Icon(Iconsax.cpu, color: colorScheme.onPrimaryContainer, size: 28),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Text(
                           'Agent Sessions',
                           style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                         ),
                         const SizedBox(height: 4),
                         Text(
                           state.hostConfig != null
                               ? '${state.hostConfig!.host}:${state.hostConfig!.port}'
                               : 'Connected',
                           style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                           overflow: TextOverflow.ellipsis,
                         ),
                       ],
                     ),
                   ),
                 ],
               ),
             ),
             Expanded(
               child: sessions.isEmpty
                   ? Center(
                       child: Padding(
                         padding: const EdgeInsets.all(24),
                         child: Column(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             Icon(Iconsax.box, size: 48, color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
                             const SizedBox(height: 12),
                             Text(
                               'No active sessions',
                               style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                             ),
                           ],
                         ),
                       ),
                     )
                   : ListView.builder(
                       padding: const EdgeInsets.symmetric(horizontal: 8),
                       itemCount: sessions.length,
                       itemBuilder: (context, index) {
                         final sess = sessions[index];
                         final isSelected = sess.id == state.activeSessionId;
                         return Container(
                           margin: const EdgeInsets.symmetric(vertical: 4),
                           decoration: BoxDecoration(
                             color: isSelected ? colorScheme.primaryContainer.withOpacity(0.35) : Colors.transparent,
                             borderRadius: BorderRadius.circular(12),
                             border: Border.all(
                               color: isSelected ? colorScheme.primary.withOpacity(0.5) : Colors.transparent,
                             ),
                           ),
                           child: ListTile(
                             leading: SvgPicture.asset(
                               sess.agent.logoAsset,
                               width: 26,
                               height: 26,
                             ),
                             title: Text(sess.agent.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                             subtitle: Text(sess.id, style: const TextStyle(fontSize: 11)),
                             trailing: IconButton(
                               icon: const Icon(Iconsax.close_circle, size: 20),
                               onPressed: () {
                                 ref.read(bridgeProvider.notifier).closeSession(sess.id);
                               },
                             ),
                             onTap: () {
                               ref.read(bridgeProvider.notifier).selectSession(sess.id);
                               Navigator.of(context).pop();
                             },
                           ),
                         );
                       },
                     ),
             ),
             const Divider(height: 1),
             Padding(
               padding: const EdgeInsets.all(16),
               child: FilledButton.tonalIcon(
                 style: FilledButton.styleFrom(
                   minimumSize: const Size.fromHeight(48),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                 ),
                 icon: const Icon(Iconsax.add, size: 20),
                 label: const Text('Start New Session'),
                 onPressed: () {
                   Navigator.of(context).pop();
                   _showCreateSessionDialog();
                 },
               ),
             ),
           ],
         ),
       ),
       body: activeSession == null
           ? Center(
               child: Padding(
                 padding: const EdgeInsets.all(32),
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Container(
                       padding: const EdgeInsets.all(24),
                       decoration: BoxDecoration(
                       color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                         shape: BoxShape.circle,
                       ),
                       child: Icon(Iconsax.command, size: 56, color: colorScheme.primary),
                     ),
                     const SizedBox(height: 24),
                     const Text(
                       'No active CLI session',
                       style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                     ),
                     const SizedBox(height: 8),
                     Text(
                       'Launch a session to start interacting with Codex, Claude, OpenCode or Hermes.',
                       textAlign: TextAlign.center,
                       style: TextStyle(color: colorScheme.onSurfaceVariant),
                     ),
                     const SizedBox(height: 24),
                     FilledButton.icon(
                       onPressed: _showCreateSessionDialog,
                       icon: const Icon(Iconsax.play, size: 20),
                       label: const Text('Start Session'),
                       style: FilledButton.styleFrom(
                         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                       ),
                     ),
                   ],
                 ),
               ),
             )
            : TabBarView(
                controller: _tabController,
                children: [
                  ChatView(sessionId: activeSession.id, agentType: activeSession.agent),
                  TerminalTab(sessionId: activeSession.id),
                ],
              ),
     );
   }
 }
