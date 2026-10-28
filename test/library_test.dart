import 'dart:async';
import 'dart:typed_data';

import 'package:device_audio_query/device_audio_query.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riko_player/core/theme/app_theme.dart';
import 'package:riko_player/features/library/data/music_library_service.dart';
import 'package:riko_player/features/library/logic/library_controller.dart';
import 'package:riko_player/features/library/logic/song_details.dart';
import 'package:riko_player/features/library/view/library_content.dart';
import 'package:riko_player/features/library/view/widgets/song_tile.dart';

// Dados restritos aos testes; o aplicativo consulta somente o MediaStore.
const tracks = [
  SongModel(id: 1, title: 'Canção do vento', artist: 'Ana', duration: 185000),
  SongModel(id: 2, title: 'Horizonte', artist: 'Banda Lua', duration: 61000),
];

class TestMusicService extends MusicLibraryService {
  PermissionStatus permission = PermissionStatus.granted;
  List<SongModel> result = tracks;
  Completer<List<SongModel>>? pending;
  bool fail = false;
  bool settingsOpened = false;
  int clearCount = 0;
  @override
  void clearArtwork() {
    clearCount++;
    super.clearArtwork();
  }

  int queryCount = 0;
  int requestCount = 0;

  @override
  bool get isSupported => true;

  @override
  Future<PermissionStatus> access({required bool request}) async {
    if (request) requestCount++;
    return permission;
  }

  @override
  Future<List<SongModel>> songs() async {
    queryCount++;
    if (fail) throw StateError('Falha de leitura');
    return pending == null ? result : pending!.future;
  }

  @override
  Future<Uint8List?> artwork(SongModel song) async => null;

  @override
  Future<bool> openSettings() async {
    settingsOpened = true;
    return true;
  }
}

Widget screen(TestMusicService service) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: LibraryContent(service: service)),
);

void main() {
  test(
    'Pesquisa título e artista, preservando a pesquisa na atualização',
    () async {
      final service = TestMusicService();
      final controller = LibraryController(service);
      addTearDown(controller.dispose);
      await controller.load(requestPermission: true);
      expect(controller.status, LibraryStatus.ready);
      controller.search(' CANÇÃO ');
      expect(controller.songs.single.id, 1);
      controller.search('banda LUA');
      expect(controller.songs.single.id, 2);
      service.result = const [tracksFirst];
      await controller.load();
      expect(controller.songs, isEmpty);
      controller.search('');
      expect(controller.songs.single.id, 1);
      expect(service.requestCount, 1);
    },
  );

  test('Permissão negada impede consulta e pode ser recuperada', () async {
    final service = TestMusicService()
      ..permission = PermissionStatus.deniedForever;
    final controller = LibraryController(service);
    addTearDown(controller.dispose);
    await controller.load(requestPermission: true);
    expect(controller.status, LibraryStatus.denied);
    expect(controller.permanentlyDenied, isTrue);
    expect(service.queryCount, 0);
    await controller.openSettings();
    expect(service.settingsOpened, isTrue);
    service.permission = PermissionStatus.granted;
    await controller.load();
    expect(controller.status, LibraryStatus.ready);
    expect(controller.songs.length, 2);
  });

  test('Erro de consulta permite tentar novamente', () async {
    final service = TestMusicService()..fail = true;
    final controller = LibraryController(service);
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.status, LibraryStatus.error);
    service.fail = false;
    service.result = [];
    await controller.load();
    expect(controller.status, LibraryStatus.ready);
    expect(controller.isEmpty, isTrue);
  });

  test('Ignora consultas simultâneas e conclusão após descarte', () async {
    final service = TestMusicService()..pending = Completer<List<SongModel>>();
    final controller = LibraryController(service);
    final loading = controller.load();
    await Future<void>.delayed(Duration.zero);
    await controller.load();
    expect(service.queryCount, 1);
    controller.dispose();
    service.pending!.complete(tracks);
    await loading;
  });

  test('Formata duração e metadados ausentes', () {
    expect(tracks.first.formattedDuration, '3:05');
    expect(
      const SongModel(id: 3, title: '', duration: 3601000).formattedDuration,
      '60:01',
    );
    const missing = SongModel(id: 4, title: '', artist: '<unknown>');
    expect(missing.displayTitle, 'Música sem título');
    expect(missing.displayArtist, 'Artista desconhecido');
    expect(missing.formattedDuration, '--:--');
  });

  testWidgets('Exibe carregamento, músicas, duração e ícone sem capa', (
    tester,
  ) async {
    final service = TestMusicService()..pending = Completer<List<SongModel>>();
    await tester.pumpWidget(screen(service));
    await tester.pump();
    expect(find.text('Buscando suas músicas…'), findsOneWidget);
    service.pending!.complete(tracks);
    await tester.pumpAndSettle();
    expect(find.text('Canção do vento'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('3:05'), findsOneWidget);
    expect(find.byIcon(Icons.music_note), findsNWidgets(2));
    await tester.enterText(find.byType(TextField), 'lua');
    await tester.pumpAndSettle();
    expect(find.text('Horizonte'), findsOneWidget);
    expect(find.text('Canção do vento'), findsNothing);
    await tester.enterText(find.byType(TextField), 'inexistente');
    await tester.pumpAndSettle();
    expect(find.text('Nenhum resultado para a pesquisa'), findsOneWidget);
  });

  testWidgets('Atualização manual encontra músicas adicionadas', (
    tester,
  ) async {
    final service = TestMusicService()..result = [];
    await tester.pumpWidget(screen(service));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma música encontrada'), findsOneWidget);
    service.result = tracks;
    await tester.tap(find.byTooltip('Atualizar biblioteca'));
    await tester.pumpAndSettle();
    expect(find.text('Horizonte'), findsOneWidget);
    expect(service.queryCount, 2);
  });

  testWidgets('Permissão negada e erro têm ações de recuperação', (
    tester,
  ) async {
    final service = TestMusicService()..permission = PermissionStatus.denied;
    await tester.pumpWidget(screen(service));
    await tester.pumpAndSettle();
    expect(find.text('Permita o acesso às suas músicas'), findsOneWidget);
    await tester.tap(find.text('Abrir configurações'));
    await tester.pumpAndSettle();
    expect(service.settingsOpened, isTrue);
    service.permission = PermissionStatus.granted;
    service.fail = true;
    await tester.tap(find.text('Permitir acesso'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível ler as músicas'), findsOneWidget);
    service.fail = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Horizonte'), findsOneWidget);
  });

  testWidgets('Retorno ao aplicativo atualiza sem pedir permissão novamente', (
    tester,
  ) async {
    final service = TestMusicService();
    await tester.pumpWidget(screen(service));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(service.queryCount, 2);
    expect(service.requestCount, 1);
  });

  testWidgets('Mantém lista e estado durante atualização e filtragem', (
    tester,
  ) async {
    final service = TestMusicService();
    await tester.pumpWidget(screen(service));
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey(2));
    final original = tester.state(tile);
    service.pending = Completer<List<SongModel>>();
    await tester.tap(find.byTooltip('Atualizar biblioteca'));
    await tester.pump();
    expect(find.text('Horizonte'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.state(tile), same(original));
    await tester.enterText(find.byType(TextField), 'lua');
    await tester.pump();
    expect(tester.state(tile), same(original));
    service.pending!.complete([
      SongModel(id: 1, title: tracks[0].title, artist: tracks[0].artist),
      SongModel(id: 2, title: tracks[1].title, artist: tracks[1].artist),
    ]);
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.state(tile), same(original));
    // Limpar a pesquisa altera novamente o índice do item preservado.
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(tester.state(tile), same(original));
  });

  testWidgets('Revogação remove lista existente e limpa capas', (tester) async {
    final service = TestMusicService();
    await tester.pumpWidget(screen(service));
    await tester.pumpAndSettle();
    service.permission = PermissionStatus.denied;
    await tester.tap(find.byTooltip('Atualizar biblioteca'));
    await tester.pumpAndSettle();
    expect(find.text('Horizonte'), findsNothing);
    expect(find.byType(SongTile), findsNothing);
    expect(find.text('Permita o acesso às suas músicas'), findsOneWidget);
    expect(service.clearCount, 1);
    expect(service.queryCount, 1);
  });

  testWidgets('Atualização para biblioteca vazia remove itens antigos', (
    tester,
  ) async {
    final service = TestMusicService();
    await tester.pumpWidget(screen(service));
    await tester.pumpAndSettle();
    service.result = [];
    await tester.tap(find.byTooltip('Atualizar biblioteca'));
    await tester.pumpAndSettle();
    expect(find.byType(SongTile), findsNothing);
    expect(find.text('Nenhuma música encontrada'), findsOneWidget);
  });

  testWidgets('Falha de atualização preserva o tratamento de erro', (
    tester,
  ) async {
    final service = TestMusicService();
    await tester.pumpWidget(screen(service));
    await tester.pumpAndSettle();
    service.fail = true;
    await tester.tap(find.byTooltip('Atualizar biblioteca'));
    await tester.pumpAndSettle();
    expect(find.byType(SongTile), findsNothing);
    expect(find.text('Não foi possível ler as músicas'), findsOneWidget);
    expect(service.clearCount, 1);
  });

  test('Revogação durante consulta não restaura músicas antigas', () async {
    final service = TestMusicService();
    final controller = LibraryController(service);
    addTearDown(controller.dispose);
    await controller.load();
    service.pending = Completer<List<SongModel>>();
    final updating = controller.load();
    await Future<void>.delayed(Duration.zero);
    expect(controller.isRefreshing, isTrue);
    expect(controller.songs.length, 2);
    service.permission = PermissionStatus.denied;
    service.pending!.complete(tracks);
    await updating;
    expect(controller.status, LibraryStatus.denied);
    expect(controller.songs, isEmpty);
    expect(service.clearCount, 1);
  });
}

const tracksFirst = SongModel(
  id: 1,
  title: 'Canção do vento',
  artist: 'Ana',
  duration: 185000,
);
