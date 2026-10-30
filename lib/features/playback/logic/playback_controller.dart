import 'dart:async';

import 'package:device_audio_query/device_audio_query.dart';
import 'package:flutter/foundation.dart';

import '../data/audio_playback_service.dart';

/// Fila é uma cópia imutável da lista visível no momento do toque.
class PlaybackController extends ChangeNotifier {
  PlaybackController(this._service);
  final PlaybackService _service;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  List<SongModel> _queue = const [];
  List<SongModel> get queue => _queue;
  int _index = -1;
  int get index => _index;
  SongModel? get song => _index < 0 ? null : _queue[_index];
  bool playing = false;
  bool loading = false;
  bool completed = false;
  Duration position = Duration.zero;
  Duration? duration;
  String? error;
  bool _disposed = false;
  bool _foreground = true;
  bool _started = false;
  int _generation = 0;
  Future<void> _pending = Future.value();
  bool get hasNext => _index >= 0 && _index + 1 < _queue.length;

  static Uri sourceFor(SongModel song) {
    final uri = Uri.tryParse(song.uri ?? '');
    if (uri == null ||
        uri.scheme != 'content' ||
        uri.authority != 'media' ||
        uri.pathSegments.isEmpty) {
      throw const FormatException('URI do MediaStore indisponível');
    }
    return uri;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _listen() {
    if (_started) return;
    _started = true;
    _subscriptions.add(
      _service.events.listen((event) {
        if (_disposed || loading || error != null) return;
        playing = event.playing;
        if (event.phase == PlaybackPhase.completed && !completed) {
          completed = true;
          playing = false;
          if (hasNext && _foreground) {
            unawaited(next());
          } else {
            unawaited(pause());
          }
        }
        _notify();
      }, onError: (Object e) => _fail()),
    );
    _subscriptions.add(
      _service.positions.listen((value) {
        if (_disposed || loading) return;
        position = value;
        _notify();
      }),
    );
    _subscriptions.add(
      _service.durations.listen((value) {
        if (_disposed || loading) return;
        duration = value;
        _notify();
      }),
    );
    _subscriptions.add(
      _service.errors.listen((e) {
        if (!loading) _fail();
      }),
    );
  }

  void _fail() {
    if (_disposed) return;
    error =
        'Não foi possível reproduzir esta música. O arquivo pode ter sido '
        'removido ou o acesso foi negado. Tente novamente ou avance.';
    playing = false;
    loading = false;
    _notify();
    unawaited(_service.pause().catchError((Object _) {}));
  }

  Future<void> playQueue(List<SongModel> songs, int index) {
    if (_disposed || index < 0 || index >= songs.length) return Future.value();
    _queue = List.unmodifiable(songs);
    return _select(index);
  }

  Future<void> _select(int index) {
    final generation = ++_generation;
    final selectedSong = _queue[index];
    _index = index;
    loading = true;
    playing = false;
    completed = false;
    position = Duration.zero;
    duration = null;
    error = null;
    _notify();
    // Serializa o acesso nativo e descarta seleções superadas antes de carregar.
    _pending = _pending.then((_) async {
      if (_disposed || generation != _generation) return;
      try {
        _listen();
        await _service.pause();
        if (_disposed || generation != _generation) return;
        final loadedDuration = await _service.load(sourceFor(selectedSong));
        if (_disposed || generation != _generation) return;
        duration = loadedDuration;
        loading = false;
        if (_foreground) _play(generation);
        _notify();
      } catch (_) {
        if (!_disposed && generation == _generation) _fail();
      }
    });
    return _pending;
  }

  void _play(int generation) {
    playing = true;
    // play() só conclui quando a reprodução pausa ou termina.
    unawaited(
      Future<void>.sync(_service.play).catchError((Object _) {
        if (!_disposed && generation == _generation) _fail();
      }),
    );
  }

  Future<void> toggle() async {
    if (_disposed || song == null || loading) return;
    if (playing) {
      await pause();
      return;
    }
    if (error != null) {
      await _select(_index);
      return;
    }
    if (!_foreground) return;
    if (completed) {
      await seek(Duration.zero);
      if (_disposed || error != null) return;
      completed = false;
    }
    _play(_generation);
    _notify();
  }

  Future<void> pause() async {
    if (_disposed) return;
    playing = false;
    _notify();
    if (!_started) return;
    try {
      await _service.pause();
    } catch (_) {
      _fail();
    }
  }

  Future<void> next() async {
    if (!_disposed && hasNext) await _select(_index + 1);
  }

  Future<void> previous() async {
    if (_disposed || song == null) return;
    await _select(_index > 0 ? _index - 1 : 0);
  }

  Future<void> seek(Duration value) async {
    if (_disposed || song == null || loading || error != null) return;
    final generation = _generation;
    final max = duration?.inMilliseconds;
    final milliseconds = value.inMilliseconds.clamp(0, max ?? 0);
    try {
      await _service.seek(Duration(milliseconds: milliseconds));
      if (_disposed || generation != _generation) return;
      position = Duration(milliseconds: milliseconds);
      completed = duration != null && position >= duration!;
      _notify();
    } catch (_) {
      if (generation == _generation) _fail();
    }
  }

  void setForeground(bool value) {
    if (_disposed) return;
    _foreground = value;
    if (!value) unawaited(pause());
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    // Interrompe também um carregamento nativo ainda pendente.
    unawaited(_service.dispose().catchError((Object _) {}));
    super.dispose();
  }
}
