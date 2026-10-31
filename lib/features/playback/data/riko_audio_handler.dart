import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:device_audio_query/device_audio_query.dart';

import '../../library/logic/song_details.dart';
import '../logic/playback_controller.dart';
import 'media_artwork_store.dart';

/// Adaptador de comandos e projeções para o Android; não possui outra fila/player.
class RikoAudioHandler extends BaseAudioHandler {
  RikoAudioHandler(this.controller, this.artworkStore) {
    controller.addListener(_publish);
    _publish();
  }
  final PlaybackController controller;
  final MediaArtworkStore artworkStore;
  List<SongModel>? _publishedQueue;
  SongArtworkKey? _artworkKey;
  Uri? _artUri;
  int _artworkRequest = 0;
  bool _closed = false;
  Future<void>? _closing;

  MediaItem _item(SongModel song, {Uri? artwork, Duration? duration}) =>
      MediaItem(
        id: song.uri ?? song.id.toString(),
        title: song.displayTitle,
        artist: song.displayArtist,
        album: song.album,
        duration:
            duration ??
            (song.duration == null
                ? null
                : Duration(milliseconds: song.duration!)),
        artUri: artwork,
      );

  void _publish() {
    if (_closed) return;
    final song = controller.song;
    if (!identical(_publishedQueue, controller.queue)) {
      _publishedQueue = controller.queue;
      queue.add(
        controller.queue.map((song) => _item(song)).toList(growable: false),
      );
    }
    if (song != null && !controller.stopped && _artworkKey != song.artworkKey) {
      _artworkKey = song.artworkKey;
      _artUri = null;
      final request = ++_artworkRequest;
      unawaited(_loadArtwork(song, request));
    }
    if (controller.stopped && _artworkKey != null) {
      _artworkKey = null;
      _artUri = null;
      _artworkRequest++;
      unawaited(artworkStore.clear().catchError((Object _) {}));
    }
    final item = song == null
        ? null
        : _item(song, artwork: _artUri, duration: controller.duration);
    final previous = mediaItem.value;
    if (previous?.id != item?.id ||
        previous?.title != item?.title ||
        previous?.artist != item?.artist ||
        previous?.album != item?.album ||
        previous?.duration != item?.duration ||
        previous?.artUri != item?.artUri) {
      mediaItem.add(item);
    }

    final controls = <MediaControl>[
      if (song != null) MediaControl.skipToPrevious,
      controller.playing ? MediaControl.pause : MediaControl.play,
      if (controller.hasNext) MediaControl.skipToNext,
      MediaControl.stop,
    ];
    playbackState.add(
      PlaybackState(
        controls: controls,
        androidCompactActionIndices: List.generate(
          controls.length > 3 ? 3 : controls.length,
          (index) => index,
        ),
        systemActions: {
          if (song != null && !controller.loading && controller.error == null)
            MediaAction.seek,
        },
        processingState: controller.stopped
            ? AudioProcessingState.idle
            : controller.error != null
            ? AudioProcessingState.error
            : controller.loading
            ? AudioProcessingState.loading
            : controller.buffering
            ? AudioProcessingState.buffering
            : controller.completed
            ? AudioProcessingState.completed
            : AudioProcessingState.ready,
        playing: controller.playing,
        updatePosition: controller.position,
        bufferedPosition: controller.position,
        speed: 1,
        shuffleMode: controller.shuffleEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        repeatMode: switch (controller.repeatMode) {
          PlaybackRepeatMode.off => AudioServiceRepeatMode.none,
          PlaybackRepeatMode.all => AudioServiceRepeatMode.all,
          PlaybackRepeatMode.one => AudioServiceRepeatMode.one,
        },
        queueIndex: controller.index < 0 ? null : controller.index,
        errorCode: controller.error == null ? null : 1,
        errorMessage: controller.error,
      ),
    );
  }

  Future<void> _loadArtwork(SongModel song, int request) async {
    try {
      final uri = await artworkStore.artwork(song);
      if (_closed || request != _artworkRequest || controller.stopped) return;
      _artUri = uri;
      _publish();
    } catch (_) {
      // Sem capa, preserva os metadados e a reprodução.
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    controller.setShuffle(shuffleMode != AudioServiceShuffleMode.none);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    controller.setRepeatMode(switch (repeatMode) {
      AudioServiceRepeatMode.none => PlaybackRepeatMode.off,
      AudioServiceRepeatMode.one => PlaybackRepeatMode.one,
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group => PlaybackRepeatMode.all,
    });
  }

  @override
  Future<void> play() => controller.play();
  @override
  Future<void> pause() => controller.pause();
  @override
  Future<void> skipToNext() => controller.next();
  @override
  Future<void> skipToPrevious() => controller.previous();
  @override
  Future<void> seek(Duration position) => controller.seek(position);
  @override
  Future<void> stop() async {
    await controller.stop();
  }

  @override
  Future<void> onNotificationDeleted() => stop();
  @override
  Future<void> onTaskRemoved() async {
    if (!controller.playing && !controller.loading) await stop();
  }

  /// Encerramento definitivo, separado de stop (que permite nova reprodução).
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    if (_closed) return;
    await stop();
    _closed = true;
    controller.removeListener(_publish);
    controller.dispose();
    await artworkStore.clear();
    await Future.wait([
      playbackState.close(),
      queue.close(),
      queueTitle.close(),
      mediaItem.close(),
      androidPlaybackInfo.close(),
      ratingStyle.close(),
      customEvent.close(),
      customState.close(),
    ]);
  }
}
