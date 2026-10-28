import 'package:device_audio_query/device_audio_query.dart';

typedef SongArtworkKey = (int, int?, int?, int?, String?);

extension SongDetails on SongModel {
  SongArtworkKey get artworkKey => (id, albumId, dateModified, size, data);

  String get displayTitle =>
      title.trim().isEmpty || title == 'Unknown' ? 'Música sem título' : title;

  String get displayArtist {
    final name = artist?.trim();
    return name == null ||
            name.isEmpty ||
            name == '<unknown>' ||
            name.toLowerCase() == 'unknown'
        ? 'Artista desconhecido'
        : name;
  }

  String get formattedDuration {
    if (duration == null || duration! < 0) return '--:--';
    final seconds = duration! ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
