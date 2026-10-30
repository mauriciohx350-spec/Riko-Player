import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

enum PlaybackPhase { idle, loading, ready, completed }

class PlaybackEvent {
  const PlaybackEvent(this.phase, this.playing);
  final PlaybackPhase phase;
  final bool playing;
}

abstract class PlaybackService {
  Stream<PlaybackEvent> get events;
  Stream<Duration> get positions;
  Stream<Duration?> get durations;
  Stream<Object> get errors;
  Stream<void> get interruptions;
  Future<Duration?> load(Uri uri);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

/// Único proprietário do AudioPlayer. stop libera o decoder sem criar outro player.
class AudioPlaybackService implements PlaybackService {
  AudioPlayer? _player;
  AudioSession? _session;
  Future<void>? _configuration;
  final _interruptions = StreamController<void>.broadcast(sync: true);
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _disposed = false;
  int _playRequest = 0;
  AudioPlayer get _audio {
    if (_disposed) throw StateError('Reprodutor encerrado');
    return _player ??= AudioPlayer(
      handleInterruptions: false,
      handleAudioSessionActivation: false,
    );
  }

  Future<void> _configure() => _configuration ??= _configureSession();
  Future<void> _configureSession() async {
    final session = await AudioSession.instance;
    if (_disposed) return;
    await session.configure(const AudioSessionConfiguration.music());
    if (_disposed) return;
    _session = session;
    _subscriptions.add(
      session.becomingNoisyEventStream.listen((_) {
        _interruptions.add(null);
      }),
    );
    _subscriptions.add(
      session.interruptionEventStream.listen((event) {
        // Ducking de música é feito pelo Android. Nunca retomar automaticamente.
        if (event.begin && event.type != AudioInterruptionType.duck) {
          _interruptions.add(null);
        }
      }),
    );
  }

  @override
  Stream<void> get interruptions => _interruptions.stream;
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
    await _configure();
    if (_disposed) return null;
    return _audio.setAudioSource(AudioSource.uri(uri));
  }

  @override
  Future<void> play() async {
    final request = ++_playRequest;
    await _configure();
    if (_disposed || request != _playRequest) return;
    final granted = await _session!.setActive(true);
    if (_disposed) {
      await _session?.setActive(false);
      return;
    }
    if (request != _playRequest) return;
    if (!granted) throw StateError('Não foi possível obter foco de áudio');
    await _audio.play();
  }

  @override
  Future<void> pause() async {
    final request = ++_playRequest;
    await _player?.pause();
    if (!_disposed && request == _playRequest) await _session?.setActive(false);
  }

  @override
  Future<void> stop() async {
    final request = ++_playRequest;
    await _player?.stop();
    if (!_disposed && request == _playRequest) await _session?.setActive(false);
  }

  @override
  Future<void> seek(Duration position) => _audio.seek(position);
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _playRequest++;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player?.dispose();
    await _session?.setActive(false);
    await _interruptions.close();
  }
}
