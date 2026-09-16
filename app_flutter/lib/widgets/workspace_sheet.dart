 import 'dart:convert';
 import 'package:flutter/material.dart';
 import 'package:flutter_riverpod/flutter_riverpod.dart';
 import 'package:iconsax_flutter/iconsax_flutter.dart';
 import 'package:http/http.dart' as http;
 import '../models/models.dart';
 import '../providers/bridge_provider.dart';
 
 class WorkspaceSheet extends ConsumerStatefulWidget {
   final String workdir;
 
   const WorkspaceSheet({super.key, required this.workdir});
 
   @override
   ConsumerState<WorkspaceSheet> createState() => _WorkspaceSheetState();
 }
 
 class _WorkspaceSheetState extends ConsumerState<WorkspaceSheet> with SingleTickerProviderStateMixin {
   late TabController _tabController;
   List<WorkspaceFileItem> _files = [];
   GitStatusData? _gitStatus;
   bool _isLoading = true;
   String? _diffContent;
 
   @override
   void initState() {
     super.initState();
     _tabController = TabController(length: 2, vsync: this);
     _loadWorkspaceData();
   }
 
   Future<void> _loadWorkspaceData() async {
     final hostConfig = ref.read(bridgeProvider).hostConfig;
     if (hostConfig == null) return;
 
     setState(() => _isLoading = true);
     try {
       final baseUrl = hostConfig.httpUrl;
       final treeRes = await http.get(Uri.parse(baseUrl + '/api/files/tree?dir=' + Uri.encodeComponent(widget.workdir) + '&depth=2'));
       if (treeRes.statusCode == 200) {
         final json = jsonDecode(treeRes.body);
         _files = (json['tree'] as List<dynamic>?)
                 ?.map((i) => WorkspaceFileItem.fromJson(i as Map<String, dynamic>))
                 .toList() ??
             [];
       }
 
       final gitRes = await http.get(Uri.parse(baseUrl + '/api/git/status?dir=' + Uri.encodeComponent(widget.workdir)));
       if (gitRes.statusCode == 200) {
         _gitStatus = GitStatusData.fromJson(jsonDecode(gitRes.body));
       }
 
       final diffRes = await http.get(Uri.parse(baseUrl + '/api/git/diff?dir=' + Uri.encodeComponent(widget.workdir)));
       if (diffRes.statusCode == 200) {
         final json = jsonDecode(diffRes.body);
         _diffContent = json['diff'] as String?;
       }
     } catch (e) {
       debugPrint('Error loading workspace data: ' + e.toString());
     } finally {
       if (mounted) setState(() => _isLoading = false);
     }
   }
 
   void _showFileContent(WorkspaceFileItem item) async {
     final hostConfig = ref.read(bridgeProvider).hostConfig;
     if (hostConfig == null) return;
 
     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
         title: Row(
           children: [
             const Icon(Iconsax.document_text, size: 20),
             const SizedBox(width: 8),
             Expanded(child: Text(item.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16))),
           ],
         ),
         content: FutureBuilder<http.Response>(
           future: http.get(Uri.parse(hostConfig.httpUrl + '/api/files/content?path=' + Uri.encodeComponent(item.path))),
           builder: (context, snapshot) {
             if (snapshot.connectionState == ConnectionState.waiting) {
               return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
             }
             if (snapshot.hasError || snapshot.data?.statusCode != 200) {
               return const Text('Failed to load file content');
             }
             final content = jsonDecode(snapshot.data!.body)['content'] as String? ?? '';
             return Container(
               width: double.maxFinite,
               height: 350,
               padding: const EdgeInsets.all(8),
               decoration: BoxDecoration(
                 color: Colors.black45,
                 borderRadius: BorderRadius.circular(8),
               ),
               child: SingleChildScrollView(
                 child: SelectableText(
                   content,
                   style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
                 ),
               ),
             );
           },
         ),
         actions: [
           TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
         ],
       ),
     );
   }
 
   @override
   Widget build(BuildContext context) {
     final colorScheme = Theme.of(context).colorScheme;
 
     return Container(
       height: MediaQuery.of(context).size.height * 0.75,
       decoration: BoxDecoration(
         color: colorScheme.surface,
         borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
       ),
       child: Column(
         children: [
           Container(
             margin: const EdgeInsets.symmetric(vertical: 8),
             width: 40,
             height: 4,
             decoration: BoxDecoration(
               color: colorScheme.outlineVariant,
               borderRadius: BorderRadius.circular(2),
             ),
           ),
           TabBar(
             controller: _tabController,
             tabs: [
               Tab(icon: const Icon(Iconsax.folder_2, size: 20), text: 'Files (' + _files.length.toString() + ')'),
               Tab(
                 icon: const Icon(Iconsax.code_1, size: 20),
                 text: _gitStatus?.isGit == true ? 'Git (' + (_gitStatus?.branch ?? '') + ')' : 'Git',
               ),
             ],
           ),
           Expanded(
             child: _isLoading
                 ? const Center(child: CircularProgressIndicator())
                 : TabBarView(
                     controller: _tabController,
                     children: [
                       _buildFileTree(colorScheme),
                       _buildGitTab(colorScheme),
                     ],
                   ),
           ),
         ],
       ),
     );
   }
 
   Widget _buildFileTree(ColorScheme colorScheme) {
     if (_files.isEmpty) {
       return const Center(child: Text('No files found in workspace'));
     }
     return ListView.builder(
       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
       itemCount: _files.length,
       itemBuilder: (context, index) {
         final item = _files[index];
         return _buildFileNodeTile(item, colorScheme);
       },
     );
   }
 
   Widget _buildFileNodeTile(WorkspaceFileItem item, ColorScheme colorScheme) {
     if (item.isDirectory) {
       return ExpansionTile(
         leading: const Icon(Iconsax.folder, color: Colors.amber, size: 20),
         title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
         childrenPadding: const EdgeInsets.only(left: 16),
         children: (item.children ?? []).map((c) => _buildFileNodeTile(c, colorScheme)).toList(),
       );
     }
     return ListTile(
       dense: true,
       leading: const Icon(Iconsax.document, size: 18, color: Colors.blueAccent),
       title: Text(item.name, style: const TextStyle(fontSize: 13)),
       trailing: item.size != null
           ? Text((item.size! / 1024).toStringAsFixed(1) + ' KB', style: const TextStyle(fontSize: 10, color: Colors.grey))
           : null,
       onTap: () => _showFileContent(item),
     );
   }
 
   Widget _buildGitTab(ColorScheme colorScheme) {
     if (_gitStatus == null || !_gitStatus!.isGit) {
       return const Center(child: Text('Not a git repository'));
     }
 
     final hasChanges = _gitStatus!.modified.isNotEmpty || _gitStatus!.untracked.isNotEmpty || _gitStatus!.staged.isNotEmpty;
 
     return SingleChildScrollView(
       padding: const EdgeInsets.all(16),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
          Row(
            children: [
              const Icon(Iconsax.code_1, size: 20, color: Colors.orangeAccent),
              const SizedBox(width: 8),
               Text('Branch: ' + (_gitStatus!.branch ?? 'HEAD'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
               const Spacer(),
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                 decoration: BoxDecoration(
                   color: hasChanges ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: Text(
                   hasChanges ? 'Dirty Worktree' : 'Clean',
                   style: TextStyle(
                     color: hasChanges ? Colors.orangeAccent : Colors.greenAccent,
                     fontWeight: FontWeight.bold,
                     fontSize: 11,
                   ),
                 ),
               ),
             ],
           ),
           const SizedBox(height: 16),
           if (_gitStatus!.modified.isNotEmpty) ...[
             const Text('Modified Files:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber)),
             const SizedBox(height: 6),
             ..._gitStatus!.modified.map((f) => Text(' • ' + f, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
             const SizedBox(height: 12),
           ],
           if (_gitStatus!.untracked.isNotEmpty) ...[
             const Text('Untracked Files:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.redAccent)),
             const SizedBox(height: 6),
             ..._gitStatus!.untracked.map((f) => Text(' • ' + f, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
             const SizedBox(height: 12),
           ],
           if (_diffContent != null && _diffContent!.isNotEmpty) ...[
             const Text('Git Diff Preview:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
             const SizedBox(height: 6),
             Container(
               width: double.infinity,
               padding: const EdgeInsets.all(10),
               decoration: BoxDecoration(
                 color: Colors.black45,
                 borderRadius: BorderRadius.circular(10),
               ),
               child: SelectableText(
                 _diffContent!,
                 style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white70),
               ),
             ),
           ],
         ],
       ),
     );
   }
 }
