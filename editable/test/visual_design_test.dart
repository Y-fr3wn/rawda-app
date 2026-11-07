import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rawda/main.dart';

void main() {
  testWidgets('Digital tasbih bead ring paints at all progress levels',
      (tester) async {
    for (final progress in [0.0, .33, 1.0]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: CustomPaint(
              painter: RawdaBeadPainter(
                  progress: progress, isDark: false),
              child: const SizedBox(width: 290, height: 292),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Qibla compass paints from a real sensor heading',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: RawdaCompassFace(
            bearing: 136.0, heading: 28.0, dark: false),
      ),
    ));
    expect(tester.takeException(), isNull);
  });

  test('Tasbih painter repaints only when progress or mode changes', () {
    const painter = RawdaBeadPainter(
        progress: 0.0, isDark: false);
    expect(painter.shouldRepaint(const RawdaBeadPainter(
        progress: 0.0, isDark: false)), isFalse);
    expect(painter.shouldRepaint(const RawdaBeadPainter(
        progress: .3, isDark: false)), isTrue);
  });
}
