import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:device_audio_query/device_audio_query.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:riko_player/features/playlists/data/playlists_database.dart';
import 'package:riko_player/features/playlists/data/playlists_repository.dart';
import 'package:riko_player/features/playlists/models/playlist.dart';
import 'package:riko_player/features/playlists/models/playlist_track.dart';
import 'package:riko_player/features/playlists/logic/playlist_details_controller.dart';
import 'package:riko_player/features/playlists/logic/playlist_song_resolver.dart';
import 'package:riko_player/features/library/logic/library_controller.dart';
import 'package:riko_player/features/playback/logic/playback_controller.dart';

import 'library_test.dart' show TestMusicService;
import 'playback_test.dart' show FakePlaybackService;

const playlistSongs = [
  SongModel(
    id: 1,
    title: 'Zebra',
    artist: 'Banda',
    uri: 'content://media/external/audio/media/1',
    dateAdded: 10,
  ),
  SongModel(
    id: 2,
    title: 'Água',
    artist: 'Zélia',
    uri: 'content://media/external/audio/media/2',
  ),
  SongModel(
    id: 3,
    title: 'Beco',
    artist: 'Ana',
    uri: 'content://media/external/audio/media/3',
  ),
];

class RetryDatabaseFactory extends Fake implements DatabaseFactory {
  RetryDatabaseFactory(this.delegate);
  final DatabaseFactory delegate;
  bool fail = true;
  @override
  Future<Database> openDatabase(
    String path, {
    OpenDatabaseOptions? options,
  }) async {
    if (fail) {
      fail = false;
      throw StateError('falha temporária');
    }
    return delegate.openDatabase(path, options: options);
  }
}

void main() {
  sqfliteFfiInit();
  late Directory folder;
  late PlaylistsDatabase database;
  late SqlitePlaylistsRepository repository;

  test('shuffle keeps SQLite order and active traversal isolated from playlist edits', () async {
    final playlist = await repository.create('Shuffle');
    await repository.add(playlist.id, playlistSongs);
    final library = LibraryController(
      TestMusicService()..result = playlistSongs,
    );
    final playback = PlaybackController(
      FakePlaybackService(),
      random: Random(41),
    );
    final reference = PlaybackController(
      FakePlaybackService(),
      random: Random(41),
    );
    addTearDown(library.dispose);
    addTearDown(playback.dispose);
    addTearDown(reference.dispose);
    await library.load();
    final original = (await repository.read(playlist.id))!.tracks;
    playback.setShuffle(true);
    reference.setShuffle(true);
    await PlaylistSongResolver().play(original, library, playback);
    await reference.playQueue(playlistSongs, 0);
    expect(
      (await repository.read(playlist.id))!.tracks.map((e) => e.id),
      original.map((e) => e.id),
    );
    final queue = playback.queue;
    await repository.sort(playlist.id, PlaylistSort.title);
    expect((await repository.read(playlist.id))!.tracks.first.mediaId, 2);
    await repository.rename(playlist.id, 'Edited');
    await repository.remove(playlist.id, original[1].id);
    await repository.delete(playlist.id);
    expect(playback.queue, same(queue));
    expect(playback.queue, playlistSongs);
    while (reference.hasNext) {
      await playback.next();
      await reference.next();
      expect(playback.index, reference.index);
    }
    expect(playback.hasNext, isFalse);
    await playback.previous();
    await reference.previous();
    expect(playback.index, reference.index);
    expect(playback.queue, playlistSongs);
  });

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('riko_playlists_test_');
    database = PlaylistsDatabase(
      factory: databaseFactoryFfi,
      path: '${folder.path}/playlists.db',
    );
    repository = SqlitePlaylistsRepository(database);
  });
  tearDown(() async {
    await repository.close();
    await folder.delete(recursive: true);
  });

  test('falha ao abrir permite nova tentativa sem apagar dados', () async {
    final factory = RetryDatabaseFactory(databaseFactoryFfi);
    final db = PlaylistsDatabase(
      factory: factory,
      path: '${folder.path}/retry.db',
    );
    await expectLater(db.open(), throwsStateError);
    final connection = await db.open();
    expect(
      (await connection.rawQuery('PRAGMA foreign_keys')).single.values.single,
      1,
    );
    await db.close();
  });
  test(
    'ordenação usa metadados atuais apenas para a mesma referência',
    () async {
      final playlist = await repository.create('Referências');
      await repository.add(playlist.id, playlistSongs);
      await repository.sort(
        playlist.id,
        PlaylistSort.title,
        catalog: {
          playlistSongs[0].uri!: SongModel(
            id: 1,
            title: 'AAA',
            uri: playlistSongs[0].uri,
            dateAdded: 999,
          ),
          playlistSongs[2].uri!: SongModel(
            id: 3,
            title: 'Zulu',
            uri: playlistSongs[2].uri,
          ),
        },
      );
      expect(
        (await repository.read(playlist.id))!.tracks
            .map((entry) => entry.mediaId),
        [2, 1, 3],
      );
    },
  );
  test('nomes válidos, UUIDs estáveis e nomes repetidos permitidos', () async {
    final first = await repository.create('  Viagem  ');
    final second = await repository.create('Viagem');
    expect(first.name, 'Viagem');
    expect(first.id, isNot(second.id));
    expect(first.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
    await repository.rename(first.id, 'Estrada');
    expect((await repository.read(first.id))?.playlist.name, 'Estrada');
    expect(() => validatePlaylistName(' '), throwsA(isA<PlaylistException>()));
    expect(
      () => validatePlaylistName('x' * 101),
      throwsA(isA<PlaylistException>()),
    );
  });
  test('persiste músicas e ordem após fechar e reabrir o banco', () async {
    final playlist = await repository.create('Favoritas');
    await repository.add(playlist.id, playlistSongs);
    final entries = (await repository.read(playlist.id))!.tracks;
    await repository.move(
      playlist.id,
      entries.last.id,
      beforeEntryId: entries.first.id,
    );
    final originalIds = (await repository.read(playlist.id))!.tracks
        .map((entry) => entry.id)
        .toList();
    await repository.close();
    database = PlaylistsDatabase(
      factory: databaseFactoryFfi,
      path: '${folder.path}/playlists.db',
    );
    repository = SqlitePlaylistsRepository(database);
    final loaded = (await repository.read(playlist.id))!;
    expect(loaded.tracks.map((entry) => entry.mediaId), [3, 1, 2]);
    expect(loaded.tracks.map((entry) => entry.id), originalIds);
    expect(loaded.tracks.map((entry) => entry.position), [0, 1, 2]);
    expect((await repository.list()).single.trackCount, 3);
  });
  test(
    'ativa FK, recusa órfãos e duplicatas SQL, e exclui entradas em cascata',
    () async {
      final playlist = await repository.create('Teste');
      await repository.add(playlist.id, playlistSongs);
      final db = await database.open();
      expect(
        (await db.rawQuery('PRAGMA foreign_keys')).single.values.single,
        1,
      );
      final row = (await db.query('playlist_tracks')).first;
      await expectLater(
        db.insert('playlist_tracks', {
          ...row,
          'id': 'orphan',
          'playlist_id': 'missing',
        }),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        db.insert('playlist_tracks', {
          ...row,
          'id': 'duplicate',
          'position': 10,
        }),
        throwsA(isA<DatabaseException>()),
      );
      await repository.delete(playlist.id);
      expect(await db.query('playlist_tracks'), isEmpty);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );
  test('adição múltipla ignora duplicatas no lote e entre lotes', () async {
    final playlist = await repository.create('Teste');
    expect(
      await repository.add(playlist.id, [
        playlistSongs[0],
        playlistSongs[0],
        playlistSongs[1],
      ]),
      2,
    );
    expect(await repository.add(playlist.id, playlistSongs), 1);
    final entries = (await repository.read(playlist.id))!.tracks;
    expect(entries.map((entry) => entry.mediaId), [1, 2, 3]);
    expect(entries.map((entry) => entry.position), [0, 1, 2]);
  });
  test('falha no meio do lote faz rollback de todas as inserções', () async {
    final playlist = await repository.create('Teste');
    await expectLater(
      repository.add(playlist.id, [
        playlistSongs.first,
        const SongModel(id: 99, title: 'Inválida', data: '/storage/a.mp3'),
      ]),
      throwsA(isA<PlaylistException>()),
    );
    expect((await repository.read(playlist.id))!.tracks, isEmpty);
  });
  test('ordena por título e artista e normaliza posições ao remover', () async {
    final playlist = await repository.create('Teste');
    await repository.add(playlist.id, playlistSongs);
    await repository.sort(playlist.id, PlaylistSort.title);
    expect(
      (await repository.read(playlist.id))!.tracks
          .map((entry) => entry.mediaId),
      [2, 3, 1],
    );
    await repository.sort(playlist.id, PlaylistSort.artist);
    var entries = (await repository.read(playlist.id))!.tracks;
    expect(entries.map((entry) => entry.mediaId), [3, 1, 2]);
    await repository.remove(playlist.id, entries[1].id);
    entries = (await repository.read(playlist.id))!.tracks;
    expect(entries.map((entry) => entry.position), [0, 1]);
    expect(entries.map((entry) => entry.mediaId), [3, 2]);
  });
  test(
    'reordenação por índices finais usa a posição corrigida do Flutter',
    () async {
      final playlist = await repository.create('Teste');
      await repository.add(playlist.id, playlistSongs);
      final details = PlaylistDetailsController(repository, playlist.id);
      addTearDown(details.dispose);
      await details.load();
      expect(await details.move(0, 2), isTrue);
      expect(details.details!.tracks.map((entry) => entry.mediaId), [2, 3, 1]);
      expect(await details.move(2, 0), isTrue);
      expect(details.details!.tracks.map((entry) => entry.mediaId), [1, 2, 3]);
    },
  );
  test(
    'repositórios concorrentes preservam adições, duplicatas e renomeação',
    () async {
      final playlist = await repository.create('Teste');
      final other = SqlitePlaylistsRepository(
        PlaylistsDatabase(
          factory: databaseFactoryFfi,
          path: '${folder.path}/playlists.db',
        ),
      );
      // singleInstance compartilha a conexão; fechamos só depois de todas as operações.
      await Future.wait([
        repository.add(playlist.id, playlistSongs),
        other.add(playlist.id, playlistSongs),
        repository.rename(playlist.id, 'Novo nome'),
      ]);
      final loaded = (await repository.read(playlist.id))!;
      expect(loaded.playlist.name, 'Novo nome');
      expect(loaded.tracks.length, 3);
      expect(loaded.tracks.map((entry) => entry.position).toSet(), {0, 1, 2});
      await other.close();
    },
  );
  test('mover e adicionar concorrentemente preserva a música nova', () async {
    final playlist = await repository.create('Teste');
    await repository.add(playlist.id, playlistSongs.take(2).toList());
    final before = (await repository.read(playlist.id))!.tracks;
    await Future.wait([
      repository.add(playlist.id, [playlistSongs.last]),
      repository.move(
        playlist.id,
        before.last.id,
        beforeEntryId: before.first.id,
      ),
    ]);
    expect(
      (await repository.read(playlist.id))!.tracks
          .map((entry) => entry.mediaId),
      [2, 1, 3],
    );
    await expectLater(
      repository.move(playlist.id, before.first.id, beforeEntryId: 'removed'),
      throwsA(isA<PlaylistException>()),
    );
    expect(
      (await repository.read(playlist.id))!.tracks
          .map((entry) => entry.mediaId),
      [2, 1, 3],
    );
  });
  test('resolver não considera ausência em carregamento, erro ou falta de permissão', () async {
    final playlist = await repository.create('Teste');
    await repository.add(playlist.id, playlistSongs);
    final entries = (await repository.read(playlist.id))!.tracks;
    final service = TestMusicService()..result = playlistSongs;
    final library = LibraryController(service);
    addTearDown(library.dispose);
    final resolver = PlaylistSongResolver();
    expect(
      resolver
          .resolve(entries, library)
          .every((entry) => entry.status == PlaylistSongStatus.checking),
      isTrue,
    );
    await library.load();
    library.search('nenhum resultado');
    expect(library.songs, isEmpty);
    expect(
      resolver
          .resolve(entries, library)
          .every((entry) => entry.status == PlaylistSongStatus.available),
      isTrue,
    );
    service.pending = Completer<List<SongModel>>();
    final loading = library.load();
    expect(
      resolver.resolve(entries, library).first.status,
      PlaylistSongStatus.checking,
    );
    service.pending!.complete([]);
    await loading;
    expect(
      resolver
          .resolve(entries, library)
          .every((entry) => entry.status == PlaylistSongStatus.unavailable),
      isTrue,
    );
    service.permission = PermissionStatus.denied;
    await library.load();
    expect(
      resolver.resolve(entries, library).first.status,
      PlaylistSongStatus.checking,
    );
    service.permission = PermissionStatus.granted;
    service.fail = true;
    await library.load();
    expect(
      resolver.resolve(entries, library).first.status,
      PlaylistSongStatus.checking,
    );
    expect((await repository.read(playlist.id))!.tracks.length, 3);
  });
  test(
    'música ausente é preservada; começar no meio ignora ausentes e isola fila',
    () async {
      final playlist = await repository.create('Teste');
      await repository.add(playlist.id, playlistSongs);
      final service = TestMusicService()
        ..result = [playlistSongs[0], playlistSongs[2]];
      final library = LibraryController(service);
      final playbackService = FakePlaybackService();
      final playback = PlaybackController(playbackService);
      addTearDown(library.dispose);
      addTearDown(playback.dispose);
      await library.load();
      final resolver = PlaylistSongResolver();
      var entries = (await repository.read(playlist.id))!.tracks;
      expect(
        await resolver.play(
          entries,
          library,
          playback,
          startingEntryId: entries.last.id,
        ),
        1,
      );
      expect(playback.queue.map((song) => song.id), [1, 3]);
      expect(playback.index, 1);
      await repository.sort(playlist.id, PlaylistSort.artist);
      await repository.remove(playlist.id, entries.first.id);
      await repository.delete(playlist.id);
      expect(playback.queue.map((song) => song.id), [1, 3]);
      expect(playback.song?.id, 3);
      service.result = [];
      await library.load();
      await expectLater(
        resolver.play(entries, library, playback),
        throwsA(isA<PlaylistException>()),
      );
      expect(playback.queue.map((song) => song.id), [1, 3]);
    },
  );
  test(
    'reutilização suspeita do ID não associa outro arquivo por nome',
    () async {
      final playlist = await repository.create('Teste');
      await repository.add(playlist.id, [playlistSongs.first]);
      final library = LibraryController(
        TestMusicService()
          ..result = [
            SongModel(
              id: 1,
              title: 'Zebra',
              uri: playlistSongs.first.uri,
              dateAdded: 99,
            ),
          ],
      );
      addTearDown(library.dispose);
      await library.load();
      final entries = (await repository.read(playlist.id))!.tracks;
      expect(
        PlaylistSongResolver().resolve(entries, library).single.status,
        PlaylistSongStatus.unavailable,
      );
    },
  );
}
