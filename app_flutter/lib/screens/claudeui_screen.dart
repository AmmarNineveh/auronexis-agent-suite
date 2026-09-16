 import 'package:flutter/material.dart';
 import 'package:webview_flutter/webview_flutter.dart';
 import 'package:iconsax_flutter/iconsax_flutter.dart';
 
 class ClaudeUiScreen extends StatefulWidget {
   final String serverUrl;
 
   const ClaudeUiScreen({super.key, required this.serverUrl});
 
   @override
   State<ClaudeUiScreen> createState() => _ClaudeUiScreenState();
 }
 
 class _ClaudeUiScreenState extends State<ClaudeUiScreen> {
   late final WebViewController _controller;
   bool _isLoading = true;
   double _progress = 0.0;
 
   @override
   void initState() {
     super.initState();
     _controller = WebViewController()
       ..setJavaScriptMode(JavaScriptMode.unrestricted)
       ..setBackgroundColor(const Color(0xFF0F172A))
       ..setNavigationDelegate(
         NavigationDelegate(
           onProgress: (int progress) {
             setState(() {
               _progress = progress / 100;
             });
           },
           onPageStarted: (String url) {
             setState(() {
               _isLoading = true;
             });
           },
           onPageFinished: (String url) {
             setState(() {
               _isLoading = false;
             });
           },
           onWebResourceError: (WebResourceError error) {
             debugPrint('Web resource error: ${error.description}');
           },
         ),
       )
       ..loadRequest(Uri.parse(widget.serverUrl));
   }
 
   @override
   Widget build(BuildContext context) {
     return Scaffold(
       backgroundColor: const Color(0xFF0F172A),
       appBar: AppBar(
         backgroundColor: const Color(0xFF0F172A),
         elevation: 0,
         title: Row(
           children: [
             Image.asset(
               'assets/logos/app_logo.png',
               width: 32,
               height: 32,
             ),
             const SizedBox(width: 10),
             const Text(
               'AgentMobile Pro',
               style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
             ),
           ],
         ),
         actions: [
           IconButton(
             icon: const Icon(Iconsax.refresh, size: 20),
             onPressed: () => _controller.reload(),
           ),
         ],
         bottom: _isLoading
             ? PreferredSize(
                 preferredSize: const Size.fromHeight(2),
                 child: LinearProgressIndicator(
                   value: _progress,
                   backgroundColor: Colors.transparent,
                   valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                 ),
               )
             : null,
       ),
       body: SafeArea(
         child: WebViewWidget(controller: _controller),
       ),
     );
   }
 }
