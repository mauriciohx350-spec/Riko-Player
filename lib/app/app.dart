import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/library/data/music_library_service.dart';
import '../features/library/view/library_page.dart';
import '../features/playback/data/audio_playback_service.dart';
import '../features/playback/logic/playback_controller.dart';
import '../features/playback/logic/playback_runtime.dart';
import '../features/playback/view/playback_scope.dart';

class RikoPlayerApp extends StatefulWidget {
  const RikoPlayerApp({
    super.key,
    this.runtime,
    this.playbackService,
    this.libraryService,
  });
  final PlaybackRuntime? runtime;
  final PlaybackService? playbackService;
  final MusicLibraryService? libraryService;
  @override
  State<RikoPlayerApp> createState() => _RikoPlayerAppState();
}

class _RikoPlayerAppState extends State<RikoPlayerApp> {
  late final PlaybackController _playback;
  late final MusicLibraryService _library;
  @override
  void initState() {
    super.initState();
    _playback =
        widget.runtime?.controller ??
        PlaybackController(widget.playbackService ?? AudioPlaybackService());
    _library =
        widget.runtime?.library ??
        widget.libraryService ??
        MusicLibraryService();
  }

  @override
  void dispose() {
    // Em produção, o serviço continua mesmo sem interface anexada.
    if (widget.runtime == null) {
      _playback.dispose();
      _library.clearArtwork();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PlaybackScope(
    controller: _playback,
    libraryService: _library,
    child: MaterialApp(
      title: 'Riko Player',
      debugShowCheckedModeBanner: false,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const LibraryPage(),
    ),
  );
}
