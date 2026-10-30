class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.trackCount = 0,
  });
  final String id;
  final String name;
  final int createdAt;
  final int updatedAt;
  final int trackCount;
  factory Playlist.fromMap(Map<String, Object?> row) => Playlist(
    id: row['id'] as String,
    name: row['name'] as String,
    createdAt: row['created_at'] as int,
    updatedAt: row['updated_at'] as int,
    trackCount: (row['track_count'] as int?) ?? 0,
  );
}

class PlaylistException implements Exception {
  const PlaylistException(this.message);
  final String message;
  @override
  String toString() => message;
}

String validatePlaylistName(String value) {
  final name = value.trim();
  if (name.isEmpty) {
    throw const PlaylistException('Digite um nome para a playlist.');
  }
  if (name.runes.length > 100) {
    throw const PlaylistException('Use no máximo 100 caracteres.');
  }
  return name;
}
