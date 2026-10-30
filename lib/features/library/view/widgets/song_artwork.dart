import 'dart:typed_data';

import 'package:device_audio_query/device_audio_query.dart';
import 'package:flutter/material.dart';

import '../../data/music_library_service.dart';
import '../../logic/song_details.dart';

/// Compartilha o cache existente e mantém o Future entre reconstruções.
class SongArtwork extends StatefulWidget {
  const SongArtwork({
    super.key,
    required this.song,
    required this.service,
    this.size = 52,
  });
  final SongModel song;
  final MusicLibraryService service;
  final double size;
  @override
  State<SongArtwork> createState() => _SongArtworkState();
}

class _SongArtworkState extends State<SongArtwork> {
  late Future<Uint8List?> _artwork;
  @override
  void initState() {
    super.initState();
    _artwork = widget.service.artwork(widget.song);
  }

  @override
  void didUpdateWidget(covariant SongArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.artworkKey != widget.song.artworkKey ||
        oldWidget.service != widget.service) {
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
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox.square(
          dimension: widget.size,
          child: FutureBuilder<Uint8List?>(
            future: _artwork,
            builder: (context, snapshot) {
              // Não exibe a capa da faixa anterior enquanto a nova carrega.
              final bytes = snapshot.connectionState == ConnectionState.done
                  ? snapshot.data
                  : null;
              if (bytes == null || bytes.isEmpty) return placeholder;
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                cacheWidth:
                    (widget.size * MediaQuery.devicePixelRatioOf(context))
                        .round()
                        .clamp(1, 1200),
                errorBuilder: (context, error, stack) => placeholder,
              );
            },
          ),
        ),
      ),
    );
  }
}
