import 'package:device_audio_query/device_audio_query.dart';
import 'package:flutter/material.dart';

import '../../data/music_library_service.dart';
import '../../logic/song_details.dart';
import 'song_artwork.dart';

class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.service,
    this.onTap,
  });
  final SongModel song;
  final MusicLibraryService service;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    leading: SongArtwork(song: song, service: service),
    title: Text(
      song.displayTitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: Text(
      song.displayArtist,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: Text(
      song.formattedDuration,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}
