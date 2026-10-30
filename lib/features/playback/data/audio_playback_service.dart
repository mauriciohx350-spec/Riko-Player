import 'package:just_audio/just_audio.dart';

enum PlaybackPhase { idle, loading, ready, completed }

class PlaybackEvent {
  const PlaybackEvent(this.phase, this.playing);
  final PlaybackPhase phase;
  final bool playing;
}

/// Contrato pequeno para testar a lógica sem canais nativos.
abstract class PlaybackService {
  Stream<PlaybackEvent> get events;
  Stream<Duration> get positions;
  Stream<Duration?> get durations;
  Stream<Object> get errors;
  Future<Duration?> load(Uri uri);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

class AudioPlaybackService implements PlaybackService {
  AudioPlayer? _player;
  bool _disposed = false;
  AudioPlayer get _audio {
    if (_disposed) throw StateError('Reprodutor encerrado');
    return _player ??= AudioPlayer();
  }

  @override
  Stream<PlaybackEvent> get events => _audio.playerStateStream.map(
    (state) => PlaybackEvent(switch (state.processingState) {
      ProcessingState.idle => PlaybackPhase.idle,
      ProcessingState.loading ||
      ProcessingState.buffering => PlaybackPhase.loading,
      ProcessingState.ready => PlaybackPhase.ready,
      ProcessingState.completed => PlaybackPhase.completed,
    }, state.playing),
  );
  @override
  Stream<Duration> get positions => _audio.positionStream;
  @override
  Stream<Duration?> get durations => _audio.durationStream;
  @override
  Stream<Object> get errors => _audio.errorStream;
  @override
  Future<Duration?> load(Uri uri) async {
    return await _audio.setAudioSource(AudioSource.uri(uri));
  }

  @override
  Future<void> play() => _audio.play();
  @override
  Future<void> pause() => _audio.pause();
  @override
  Future<void> seek(Duration position) => _audio.seek(position);
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _player?.dispose();
  }
}
