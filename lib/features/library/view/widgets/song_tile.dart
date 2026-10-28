import 'dart:typed_data';

import 'package:device_audio_query/device_audio_query.dart';
import 'package:flutter/material.dart';

import '../../data/music_library_service.dart';
import '../../logic/song_details.dart';

class SongTile extends StatefulWidget {
  const SongTile({super.key, required this.song, required this.service});

  final SongModel song;
  final MusicLibraryService service;

  @override
  State<SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<SongTile> {
  late Future<Uint8List?> _artwork;

  @override
  void initState() {
    super.initState();
    _artwork = widget.service.artwork(widget.song);
  }

  @override
  void didUpdateWidget(covariant SongTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song != widget.song || oldWidget.service != widget.service) {
      _artwork = widget.service.artwork(widget.song);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(child: Icon(Icons.music_note, color: colors.primary)),
    );
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox.square(
            dimension: 52,
            child: FutureBuilder<Uint8List?>(
              future: _artwork,
              builder: (context, snapshot) {
                final bytes = snapshot.data;
                if (bytes == null || bytes.isEmpty) return placeholder;
                return Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  cacheWidth: 156,
                  errorBuilder: (context, error, stack) => placeholder,
                );
              },
            ),
          ),
        ),
      ),
      title: Text(
        widget.song.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        widget.song.displayArtist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        widget.song.formattedDuration,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
