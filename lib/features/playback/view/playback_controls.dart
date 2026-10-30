import 'package:flutter/material.dart';

import '../logic/playback_controller.dart';

class PlaybackControls extends StatelessWidget {
  const PlaybackControls({
    super.key,
    required this.controller,
    this.compact = false,
  });
  final PlaybackController controller;
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        tooltip: 'Música anterior',
        onPressed: controller.previous,
        icon: Icon(Icons.skip_previous_rounded, size: compact ? 26 : 36),
      ),
      IconButton.filled(
        tooltip: controller.error != null
            ? 'Tentar novamente'
            : controller.playing
            ? 'Pausar'
            : 'Reproduzir',
        onPressed: controller.loading ? null : controller.toggle,
        icon: controller.loading && !compact
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                controller.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: compact ? 26 : 40,
              ),
      ),
      IconButton(
        tooltip: 'Próxima música',
        onPressed: controller.hasNext ? controller.next : null,
        icon: Icon(Icons.skip_next_rounded, size: compact ? 26 : 36),
      ),
    ],
  );
}

String playbackTime(Duration? duration) {
  if (duration == null) return '--:--';
  final seconds = duration.inSeconds.clamp(0, 999999999);
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
