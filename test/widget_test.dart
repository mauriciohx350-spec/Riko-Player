import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riko_player/app/app.dart';

void main() {
  testWidgets('Displays the temporary Riko Player screen', (tester) async {
    await tester.pumpWidget(const RikoPlayerApp());

    expect(find.text('Riko Player'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Riko Player'),
        matching: find.byType(Center),
      ),
      findsOneWidget,
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Riko Player');
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(app.themeMode, ThemeMode.dark);

    final textFinder = find.text('Riko Player');
    final theme = Theme.of(tester.element(textFinder));
    expect(theme.brightness, Brightness.dark);
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, const Color(0xFF9B8AFB));
    expect(theme.scaffoldBackgroundColor, const Color(0xFF101116));
    expect(theme.colorScheme.surface, const Color(0xFF1C1D25));
    expect(theme.colorScheme.onSurface, const Color(0xFFF5F5F7));
    expect(theme.colorScheme.onSurfaceVariant, const Color(0xFFA3A3AD));
    expect(
      DefaultTextStyle.of(tester.element(textFinder)).style.color,
      const Color(0xFFF5F5F7),
    );
  });
}
