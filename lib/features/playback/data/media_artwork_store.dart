import 'dart:io';

import 'package:device_audio_query/device_audio_query.dart';
import 'package:path_provider/path_provider.dart';

import '../../library/data/music_library_service.dart';
import '../../library/logic/song_details.dart';

abstract class MediaArtworkStore {
  Future<Uri?> artwork(SongModel song);
  Future<void> clear();
}

/// Ponte do cache LRU de bytes para artUri, sem alterar o cache da biblioteca.
class CachedMediaArtworkStore implements MediaArtworkStore {
  CachedMediaArtworkStore(
    this.library, {
    Future<Directory> Function()? directory,
  }) : _directory = directory ?? getTemporaryDirectory;
  final MusicLibraryService library;
  final Future<Directory> Function() _directory;
  Future<void> _pending = Future.value();
  Directory? _folder;
  int _epoch = 0;
  final Map<SongArtworkKey, File> _files = {};
  @override
  Future<Uri?> artwork(SongModel song) {
    final epoch = _epoch;
    // Consulta nativa e gravação nunca bloqueiam o carregamento do áudio.
    final result = _pending
        .then((_) async {
          if (epoch != _epoch) {
            return null;
          }
          final key = song.artworkKey;
          final cached = _files.remove(key);
          if (cached != null) {
            _files[key] = cached;
            return cached.uri;
          }
          final bytes = await library.artwork(song);
          if (bytes == null ||
              bytes.isEmpty ||
              bytes.length > 8 * 1024 * 1024 ||
              epoch != _epoch) {
            return null;
          }
          _folder ??= await _createFolder();
          final file = File(
            '${_folder!.path}/${song.id}_${DateTime.now().microsecondsSinceEpoch}.img',
          );
          await file.writeAsBytes(bytes, flush: true);
          if (epoch != _epoch) {
            await file.delete();
            return null;
          }
          _files[key] = file;
          // No máximo oito capas, cada uma com no máximo 8 MiB.
          while (_files.length > 8) {
            final old = _files.remove(_files.keys.first)!;
            try {
              await old.delete();
            } catch (_) {}
          }
          return file.uri;
        })
        .catchError((Object _) => null);
    _pending = result.then<void>((_) {});
    return result;
  }

  Future<Directory> _createFolder() async {
    final folder = Directory('${(await _directory()).path}/riko_media_artwork');
    // Remove apenas nosso diretório privado de capas da sessão anterior.
    if (await folder.exists()) await folder.delete(recursive: true);
    return folder.create(recursive: true);
  }

  @override
  Future<void> clear() {
    _epoch++;
    final clearing = _pending.then((_) async {
      _files.clear();
      final folder = _folder;
      _folder = null;
      if (folder != null) {
        try {
          await folder.delete(recursive: true);
        } catch (_) {}
      }
    });
    _pending = clearing;
    return clearing;
  }
}
