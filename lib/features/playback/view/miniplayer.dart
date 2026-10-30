import 'package:flutter/material.dart';

import '../../library/logic/song_details.dart';
import '../../library/view/widgets/song_artwork.dart';
import 'playback_controls.dart';
import 'playback_page.dart';
import 'playback_scope.dart';

class Miniplayer extends StatelessWidget {
  const Miniplayer({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = PlaybackScope.of(context);
    final controller = scope.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final song = controller.song;
        final duration = controller.duration?.inMilliseconds ?? 0;
        final progress = duration > 0
            ? (controller.position.inMilliseconds / duration).clamp(0.0, 1.0)
            : 0.0;
        final colors = Theme.of(context).colorScheme;
        return AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.bottomCenter,
          child: song == null
              ? const SizedBox.shrink()
              : Material(
                  color: colors.surfaceContainer,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PlaybackPage(),
                            ),
                          );
                        },
                        child: SafeArea(
                          top: false,
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                            child: Row(
                              children: [
                                SongArtwork(
                                  song: song,
                                  service: scope.libraryService,
                                  size: 44,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        song.displayTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        controller.error != null
                                            ? 'Falha ao reproduzir • toque para abrir'
                                            : song.displayArtist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                PlaybackControls(
                                  controller: controller,
                                  compact: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      LinearProgressIndicator(
                        key: const ValueKey('miniplayer-progress'),
                        value: progress,
                        minHeight: 2,
                        color: colors.primary,
                        backgroundColor: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.zero,
                        stopIndicatorColor: Colors.transparent,
                        trackGap: 0,
                        semanticsLabel: 'Progresso da música',
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
