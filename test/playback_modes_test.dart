import 'dart:async';
import 'dart:math';

import 'package:device_audio_query/device_audio_query.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riko_player/features/playback/data/audio_playback_service.dart';
import 'package:riko_player/features/playback/logic/playback_controller.dart';

import 'playback_test.dart' show FakePlaybackService, tick;

final tracks = List.generate(
  5,
  (i) => SongModel(
    id: i + 1,
    title: 'Track ${i + 1}',
    uri: 'content://media/external/audio/media/${i + 1}',
  ),
);

void main() {
  late FakePlaybackService service;
  late PlaybackController controller;
  setUp(() {
    service = FakePlaybackService();
    controller = PlaybackController(service, random: Random(19));
  });
  tearDown(() => controller.dispose());

  void complete() =>
      service.state.add(const PlaybackEvent(PlaybackPhase.completed, true));
  Future<void> settle() async {
    await tick();
    await tick();
    await tick();
  }

  test(
    'mode changes preserve original queue, position, song and play state',
    () async {
      await controller.playQueue(tracks, 2);
      await settle();
      service.progress.add(const Duration(seconds: 17));
      final queue = controller.queue;
      final loads = service.loaded.length;
      final plays = service.plays;
      for (final paused in [false, true]) {
        if (paused) await controller.pause();
        for (final shuffle in [true, false, true]) {
          controller.setShuffle(shuffle);
          for (var i = 0; i < 3; i++) {
            controller.cycleRepeatMode();
            expect(controller.song, tracks[2]);
            expect(controller.position.inSeconds, 17);
            expect(controller.playing, !paused);
            expect(identical(controller.queue, queue), isTrue);
          }
        }
      }
      await settle();
      expect(service.loaded.length, loads);
      expect(service.plays, plays);
      expect(controller.repeatMode, PlaybackRepeatMode.off);
      expect(controller.queue, tracks);
    },
  );

  test(
    'automatic and manual navigation share shuffle order and history',
    () async {
      controller.setShuffle(true);
      await controller.playQueue(tracks, 2);
      final path = [controller.index];
      await controller.next();
      path.add(controller.index);
      complete();
      await settle();
      path.add(controller.index);
      await controller.previous();
      expect(controller.index, path[1]);
      await controller.next();
      expect(controller.index, path[2]);
      while (controller.hasNext) {
        complete();
        await settle();
        path.add(controller.index);
      }
      expect(path.toSet().length, tracks.length);
      complete();
      await settle();
      expect(controller.completed, isTrue);
      expect(controller.playing, isFalse);
      expect(controller.queue, tracks);
    },
  );

  test(
    'repeat all wraps automatically and manually without adjacent repeats',
    () async {
      controller.setShuffle(true);
      controller.setRepeatMode(PlaybackRepeatMode.all);
      await controller.playQueue(tracks, 0);
      final path = [controller.index];
      for (var i = 0; i < 14; i++) {
        final previous = controller.index;
        if (i.isEven) {
          complete();
          await settle();
        } else {
          await controller.next();
        }
        expect(controller.index, isNot(previous));
        path.add(controller.index);
      }
      for (var i = 0; i < 15; i += 5) {
        expect(path.sublist(i, i + 5).toSet().length, 5);
      }
    },
  );

  test(
    'sequential repeat all wraps, but repeat one only affects completion',
    () async {
      await controller.playQueue(tracks, 0);
      controller.setRepeatMode(PlaybackRepeatMode.one);
      complete();
      complete();
      await settle();
      expect(controller.index, 0);
      expect(service.loaded.length, 2);
      expect(controller.playing, isTrue);
      await controller.next();
      expect(controller.index, 1);
      await controller.previous();
      expect(controller.index, 0);
      await controller.playQueue(tracks, 4);
      expect(controller.hasNext, isFalse);
      await controller.next();
      expect(controller.index, 4);
      controller.setRepeatMode(PlaybackRepeatMode.all);
      complete();
      await settle();
      expect(controller.index, 0);
      await controller.playQueue(tracks, 4);
      await controller.next();
      expect(controller.index, 0);
    },
  );

  test('empty and single-entry queues are safe in every mode', () async {
    for (final mode in PlaybackRepeatMode.values) {
      controller.setRepeatMode(mode);
      controller.setShuffle(true);
      await controller.playQueue([], 0);
      await controller.next();
      await controller.previous();
      expect(controller.song, isNull);
    }
    for (final mode in PlaybackRepeatMode.values) {
      controller.setRepeatMode(mode);
      await controller.playQueue([tracks.first], 0);
      final loads = service.loaded.length;
      complete();
      complete();
      await settle();
      expect(
        service.loaded.length,
        loads + (mode == PlaybackRepeatMode.off ? 0 : 1),
      );
      expect(controller.playing, mode != PlaybackRepeatMode.off);
      expect(controller.index, 0);
      await controller.stop();
    }
  });

  test(
    'duplicate completions during load do not skip or repeat twice',
    () async {
      controller.setRepeatMode(PlaybackRepeatMode.all);
      await controller.playQueue(tracks, 0);
      service.pending = Completer<Duration?>();
      complete();
      complete();
      await tick();
      complete();
      expect(controller.index, 1);
      expect(service.loaded.length, 2);
      final pending = service.pending!;
      service.pending = null;
      pending.complete(const Duration(seconds: 60));
      await settle();
      expect(controller.index, 1);
      expect(controller.playing, isTrue);
    },
  );

  test('pause during repeat-one reload cancels automatic playback', () async {
    controller.setRepeatMode(PlaybackRepeatMode.one);
    await controller.playQueue(tracks, 0);
    await settle();
    final plays = service.plays;
    service.pending = Completer<Duration?>();
    complete();
    await tick();
    await controller.pause();
    controller.setShuffle(true);
    controller.setRepeatMode(PlaybackRepeatMode.all);
    service.pending!.complete(const Duration(seconds: 60));
    service.pending = null;
    await settle();
    expect(controller.playing, isFalse);
    expect(service.plays, plays);
    expect(controller.index, 0);
  });

  test(
    'latest navigation wins over automatic pending load and late failure',
    () async {
      controller.setShuffle(true);
      await controller.playQueue(tracks, 0);
      service.pending = Completer<Duration?>();
      complete();
      await tick();
      final next = controller.next();
      final previous = controller.previous();
      final last = controller.index;
      controller.setShuffle(false);
      final pending = service.pending!;
      service.pending = null;
      pending.completeError(StateError('old load'));
      await Future.wait([next, previous]);
      await settle();
      expect(controller.index, last);
      expect(controller.error, isNull);
      expect(controller.playing, isTrue);
      expect(controller.queue, tracks);
    },
  );

  test(
    'new queue and stop invalidate repeat loads and preserve preferences',
    () async {
      controller.setShuffle(true);
      controller.setRepeatMode(PlaybackRepeatMode.one);
      await controller.playQueue(tracks, 0);
      service.pending = Completer<Duration?>();
      complete();
      await tick();
      final pending = service.pending!;
      service.pending = null;
      final replacement = controller.playQueue(tracks.sublist(3), 1);
      await controller.stop();
      pending.complete(const Duration(seconds: 60));
      await replacement;
      await settle();
      expect(controller.stopped, isTrue);
      expect(controller.playing, isFalse);
      expect(controller.queue.length, 2);
      expect(controller.shuffleEnabled, isTrue);
      expect(controller.repeatMode, PlaybackRepeatMode.one);
      await controller.play();
      expect(controller.song, tracks[4]);
    },
  );

  test(
    'errors halt repeats; interruptions do not automatically resume',
    () async {
      for (final mode in [PlaybackRepeatMode.all, PlaybackRepeatMode.one]) {
        controller.setRepeatMode(mode);
        await controller.playQueue(tracks, 0);
        await settle();
        service.failures.add(StateError('missing file'));
        final loads = service.loaded.length;
        complete();
        await settle();
        expect(controller.error, isNotNull);
        expect(controller.playing, isFalse);
        expect(service.loaded.length, loads);
        await controller.next();
        expect(controller.error, isNull);
        service.interrupted.add(null);
        complete();
        await settle();
        expect(controller.playing, isFalse);
      }
    },
  );

  test('failed automatic repeat is not retried forever', () async {
    controller.setRepeatMode(PlaybackRepeatMode.one);
    await controller.playQueue(tracks, 0);
    service.fail = true;
    complete();
    await settle();
    complete();
    await settle();
    expect(service.loaded.length, 2);
    expect(controller.error, isNotNull);
    expect(controller.playing, isFalse);
  });

  test('explicit replay after off completion can finish again', () async {
    await controller.playQueue([tracks.first], 0);
    complete();
    await settle();
    await controller.play();
    complete();
    await settle();
    expect(controller.playing, isFalse);
    expect(controller.completed, isTrue);
  });
}
