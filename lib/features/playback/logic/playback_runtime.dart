import 'package:flutter/foundation.dart';

import 'dart:async';

import 'package:audio_service/audio_service.dart';

import '../../library/data/music_library_service.dart';
import '../data/audio_playback_service.dart';
import '../data/media_artwork_store.dart';
import '../data/riko_audio_handler.dart';
import 'playback_controller.dart';

/// Vive no engine do serviço, não na Activity ou nas rotas Flutter.
class PlaybackRuntime {
  PlaybackRuntime(this.controller, this.library, this.handler);
  static Future<PlaybackRuntime>? _initialization;
  final PlaybackController controller;
  final MusicLibraryService library;
  final RikoAudioHandler handler;
  StreamSubscription<Object>? _errors;

  static Future<PlaybackRuntime> initialize() =>
      _initialization ??= _initialize();
  static Future<PlaybackRuntime> _initialize() async {
    final library = MusicLibraryService();
    final controller = PlaybackController(AudioPlaybackService());
    try {
      final handler = await AudioService.init(
        builder: () =>
            RikoAudioHandler(controller, CachedMediaArtworkStore(library)),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.example.riko_player.playback',
          androidNotificationChannelName: 'Reprodução de músicas',
          androidNotificationChannelDescription: 'Controles do Riko Player',
          androidNotificationIcon: 'drawable/audio_service_play_arrow',
          androidNotificationOngoing: false,
          // Mantém a sessão apta a retomar pela notificação após pausas longas.
          // stop/dispensar notificação encerra o serviço e libera recursos.
          androidStopForegroundOnPause: false,
          artDownscaleWidth: 512,
          artDownscaleHeight: 512,
        ),
      );
      final runtime = PlaybackRuntime(controller, library, handler);
      runtime._errors = AudioService.asyncError.listen((error) {
        if (error.toString().toLowerCase().contains('foreground')) {
          controller.reportError();
        } else {
          debugPrint('Falha na integração de mídia: $error');
        }
      });
      return runtime;
    } catch (_) {
      controller.dispose();
      rethrow;
    }
  }

  Future<void> close() async {
    await _errors?.cancel();
    await handler.close();
    library.clearArtwork();
  }
}
