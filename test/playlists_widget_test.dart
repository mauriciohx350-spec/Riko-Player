import 'package:device_audio_query/device_audio_query.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riko_player/app/app.dart';
import 'package:riko_player/features/playlists/view/playlists_scope.dart';
import 'package:riko_player/features/playlists/view/playlist_details_page.dart';
import 'package:riko_player/features/playlists/view/playlist_song_picker_page.dart';
import 'package:riko_player/features/playback/view/playback_scope.dart';

import 'support/memory_playlists_repository.dart';
import 'library_test.dart' show TestMusicService;
import 'playback_test.dart' show FakePlaybackService;
import 'playlists_repository_test.dart' show playlistSongs;

void main() {
  testWidgets(
    'cria, valida nome, adiciona seleção filtrada, reproduz e exclui com confirmação',
    (tester) async {
      final repository = MemoryPlaylistsRepository();
      final audio = FakePlaybackService();
      final library = TestMusicService()..result = playlistSongs;
      await tester.pumpWidget(
        RikoPlayerApp(
          playlistsRepository: repository,
          libraryService: library,
          playbackService: audio,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Playlists'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma playlist por aqui'), findsOneWidget);
      await tester.tap(find.text('Nova playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('Digite um nome para a playlist.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '  Viagem  ');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.byType(PlaylistDetailsPage), findsOneWidget);
      expect(find.text('Viagem'), findsOneWidget);
      await tester.tap(find.byTooltip('Adicionar músicas'));
      await tester.pumpAndSettle();
      expect(find.byType(PlaylistSongPickerPage), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Zebra');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Água');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      expect(find.text('Adicionar (2)'), findsOneWidget);
      await tester.tap(find.text('Adicionar (2)'));
      await tester.pumpAndSettle();
      expect(repository.data.values.single.tracks.length, 2);
      final details = find.byType(PlaylistDetailsPage);
      final playback = PlaybackScope.of(tester.element(details)).controller;
      await tester.tap(find.text('Reproduzir'));
      await tester.pumpAndSettle();
      expect(playback.queue.map((song) => song.id), [1, 2]);
      playback.setShuffle(true);
      final activeQueue = playback.queue;
      await tester.tap(find.byTooltip('Adicionar músicas'));
      await tester.pumpAndSettle();
      expect(find.text('Já adicionada'), findsNWidgets(2));
      final existing = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .where((tile) => tile.value == true);
      expect(existing.every((tile) => tile.onChanged == null), isTrue);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Opções da playlist').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Renomear'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Estrada');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('Estrada'), findsOneWidget);
      await tester.tap(find.byTooltip('Remover da playlist').first);
      await tester.pumpAndSettle();
      expect(repository.data.values.single.tracks.length, 1);
      expect(playback.queue.length, 2);
      await tester.tap(find.byTooltip('Opções da playlist').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir playlist'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Os arquivos de áudio não serão excluídos'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(repository.data.length, 1);
      await tester.tap(find.byTooltip('Opções da playlist').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      expect(repository.data, isEmpty);
      expect(playback.queue, same(activeQueue));
      expect(playback.shuffleEnabled, isTrue);
      await playback.next();
      await tester.pumpAndSettle();
      expect(playback.song?.id, 2);
      expect(playback.queue.length, 2);
      expect(playback.playing, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await repository.close();
    },
  );

  testWidgets(
    'arraste, ordenação, ausências e falha de escrita em tela pequena',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repository = MemoryPlaylistsRepository();
      final playlist = await repository.create('Favoritas');
      await repository.add(playlist.id, playlistSongs);
      final library = TestMusicService()..result = playlistSongs;
      await tester.pumpWidget(
        RikoPlayerApp(
          playlistsRepository: repository,
          libraryService: library,
          playbackService: FakePlaybackService(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Playlists'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Favoritas'));
      await tester.pumpAndSettle();
      final handles = find.byType(ReorderableDragStartListener);
      final start = tester.getCenter(handles.first);
      final end = tester.getCenter(handles.last) + const Offset(0, 20);
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(end);
      await tester.pump(const Duration(milliseconds: 250));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(repository.data[playlist.id]!.tracks.first.mediaId, isNot(1));
      await tester.tap(find.byTooltip('Opções da playlist').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ordenar por artista'));
      await tester.pumpAndSettle();
      expect(
        repository.data[playlist.id]!.tracks.map((entry) => entry.mediaId),
        [3, 1, 2],
      );
      final catalog = PlaylistsScope.of(
        tester.element(find.byType(PlaylistDetailsPage)),
      ).library;
      library.permission = PermissionStatus.denied;
      await catalog.load();
      await tester.pumpAndSettle();
      expect(find.textContaining('Música indisponível'), findsNothing);
      expect(find.text('Aguardando biblioteca'), findsNWidgets(3));
      library.permission = PermissionStatus.granted;
      library.result = [];
      await catalog.load();
      await tester.pumpAndSettle();
      expect(find.textContaining('Música indisponível'), findsNWidgets(3));
      expect(repository.data[playlist.id]!.tracks.length, 3);
      repository.failWrites = true;
      await tester.tap(find.byTooltip('Remover da playlist').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Não foi possível salvar'), findsOneWidget);
      expect(repository.data[playlist.id]!.tracks.length, 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await repository.close();
    },
  );
}
