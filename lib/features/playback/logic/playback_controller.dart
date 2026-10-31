import 'dart:async';
import 'dart:math';

import 'package:device_audio_query/device_audio_query.dart';
import 'package:flutter/foundation.dart';

import '../data/audio_playback_service.dart';
import 'playback_order.dart';

/// Repeat One afeta somente o término automático, nunca os botões.
enum PlaybackRepeatMode { off, all, one }

/// Fonte única da fila e do estado, independente do ciclo de vida da interface.
class PlaybackController extends ChangeNotifier {
  PlaybackController(this._service, {Random? random})
    : _order = PlaybackOrder(random: random);
  final PlaybackOrder _order;
  PlaybackRepeatMode _repeatMode = PlaybackRepeatMode.off;
  PlaybackRepeatMode get repeatMode => _repeatMode;
  bool get shuffleEnabled => _order.shuffle;
  bool _completionArmed = false;

  void setShuffle(bool enabled) {
    if (_disposed || enabled == shuffleEnabled) return;
    _order.setShuffle(enabled);
    _notify();
  }

  void setRepeatMode(PlaybackRepeatMode mode) {
    if (_disposed || mode == _repeatMode) return;
    _repeatMode = mode;
    _notify();
  }

  void cycleRepeatMode() =>
      setRepeatMode(PlaybackRepeatMode.values[(_repeatMode.index + 1) % 3]);
  final PlaybackService _service;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  List<SongModel> _queue = const [];
  List<SongModel> get queue => _queue;
  int _index = -1;
  int get index => _index;
  SongModel? get song => _index < 0 ? null : _queue[_index];
  bool playing = false;
  bool loading = false;
  bool buffering = false;
  bool completed = false;
  bool stopped = true;
  Duration position = Duration.zero;
  Duration? duration;
  String? error;
  bool _disposed = false;
  bool _started = false;
  bool _wantsPlay = false;
  int _generation = 0;
  int _playRequest = 0;
  int _seekRequest = 0;
  Future<void> _pending = Future.value();
  bool get hasNext =>
      song != null && (_order.hasNext || _repeatMode == PlaybackRepeatMode.all);

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
        if (_disposed || stopped || error != null) return;
        if (event.phase == PlaybackPhase.ready) _completionArmed = true;
        if (loading) {
          return;
        }
        // Uma conclusão só é aceita após ready/seek da fonte atual.
        if (event.phase == PlaybackPhase.completed && !_completionArmed) return;
        playing = event.playing && _wantsPlay;
        buffering = event.phase == PlaybackPhase.loading;
        if (event.phase == PlaybackPhase.completed && _completionArmed) {
          _completionArmed = false;
          completed = true;
          playing = false;
          if (_wantsPlay && _repeatMode == PlaybackRepeatMode.one) {
            unawaited(_select(_index));
          } else if (hasNext && _wantsPlay) {
            unawaited(next());
          } else {
            unawaited(pause());
          }
        }
        _notify();
      }, onError: (Object _) => reportError()),
    );
    _subscriptions.add(
      _service.positions.listen((value) {
        if (_disposed || loading || stopped) return;
        position = value;
        _notify();
      }, onError: (Object _) => reportError()),
    );
    _subscriptions.add(
      _service.durations.listen((value) {
        if (_disposed || loading || stopped) return;
        duration = value;
        _notify();
      }, onError: (Object _) => reportError()),
    );
    _subscriptions.add(
      _service.errors.listen((_) {
        if (!loading) reportError();
      }, onError: (Object _) => reportError()),
    );
    _subscriptions.add(
      _service.interruptions.listen((_) {
        unawaited(pause());
      }),
    );
  }

  void reportError() {
    if (_disposed) return;
    _wantsPlay = false;
    _playRequest++;
    error =
        'Não foi possível reproduzir esta música. Verifique o arquivo, '
        'a permissão de acesso ou tente reproduzir novamente.';
    playing = false;
    loading = false;
    buffering = false;
    _notify();
    unawaited(_service.pause().catchError((Object _) {}));
  }

  Future<void> playQueue(List<SongModel> songs, int index) {
    if (_disposed || index < 0 || index >= songs.length) return Future.value();
    _queue = List.unmodifiable(songs);
    _order.reset(songs.length, index);
    return _select(index);
  }

  Future<void> _select(int index) {
    _completionArmed = false;
    final generation = ++_generation;
    final selectedSong = _queue[index];
    _playRequest++;
    _wantsPlay = true;
    _index = index;
    stopped = false;
    loading = true;
    buffering = false;
    playing = false;
    completed = false;
    position = Duration.zero;
    duration = null;
    error = null;
    _notify();
    _pending = _pending.then((_) async {
      if (_disposed || generation != _generation) return;
      try {
        _listen();
        await _service.pause();
        if (_disposed || generation != _generation) return;
        _completionArmed = false;
        final loadedDuration = await _service.load(sourceFor(selectedSong));
        if (_disposed || generation != _generation) return;
        duration = loadedDuration;
        loading = false;
        if (_wantsPlay) _play(generation);
        _notify();
      } catch (_) {
        if (!_disposed && generation == _generation) reportError();
      }
    });
    return _pending;
  }

  void _play(int generation) {
    final request = ++_playRequest;
    playing = true;
    // Publica a intenção antes de obter foco: o handler promove o serviço.
    _notify();
    unawaited(
      Future<void>(() async {
        if (_disposed ||
            generation != _generation ||
            request != _playRequest ||
            !_wantsPlay) {
          return;
        }
        await _service.play();
      }).catchError((Object _) {
        if (!_disposed &&
            generation == _generation &&
            request == _playRequest) {
          reportError();
        }
      }),
    );
  }

  Future<void> toggle() =>
      playing || (loading && _wantsPlay) ? pause() : play();
  Future<void> play() async {
    if (_disposed || song == null || playing) return;
    _wantsPlay = true;
    if (loading) return;
    if (error != null || stopped) {
      await _select(_index);
      return;
    }
    final generation = _generation;
    if (completed) {
      await seek(Duration.zero);
      if (_disposed ||
          generation != _generation ||
          !_wantsPlay ||
          error != null) {
        return;
      }
      completed = false;
    }
    _play(generation);
  }

  Future<void> pause() async {
    if (_disposed) return;
    _wantsPlay = false;
    _playRequest++;
    playing = false;
    _notify();
    if (!_started) return;
    try {
      await _service.pause();
    } catch (_) {
      reportError();
    }
  }

  Future<void> stop() async {
    if (_disposed) return;
    _generation++;
    _playRequest++;
    _wantsPlay = false;
    playing = false;
    loading = false;
    buffering = false;
    completed = false;
    stopped = true;
    error = null;
    position = Duration.zero;
    _notify();
    try {
      await _service.stop();
    } catch (_) {
      reportError();
    }
  }

  Future<void> next() async {
    if (_disposed) return;
    final selected = _order.next(
      repeatAll: _repeatMode == PlaybackRepeatMode.all,
    );
    if (selected != null) await _select(selected);
  }

  Future<void> previous() async {
    if (_disposed) return;
    final selected = _order.previous();
    if (selected != null) await _select(selected);
  }

  Future<void> seek(Duration value) async {
    if (_disposed || song == null || loading || stopped || error != null) {
      return;
    }
    final generation = _generation;
    final request = ++_seekRequest;
    final milliseconds = value.inMilliseconds.clamp(
      0,
      duration?.inMilliseconds ?? 0,
    );
    try {
      await _service.seek(Duration(milliseconds: milliseconds));
      if (_disposed || generation != _generation) return;
      if (request != _seekRequest) return;
      position = Duration(milliseconds: milliseconds);
      completed = duration != null && position >= duration!;
      if (!completed) _completionArmed = true;
      _notify();
    } catch (_) {
      if (generation == _generation) reportError();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _playRequest++;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_service.dispose().catchError((Object _) {}));
    super.dispose();
  }
}
