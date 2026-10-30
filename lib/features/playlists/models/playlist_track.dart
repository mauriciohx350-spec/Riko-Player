import 'package:device_audio_query/device_audio_query.dart';

import 'playlist.dart';

class PlaylistTrack {
  const PlaylistTrack({
    required this.id,
    required this.playlistId,
    required this.uri,
    required this.mediaId,
    required this.position,
    required this.title,
    this.artist,
    this.album,
    this.duration,
    this.size,
    this.dateAdded,
  });
  final String id;
  final String playlistId;
  final String uri;
  final int mediaId;
  final int position;
  final String title;
  final String? artist;
  final String? album;
  final int? duration;
  final int? size;
  final int? dateAdded;
  factory PlaylistTrack.fromMap(Map<String, Object?> row) => PlaylistTrack(
    id: row['id'] as String,
    playlistId: row['playlist_id'] as String,
    uri: row['media_uri'] as String,
    mediaId: row['media_id'] as int,
    position: row['position'] as int,
    title: row['title'] as String,
    artist: row['artist'] as String?,
    album: row['album'] as String?,
    duration: row['duration'] as int?,
    size: row['size'] as int?,
    dateAdded: row['date_added'] as int?,
  );
  bool references(SongModel song) =>
      song.uri == uri &&
      song.id == mediaId &&
      (dateAdded == null ||
          song.dateAdded == null ||
          dateAdded == song.dateAdded);

  SongModel get snapshot => SongModel(
    id: mediaId,
    title: title,
    artist: artist,
    album: album,
    uri: uri,
    duration: duration,
    size: size,
    dateAdded: dateAdded,
  );
}

class PlaylistDetails {
  PlaylistDetails(this.playlist, List<PlaylistTrack> tracks)
    : tracks = List.unmodifiable(tracks);
  final Playlist playlist;
  final List<PlaylistTrack> tracks;
}

enum PlaylistSort { title, artist }
