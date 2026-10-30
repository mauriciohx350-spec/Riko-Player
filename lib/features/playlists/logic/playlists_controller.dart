import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/playlists_repository.dart';
import '../models/playlist.dart';

/// Releituras concorrentes são agrupadas, sem permitir que uma resposta antiga
/// substitua outra. Uma alteração durante a leitura solicita mais uma passagem.
abstract class PlaylistActionController extends ChangeNotifier {
  bool loading = false;
  bool busy = false;
  bool hasLoaded = false;
  String? error;
  bool disposed = false;
  bool _reload = false;
  Future<void>? _loading;
  String get readFailure;
  Future<void> fetch();
  void changed() {
    if (!disposed) notifyListeners();
  }

  Future<void> load() {
    if (disposed) return Future.value();
    hasLoaded = true;
    _reload = true;
    return _loading ??= _drain();
  }

  Future<void> _drain() async {
    loading = true;
    changed();
    try {
      while (_reload && !disposed) {
        _reload = false;
        error = null;
        try {
          await fetch();
        } catch (_) {
          if (!disposed) error = readFailure;
        }
      }
    } finally {
      _loading = null;
      loading = false;
      changed();
    }
  }

  Future<bool> act(Future<void> Function() action) async {
    if (disposed || busy) return false;
    busy = true;
    error = null;
    changed();
    try {
      await action();
      if (!disposed) await load();
      return true;
    } catch (e) {
      if (!disposed) {
        error = e is PlaylistException
            ? e.message
            : 'Não foi possível salvar a playlist. Tente novamente.';
      }
      return false;
    } finally {
      busy = false;
      changed();
    }
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class PlaylistsController extends PlaylistActionController {
  PlaylistsController(this.repository) {
    _subscription = repository.changes.listen((_) {
      if (hasLoaded) unawaited(load());
    });
  }
  final PlaylistsRepository repository;
  late final StreamSubscription<void> _subscription;
  List<Playlist> playlists = const [];
  @override
  String get readFailure => 'Não foi possível carregar as playlists.';
  @override
  Future<void> fetch() async {
    final result = await repository.list();
    if (!disposed) playlists = List.unmodifiable(result);
  }

  Future<Playlist?> create(String name) async {
    Playlist? result;
    return await act(() async {
          result = await repository.create(name);
        })
        ? result
        : null;
  }

  Future<bool> rename(String id, String name) =>
      act(() => repository.rename(id, name));
  Future<bool> delete(String id) => act(() => repository.delete(id));
  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
