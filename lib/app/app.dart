import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/library/data/music_library_service.dart';
import '../features/library/view/library_page.dart';
import '../features/playback/data/audio_playback_service.dart';
import '../features/playback/logic/playback_controller.dart';
import '../features/playback/view/playback_scope.dart';

class RikoPlayerApp extends StatefulWidget {
  const RikoPlayerApp({super.key, this.playbackService, this.libraryService});
  final PlaybackService? playbackService;
  final MusicLibraryService? libraryService;
  @override
  State<RikoPlayerApp> createState() => _RikoPlayerAppState();
}

class _RikoPlayerAppState extends State<RikoPlayerApp>
    with WidgetsBindingObserver {
  late final PlaybackController _playback;
  late final MusicLibraryService _library;
  @override
  void initState() {
    super.initState();
    _playback = PlaybackController(
      widget.playbackService ?? AudioPlaybackService(),
    );
    _library = widget.libraryService ?? MusicLibraryService();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _playback.dispose();
    } else {
      _playback.setForeground(state == AppLifecycleState.resumed);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playback.dispose();
    _library.clearArtwork();
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
