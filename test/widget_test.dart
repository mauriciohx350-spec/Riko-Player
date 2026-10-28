import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riko_player/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('device_audio_query'), (
          call,
        ) async {
          switch (call.method) {
            case 'checkPermissionStatus':
            case 'requestPermission':
              return 0;
            case 'querySongs':
              return <Map<String, Object?>>[];
            default:
              throw PlatformException(
                code: 'unexpected_call',
                message: call.method,
              );
          }
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('device_audio_query'),
          null,
        );
  });
  testWidgets('Shows the empty library with the global dark theme', (
    tester,
  ) async {
    await tester.pumpWidget(const RikoPlayerApp());
    await tester.pumpAndSettle();

    expect(find.text('Riko Player'), findsOneWidget);
    expect(find.text('Suas músicas'), findsOneWidget);
    expect(find.text('Nenhuma música encontrada'), findsOneWidget);
    expect(find.byTooltip('Configurações'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(2));
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Riko Player');
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(app.themeMode, ThemeMode.dark);

    final theme = Theme.of(tester.element(find.text('Suas músicas')));
    expect(theme.brightness, Brightness.dark);
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, const Color(0xFF9B8AFB));
    expect(theme.scaffoldBackgroundColor, const Color(0xFF101116));
    expect(theme.colorScheme.surface, const Color(0xFF1C1D25));
    expect(theme.colorScheme.onSurface, const Color(0xFFF5F5F7));
    expect(theme.colorScheme.onSurfaceVariant, const Color(0xFFA3A3AD));
  });

  testWidgets('Accepts search text and preserves it when changing tabs', (
    tester,
  ) async {
    await tester.pumpWidget(const RikoPlayerApp());
    await tester.pumpAndSettle();
    expect(find.text('Pesquisar músicas'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Minha música');

    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma playlist por aqui'), findsOneWidget);
    expect(find.text('Nenhuma música encontrada'), findsNothing);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    await tester.tap(find.text('Biblioteca'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma música encontrada'), findsOneWidget);
    expect(find.text('Minha música'), findsOneWidget);
  });

  testWidgets('Opens settings and returns to the library', (tester) async {
    await tester.pumpWidget(const RikoPlayerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Configurações'));
    await tester.pumpAndSettle();

    expect(find.text('Configurações'), findsOneWidget);
    expect(
      find.text('As configurações estarão disponíveis em breve.'),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Suas músicas'), findsOneWidget);
  });

  testWidgets('Fits a narrow screen with larger text and the keyboard open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const RikoPlayerApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.showKeyboard(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Nenhuma música encontrada'), findsOneWidget);
  });
}
