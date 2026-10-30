import 'package:flutter/material.dart';

import '../../../library/data/music_library_service.dart';
import '../../../library/logic/song_details.dart';
import '../../../library/view/widgets/song_artwork.dart';
import '../../logic/playlist_song_resolver.dart';

class PlaylistTrackTile extends StatelessWidget {
  const PlaylistTrackTile({
    super.key,
    required this.track,
    required this.service,
    required this.index,
    required this.busy,
    required this.onPlay,
    required this.onRemove,
  });
  final ResolvedPlaylistTrack track;
  final MusicLibraryService service;
  final int index;
  final bool busy;
  final VoidCallback onPlay;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) {
    final song = track.displaySong;
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 12, right: 4),
      leading: track.song == null
          ? SizedBox.square(
              dimension: 44,
              child: Icon(
                Icons.music_note_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : SongArtwork(song: song, service: service, size: 44),
      title: Text(
        song.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        switch (track.status) {
          PlaylistSongStatus.available => song.displayArtist,
          PlaylistSongStatus.checking => 'Aguardando biblioteca',
          PlaylistSongStatus.unavailable =>
            'Música indisponível • ${song.displayArtist}',
        },
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: !busy && track.status == PlaylistSongStatus.available
          ? onPlay
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Remover da playlist',
            onPressed: busy ? null : onRemove,
            icon: const Icon(Icons.remove_circle_outline, size: 22),
          ),
          ReorderableDragStartListener(
            index: index,
            enabled: !busy,
            child: const SizedBox(
              width: 40,
              height: 48,
              child: Tooltip(
                message: 'Reorganizar música',
                child: Icon(Icons.drag_handle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
