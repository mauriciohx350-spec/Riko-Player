import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:device_audio_query/device_audio_query.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riko_player/features/playback/data/media_artwork_store.dart';

import 'library_test.dart' show TestMusicService;
import 'playback_test.dart' show songs;

class ArtworkLibrary extends TestMusicService {
  int reads = 0;
  Completer<Uint8List?>? pendingArtwork;
  @override
  Future<Uint8List?> artwork(SongModel song) async {
    reads++;
    return pendingArtwork == null
        ? Uint8List.fromList([1, 2, 3])
        : pendingArtwork!.future;
  }
}

void main() {
  late Directory root;
  late ArtworkLibrary library;
  late CachedMediaArtworkStore store;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('riko_artwork_test_');
    library = ArtworkLibrary();
    store = CachedMediaArtworkStore(library, directory: () async => root);
  });
  tearDown(() async {
    await store.clear();
    await root.delete(recursive: true);
  });
  test('reutiliza arquivo e limita capas de notificação', () async {
    final first = await store.artwork(songs.first);
    expect(await File.fromUri(first!).readAsBytes(), [1, 2, 3]);
    expect(await store.artwork(songs.first), first);
    expect(library.reads, 1);
    for (var id = 2; id <= 10; id++) {
      await store.artwork(SongModel(id: id, title: 'Faixa'));
    }
    final folder = Directory('${root.path}/riko_media_artwork');
    expect(await folder.list().length, 8);
    expect(await File.fromUri(first).exists(), isFalse);
    await store.clear();
    expect(await folder.exists(), isFalse);
  });
  test(
    'clear invalida consulta pendente e próxima capa pode ser gravada',
    () async {
      library.pendingArtwork = Completer<Uint8List?>();
      final old = store.artwork(songs.first);
      await Future<void>.delayed(Duration.zero);
      final clearing = store.clear();
      library.pendingArtwork!.complete(Uint8List.fromList([4]));
      expect(await old, isNull);
      await clearing;
      library.pendingArtwork = null;
      expect(await store.artwork(songs[1]), isNotNull);
    },
  );
}
