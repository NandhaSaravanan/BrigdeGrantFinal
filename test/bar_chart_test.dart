import 'package:bridgegrant/src/bar_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const labels = [
    'Rock Hill',
    'Fort Mill',
    'Clover',
    'York',
    'Lake Wylie',
    'Tega Cay',
    'Mcconnells',
  ];

  Future<void> pumpChart(
    WidgetTester tester, {
    required int selected,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(375, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(375, 500),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: VerticalBarChart(
                labels: labels,
                values: const [24.2, 7.3, 1.3, 0.9, 0.8, 0.1, 0.03],
                valueLabels: const [
                  r'$24.2M',
                  r'$7.3M',
                  r'$1.3M',
                  r'$900K',
                  r'$800K',
                  r'$72K',
                  r'$30K',
                ],
                selected: selected,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final scale in [1.0, 1.6]) {
    for (final selected in [0, 3, 6]) {
      testWidgets('value tip stays inside the chart '
          '(text x$scale, bar $selected)', (tester) async {
        await pumpChart(tester, selected: selected, textScale: scale);
        expect(tester.takeException(), isNull);

        final chart = tester.getRect(find.byType(VerticalBarChart));
        final tipText = find.text(
          [r'$24.2M', r'$900K', r'$30K'][[0, 3, 6].indexOf(selected)],
        );
        expect(tipText, findsOneWidget);
        final tip = tester.getRect(
          find.ancestor(of: tipText, matching: find.byType(Container)).first,
        );
        expect(tip.left, greaterThanOrEqualTo(chart.left));
        expect(tip.right, lessThanOrEqualTo(chart.right));
        expect(tip.top, greaterThanOrEqualTo(chart.top));
      });
    }
  }

  testWidgets('multi-word labels split between words', (tester) async {
    await pumpChart(tester, selected: 0);
    expect(find.text('Rock\nHill'), findsOneWidget);
    expect(find.text('Lake\nWylie'), findsOneWidget);
    expect(find.text('Mcconnells'), findsOneWidget);
  });
}
