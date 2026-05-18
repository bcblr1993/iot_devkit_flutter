import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/ui/lab/lab.dart';
import 'package:iot_devkit/ui/lab/lab_gallery.dart';

void main() {
  testWidgets('LabGallery renders every Lab atom across all 8 themes',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LabGallery()));
    await tester.pump();

    expect(find.byType(LabGallery), findsOneWidget);
    expect(find.text('LAB GALLERY'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Cycle through every theme — each must render the full component
    // set without throwing (paint / layout / token resolution).
    for (final t in LabThemes.all) {
      final btn = find.byWidgetPredicate(
        (w) => w is LabButton && w.label == t.name,
      );
      expect(btn, findsWidgets, reason: 'theme switch button for ${t.name}');
      tester.widget<LabButton>(btn.first).onPressed!();
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'theme ${t.name}');
    }
  });
}
