import 'package:sqflite/sqflite.dart';

/// Conexão injetável para executar o mesmo SQL no Android e nos testes FFI.
class PlaylistsDatabase {
  PlaylistsDatabase({DatabaseFactory? factory, this.path = 'riko_playlists.db'})
    : factory = factory ?? databaseFactorySqflitePlugin;
  final DatabaseFactory factory;
  final String path;
  Future<Database>? _opening;
  bool _closed = false;
  Future<Database> open() {
    if (_closed) throw StateError('Banco de playlists encerrado');
    return _opening ??= _open();
  }

  Future<Database> _open() async {
    try {
      return await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
            final enabled = await db.rawQuery('PRAGMA foreign_keys');
            if (enabled.single.values.single != 1) {
              throw StateError('Integridade referencial indisponível');
            }
          },
          onCreate: (db, version) async {
            await db.execute("""
          CREATE TABLE playlists (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 100),
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        """);
            await db.execute("""
          CREATE TABLE playlist_tracks (
            id TEXT PRIMARY KEY NOT NULL,
            playlist_id TEXT NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
            media_uri TEXT NOT NULL,
            media_id INTEGER NOT NULL,
            position INTEGER NOT NULL CHECK(position >= 0),
            title TEXT NOT NULL,
            artist TEXT,
            album TEXT,
            duration INTEGER,
            size INTEGER,
            date_added INTEGER,
            UNIQUE(playlist_id, media_uri),
            UNIQUE(playlist_id, position)
          )
        """);
          },
          onOpen: (db) async {
            if ((await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
              throw StateError('Banco de playlists inconsistente');
            }
          },
        ),
      );
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await (await _opening)?.close();
  }
}
