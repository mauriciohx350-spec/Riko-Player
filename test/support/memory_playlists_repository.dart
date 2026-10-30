import 'dart:async';

import 'package:device_audio_query/device_audio_query.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riko_player/features/playlists/data/playlists_repository.dart';
import 'package:riko_player/features/playlists/models/playlist.dart';
import 'package:riko_player/features/playlists/models/playlist_track.dart';

/// Double em memória para testes de widgets; o SQL real tem testes separados.
class MemoryPlaylistsRepository extends Fake implements PlaylistsRepository {
  final Map<String, PlaylistDetails> data = {};
  final _changes = StreamController<void>.broadcast();
  int _id = 0;
  bool failWrites = false;
  bool failReads = false;
  @override
  Stream<void> get changes => _changes.stream;
  void _check() {
    if (failWrites) throw StateError('disco indisponível');
  }

  void _emit() => _changes.add(null);
  @override
  Future<List<Playlist>> list() async {
    if (failReads) throw StateError('leitura indisponível');
    return data.values
        .map(
          (details) => Playlist(
            id: details.playlist.id,
            name: details.playlist.name,
            createdAt: 0,
            updatedAt: 0,
            trackCount: details.tracks.length,
          ),
        )
        .toList();
  }

  @override
  Future<PlaylistDetails?> read(String id) async {
    if (failReads) throw StateError('leitura indisponível');
    return data[id];
  }

  @override
  Future<Playlist> create(String name) async {
    _check();
    final playlist = Playlist(
      id: 'playlist-${_id++}',
      name: validatePlaylistName(name),
      createdAt: 0,
      updatedAt: 0,
    );
    data[playlist.id] = PlaylistDetails(playlist, []);
    _emit();
    return playlist;
  }

  @override
  Future<void> rename(String id, String name) async {
    _check();
    final details = data[id]!;
    data[id] = PlaylistDetails(
      Playlist(
        id: id,
        name: validatePlaylistName(name),
        createdAt: 0,
        updatedAt: 0,
      ),
      details.tracks,
    );
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    _check();
    data.remove(id);
    _emit();
  }

  @override
  Future<int> add(String id, List<SongModel> songs) async {
    _check();
    final details = data[id]!;
    final tracks = details.tracks.toList();
    var count = 0;
    for (final song in songs) {
      if (tracks.any((entry) => entry.uri == song.uri)) continue;
      tracks.add(
        PlaylistTrack(
          id: 'entry-${_id++}',
          playlistId: id,
          uri: song.uri!,
          mediaId: song.id,
          position: tracks.length,
          title: song.title,
          artist: song.artist,
          duration: song.duration,
        ),
      );
      count++;
    }
    data[id] = PlaylistDetails(details.playlist, tracks);
    _emit();
    return count;
  }

  @override
  Future<void> remove(String id, String entryId) async {
    _check();
    final details = data[id]!;
    data[id] = PlaylistDetails(
      details.playlist,
      details.tracks.where((entry) => entry.id != entryId).toList(),
    );
    _emit();
  }

  @override
  Future<void> move(String id, String entryId, {String? beforeEntryId}) async {
    _check();
    final details = data[id]!;
    final tracks = details.tracks.toList();
    final entry = tracks.firstWhere((entry) => entry.id == entryId);
    tracks.remove(entry);
    tracks.insert(
      beforeEntryId == null
          ? tracks.length
          : tracks.indexWhere((entry) => entry.id == beforeEntryId),
      entry,
    );
    data[id] = PlaylistDetails(details.playlist, tracks);
    _emit();
  }

  @override
  Future<void> sort(
    String id,
    PlaylistSort sort, {
    Map<String, SongModel> catalog = const {},
  }) async {
    _check();
    final details = data[id]!;
    final tracks = details.tracks.toList()
      ..sort(
        (a, b) => (sort == PlaylistSort.title ? a.title : a.artist ?? '')
            .compareTo(sort == PlaylistSort.title ? b.title : b.artist ?? ''),
      );
    data[id] = PlaylistDetails(details.playlist, tracks);
    _emit();
  }

  @override
  Future<void> close() => _changes.close();
}
