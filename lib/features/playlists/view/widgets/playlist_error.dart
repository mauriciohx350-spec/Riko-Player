import 'package:flutter/material.dart';

class PlaylistError extends StatelessWidget {
  const PlaylistError({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
      ],
    ),
  );
}
