import 'dart:async';

import 'package:device_audio_query/device_audio_query.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../library/logic/song_details.dart';
import '../models/playlist.dart';
import '../models/playlist_track.dart';
import 'playlists_database.dart';

abstract class PlaylistsRepository {
  Stream<void> get changes;
  Future<List<Playlist>> list();
  Future<PlaylistDetails?> read(String id);
  Future<Playlist> create(String name);
  Future<void> rename(String id, String name);
  Future<void> delete(String id);
  Future<int> add(String id, List<SongModel> songs);
  Future<void> remove(String id, String entryId);
  Future<void> move(String id, String entryId, {String? beforeEntryId});
  Future<void> sort(
    String id,
    PlaylistSort sort, {
    Map<String, SongModel> catalog = const {},
  });
  Future<void> close();
}

class SqlitePlaylistsRepository implements PlaylistsRepository {
  SqlitePlaylistsRepository(this.database);
  final PlaylistsDatabase database;
  final _changes = StreamController<void>.broadcast();
  final _uuid = const Uuid();
  bool _closed = false;
  @override
  Stream<void> get changes => _changes.stream;
  @override
  Future<List<Playlist>> list() async {
    final db = await database.open();
    final rows = await db.rawQuery("""
      SELECT p.*, COUNT(t.id) AS track_count FROM playlists p
      LEFT JOIN playlist_tracks t ON t.playlist_id = p.id
      GROUP BY p.id ORDER BY p.created_at DESC, p.id
    """);
    return List.unmodifiable(rows.map(Playlist.fromMap));
  }

  @override
  Future<PlaylistDetails?> read(String id) async {
    final db = await database.open();
    return db.transaction((tx) async {
      final rows = await tx.query(
        'playlists',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) return null;
      final tracks = await _tracks(tx, id);
      return PlaylistDetails(
        Playlist.fromMap({...rows.single, 'track_count': tracks.length}),
        tracks,
      );
    });
  }

  Future<List<PlaylistTrack>> _tracks(DatabaseExecutor tx, String id) async =>
      (await tx.query(
        'playlist_tracks',
        where: 'playlist_id = ?',
        whereArgs: [id],
        orderBy: 'position, id',
      )).map(PlaylistTrack.fromMap).toList();
  Future<void> _exists(Transaction tx, String id) async {
    if ((await tx.query(
      'playlists',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
    )).isEmpty) {
      throw const PlaylistException('Esta playlist não existe mais.');
    }
  }

  Future<T> _write<T>(Future<T> Function(Transaction) action) async {
    final db = await database.open();
    final result = await db.transaction(action);
    if (!_closed) _changes.add(null);
    return result;
  }

  Future<void> _touch(Transaction tx, String id) async {
    await tx.update(
      'playlists',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<Playlist> create(String name) async {
    final normalized = validatePlaylistName(name);
    final now = DateTime.now().millisecondsSinceEpoch;
    final playlist = Playlist(
      id: _uuid.v4(),
      name: normalized,
      createdAt: now,
      updatedAt: now,
    );
    await _write(
      (tx) => tx.insert('playlists', {
        'id': playlist.id,
        'name': normalized,
        'created_at': now,
        'updated_at': now,
      }),
    );
    return playlist;
  }

  @override
  Future<void> rename(String id, String name) {
    final normalized = validatePlaylistName(name);
    return _write((tx) async {
      await _exists(tx, id);
      await tx.update(
        'playlists',
        {'name': normalized},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _touch(tx, id);
    });
  }

  @override
  Future<void> delete(String id) => _write((tx) async {
    await _exists(tx, id);
    await tx.delete('playlists', where: 'id = ?', whereArgs: [id]);
  });
  @override
  Future<int> add(String id, List<SongModel> songs) {
    final snapshot = List<SongModel>.of(songs);
    return _write((tx) async {
      await _exists(tx, id);
      final entries = await _tracks(tx, id);
      final existing = entries.map((entry) => entry.uri).toSet();
      var added = 0;
      for (final song in snapshot) {
        final uri = Uri.tryParse(song.uri ?? '');
        if (uri == null ||
            uri.scheme != 'content' ||
            uri.authority != 'media' ||
            uri.pathSegments.isEmpty) {
          throw const PlaylistException(
            'Uma música não tem uma referência válida do Android.',
          );
        }
        if (!existing.add(uri.toString())) continue;
        await tx.insert('playlist_tracks', {
          'id': _uuid.v4(),
          'playlist_id': id,
          'media_uri': uri.toString(),
          'media_id': song.id,
          'position': entries.length + added,
          'title': song.title,
          'artist': song.artist,
          'album': song.album,
          'duration': song.duration,
          'size': song.size,
          'date_added': song.dateAdded,
        });
        added++;
      }
      if (added > 0) await _touch(tx, id);
      return added;
    });
  }

  /// Desloca todas as posições para uma faixa livre antes de normalizar.
  /// Preserva UNIQUE(playlist_id, position) durante cada UPDATE.
  Future<void> _order(
    Transaction tx,
    String id,
    List<PlaylistTrack> entries,
  ) async {
    if (entries.isNotEmpty) {
      final max =
          (await tx.rawQuery(
                'SELECT MAX(position) AS p FROM playlist_tracks WHERE playlist_id = ?',
                [id],
              )).single['p']
              as int;
      await tx.rawUpdate(
        'UPDATE playlist_tracks SET position = position + ? WHERE playlist_id = ?',
        [max + entries.length + 1, id],
      );
      final batch = tx.batch();
      for (var i = 0; i < entries.length; i++) {
        batch.update(
          'playlist_tracks',
          {'position': i},
          where: 'id = ? AND playlist_id = ?',
          whereArgs: [entries[i].id, id],
        );
      }
      await batch.commit(noResult: true);
    }
    await _touch(tx, id);
  }

  @override
  Future<void> remove(String id, String entryId) => _write((tx) async {
    await _exists(tx, id);
    await tx.delete(
      'playlist_tracks',
      where: 'id = ? AND playlist_id = ?',
      whereArgs: [entryId, id],
    );
    await _order(tx, id, await _tracks(tx, id));
  });
  @override
  Future<void> move(String id, String entryId, {String? beforeEntryId}) =>
      _write((tx) async {
        await _exists(tx, id);
        final entries = await _tracks(tx, id);
        final index = entries.indexWhere((entry) => entry.id == entryId);
        if (index < 0) {
          throw const PlaylistException(
            'A lista mudou. Atualize e tente novamente.',
          );
        }
        if (beforeEntryId == entryId) return;
        final moved = entries.removeAt(index);
        final target = beforeEntryId == null
            ? entries.length
            : entries.indexWhere((entry) => entry.id == beforeEntryId);
        if (target < 0) {
          throw const PlaylistException(
            'A lista mudou. Atualize e tente novamente.',
          );
        }
        entries.insert(target, moved);
        await _order(tx, id, entries);
      });
  @override
  Future<void> sort(
    String id,
    PlaylistSort sort, {
    Map<String, SongModel> catalog = const {},
  }) {
    final snapshot = Map<String, SongModel>.of(catalog);
    return _write((tx) async {
      await _exists(tx, id);
      final entries = await _tracks(tx, id);
      entries.sort((a, b) {
        final leftLive = snapshot[a.uri];
        final left = leftLive != null && a.references(leftLive)
            ? leftLive
            : a.snapshot;
        final rightLive = snapshot[b.uri];
        final right = rightLive != null && b.references(rightLive)
            ? rightLive
            : b.snapshot;
        final first =
            _key(
              sort == PlaylistSort.title
                  ? left.displayTitle
                  : left.displayArtist,
            ).compareTo(
              _key(
                sort == PlaylistSort.title
                    ? right.displayTitle
                    : right.displayArtist,
              ),
            );
        if (first != 0) return first;
        final title = _key(left.displayTitle)
            .compareTo(_key(right.displayTitle));
        return title != 0 ? title : a.position.compareTo(b.position);
      });
      await _order(tx, id, entries);
    });
  }

  String _key(String text) {
    const accents = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const plain = 'aaaaaeeeeiiiiooooouuuuc';
    final lower = text.toLowerCase();
    return String.fromCharCodes(
      lower.runes.map((rune) {
        final index = accents.indexOf(String.fromCharCode(rune));
        return index < 0 ? rune : plain.codeUnitAt(index);
      }),
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await database.close();
    await _changes.close();
  }
}
