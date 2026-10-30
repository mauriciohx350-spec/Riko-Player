import 'package:flutter/material.dart';

import '../../library/logic/song_details.dart';
import '../../library/view/widgets/song_artwork.dart';
import '../logic/playback_controller.dart';
import 'playback_controls.dart';
import 'playback_scope.dart';

class PlaybackPage extends StatelessWidget {
  const PlaybackPage({super.key});
  @override
  Widget build(BuildContext context) {
    final scope = PlaybackScope.of(context);
    final controller = scope.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Reproduzindo agora')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final song = controller.song;
            if (song == null) {
              return const Center(child: Text('Nenhuma música selecionada'));
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final size = (constraints.maxWidth - 48).clamp(
                  100.0,
                  (constraints.maxHeight * 0.42).clamp(100.0, 340.0),
                );
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        children: [
                          SongArtwork(
                            song: song,
                            service: scope.libraryService,
                            size: size,
                          ),
                          const SizedBox(height: 28),
                          Text(
                            song.displayTitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            song.displayArtist,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 24),
                          PlaybackProgress(
                            key: ValueKey((song.id, controller.index)),
                            controller: controller,
                          ),
                          const SizedBox(height: 16),
                          PlaybackControls(controller: controller),
                          if (controller.error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  controller.error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class PlaybackProgress extends StatefulWidget {
  const PlaybackProgress({super.key, required this.controller});
  final PlaybackController controller;
  @override
  State<PlaybackProgress> createState() => _PlaybackProgressState();
}

class _PlaybackProgressState extends State<PlaybackProgress> {
  double? _drag;
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final max = controller.duration?.inMilliseconds.toDouble() ?? 0;
    final enabled = max > 0 && !controller.loading && controller.error == null;
    final value = (_drag ?? controller.position.inMilliseconds.toDouble())
        .clamp(0.0, max > 0 ? max : 1.0);
    return Column(
      children: [
        Slider(
          label: playbackTime(Duration(milliseconds: value.round())),
          semanticFormatterCallback: (value) =>
              playbackTime(Duration(milliseconds: value.round())),
          value: value,
          max: max > 0 ? max : 1,
          onChangeStart: enabled
              ? (value) => setState(() => _drag = value)
              : null,
          onChanged: enabled ? (value) => setState(() => _drag = value) : null,
          onChangeEnd: enabled
              ? (value) {
                  setState(() => _drag = null);
                  controller.seek(Duration(milliseconds: value.round()));
                }
              : null,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(playbackTime(Duration(milliseconds: value.round()))),
            Text(playbackTime(controller.duration)),
          ],
        ),
      ],
    );
  }
}
