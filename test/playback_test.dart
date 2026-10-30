import 'dart:async';

import 'package:device_audio_query/device_audio_query.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riko_player/features/playback/data/audio_playback_service.dart';
import 'package:riko_player/features/playback/logic/playback_controller.dart';

class FakePlaybackService implements PlaybackService {
  final state = StreamController<PlaybackEvent>.broadcast(sync: true);
  final progress = StreamController<Duration>.broadcast(sync: true);
  final length = StreamController<Duration?>.broadcast(sync: true);
  final failures = StreamController<Object>.broadcast(sync: true);
  final loaded = <Uri>[];
  int plays = 0;
  int pauses = 0;
  int disposals = 0;
  Duration? sought;
  bool fail = false;
  Completer<Duration?>? pending;
  @override
  Stream<PlaybackEvent> get events => state.stream;
  @override
  Stream<Duration> get positions => progress.stream;
  @override
  Stream<Duration?> get durations => length.stream;
  @override
  Stream<Object> get errors => failures.stream;
  @override
  Future<Duration?> load(Uri uri) async {
    loaded.add(uri);
    if (fail) throw StateError('arquivo ausente');
    return pending == null ? const Duration(seconds: 60) : pending!.future;
  }

  @override
  Future<void> play() async {
    plays++;
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> seek(Duration position) async {
    sought = position;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await state.close();
    await progress.close();
    await length.close();
    await failures.close();
  }
}

const songs = [
  SongModel(id: 1, title: 'Um', uri: 'content://media/external/audio/media/1'),
  SongModel(
    id: 2,
    title: 'Dois',
    uri: 'content://media/external/audio/media/2',
  ),
];
Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  late FakePlaybackService service;
  late PlaybackController controller;
  setUp(() {
    service = FakePlaybackService();
    controller = PlaybackController(service);
  });
  tearDown(() => controller.dispose());

  test('usa URI content e mantém cópia imutável da fila', () async {
    final visible = songs.toList();
    await controller.playQueue(visible, 0);
    visible.clear();
    expect(controller.queue.length, 2);
    expect(() => controller.queue.clear(), throwsUnsupportedError);
    expect(service.loaded.single.toString(), songs.first.uri);
    expect(controller.playing, isTrue);
    expect(controller.duration, const Duration(seconds: 60));
  });
  test('recusa caminho de arquivo sem URI do MediaStore', () async {
    await controller.playQueue([
      const SongModel(id: 3, title: 'Ausente', data: '/storage/music.mp3'),
    ], 0);
    expect(controller.error, isNotNull);
    expect(service.loaded, isEmpty);
    expect(controller.playing, isFalse);
  });
  test('pausa, continua, avança, volta e reinicia primeira faixa', () async {
    await controller.playQueue(songs, 0);
    await controller.toggle();
    expect(controller.playing, isFalse);
    await controller.toggle();
    expect(controller.playing, isTrue);
    await controller.next();
    expect(controller.index, 1);
    await controller.next();
    expect(controller.index, 1);
    await controller.previous();
    expect(controller.index, 0);
    await controller.previous();
    expect(controller.index, 0);
    expect(service.loaded.length, 4);
  });
  test('conclusão avança e última faixa termina sem repetir', () async {
    await controller.playQueue(songs, 0);
    service.state.add(const PlaybackEvent(PlaybackPhase.completed, true));
    await tick();
    expect(controller.index, 1);
    service.state.add(const PlaybackEvent(PlaybackPhase.completed, true));
    await tick();
    expect(controller.playing, isFalse);
    expect(controller.completed, isTrue);
    expect(service.loaded.length, 2);
    await controller.toggle();
    expect(service.sought, Duration.zero);
    expect(controller.playing, isTrue);
  });
  test('seek após conclusão preserva posição ao continuar', () async {
    await controller.playQueue(songs, 1);
    service.state.add(const PlaybackEvent(PlaybackPhase.completed, true));
    await tick();
    await controller.seek(const Duration(seconds: 30));
    expect(controller.completed, isFalse);
    await controller.toggle();
    expect(service.sought, const Duration(seconds: 30));
    expect(controller.playing, isTrue);
  });
  test('progresso e seek respeitam limites', () async {
    await controller.playQueue(songs, 0);
    service.progress.add(const Duration(seconds: 12));
    expect(controller.position.inSeconds, 12);
    await controller.seek(const Duration(seconds: 90));
    expect(service.sought?.inSeconds, 60);
    await controller.seek(const Duration(seconds: -1));
    expect(service.sought, Duration.zero);
    service.length.add(null);
    expect(controller.duration, isNull);
  });
  test('erro permite tentar novamente e avançar', () async {
    service.fail = true;
    await controller.playQueue(songs, 0);
    expect(controller.error, isNotNull);
    expect(controller.loading, isFalse);
    service.fail = false;
    await controller.toggle();
    expect(controller.error, isNull);
    service.failures.add(StateError('removido'));
    expect(controller.playing, isFalse);
    expect(controller.error, isNotNull);
    await controller.next();
    expect(controller.song?.id, 2);
    expect(controller.error, isNull);
  });
  test('seleção mais recente vence carregamento pendente', () async {
    service.pending = Completer<Duration?>();
    final first = controller.playQueue(songs, 0);
    await tick();
    final second = controller.playQueue(songs, 1);
    final pending = service.pending!;
    service.pending = null;
    pending.complete(const Duration(seconds: 20));
    await Future.wait([first, second]);
    expect(controller.song?.id, 2);
    expect(service.plays, 1);
  });
  test('segundo plano pausa inclusive durante carregamento', () async {
    service.pending = Completer<Duration?>();
    final loading = controller.playQueue(songs, 0);
    await tick();
    controller.setForeground(false);
    service.pending!.complete(const Duration(seconds: 60));
    await loading;
    expect(service.plays, 0);
    controller.setForeground(true);
    expect(controller.playing, isFalse);
    await controller.toggle();
    expect(service.plays, 1);
    controller.setForeground(false);
    expect(controller.playing, isFalse);
  });
  test('descarte é único e ignora conclusão pendente', () async {
    service.pending = Completer<Duration?>();
    final loading = controller.playQueue(songs, 0);
    await tick();
    controller.dispose();
    controller.dispose();
    service.pending!.complete(const Duration(seconds: 60));
    await loading;
    expect(service.disposals, 1);
    expect(service.plays, 0);
  });
}
