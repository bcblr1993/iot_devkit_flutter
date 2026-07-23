import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_devkit/l10n/generated/app_localizations.dart';
import 'package:iot_devkit/ui/widgets/json_tree_view.dart';

void main() {
  testWidgets('large collapsed branches do not eagerly build their children',
      (tester) async {
    final data = {
      'values': [
        for (var index = 0; index < 10000; index++)
          {'ts': index, 'value': '$index'},
      ],
    };

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: JsonTreeView(data: data, isRoot: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(JsonTreeView), findsNWidgets(2));

    await tester.tap(find.byType(ExpansionTile).last);
    await tester.pumpAndSettle();

    expect(find.byType(JsonTreeView), findsNWidgets(102));
    expect(find.text('Load more (100/10000)'), findsOneWidget);
  });
}
