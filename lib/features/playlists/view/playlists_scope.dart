import 'package:flutter/widgets.dart';

import '../../library/logic/library_controller.dart';
import '../logic/playlists_controller.dart';

class PlaylistsScope extends InheritedWidget {
  const PlaylistsScope({
    super.key,
    required this.controller,
    required this.library,
    required super.child,
  });
  final PlaylistsController controller;
  final LibraryController library;
  static PlaylistsScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlaylistsScope>();
  static PlaylistsScope of(BuildContext context) => maybeOf(context)!;
  @override
  bool updateShouldNotify(PlaylistsScope oldWidget) =>
      controller != oldWidget.controller || library != oldWidget.library;
}
