import 'package:device_audio_query/device_audio_query.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

import '../logic/song_details.dart';
import 'artwork_cache.dart';

/// Isola o acesso ao MediaStore e às permissões da interface.
class MusicLibraryService {
  final DeviceAudioQuery _query = DeviceAudioQuery();

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<PermissionStatus> access({required bool request}) async {
    final status = await _query.checkPermission();
    if (status == PermissionStatus.granted || !request) return status;
    // O plugin seleciona READ_MEDIA_AUDIO na API 33+ e
    // READ_EXTERNAL_STORAGE nas APIs anteriores, sem pedir imagens ou escrita.
    return _query.requestPermission();
  }

  Future<List<SongModel>> songs() => _query.querySongs();

  final _artworkCache = ArtworkCache<SongArtworkKey>();

  Future<Uint8List?> artwork(SongModel song) =>
      _artworkCache.get(song.artworkKey, () => _loadArtwork(song));

  // Mantém capas inalteradas e invalida músicas removidas ou modificadas.
  void retainArtworkFor(List<SongModel> songs) =>
      _artworkCache.retainKeys(songs.map((song) => song.artworkKey).toSet());

  void clearArtwork() => _artworkCache.clear();

  Future<Uint8List?> _loadArtwork(SongModel song) async {
    try {
      final audio = await _query.queryArtwork(
        id: song.id,
        type: ArtworkType.audio,
      );
      if (audio != null && audio.isNotEmpty) return audio;
      final albumId = song.albumId;
      if (albumId == null || albumId <= 0) return null;
      return await _query.queryArtwork(id: albumId, type: ArtworkType.album);
    } catch (_) {
      // Uma capa ausente ou ilegível não impede a exibição da música.
      return null;
    }
  }

  Future<bool> openSettings() => permissions.openAppSettings();
}
