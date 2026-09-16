 import 'package:flutter_test/flutter_test.dart';
 import 'package:iconsax_flutter/iconsax_flutter.dart';
 
 void main() {
   test('Iconsax smoke test', () {
     expect(Iconsax.code, isNotNull);
     expect(Iconsax.scan, isNotNull);
     expect(Iconsax.send_1, isNotNull);
     expect(Iconsax.add_circle, isNotNull);
     expect(Iconsax.logout, isNotNull);
     expect(Iconsax.arrow_up_2, isNotNull);
     expect(Iconsax.tick_circle, isNotNull);
     expect(Iconsax.close_circle, isNotNull);
   });
 }
