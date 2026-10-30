import 'package:flutter/widgets.dart';

import '../../library/data/music_library_service.dart';
import '../logic/playback_controller.dart';

class PlaybackScope extends InheritedWidget {
  const PlaybackScope({
    super.key,
    required this.controller,
    required this.libraryService,
    required super.child,
  });
  final PlaybackController controller;
  final MusicLibraryService libraryService;
  static PlaybackScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlaybackScope>();
  static PlaybackScope of(BuildContext context) => maybeOf(context)!;
  @override
  bool updateShouldNotify(PlaybackScope oldWidget) =>
      controller != oldWidget.controller ||
      libraryService != oldWidget.libraryService;
}
