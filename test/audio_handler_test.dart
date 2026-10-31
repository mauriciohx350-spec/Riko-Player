import 'package:riko_player/features/playback/data/audio_playback_service.dart';

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:device_audio_query/device_audio_query.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riko_player/app/app.dart';
import 'package:riko_player/features/playback/data/media_artwork_store.dart';
import 'package:riko_player/features/playback/data/riko_audio_handler.dart';
import 'package:riko_player/features/playback/logic/playback_controller.dart';
import 'package:riko_player/features/playback/logic/playback_runtime.dart';

import 'playback_test.dart' show FakePlaybackService, songs, tick;
import 'library_test.dart' show TestMusicService;

class FakeArtworkStore implements MediaArtworkStore {
  final pending = <Completer<Uri?>>[];
  int clears = 0;
  @override
  Future<Uri?> artwork(SongModel song) {
    final result = Completer<Uri?>();
    pending.add(result);
    return result.future;
  }

  @override
  Future<void> clear() async {
    clears++;
    for (final result in pending) {
      if (!result.isCompleted) result.complete(null);
    }
  }
}

void main() {
  group('handler', () {
    late FakePlaybackService service;
    late PlaybackController controller;
    late FakeArtworkStore artwork;
    late RikoAudioHandler handler;
    setUp(() {
      service = FakePlaybackService();
      controller = PlaybackController(service);
      artwork = FakeArtworkStore();
      handler = RikoAudioHandler(controller, artwork);
    });
    tearDown(() async {
      await handler.close();
    });

    test(
      'comandos remotos compartilham fila, posição e estado do controller',
      () async {
        await controller.playQueue(songs, 0);
        await tick();
        expect(
          handler.queue.value.map((item) => item.id),
          songs.map((song) => song.uri),
        );
        expect(handler.mediaItem.value?.title, 'Um');
        expect(handler.mediaItem.value?.duration, const Duration(seconds: 60));
        expect(handler.playbackState.value.playing, isTrue);
        expect(
          handler.playbackState.value.controls,
          contains(MediaControl.pause),
        );
        await handler.pause();
        expect(controller.playing, isFalse);
        expect(handler.playbackState.value.playing, isFalse);
        await handler.play();
        await handler.play();
        await tick();
        expect(service.plays, 2);
        await handler.seek(const Duration(seconds: 12));
        expect(controller.position.inSeconds, 12);
        expect(handler.playbackState.value.updatePosition.inSeconds, 12);
        await handler.skipToNext();
        expect(controller.index, 1);
        expect(handler.mediaItem.value?.title, 'Dois');
        expect(
          handler.playbackState.value.controls,
          isNot(contains(MediaControl.skipToNext)),
        );
        await handler.skipToPrevious();
        expect(controller.index, 0);
      },
    );

    test(
      'modes synchronize in both directions without changing queue or playback',
      () async {
        await controller.playQueue(songs, 1);
        await handler.pause();
        final queue = handler.queue.value;
        final loads = service.loaded.length;
        await handler.setShuffleMode(AudioServiceShuffleMode.all);
        expect(controller.shuffleEnabled, isTrue);
        expect(
          handler.playbackState.value.shuffleMode,
          AudioServiceShuffleMode.all,
        );
        await handler.setShuffleMode(AudioServiceShuffleMode.none);
        await handler.setRepeatMode(AudioServiceRepeatMode.one);
        expect(controller.repeatMode, PlaybackRepeatMode.one);
        expect(
          handler.playbackState.value.repeatMode,
          AudioServiceRepeatMode.one,
        );
        expect(
          handler.playbackState.value.controls,
          isNot(contains(MediaControl.skipToNext)),
        );
        await handler.setRepeatMode(AudioServiceRepeatMode.group);
        expect(controller.repeatMode, PlaybackRepeatMode.all);
        expect(
          handler.playbackState.value.repeatMode,
          AudioServiceRepeatMode.all,
        );
        expect(
          handler.playbackState.value.controls,
          contains(MediaControl.skipToNext),
        );
        controller.setShuffle(false);
        controller.setRepeatMode(PlaybackRepeatMode.off);
        expect(
          handler.playbackState.value.shuffleMode,
          AudioServiceShuffleMode.none,
        );
        expect(
          handler.playbackState.value.repeatMode,
          AudioServiceRepeatMode.none,
        );
        await handler.setShuffleMode(AudioServiceShuffleMode.group);
        expect(controller.shuffleEnabled, isTrue);
        await handler.setShuffleMode(AudioServiceShuffleMode.none);
        await handler.setRepeatMode(AudioServiceRepeatMode.none);
        expect(controller.shuffleEnabled, isFalse);
        expect(controller.repeatMode, PlaybackRepeatMode.off);
        expect(handler.queue.value, same(queue));
        expect(handler.playbackState.value.queueIndex, 1);
        expect(handler.playbackState.value.playing, isFalse);
        expect(service.loaded.length, loads);
      },
    );

    test(
      'remote next ignores repeat one and repeat all wraps with original index',
      () async {
        await controller.playQueue(songs, 0);
        await handler.setRepeatMode(AudioServiceRepeatMode.one);
        await handler.skipToNext();
        expect(controller.index, 1);
        expect(handler.playbackState.value.queueIndex, 1);
        await handler.setRepeatMode(AudioServiceRepeatMode.all);
        await handler.skipToNext();
        expect(controller.index, 0);
        expect(handler.mediaItem.value?.id, songs[0].uri);
        await handler.skipToPrevious();
        expect(controller.index, 1);
        await handler.stop();
        expect(
          handler.playbackState.value.repeatMode,
          AudioServiceRepeatMode.all,
        );
        expect(
          handler.playbackState.value.processingState,
          AudioProcessingState.idle,
        );
      },
    );

    test('capa antiga não substitui faixa nova e não bloqueia áudio', () async {
      await controller.playQueue(songs, 0);
      await tick();
      expect(service.plays, 1);
      expect(handler.mediaItem.value?.artUri, isNull);
      await handler.skipToNext();
      await tick();
      artwork.pending[1].complete(Uri.file('/new.jpg'));
      await tick();
      expect(handler.mediaItem.value?.artUri, Uri.file('/new.jpg'));
      artwork.pending[0].complete(Uri.file('/old.jpg'));
      await tick();
      expect(handler.mediaItem.value?.title, 'Dois');
      expect(handler.mediaItem.value?.artUri, Uri.file('/new.jpg'));
    });
    test('falha da capa preserva reprodução e metadados', () async {
      await controller.playQueue(songs, 0);
      artwork.pending.single.completeError(StateError('sem capa'));
      await tick();
      expect(controller.playing, isTrue);
      expect(handler.mediaItem.value?.title, 'Um');
      expect(controller.error, isNull);
    });
    test(
      'erro de reprodução e interrupção são refletidos nos controles Android',
      () async {
        await controller.playQueue(songs, 0);
        await tick();
        service.interrupted.add(null);
        await tick();
        expect(handler.playbackState.value.playing, isFalse);
        expect(
          handler.playbackState.value.controls,
          contains(MediaControl.play),
        );
        await handler.play();
        await tick();
        service.failures.add(StateError('arquivo removido'));
        expect(
          handler.playbackState.value.processingState,
          AudioProcessingState.error,
        );
        expect(handler.playbackState.value.errorMessage, controller.error);
        expect(handler.playbackState.value.playing, isFalse);
      },
    );
    test('remover tarefa tocando mantém sessão; pausada encerra sem descartar player', () async {
      await controller.playQueue(songs, 0);
      await tick();
      await handler.onTaskRemoved();
      expect(service.stops, 0);
      expect(controller.playing, isTrue);
      await handler.pause();
      await handler.onTaskRemoved();
      expect(controller.stopped, isTrue);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.idle,
      );
      expect(service.disposals, 0);
      await handler.play();
      await tick();
      expect(controller.playing, isTrue);
      await handler.onNotificationDeleted();
      expect(service.stops, 2);
      expect(controller.stopped, isTrue);
    });
    test('retoma pela notificação após longa pausa lógica sem perder fila e posição', () async {
      await controller.playQueue(songs, 0);
      await tick();
      service.progress.add(const Duration(seconds: 42));
      await handler.pause();
      // A retomada não depende de timeout, visibilidade ou outro carregamento.
      await handler.play();
      await tick();
      expect(service.loaded.length, 1);
      expect(controller.queue.length, 2);
      expect(controller.position.inSeconds, 42);
      expect(handler.playbackState.value.updatePosition.inSeconds, 42);
      expect(controller.playing, isTrue);
    });
  });
  testWidgets(
    'runtime sobrevive à remoção da interface e reutiliza o controller',
    (tester) async {
      final service = FakePlaybackService();
      final controller = PlaybackController(service);
      final handler = RikoAudioHandler(controller, FakeArtworkStore());
      final library = TestMusicService()..result = songs;
      final runtime = PlaybackRuntime(controller, library, handler);
      await tester.pumpWidget(RikoPlayerApp(runtime: runtime));
      await tester.pumpAndSettle();
      await controller.playQueue(songs, 0);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(service.disposals, 0);
      expect(controller.playing, isTrue);
      service.state.add(const PlaybackEvent(PlaybackPhase.completed, true));
      await tester.pumpAndSettle();
      expect(controller.index, 1);
      await tester.pumpWidget(RikoPlayerApp(runtime: runtime));
      await tester.pumpAndSettle();
      expect(find.text('Dois'), findsNWidgets(2));
      expect(service.loaded.length, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      final closing = handler.close();
      await tester.pumpAndSettle();
      await closing;
    },
  );
}
