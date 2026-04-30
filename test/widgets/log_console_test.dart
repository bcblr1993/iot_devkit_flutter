import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/ui/widgets/log_console.dart';

void main() {
  testWidgets('LogConsole toolbar does not overflow on compact widths',
      (tester) async {
    tester.view.physicalSize = const Size(360, 240);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 240,
            child: LogConsole(
              logs: [
                LogEntry('message 1', 'info', '10:00:00'),
                LogEntry('message 2', 'error', '10:00:01'),
              ],
              isExpanded: true,
              onToggle: () {},
              onClear: () {},
              onMaximize: () {},
              headerContent: const Row(
                children: [
                  Text('Devices: 100000'),
                  SizedBox(width: 16),
                  Text('Success: 99999'),
                  SizedBox(width: 16),
                  Text('Failed: 1'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LogConsole), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
