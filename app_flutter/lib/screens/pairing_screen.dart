 import 'dart:convert';
 import 'package:flutter/material.dart';
 import 'package:flutter_riverpod/flutter_riverpod.dart';
 import 'package:mobile_scanner/mobile_scanner.dart';
 import 'package:iconsax_flutter/iconsax_flutter.dart';
 import '../models/models.dart';
 import '../providers/bridge_provider.dart';
 import 'claudeui_screen.dart';
 
 class PairingScreen extends ConsumerStatefulWidget {
   const PairingScreen({super.key});
 
   @override
   ConsumerState<PairingScreen> createState() => _PairingScreenState();
 }
 
 class _PairingScreenState extends ConsumerState<PairingScreen> {
   final _hostController = TextEditingController(text: '192.168.1.90');
   final _portController = TextEditingController(text: '8088');
   bool _showScanner = false;
 
   @override
   void dispose() {
     _hostController.dispose();
     _portController.dispose();
     super.dispose();
   }
 
   void _launchUi() {
     final host = _hostController.text.trim();
     final port = int.tryParse(_portController.text.trim()) ?? 8088;
 
     if (host.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Please enter Host IP')),
       );
       return;
     }
 
     final url = 'http://' + host + ':' + port.toString();
     Navigator.of(context).pushReplacement(
       MaterialPageRoute(builder: (_) => ClaudeUiScreen(serverUrl: url)),
     );
   }
 
   void _handleBarcode(BarcodeCapture capture) {
     for (final barcode in capture.barcodes) {
       final rawValue = barcode.rawValue;
       if (rawValue != null) {
         try {
           final json = jsonDecode(rawValue);
           if (json['host'] != null) {
             setState(() {
               _hostController.text = json['host'];
               _portController.text = (json['port'] ?? 8088).toString();
               _showScanner = false;
             });
             _launchUi();
             break;
           }
         } catch (e) {}
       }
     }
   }
 
   @override
   Widget build(BuildContext context) {
     final colorScheme = Theme.of(context).colorScheme;
 
     return Scaffold(
      appBar: AppBar(
        title: const Text('AURONEXIS Agents', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
         actions: [
           IconButton(
             icon: Icon(_showScanner ? Iconsax.keyboard : Iconsax.scan_barcode),
             tooltip: _showScanner ? 'Manual Entry' : 'Scan QR',
             onPressed: () {
               setState(() {
                 _showScanner = !_showScanner;
               });
             },
           ),
         ],
       ),
       body: _showScanner
           ? Stack(
               children: [
                 MobileScanner(onDetect: _handleBarcode),
                 Positioned(
                   bottom: 36,
                   left: 24,
                   right: 24,
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                     decoration: BoxDecoration(
                       color: colorScheme.surface.withOpacity(0.92),
                       borderRadius: BorderRadius.circular(16),
                       border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
                     ),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         Icon(Iconsax.scan, color: colorScheme.primary, size: 22),
                         const SizedBox(width: 12),
                         const Flexible(
                           child: Text(
                             'Scan the QR code shown on your computer screen',
                             textAlign: TextAlign.center,
                             style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                           ),
                         ),
                       ],
                     ),
                   ),
                 )
               ],
             )
           : Center(
               child: SingleChildScrollView(
                 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                 child: ConstrainedBox(
                   constraints: const BoxConstraints(maxWidth: 480),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.stretch,
                     children: [
                       Center(
                         child: Image.asset(
                           'assets/logos/app_logo.png',
                           width: 130,
                           height: 75,
                           fit: BoxFit.contain,
                         ),
                       ),
                       const SizedBox(height: 24),
                       const Text(
                         'Connect to Agent Engine',
                         textAlign: TextAlign.center,
                         style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                       ),
                       const SizedBox(height: 8),
                       Text(
                         'Full ClaudeUI & Codex Agent Suite in your pocket.',
                         textAlign: TextAlign.center,
                         style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14, height: 1.4),
                       ),
                       const SizedBox(height: 32),
                       Card(
                         child: Padding(
                           padding: const EdgeInsets.all(20),
                           child: Column(
                             children: [
                               TextField(
                                 controller: _hostController,
                                 decoration: InputDecoration(
                                   labelText: 'Host IP / Domain',
                                   prefixIcon: const Icon(Iconsax.global),
                                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                   hintText: '192.168.1.90',
                                 ),
                               ),
                               const SizedBox(height: 16),
                               TextField(
                                 controller: _portController,
                                 keyboardType: TextInputType.number,
                                 decoration: InputDecoration(
                                   labelText: 'Port',
                                   prefixIcon: const Icon(Iconsax.routing),
                                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                 ),
                               ),
                             ],
                           ),
                         ),
                       ),
                       const SizedBox(height: 24),
                       FilledButton.icon(
                         onPressed: _launchUi,
                         icon: const Icon(Iconsax.link_2),
                         label: const Text(
                           'Launch Full Agent Suite',
                           style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                         ),
                         style: FilledButton.styleFrom(
                           padding: const EdgeInsets.symmetric(vertical: 16),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                         ),
                       ),
                       const SizedBox(height: 12),
                       OutlinedButton.icon(
                         onPressed: () {
                           setState(() {
                             _showScanner = true;
                           });
                         },
                         icon: const Icon(Iconsax.scan_barcode),
                         label: const Text('Scan QR Code from Screen'),
                         style: OutlinedButton.styleFrom(
                           padding: const EdgeInsets.symmetric(vertical: 16),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                         ),
                       ),
                     ],
                   ),
                 ),
               ),
             ),
     );
   }
 }
