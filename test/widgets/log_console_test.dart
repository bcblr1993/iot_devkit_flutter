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

  testWidgets('LogConsole collapsed empty state shows ready only once',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 80,
            child: LogConsole(
              logs: const [],
              isExpanded: false,
              onToggle: () {},
              onClear: () {},
              onMaximize: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('LogConsole collapsed stats keep room before warning badges',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 120);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final logs = <LogEntry>[
      ...List.generate(48, (i) => LogEntry('warning $i', 'warning', '10:00')),
      ...List.generate(48, (i) => LogEntry('error $i', 'error', '10:01')),
      ...List.generate(5, (i) => LogEntry('info $i', 'info', '10:02')),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1024,
            height: 80,
            child: LogConsole(
              logs: logs,
              isExpanded: false,
              onToggle: () {},
              onClear: () {},
              onMaximize: () {},
              headerContent: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('设备总数 12'),
                  SizedBox(width: 20),
                  Text('在线数 0'),
                  SizedBox(width: 20),
                  Text('已发送 0'),
                  SizedBox(width: 20),
                  Text('成功数 0'),
                  SizedBox(width: 20),
                  Text('失败数 0'),
                  SizedBox(width: 20),
                  Text('CPU 0.0%'),
                  SizedBox(width: 20),
                  Text('内存 0 MB'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final memoryRect = tester.getRect(find.text('内存 0 MB'));
    final warningRect = tester.getRect(find.text('W 48'));

    expect(memoryRect.right, lessThan(warningRect.left));
    expect(tester.takeException(), isNull);
  });
}
