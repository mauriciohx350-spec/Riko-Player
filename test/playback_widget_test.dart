import 'package:device_audio_query/device_audio_query.dart';
import 'package:riko_player/features/library/view/widgets/song_artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riko_player/app/app.dart';
import 'package:riko_player/features/playback/view/miniplayer.dart';
import 'package:riko_player/features/playback/view/playback_page.dart';
import 'package:riko_player/features/playback/view/playback_scope.dart';

import 'library_test.dart' show TestMusicService;
import 'playback_test.dart' show FakePlaybackService, songs;

void main() {
  testWidgets('miniplayer mantém controles e progresso em tela pequena', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final tracks = [
      SongModel(
        id: 1,
        title: 'Título longo da primeira música',
        artist: 'Nome longo do artista',
        uri: songs[0].uri,
      ),
      SongModel(
        id: 2,
        title: 'Segunda música',
        artist: 'Outro artista',
        uri: songs[1].uri,
      ),
    ];
    final audio = FakePlaybackService();
    await tester.pumpWidget(
      RikoPlayerApp(
        playbackService: audio,
        libraryService: TestMusicService()..result = tracks,
      ),
    );
    await tester.pumpAndSettle();
    final mini = find.byType(Miniplayer);
    final controller = PlaybackScope.of(tester.element(mini)).controller;
    await controller.playQueue(tracks, 1);
    await tester.pumpAndSettle();
    Finder control(String tooltip) =>
        find.descendant(of: mini, matching: find.byTooltip(tooltip));
    double? progress() => tester
        .widget<LinearProgressIndicator>(
          find.byKey(const ValueKey('miniplayer-progress')),
        )
        .value;

    expect(
      tester.getCenter(control('Música anterior')).dx,
      lessThan(tester.getCenter(control('Pausar')).dx),
    );
    expect(
      tester.getCenter(control('Pausar')).dx,
      lessThan(tester.getCenter(control('Próxima música')).dx),
    );
    expect(
      find.descendant(of: mini, matching: find.text('Segunda música')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: mini, matching: find.text('Outro artista')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: mini, matching: find.byType(SongArtwork)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: mini,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    expect(progress(), 0);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('miniplayer-progress')),
    );
    expect(bar.color, const Color(0xFF9B8AFB));
    expect(bar.minHeight, 2);
    audio.progress.add(const Duration(seconds: 30));
    await tester.pump();
    expect(progress(), 0.5);
    await tester.tap(control('Pausar'));
    await tester.pump();
    expect(controller.playing, isFalse);
    expect(progress(), 0.5);
    await tester.tap(control('Reproduzir'));
    await tester.pump();
    expect(controller.playing, isTrue);
    expect(progress(), 0.5);
    await tester.tap(control('Música anterior'));
    await tester.pumpAndSettle();
    expect(controller.index, 0);
    expect(progress(), 0);
    audio.progress.add(const Duration(seconds: 90));
    await tester.pump();
    expect(progress(), 1);
    audio.length.add(null);
    await tester.pump();
    expect(progress(), 0);
    audio.length.add(Duration.zero);
    await tester.pump();
    expect(progress(), 0);
    await tester.tap(control('Próxima música'));
    await tester.pumpAndSettle();
    expect(controller.index, 1);
    expect(progress(), 0);
    expect(find.byType(PlaybackPage), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(
      find.descendant(of: mini, matching: find.text('Segunda música')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlaybackPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('toque inicia música, preserva fila e player entre telas', (
    tester,
  ) async {
    final audio = FakePlaybackService();
    final library = TestMusicService()..result = songs;
    await tester.pumpWidget(
      RikoPlayerApp(playbackService: audio, libraryService: library),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Miniplayer), findsOneWidget);
    expect(audio.loaded, isEmpty);
    await tester.tap(find.text('Um'));
    await tester.pumpAndSettle();
    expect(audio.loaded.single.toString(), songs.first.uri);
    expect(find.byTooltip('Pausar'), findsOneWidget);
    final controller = PlaybackScope.of(tester.element(find.byType(Miniplayer)))
        .controller;

    await tester.enterText(find.byType(TextField), 'Dois');
    await tester.pumpAndSettle();
    expect(controller.queue.length, 2);
    library.result = [];
    await tester.tap(find.byTooltip('Atualizar biblioteca'));
    await tester.pumpAndSettle();
    expect(controller.queue.length, 2);
    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Pausar'), findsOneWidget);

    await tester.tap(
      find.descendant(of: find.byType(Miniplayer), matching: find.text('Um')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlaybackPage), findsOneWidget);
    expect(find.text('1:00'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Pausar'));
    await tester.tap(find.byTooltip('Pausar'));
    await tester.pumpAndSettle();
    expect(controller.playing, isFalse);
    await tester.tap(find.byTooltip('Reproduzir'));
    await tester.pumpAndSettle();
    expect(controller.playing, isTrue);
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChangeEnd!(30000);
    await tester.pumpAndSettle();
    expect(audio.sought, const Duration(seconds: 30));
    await tester.tap(find.byTooltip('Próxima música'));
    await tester.pumpAndSettle();
    expect(controller.song?.id, 2);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(Miniplayer), matching: find.text('Dois')),
      findsOneWidget,
    );
    expect(audio.loaded.length, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(controller.playing, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(controller.playing, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(controller.playing, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(audio.disposals, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('erro visível permite nova tentativa em tela estreita', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final audio = FakePlaybackService()..fail = true;
    await tester.pumpWidget(
      RikoPlayerApp(
        playbackService: audio,
        libraryService: TestMusicService()..result = songs,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Um'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Tentar novamente'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(
      find.descendant(of: find.byType(Miniplayer), matching: find.text('Um')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Verifique o arquivo'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
    final retry = find.byTooltip('Tentar novamente');
    await tester.ensureVisible(retry);
    audio.fail = false;
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Pausar'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    expect(audio.disposals, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(audio.disposals, 1);
  });
}
