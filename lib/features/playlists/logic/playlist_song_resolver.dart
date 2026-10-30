import 'package:device_audio_query/device_audio_query.dart';

import '../../library/logic/library_controller.dart';
import '../../playback/logic/playback_controller.dart';
import '../models/playlist.dart';
import '../models/playlist_track.dart';

enum PlaylistSongStatus { checking, available, unavailable }

class ResolvedPlaylistTrack {
  const ResolvedPlaylistTrack(this.entry, this.status, this.song);
  final PlaylistTrack entry;
  final PlaylistSongStatus status;
  final SongModel? song;
  SongModel get displaySong => song ?? entry.snapshot;
}

class PlaylistSongResolver {
  List<ResolvedPlaylistTrack> resolve(
    List<PlaylistTrack> entries,
    LibraryController library,
  ) {
    final ready = library.status == LibraryStatus.ready && !library.isLoading;
    final catalog = ready
        ? {for (final song in library.allSongs) song.uri: song}
        : <String?, SongModel>{};
    return entries
        .map((entry) {
          if (!ready) {
            return ResolvedPlaylistTrack(
              entry,
              PlaylistSongStatus.checking,
              null,
            );
          }
          final song = catalog[entry.uri];
          final matches = song != null && entry.references(song);
          return ResolvedPlaylistTrack(
            entry,
            matches
                ? PlaylistSongStatus.available
                : PlaylistSongStatus.unavailable,
            matches ? song : null,
          );
        })
        .toList(growable: false);
  }

  /// Só o toque explícito altera a fila. Edições no banco não chamam o player.
  Future<int> play(
    List<PlaylistTrack> entries,
    LibraryController library,
    PlaybackController playback, {
    String? startingEntryId,
  }) async {
    if (library.status != LibraryStatus.ready || library.isLoading) {
      throw const PlaylistException(
        'Atualize a biblioteca e permita o acesso às músicas antes de reproduzir.',
      );
    }
    final resolved = resolve(entries, library);
    final available = resolved.where((item) => item.song != null).toList();
    if (available.isEmpty) {
      throw const PlaylistException(
        'Nenhuma música disponível nesta playlist.',
      );
    }
    final start = startingEntryId == null
        ? 0
        : available.indexWhere((item) => item.entry.id == startingEntryId);
    if (start < 0) {
      throw const PlaylistException('Esta música está indisponível.');
    }
    await playback.playQueue(
      available.map((item) => item.song!).toList(),
      start,
    );
    return entries.length - available.length;
  }
}
