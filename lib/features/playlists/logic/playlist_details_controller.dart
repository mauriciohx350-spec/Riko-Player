import 'dart:async';

import 'package:device_audio_query/device_audio_query.dart';

import '../data/playlists_repository.dart';
import '../models/playlist_track.dart';
import 'playlists_controller.dart';

class PlaylistDetailsController extends PlaylistActionController {
  PlaylistDetailsController(this.repository, this.id) {
    _subscription = repository.changes.listen((_) => unawaited(load()));
  }
  final PlaylistsRepository repository;
  final String id;
  late final StreamSubscription<void> _subscription;
  PlaylistDetails? details;
  @override
  String get readFailure => 'Não foi possível carregar esta playlist.';
  @override
  Future<void> fetch() async {
    final result = await repository.read(id);
    if (!disposed) details = result;
  }

  Future<int?> add(List<SongModel> songs) async {
    int? count;
    return await act(() async {
          count = await repository.add(id, songs);
        })
        ? count
        : null;
  }

  Future<bool> remove(String entryId) =>
      act(() => repository.remove(id, entryId));

  /// onReorderItem já fornece o índice final após retirar o item antigo.
  Future<bool> move(int oldIndex, int newIndex) async {
    final entries = details?.tracks.toList();
    if (entries == null ||
        oldIndex < 0 ||
        oldIndex >= entries.length ||
        newIndex < 0 ||
        newIndex >= entries.length) {
      return false;
    }
    final entry = entries.removeAt(oldIndex);
    entries.insert(newIndex, entry);
    final before = newIndex + 1 < entries.length
        ? entries[newIndex + 1].id
        : null;
    return act(() => repository.move(id, entry.id, beforeEntryId: before));
  }

  Future<bool> sort(PlaylistSort sort, Map<String, SongModel> catalog) =>
      act(() => repository.sort(id, sort, catalog: catalog));
  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
